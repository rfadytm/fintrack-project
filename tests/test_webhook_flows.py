"""'Simulasi' alur wizard bot v3 tanpa Telegram/Supabase asli — panggil handler
langsung dengan bot_state & DB yang di-mock. Ini pengganti round-trip webhook
nyata (tidak ada bot token/Supabase di lingkungan ini); lihat catatan yang sama
di e2e/README.md untuk keterbatasan serupa di sisi frontend.

Jalankan: python -m pytest tests/
"""
import os
import sys
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# See test_activity.py for why these are set-then-restored rather than left in os.environ.
_had_url = "SUPABASE_URL" in os.environ
_had_key = "SUPABASE_SERVICE_KEY" in os.environ
os.environ.setdefault("SUPABASE_URL", "https://test.supabase.co")
os.environ.setdefault("SUPABASE_SERVICE_KEY", "test-service-key")
try:
    from api.telegram import webhook  # noqa: E402
finally:
    if not _had_url:
        os.environ.pop("SUPABASE_URL", None)
    if not _had_key:
        os.environ.pop("SUPABASE_SERVICE_KEY", None)


class FakeState:
    """In-memory stand-in untuk bot_state — cukup untuk menguji transisi step."""

    def __init__(self):
        self.state = "IDLE"
        self.data = {}

    def get(self, user_id):
        return {"user_id": user_id, "state": self.state, "state_data": dict(self.data)}

    def set(self, user_id, state, state_data=None):
        self.state = state
        self.data = state_data or {}

    def reset(self, user_id):
        self.state = "IDLE"
        self.data = {}


def _mock_table(data=None):
    m = MagicMock()
    for method in ("select", "eq", "order", "limit", "like"):
        getattr(m, method).return_value = m
    result = MagicMock()
    result.data = data if data is not None else []
    m.execute.return_value = result
    m.insert.return_value.execute.return_value = result
    m.upsert.return_value.execute.return_value = result
    m.update.return_value.eq.return_value.execute.return_value = result
    return m


def test_goal_wizard_step_transitions():
    fs = FakeState()
    cash_table = _mock_table(data=[{"code": "1120", "account_name": "Kas Kecil"}])
    with patch.object(webhook, "get_state", side_effect=lambda uid: fs.get(uid)), patch.object(
        webhook, "set_state", side_effect=fs.set
    ), patch.object(webhook.tg, "send_message"), patch.object(
        webhook, "db", return_value=MagicMock(table=MagicMock(return_value=cash_table))
    ):
        webhook.cmd_goal_start(chat_id=1, user_id=1)
        assert fs.state == "GOAL_NAME"

        webhook.handle_goal_input(chat_id=1, user_id=1, state="GOAL_NAME", text="Laptop baru")
        assert fs.state == "GOAL_AMOUNT"
        assert fs.data["name"] == "Laptop baru"

        webhook.handle_goal_input(chat_id=1, user_id=1, state="GOAL_AMOUNT", text="10jt")
        assert fs.state == "GOAL_ACCOUNT"
        assert fs.data["target_amount"] == 10_000_000


def test_goal_wizard_rejects_invalid_amount():
    fs = FakeState()
    fs.set(1, "GOAL_AMOUNT", {"name": "Laptop"})
    sent = []
    with patch.object(webhook, "get_state", side_effect=lambda uid: fs.get(uid)), patch.object(
        webhook, "set_state", side_effect=fs.set
    ), patch.object(webhook.tg, "send_message", side_effect=lambda cid, text, **kw: sent.append(text)):
        webhook.handle_goal_input(chat_id=1, user_id=1, state="GOAL_AMOUNT", text="bukan angka")
    assert fs.state == "GOAL_AMOUNT"  # state tidak maju
    assert any("valid" in t.lower() or "⚠️" in t for t in sent)


