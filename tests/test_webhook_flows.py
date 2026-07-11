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


def test_act_cancel_offers_quick_shortcuts():
    """UX request: instead of making the user type /menu again after cancelling
    an in-progress input, offer one-tap shortcuts straight below "Dibatalkan"."""
    fs = FakeState()
    fs.set(1, "EXPENSE_AMOUNT", {"account_code": "5130"})
    cb = {"from": {"id": 1}, "message": {"chat": {"id": 1}, "message_id": 1}, "id": "cbid", "data": "act:cancel"}
    with patch.object(webhook, "reset_state", side_effect=fs.reset), patch.object(
        webhook.tg, "answer_callback"
    ), patch.object(webhook.tg, "edit_message") as edit:
        webhook.handle_callback(cb)
    assert fs.state == "IDLE"
    edit.assert_called_once()
    text = edit.call_args.args[2] if len(edit.call_args.args) > 2 else edit.call_args.kwargs.get("text")
    assert "Dibatalkan" in text
    kb = edit.call_args.kwargs.get("keyboard")
    callbacks = [btn["callback_data"] for row in kb for btn in row]
    assert callbacks == ["act:menu", "act:saldo", "act:hari"]


def test_continue_keyboard_offers_saldo_and_recent_shortcuts():
    """UX request: the same quick-shortcut treatment given to act:cancel should
    also apply after a successful posting (exp_post/inc_post/tr_post all use
    continue_keyboard()) — add Saldo & Terakhir alongside the existing
    Pengeluaran/Pemasukan/Transfer Lagi + Menu buttons."""
    callbacks = [btn["callback_data"] for row in webhook.continue_keyboard() for btn in row]
    assert "act:saldo" in callbacks
    assert "act:recent" in callbacks


def test_act_recent_callback_lists_recent_transactions():
    rows = [{"doc_number": "KK-0001", "description": "Makan", "doc_type": "KK", "status": "POSTED"}]
    table = _mock_table(data=rows)
    cb = {"from": {"id": 1}, "message": {"chat": {"id": 1}, "message_id": 1}, "id": "cbid", "data": "act:recent"}
    with patch.object(webhook.tg, "answer_callback"), patch.object(
        webhook, "db", return_value=MagicMock(table=MagicMock(return_value=table))
    ), patch.object(webhook.tg, "send_message") as send:
        webhook.handle_callback(cb)
    send.assert_called_once()
    assert "transaksi terakhir" in send.call_args[0][1]


def test_act_hari_callback_with_no_transactions_offers_menu_and_saldo():
    """Blindspot fix: /hari (and its act:hari button twin) used to call cmd_bulan
    and show a whole MONTH's summary despite claiming "ringkasan hari ini" in
    /help. Now it's a real daily summary — and when today has nothing posted
    yet, fall back to Menu/Saldo shortcuts instead of an empty report."""
    cb = {"from": {"id": 1}, "message": {"chat": {"id": 1}, "message_id": 1}, "id": "cbid", "data": "act:hari"}
    table = _mock_table(data=[])
    with patch.object(webhook.tg, "answer_callback"), patch.object(
        webhook, "db", return_value=MagicMock(table=MagicMock(return_value=table))
    ), patch.object(webhook.tg, "send_message") as send:
        webhook.handle_callback(cb)
    send.assert_called_once()
    text, kb = send.call_args[0][1], send.call_args.kwargs.get("keyboard")
    assert "Belum ada transaksi hari ini" in text
    callbacks = [btn["callback_data"] for row in kb for btn in row]
    assert callbacks == ["act:menu", "act:saldo"]


def test_hari_command_with_transactions_lists_them_and_totals():
    rows = [
        {
            "doc_number": "KK-2026-07-0001",
            "description": "Makan siang",
            "doc_type": "KK",
            "journal_lines": [
                {"debit_amount": 50000, "credit_amount": 0, "chart_of_accounts": {"account_type": "beban"}},
                {"debit_amount": 0, "credit_amount": 50000, "chart_of_accounts": {"account_type": "aset"}},
            ],
        }
    ]
    table = _mock_table(data=rows)
    with patch.object(webhook, "db", return_value=MagicMock(table=MagicMock(return_value=table))), patch.object(
        webhook.tg, "send_message"
    ) as send:
        webhook.cmd_hari(chat_id=1)
    text = send.call_args[0][1]
    assert "💸 Pengeluaran: Rp 50.000" in text
    assert "KK-2026-07-0001 — Makan siang: Rp 50.000" in text


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


def test_lock_without_args_shows_usage_not_unknown_command():
    """Command audit blindspot: /lock IS a recognized command, but its old guard
    (cmd == "/lock" and len(parts) > 1 and "-" in parts[1]) meant missing/malformed
    args fell all the way through to the generic "Perintah tidak dikenal" fallback
    — factually wrong, since /lock was recognized, just missing an argument."""
    with patch.object(webhook.tg, "send_message") as send:
        webhook.handle_command(chat_id=1, user_id=1, text="/lock")
    assert "Format: /lock YYYY-MM" in send.call_args[0][1]


def test_lock_with_valid_args_still_locks_period():
    with patch.object(webhook, "cmd_lock") as cmd_lock:
        webhook.handle_command(chat_id=1, user_id=1, text="/lock 2026-07")
    cmd_lock.assert_called_once_with(1, 2026, 7)


