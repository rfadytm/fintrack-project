"""POST /api/telegram/webhook — handler utama bot (raw httpx, B7).

Router: text commands + callback queries + state-machine text input.
Whitelist OWNER_TELEGRAM_ID. Semua POST transaksi lewat RPC post_document (double-entry + period-lock guard).
"""
import os
from datetime import datetime, timezone
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared import telegram as tg
from shared.auth import generate_token
from shared.db import get_client
from shared.doc_number import generate as gen_doc
from shared.format import bulan_nama, fmt_date, rupiah, today_wib
from shared.http import read_json, send_json
from shared.state import get_state, reset_state, set_state
from shared.validator import AmountError, parse_amount

OWNER_ID = int(os.environ.get("OWNER_TELEGRAM_ID", "0"))
APP_URL = os.environ.get("VITE_API_URL") or os.environ.get("APP_URL", "")


# ============================================================
# Helpers
# ============================================================
def db():
    return get_client()


def setting(key, default=None):
    res = db().table("bot_settings").select("value").eq("key", key).execute()
    return res.data[0]["value"] if res.data else default


def cash_accounts():
    res = (
        db().table("chart_of_accounts")
        .select("code, account_name")
        .eq("parent_code", "1100")
        .eq("is_header", False)
        .eq("is_active", True)
        .order("code")
        .execute()
    )
    return res.data


def acc_name(code):
    res = db().table("chart_of_accounts").select("account_name").eq("code", code).execute()
    return res.data[0]["account_name"] if res.data else code


def balance_of(code):
    res = db().table("account_balances").select("balance").eq("code", code).execute()
    return res.data[0]["balance"] if res.data else 0


def main_menu():
    return [
        [tg.btn("💸 Pengeluaran", "menu:expense"), tg.btn("💰 Pemasukan", "menu:income")],
        [tg.btn("🔄 Transfer", "menu:transfer"), tg.btn("📊 Laporan", "menu:report")],
        [tg.btn("💳 Saldo", "act:saldo"), tg.btn("⚙️ Pengaturan", "menu:settings")],
        [tg.btn("🟢 Tidak Ada Transaksi Hari Ini", "act:nihil")],
    ]


def post_journal(doc_type, tx_date, description, lines, source="telegram"):
    """lines: [{account_code, debit, credit}]. Return doc_number."""
    doc = gen_doc(doc_type, tx_date)
    db().rpc(
        "post_document",
        {
            "p_doc_number": doc,
            "p_doc_type": doc_type,
            "p_date": tx_date.isoformat(),
            "p_description": description,
            "p_input_source": source,
            "p_is_reversal": False,
            "p_reversal_of": None,
            "p_lines": lines,
        },
    ).execute()
    return doc


# ============================================================
# Text commands
# ============================================================
def cmd_start(chat_id, user_id):
    reset_state(user_id)
    ob = db().table("transactions").select("doc_number").eq("doc_type", "OB").limit(1).execute()
    first = "" if ob.data else "\n\n⚠️ Belum ada saldo awal. Ketik /setup untuk mulai."
    tg.send_message(
        chat_id,
        f"👋 <b>FinTrack</b> — pencatatan keuangan kamu.{first}",
        keyboard=main_menu(),
    )


def cmd_help(chat_id):
    tg.send_message(
        chat_id,
        "<b>Perintah:</b>\n"
        "/menu — menu utama\n"
        "/saldo — saldo semua akun\n"
        "/hari — ringkasan hari ini\n"
        "/bulan [YYYY-MM] — ringkasan bulan\n"
        "/recent [n] — transaksi terakhir\n"
        "/getlink — link login dashboard\n"
        "/lock YYYY-MM — kunci periode\n"
        "/setup — saldo awal (sekali)\n"
        "/reverse DOC — batalkan transaksi\n"
        "/reset — batalkan input berjalan",
    )