def test_bill_wizard_final_step_inserts_row():
    fs = FakeState()
    fs.set(1, "BILL_DUE", {"name": "Listrik PLN", "amount": 150000})
    table = _mock_table()
    with patch.object(webhook, "get_state", side_effect=lambda uid: fs.get(uid)), patch.object(
        webhook, "set_state", side_effect=fs.set
    ), patch.object(webhook, "reset_state", side_effect=fs.reset), patch.object(
        webhook, "db", return_value=MagicMock(table=MagicMock(return_value=table))
    ), patch.object(webhook.tg, "send_message"):
        webhook.handle_bill_input(chat_id=1, user_id=1, state="BILL_DUE", text="15")
    table.insert.assert_called_once_with(
        {"name": "Listrik PLN", "amount": 150000, "due_day": 15, "is_recurring": True}
    )
    assert fs.state == "IDLE"  # reset_state dipanggil setelah sukses


def test_bill_wizard_rejects_out_of_range_due_day():
    fs = FakeState()
    fs.set(1, "BILL_DUE", {"name": "Listrik", "amount": 150000})
    sent = []
    with patch.object(webhook, "get_state", side_effect=lambda uid: fs.get(uid)), patch.object(
        webhook, "set_state", side_effect=fs.set
    ), patch.object(webhook.tg, "send_message", side_effect=lambda cid, text, **kw: sent.append(text)):
        webhook.handle_bill_input(chat_id=1, user_id=1, state="BILL_DUE", text="99")
    assert fs.state == "BILL_DUE"
    assert any("1-31" in t for t in sent)


def test_budget_set_valid():
    table = _mock_table(data=[{"code": "5110", "account_name": "Makan Harian"}])  # akun ditemukan
    with patch.object(webhook, "db", return_value=MagicMock(table=MagicMock(return_value=table))), patch.object(
        webhook.tg, "send_message"
    ) as send:
        webhook.cmd_budget_set(chat_id=1, args=["5110", "500000"])
    table.upsert.assert_called_once_with({"account_code": "5110", "monthly_limit": 500000})
    send.assert_called_once()
    assert "500.000" in send.call_args[0][1] or "500000" in send.call_args[0][1]


def test_budget_set_rejects_unknown_account():
    table = _mock_table(data=[])  # akun TIDAK ditemukan
    with patch.object(webhook, "db", return_value=MagicMock(table=MagicMock(return_value=table))), patch.object(
        webhook.tg, "send_message"
    ) as send:
        webhook.cmd_budget_set(chat_id=1, args=["9999999", "500000"])
    table.upsert.assert_not_called()
    send.assert_called_once()


def test_budget_set_missing_args_shows_usage():
    with patch.object(webhook.tg, "send_message") as send:
        webhook.cmd_budget_set(chat_id=1, args=["5110"])
    send.assert_called_once()
    assert "Format" in send.call_args[0][1]


def test_convert_command_success():
    with patch.object(webhook, "fx_convert", return_value=1_580_000.0), patch.object(
        webhook.tg, "send_message"
    ) as send:
        webhook.cmd_convert(chat_id=1, args=["100", "USD", "IDR"])
    send.assert_called_once()
    assert "1,580,000" in send.call_args[0][1] or "1580000" in send.call_args[0][1]


def test_convert_command_bad_amount():
    with patch.object(webhook.tg, "send_message") as send:
        webhook.cmd_convert(chat_id=1, args=["abc", "USD", "IDR"])
    send.assert_called_once()
    assert "tidak valid" in send.call_args[0][1].lower()