def test_reverse_without_doc_shows_usage_not_unknown_command():
    with patch.object(webhook.tg, "send_message") as send:
        webhook.handle_command(chat_id=1, user_id=1, text="/reverse")
    assert "Format: /reverse" in send.call_args[0][1]


def test_reverse_with_doc_still_reverses():
    with patch.object(webhook, "cmd_reverse") as cmd_reverse:
        webhook.handle_command(chat_id=1, user_id=1, text="/reverse KK-2026-07-0001")
    cmd_reverse.assert_called_once_with(1, "KK-2026-07-0001")


# ============================================================
# tr:kaskecil_manual — manual (arbitrary-amount) BNI -> kas kecil transfer.
# Added 2026-07-11: distinct from tr:imprest (auto-fills the DIFFERENCE to
# hit kas_kecil_target, disabled once balance >= target) for the case where
# the source account doesn't have enough to reach the full target — this
# flow posts whatever amount is typed, no target check at all.
# ============================================================


def test_tr_kaskecil_manual_prompts_for_amount_using_bot_settings_accounts():
    fs = FakeState()
    cb = {"from": {"id": 1}, "message": {"chat": {"id": 1}, "message_id": 1}, "id": "cbid", "data": "tr:kaskecil_manual"}
    edited = []
    with patch.object(webhook, "get_state", side_effect=lambda uid: fs.get(uid)), patch.object(
        webhook, "set_state", side_effect=fs.set
    ), patch.object(
        webhook, "db", return_value=MagicMock(table=MagicMock(return_value=_mock_table()))
    ), patch.object(webhook.tg, "answer_callback"), patch.object(
        webhook.tg, "edit_message", side_effect=lambda cid, mid, text, **kw: edited.append(text)
    ):
        webhook.handle_callback(cb)
    # No bot_settings rows mocked -> setting() falls back to its own
    # defaults, which must match tr:imprest's source/target accounts
    # (1120/1130) so the two flows stay consistent if the settings are
    # ever reconfigured via /settings.
    assert fs.state == "TRANSFER_AMOUNT"
    assert fs.data == {"from": "1120", "to": "1130", "desc": "Transfer manual ke kas kecil"}
    assert "1120" in edited[0] and "1130" in edited[0]


def test_tr_kaskecil_manual_does_not_check_target_unlike_tr_imprest():
    """The whole point of this flow: post_journal must be reachable even
    when the amount typed is smaller than (target - current balance), which
    tr:imprest would refuse to do at all (it disables itself once balance >=
    target, and never lets the user type a smaller top-up)."""
    fs = FakeState()
    fs.set(1, "TRANSFER_AMOUNT", {"from": "1120", "to": "1130", "desc": "Transfer manual ke kas kecil"})
    fee_table = _mock_table(data=[{"fee_amount": 2500, "fee_account": "5820", "method_label": "BI-Fast BNI->SeaBank"}])
    coa_table = _mock_table(data=[{"account_name": "Bank BNI (Kas Besar)"}])
    tables = {"transfer_fee_rules": fee_table, "chart_of_accounts": coa_table}
    with patch.object(webhook, "get_state", side_effect=lambda uid: fs.get(uid)), patch.object(
        webhook, "set_state", side_effect=fs.set
    ), patch.object(
        webhook, "db", return_value=MagicMock(table=MagicMock(side_effect=lambda name: tables.get(name, _mock_table())))
    ), patch.object(webhook.tg, "send_message"):
        # 200rb typed, deliberately less than the 500rb imprest target —
        # this must NOT be rejected the way tr:imprest would refuse it.
        webhook.handle_text(chat_id=1, user_id=1, text="200000")
    assert fs.state == "TRANSFER_PREVIEW"
    assert fs.data["lines"] == [
        {"account_code": "1130", "debit": 200000, "credit": 0},
        {"account_code": "5820", "debit": 2500, "credit": 0},
        {"account_code": "1120", "debit": 0, "credit": 202500},
    ]
    assert fs.data["desc"] == "Transfer manual ke kas kecil"


def test_tr_kaskecil_manual_posts_with_its_own_description_not_generic_transfer():
    """post_journal falls back to the generic "Transfer" description when
    state_data has no "desc" (true for tr:savings_in/out today) — this flow
    must NOT fall into that default, so it's distinguishable from both
    tr:imprest's "Pengisian imprest kas kecil" and a plain savings transfer
    in the ledger."""
    fs = FakeState()
    lines = [
        {"account_code": "1130", "debit": 200000, "credit": 0},
        {"account_code": "5820", "debit": 2500, "credit": 0},
        {"account_code": "1120", "debit": 0, "credit": 202500},
    ]
    fs.set(1, "TRANSFER_PREVIEW", {"from": "1120", "to": "1130", "desc": "Transfer manual ke kas kecil", "lines": lines})
    cb = {"from": {"id": 1}, "message": {"chat": {"id": 1}, "message_id": 1}, "id": "cbid", "data": "tr_post"}
    with patch.object(webhook, "get_state", side_effect=lambda uid: fs.get(uid)), patch.object(
        webhook, "set_state", side_effect=fs.set
    ), patch.object(webhook, "reset_state", side_effect=fs.reset), patch.object(
        webhook, "post_journal", return_value="TR-2026-07-001"
    ) as post_journal, patch.object(webhook.tg, "answer_callback"), patch.object(webhook.tg, "send_message"):
        webhook.handle_callback(cb)
    post_journal.assert_called_once_with("TR", webhook.today_wib(), "Transfer manual ke kas kecil", lines)
    assert fs.state == "IDLE"