def cmd_saldo(chat_id):
    res = (
        db().table("account_balances")
        .select("*")
        .in_("account_type", ["aset", "liabilitas"])
        .order("code")
        .execute()
    )
    lines, net = ["💳 <b>Saldo</b>\n"], 0
    for r in res.data:
        if r["balance"] == 0:
            continue
        sign = 1 if r["account_type"] == "aset" else -1
        net += sign * r["balance"]
        lines.append(f"• {r['account_name']}: {rupiah(r['balance'])}")
    lines.append(f"\n<b>Net Worth: {rupiah(net)}</b>")
    tg.send_message(chat_id, "\n".join(lines))


def cmd_nihil(chat_id, user_id):
    """Catat hari tanpa transaksi → tulis ke Supabase (aktivitas/ping) + jejak harian."""
    today = today_wib()
    db().table("daily_log").upsert(
        {
            "log_date": today.isoformat(),
            "user_id": user_id,
            "note": "Tidak ada transaksi",
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }
    ).execute()
    # bonus ping: baca net worth biar ada query juga
    res = (
        db().table("account_balances")
        .select("balance, account_type")
        .in_("account_type", ["aset", "liabilitas"])
        .execute()
    )
    net = sum((r["balance"] if r["account_type"] == "aset" else -r["balance"]) for r in res.data)
    tg.send_message(
        chat_id,
        f"🟢 Tercatat: <b>tidak ada transaksi</b> hari ini ({fmt_date(today)}).\n"
        f"Saldo tetap — Net Worth: <b>{rupiah(net)}</b>",
    )


def cmd_bulan(chat_id, year, month):
    res = (
        db().rpc("income_statement", {"p_year": year, "p_month": month}).execute()
    )
    rows = res.data or []
    rev = sum(r["amount"] for r in rows if r["account_type"] == "pendapatan")
    exp = sum(r["amount"] for r in rows if r["account_type"] == "beban")
    lines = [f"📊 <b>{bulan_nama(month)} {year}</b>\n"]
    lines.append(f"💰 Pemasukan: {rupiah(rev)}")
    lines.append(f"💸 Pengeluaran: {rupiah(exp)}")
    lines.append(f"📈 Net: <b>{rupiah(rev - exp)}</b>\n")
    beban = [r for r in rows if r["account_type"] == "beban"]
    if beban:
        lines.append("<b>Breakdown beban:</b>")
        for r in sorted(beban, key=lambda x: -x["amount"]):
            lines.append(f"• {r['account_name']}: {rupiah(r['amount'])}")
    nav = [
        tg.btn("◀️ Bulan lalu", f"rep:month:{year - (month == 1)}:{12 if month == 1 else month - 1}"),
        tg.btn("Bulan depan ▶️", f"rep:month:{year + (month == 12)}:{1 if month == 12 else month + 1}"),
    ]
    tg.send_message(chat_id, "\n".join(lines), keyboard=[nav])


def cmd_recent(chat_id, n=10):
    res = (
        db().table("transactions")
        .select("doc_number, transaction_date, description, doc_type, status")
        .order("created_at", desc=True)
        .limit(min(n, 50))
        .execute()
    )
    if not res.data:
        return tg.send_message(chat_id, "Belum ada transaksi.")
    kb = []
    for t in res.data:
        tag = "❌" if t["status"] == "REVERSED" else "📋"
        label = f"{tag} {t['doc_number']} — {t['description'] or t['doc_type']}"[:60]
        btns = [tg.btn(label, f"detail:{t['doc_number']}")]
        if t["status"] == "POSTED" and not t["doc_number"].startswith("RV"):
            btns.append(tg.btn("↩️", f"rv:{t['doc_number']}"))
        kb.append(btns)
    tg.send_message(chat_id, f"🕒 <b>{len(res.data)} transaksi terakhir</b>", keyboard=kb)