def test_exp_post_success_offers_continue_keyboard():
    """UX fix: after posting, user can start another transaction straight away
    instead of needing /menu or /start again."""
    fs = FakeState()
    fs.set(1, "EXPENSE_PREVIEW", {"account_code": "5130", "amount": 30000, "source": "1120", "desc": "Makan"})
    table = _mock_table(data=[{"balance": 470000}])
    sent = []
    cb = {"from": {"id": 1}, "message": {"chat": {"id": 1}, "message_id": 1}, "id": "cbid", "data": "exp_post"}
    with patch.object(webhook, "get_state", side_effect=lambda uid: fs.get(uid)), patch.object(
        webhook, "set_state", side_effect=fs.set
    ), patch.object(webhook, "reset_state", side_effect=fs.reset), patch.object(
        webhook, "post_journal", return_value="KK-0001"
    ), patch.object(webhook, "db", return_value=MagicMock(table=MagicMock(return_value=table))), patch.object(
        webhook, "check_budget_alert"
    ), patch.object(webhook.tg, "answer_callback"), patch.object(
        webhook.tg, "send_message", side_effect=lambda cid, text, **kw: sent.append((text, kw.get("keyboard")))
    ):
        webhook.handle_callback(cb)
    assert len(sent) == 1
    text, keyboard = sent[0]
    assert "Tercatat KK-0001" in text
    assert keyboard == webhook.continue_keyboard()


def test_act_menu_callback_sends_main_menu():
    cb = {"from": {"id": 1}, "message": {"chat": {"id": 1}, "message_id": 1}, "id": "cbid", "data": "act:menu"}
    with patch.object(webhook.tg, "answer_callback"), patch.object(webhook.tg, "send_message") as send:
        webhook.handle_callback(cb)
    send.assert_called_once()
    assert send.call_args.kwargs.get("keyboard") == webhook.main_menu()


def test_skip_during_expense_desc_advances_to_source():
    """Blindspot fix: "/skip" while filling in EXPENSE_DESC used to be intercepted
    by the generic command router (text.startswith("/")) before it ever reached
    the state machine, so it always replied "Tidak ada yang di-skip." and never
    actually advanced past the description step — contradicting the prompt's own
    "(atau /skip)" hint."""
    fs = FakeState()
    fs.set(1, "EXPENSE_DESC", {"account_code": "5130", "amount": 25000})
    cash_table = _mock_table(data=[{"code": "1120", "account_name": "Kas Kecil"}])
    sent = []
    with patch.object(webhook, "get_state", side_effect=lambda uid: fs.get(uid)), patch.object(
        webhook, "set_state", side_effect=fs.set
    ), patch.object(webhook, "db", return_value=MagicMock(table=MagicMock(return_value=cash_table))), patch.object(
        webhook.tg, "send_message", side_effect=lambda cid, text, **kw: sent.append(text)
    ):
        webhook.handle_text(chat_id=1, user_id=1, text="/skip")
    assert fs.state == "EXPENSE_SOURCE"
    assert fs.data["desc"] is None
    assert sent == ["🏦 Bayar dari akun mana?"]


def test_skip_outside_desc_state_falls_back_to_generic_command():
    """"/skip" typed with nothing to skip (IDLE or any other state) should still
    hit the ordinary command router and get the fallback message, not silently
    no-op or crash."""
    fs = FakeState()  # IDLE by default
    sent = []
    with patch.object(webhook, "get_state", side_effect=lambda uid: fs.get(uid)), patch.object(
        webhook, "set_state", side_effect=fs.set
    ), patch.object(webhook.tg, "send_message", side_effect=lambda cid, text, **kw: sent.append(text)):
        webhook.handle_text(chat_id=1, user_id=1, text="/skip")
    assert sent == ["Tidak ada yang di-skip."]


def test_other_commands_still_interrupt_wizards():
    """Regression guard for the /skip routing fix: every other slash command must
    still short-circuit straight to handle_command even while a wizard is active."""
    fs = FakeState()
    fs.set(1, "EXPENSE_DESC", {"account_code": "5130", "amount": 25000})
    with patch.object(webhook, "get_state", side_effect=lambda uid: fs.get(uid)), patch.object(
        webhook, "set_state", side_effect=fs.set
    ), patch.object(webhook, "reset_state", side_effect=fs.reset), patch.object(
        webhook.tg, "send_message"
    ) as send:
        webhook.handle_text(chat_id=1, user_id=1, text="/reset")
    assert fs.state == "IDLE"
    send.assert_called_once()
    assert send.call_args.kwargs.get("keyboard") == webhook.main_menu()