def cmd_getlink(chat_id, user_id):
    expiry = int(setting("auth_token_expiry_mins", "60"))
    token, _ = generate_token(user_id, expiry)
    from datetime import timedelta, timezone

    db().table("auth_tokens").insert(
        {
            "token": token,
            "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=expiry)).isoformat(),
            "is_used": False,
        }
    ).execute()
    url = f"{APP_URL}/auth?t={token}"
    tg.send_message(
        chat_id,
        f"🔐 Link login (berlaku {expiry} menit, sekali pakai):",
        keyboard=[[tg.url_btn("Buka Dashboard", url)]],
    )


def cmd_lock(chat_id, year, month):
    from shared.period import lock_period

    lock_period(year, month)
    tg.send_message(chat_id, f"🔒 Periode {year}-{month:02d} dikunci.")


def cmd_reverse(chat_id, doc):
    today = today_wib()
    rv = gen_doc("RV", today)
    try:
        db().rpc(
            "reverse_document",
            {"p_doc": doc, "p_rv_doc": rv, "p_today": today.isoformat()},
        ).execute()
        tg.send_message(chat_id, f"↩️ {doc} di-reverse → {rv} (tgl {fmt_date(today)}).")
    except Exception as e:
        tg.send_message(chat_id, f"⚠️ Gagal reverse: {e}")


# ============================================================
# Setup wizard (B6: guard double-run)
# ============================================================
def cmd_setup(chat_id, user_id):
    ob = db().table("transactions").select("doc_number").eq("doc_type", "OB").limit(1).execute()
    if ob.data:
        cmd_saldo(chat_id)
        return tg.send_message(
            chat_id, "ℹ️ Saldo awal sudah pernah di-set (lihat di atas). Setup dibatalkan."
        )
    set_state(user_id, "SETUP_BNI", {"balances": {}})
    tg.send_message(chat_id, "🏦 Setup saldo awal.\nKetik saldo <b>BNI (1120)</b> sekarang (mis. 5jt):")


SETUP_STEPS = [
    ("SETUP_BNI", "1120", "SeaBank (1130)", "SETUP_SEABANK"),
    ("SETUP_SEABANK", "1130", "Kas Tunai (1110)", "SETUP_TUNAI"),
    ("SETUP_TUNAI", "1110", None, "SETUP_DONE"),
]


def handle_setup_input(chat_id, user_id, state, text):
    step = next((s for s in SETUP_STEPS if s[0] == state), None)
    if not step:
        return
    _, code, next_label, next_state = step
    st = get_state(user_id)
    data = st["state_data"]
    try:
        amount = parse_amount(text)
    except AmountError as e:
        return tg.send_message(chat_id, f"⚠️ {e}")
    data["balances"][code] = amount

    if next_label:
        set_state(user_id, next_state, data)
        tg.send_message(chat_id, f"✅ Tersimpan. Ketik saldo <b>{next_label}</b> (atau 0):")
    else:
        # Post OB: Dr semua kas, Cr 3110 Modal Awal
        total = sum(data["balances"].values())
        lines = [
            {"account_code": c, "debit": amt, "credit": 0}
            for c, amt in data["balances"].items()
            if amt > 0
        ]
        lines.append({"account_code": "3110", "debit": 0, "credit": total})
        doc = post_journal("OB", today_wib(), "Saldo awal (setup)", lines)
        reset_state(user_id)
        tg.send_message(chat_id, f"✅ Saldo awal tercatat ({doc}).")
        cmd_saldo(chat_id)


# ============================================================
# Expense / Income flows
# ============================================================
def show_categories(chat_id, mid, ctype, prefix):
    res = (
        db().table("bot_categories")
        .select("id, name, emoji")
        .eq("category_type", ctype)
        .eq("is_active", True)
        .order("display_order")
        .execute()
    )
    kb = tg.rows(
        [tg.btn(f"{c['emoji']} {c['name']}", f"{prefix}_cat:{c['id']}") for c in res.data], 2
    )
    kb.append([tg.btn("✖️ Batal", "act:cancel")])
    title = "💸 Pilih kategori pengeluaran:" if ctype == "expense" else "💰 Pilih kategori pemasukan:"
    tg.edit_message(chat_id, mid, title, keyboard=kb)


def show_accounts(chat_id, mid, cat_id, prefix):
    res = (
        db().table("bot_category_accounts")
        .select("account_code, chart_of_accounts(account_name)")
        .eq("category_id", cat_id)
        .order("display_order")
        .execute()
    )
    kb = tg.rows(
        [
            tg.btn(f"{r['chart_of_accounts']['account_name']} ({r['account_code']})", f"{prefix}_acc:{r['account_code']}")
            for r in res.data
        ],
        1,
    )
    kb.append([tg.btn("✖️ Batal", "act:cancel")])
    tg.edit_message(chat_id, mid, "Pilih akun:", keyboard=kb)


def expense_preview(chat_id, user_id):
    d = get_state(user_id)["state_data"]
    amt = d["amount"]
    text = (
        f"📝 <b>Preview Pengeluaran</b>\n\n"
        f"Dr {d['account_code']} {acc_name(d['account_code'])}: {rupiah(amt)}\n"
        f"Cr {d['source']} {acc_name(d['source'])}: {rupiah(amt)}\n\n"
        f"Ket: {d.get('desc') or '-'}"
    )
    kb = [[tg.btn("✅ Posting", "exp_post"), tg.btn("✖️ Batal", "act:cancel")]]
    tg.send_message(chat_id, text, keyboard=kb)


def income_preview(chat_id, user_id):
    d = get_state(user_id)["state_data"]
    amt = d["amount"]
    text = (
        f"📝 <b>Preview Pemasukan</b>\n\n"
        f"Dr {d['dest']} {acc_name(d['dest'])}: {rupiah(amt)}\n"
        f"Cr {d['account_code']} {acc_name(d['account_code'])}: {rupiah(amt)}\n\n"
        f"Ket: {d.get('desc') or '-'}"
    )
    kb = [[tg.btn("✅ Posting", "inc_post"), tg.btn("✖️ Batal", "act:cancel")]]
    tg.send_message(chat_id, text, keyboard=kb)


# ============================================================
# Transfer flow
# ============================================================
def transfer_menu(chat_id, mid):
    kb = [
        [tg.btn("🪙 Isi Kas Kecil (auto)", "tr:imprest")],
        [tg.btn("💰 Ke Tabungan", "tr:savings_in"), tg.btn("🏦 Dari Tabungan", "tr:savings_out")],
        [tg.btn("✖️ Batal", "act:cancel")],
    ]
    tg.edit_message(chat_id, mid, "🔄 Pilih jenis transfer:", keyboard=kb)


def fee_rule(frm, to):
    res = (
        db().table("transfer_fee_rules")
        .select("fee_amount, fee_account, method_label")
        .eq("from_account", frm)
        .eq("to_account", to)
        .execute()
    )
    return res.data[0] if res.data else {"fee_amount": 0, "fee_account": None, "method_label": ""}


def build_transfer_lines(frm, to, amount, fee):
    lines = [{"account_code": to, "debit": amount, "credit": 0}]
    total = amount + (fee["fee_amount"] or 0)
    if fee["fee_amount"]:
        lines.append({"account_code": fee["fee_account"] or "5820", "debit": fee["fee_amount"], "credit": 0})
    lines.append({"account_code": frm, "debit": 0, "credit": total})
    return lines, total


def transfer_imprest_preview(chat_id, user_id):
    target = int(setting("kas_kecil_target", "500000"))
    kk = setting("kas_kecil_account", "1130")
    src = setting("kas_kecil_source", "1120")
    cur = balance_of(kk)
    fill = target - cur
    if fill <= 0:
        reset_state(user_id)
        return tg.send_message(chat_id, f"✅ Kas kecil sudah {rupiah(cur)} (≥ target). Tidak perlu diisi.")
    fee = fee_rule(src, kk)
    lines, total = build_transfer_lines(src, kk, fill, fee)
    set_state(user_id, "TRANSFER_PREVIEW", {"lines": lines, "desc": "Pengisian imprest kas kecil"})
    text = (
        f"🪙 <b>Isi Kas Kecil</b>\n\n"
        f"Saldo {kk}: {rupiah(cur)} → target {rupiah(target)}\n"
        f"Isi: {rupiah(fill)}" + (f" + fee {rupiah(fee['fee_amount'])} ({fee['method_label']})" if fee['fee_amount'] else "") + "\n"
        f"Total debet sumber: {rupiah(total)}"
    )
    tg.send_message(chat_id, text, keyboard=[[tg.btn("✅ Posting", "tr_post"), tg.btn("✖️ Batal", "act:cancel")]])


def transfer_preview(chat_id, user_id):
    d = get_state(user_id)["state_data"]
    lines = d["lines"]
    text = "🔄 <b>Preview Transfer</b>\n\n" + "\n".join(
        f"{'Dr' if l['debit'] else 'Cr'} {l['account_code']} {acc_name(l['account_code'])}: {rupiah(l['debit'] or l['credit'])}"
        for l in lines
    )
    tg.send_message(chat_id, text, keyboard=[[tg.btn("✅ Posting", "tr_post"), tg.btn("✖️ Batal", "act:cancel")]])


# ============================================================
# Callback router
# ============================================================
def handle_callback(cb):
    user_id = cb["from"]["id"]
    chat_id = cb["message"]["chat"]["id"]
    mid = cb["message"]["message_id"]
    data = cb["data"]
    tg.answer_callback(cb["id"])

    if data == "act:cancel":
        reset_state(user_id)
        return tg.edit_message(chat_id, mid, "❌ Dibatalkan.")
    if data == "act:saldo":
        return cmd_saldo(chat_id)
    if data == "act:nihil":
        return cmd_nihil(chat_id, user_id)

    if data == "menu:expense":
        return show_categories(chat_id, mid, "expense", "exp")
    if data == "menu:income":
        return show_categories(chat_id, mid, "income", "inc")
    if data == "menu:transfer":
        return transfer_menu(chat_id, mid)
    if data == "menu:report":
        t = today_wib()
        return cmd_bulan(chat_id, t.year, t.month)
    if data == "menu:settings":
        return tg.edit_message(chat_id, mid, "⚙️ Pengaturan tersedia di dashboard (v1).")

    # Expense flow
    if data.startswith("exp_cat:"):
        return show_accounts(chat_id, mid, int(data.split(":")[1]), "exp")
    if data.startswith("exp_acc:"):
        set_state(user_id, "EXPENSE_AMOUNT", {"account_code": data.split(":")[1]})
        return tg.edit_message(chat_id, mid, "💵 Ketik nominal (mis. 25000 / 25k):")
    if data.startswith("exp_src:"):
        st = get_state(user_id)
        d = st["state_data"]
        d["source"] = data.split(":")[1]
        set_state(user_id, "EXPENSE_PREVIEW", d)
        return expense_preview(chat_id, user_id)
    if data == "exp_post":
        d = get_state(user_id)["state_data"]
        try:
            doc = post_journal(
                "KK", today_wib(), d.get("desc"),
                [
                    {"account_code": d["account_code"], "debit": d["amount"], "credit": 0},
                    {"account_code": d["source"], "debit": 0, "credit": d["amount"]},
                ],
            )
            reset_state(user_id)
            tg.send_message(chat_id, f"✅ Tercatat {doc}. Saldo {d['source']}: {rupiah(balance_of(d['source']))}")
        except Exception as e:
            tg.send_message(chat_id, f"⚠️ Gagal: {e}")
        return

    # Income flow
    if data.startswith("inc_cat:"):
        return show_accounts(chat_id, mid, int(data.split(":")[1]), "inc")
    if data.startswith("inc_acc:"):
        set_state(user_id, "INCOME_AMOUNT", {"account_code": data.split(":")[1]})
        return tg.edit_message(chat_id, mid, "💵 Ketik nominal pemasukan:")
    if data.startswith("inc_dst:"):
        d = get_state(user_id)["state_data"]
        d["dest"] = data.split(":")[1]
        set_state(user_id, "INCOME_PREVIEW", d)
        return income_preview(chat_id, user_id)
    if data == "inc_post":
        d = get_state(user_id)["state_data"]
        try:
            doc = post_journal(
                "KM", today_wib(), d.get("desc"),
                [
                    {"account_code": d["dest"], "debit": d["amount"], "credit": 0},
                    {"account_code": d["account_code"], "debit": 0, "credit": d["amount"]},
                ],
            )
            reset_state(user_id)
            tg.send_message(chat_id, f"✅ Tercatat {doc}. Saldo {d['dest']}: {rupiah(balance_of(d['dest']))}")
        except Exception as e:
            tg.send_message(chat_id, f"⚠️ Gagal: {e}")
        return

    # Transfer
    if data == "tr:imprest":
        return transfer_imprest_preview(chat_id, user_id)
    if data in ("tr:savings_in", "tr:savings_out"):
        savings = setting("savings_account", "1140")
        bni = "1120"
        frm, to = (bni, savings) if data == "tr:savings_in" else (savings, bni)
        set_state(user_id, "TRANSFER_AMOUNT", {"from": frm, "to": to})
        return tg.edit_message(chat_id, mid, f"💵 Ketik nominal transfer {frm}→{to}:")
    if data == "tr_post":
        d = get_state(user_id)["state_data"]
        try:
            doc = post_journal("TR", today_wib(), d.get("desc", "Transfer"), d["lines"])
            reset_state(user_id)
            tg.send_message(chat_id, f"✅ Transfer tercatat {doc}.")
        except Exception as e:
            tg.send_message(chat_id, f"⚠️ Gagal: {e}")
        return

    # Reports nav
    if data.startswith("rep:month:"):
        _, _, y, m = data.split(":")
        return cmd_bulan(chat_id, int(y), int(m))
    if data.startswith("rv:"):
        return cmd_reverse(chat_id, data.split(":", 1)[1])
    if data.startswith("detail:"):
        return show_detail(chat_id, data.split(":", 1)[1])


def show_detail(chat_id, doc):
    res = (
        db().table("journal_lines")
        .select("account_code, debit_amount, credit_amount, chart_of_accounts(account_name)")
        .eq("doc_number", doc)
        .order("line_order")
        .execute()
    )
    lines = [f"📋 <b>{doc}</b>\n"]
    for l in res.data:
        amt = l["debit_amount"] or l["credit_amount"]
        side = "Dr" if l["debit_amount"] else "Cr"
        lines.append(f"{side} {l['account_code']} {l['chart_of_accounts']['account_name']}: {rupiah(amt)}")
    tg.send_message(chat_id, "\n".join(lines))


# ============================================================
# Text input router (state machine)
# ============================================================
def handle_text(chat_id, user_id, text):
    text = text.strip()

    if text.startswith("/"):
        return handle_command(chat_id, user_id, text)

    st = get_state(user_id)
    state = st["state"]
    d = st["state_data"]

    if state.startswith("SETUP_"):
        return handle_setup_input(chat_id, user_id, state, text)

    # Amount inputs
    if state in ("EXPENSE_AMOUNT", "INCOME_AMOUNT", "TRANSFER_AMOUNT"):
        try:
            amount = parse_amount(text)
        except AmountError as e:
            return tg.send_message(chat_id, f"⚠️ {e}")
        d["amount"] = amount
        if state == "EXPENSE_AMOUNT":
            set_state(user_id, "EXPENSE_DESC", d)
            return tg.send_message(chat_id, "✏️ Ketik keterangan (atau /skip):")
        if state == "INCOME_AMOUNT":
            set_state(user_id, "INCOME_DESC", d)
            return tg.send_message(chat_id, "✏️ Ketik keterangan (atau /skip):")
        if state == "TRANSFER_AMOUNT":
            fee = fee_rule(d["from"], d["to"])
            lines, _ = build_transfer_lines(d["from"], d["to"], amount, fee)
            d["lines"] = lines
            set_state(user_id, "TRANSFER_PREVIEW", d)
            return transfer_preview(chat_id, user_id)

    # Description inputs
    if state in ("EXPENSE_DESC", "INCOME_DESC"):
        d["desc"] = None if text == "/skip" else text
        if state == "EXPENSE_DESC":
            kb = tg.rows([tg.btn(f"{a['account_name']}", f"exp_src:{a['code']}") for a in cash_accounts()], 2)
            set_state(user_id, "EXPENSE_SOURCE", d)
            return tg.send_message(chat_id, "🏦 Bayar dari akun mana?", keyboard=kb)
        else:
            dest = setting("default_income_dest", "1120")
            d["dest"] = dest
            set_state(user_id, "INCOME_PREVIEW", d)
            return income_preview(chat_id, user_id)

    tg.send_message(chat_id, "Ketik /menu untuk mulai.", keyboard=main_menu())


def handle_command(chat_id, user_id, text):
    parts = text.split()
    cmd = parts[0].lower()

    if cmd in ("/start",):
        return cmd_start(chat_id, user_id)
    if cmd in ("/menu",):
        return tg.send_message(chat_id, "📲 Menu utama:", keyboard=main_menu())
    if cmd == "/help":
        return cmd_help(chat_id)
    if cmd == "/saldo":
        return cmd_saldo(chat_id)
    if cmd == "/nihil":
        return cmd_nihil(chat_id, user_id)
    if cmd == "/hari":
        t = today_wib()
        return cmd_bulan(chat_id, t.year, t.month)
    if cmd == "/bulan":
        t = today_wib()
        if len(parts) > 1 and "-" in parts[1]:
            y, m = parts[1].split("-")
            return cmd_bulan(chat_id, int(y), int(m))
        return cmd_bulan(chat_id, t.year, t.month)
    if cmd == "/recent":
        n = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 10
        return cmd_recent(chat_id, n)
    if cmd == "/getlink":
        return cmd_getlink(chat_id, user_id)
    if cmd == "/lock" and len(parts) > 1 and "-" in parts[1]:
        y, m = parts[1].split("-")
        return cmd_lock(chat_id, int(y), int(m))
    if cmd == "/setup":
        return cmd_setup(chat_id, user_id)
    if cmd == "/reverse" and len(parts) > 1:
        return cmd_reverse(chat_id, parts[1])
    if cmd in ("/reset", "/back"):
        reset_state(user_id)
        return tg.send_message(chat_id, "🔄 Direset.", keyboard=main_menu())
    if cmd == "/skip":
        return handle_text(chat_id, user_id, "/skip") if False else tg.send_message(chat_id, "Tidak ada yang di-skip.")

    tg.send_message(chat_id, "Perintah tidak dikenal. /help")


# ============================================================
# Vercel handler
# ============================================================
class handler(BaseHTTPRequestHandler):
    def do_POST(self):
        # Verifikasi secret token Telegram (anti webhook spoofing).
        # Graceful: kalau WEBHOOK_SECRET belum di-set, lewati cek (aman saat rollout).
        secret = os.environ.get("WEBHOOK_SECRET")
        if secret and self.headers.get("X-Telegram-Bot-Api-Secret-Token") != secret:
            return send_json(self, 200, {"ok": True})

        update = read_json(self)

        # Whitelist
        msg = update.get("message")
        cb = update.get("callback_query")
        from_id = (msg or cb or {}).get("from", {}).get("id")
        if OWNER_ID and from_id != OWNER_ID:
            return send_json(self, 200, {"ok": True})  # diamkan non-owner

        try:
            if cb:
                handle_callback(cb)
            elif msg and "text" in msg:
                handle_text(msg["chat"]["id"], from_id, msg["text"])
        except Exception as e:
            # jangan biarkan Telegram retry storm; log & balas 200
            if msg:
                tg.send_message(msg["chat"]["id"], f"⚠️ Error: {e}")

        send_json(self, 200, {"ok": True})
