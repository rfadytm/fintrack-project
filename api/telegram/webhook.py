"""POST /api/telegram/webhook — handler utama bot (raw httpx, B7).

Router: text commands + callback queries + state-machine text input.
Whitelist OWNER_TELEGRAM_ID. Semua POST transaksi lewat RPC post_document (double-entry + period-lock guard).
"""
import os
from datetime import datetime, timedelta, timezone
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared import activity, ocr
from shared import telegram as tg
from shared.auth import generate_token
from shared.db import get_client
from shared.doc_number import generate as gen_doc
from shared.format import bulan_nama, fmt_date, rupiah, today_wib
from shared.fx import FxError, convert as fx_convert
from shared.http import read_json, send_json
from shared.receipt_parser import parse_receipt
from shared.reports import month_totals
from shared.retry import retry
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
        [tg.btn("🧾 Scan Struk/Nota", "act:scan")],
        # v3
        [tg.btn("💰 Budget", "act:budgets"), tg.btn("🎯 Goals", "act:goals")],
        [tg.btn("🔁 Berulang", "act:recurring"), tg.btn("🧾 Tagihan", "act:bills")],
        [tg.btn("💳 Saldo", "act:saldo"), tg.btn("⚙️ Pengaturan", "menu:settings")],
        [tg.btn("🟢 Tidak Ada Transaksi Hari Ini", "act:nihil")],
    ]


def continue_keyboard():
    """Ditempel di bawah pesan sukses posting — lanjut input transaksi baru
    tanpa perlu ketik /menu atau /start dulu."""
    return [
        [tg.btn("💸 Pengeluaran Lagi", "menu:expense"), tg.btn("💰 Pemasukan Lagi", "menu:income")],
        [tg.btn("🔄 Transfer Lagi", "menu:transfer"), tg.btn("📲 Menu", "act:menu")],
    ]


def cmd_scan(chat_id):
    """Instruksi input foto struk (OCR). Foto apa pun yang dikirim ke bot langsung diproses."""
    tg.send_message(
        chat_id,
        "🧾 <b>Scan Struk / Nota</b>\n\n"
        "Kirim <b>foto struk</b> belanja atau <b>screenshot e-wallet</b> "
        "(GoPay/OVO/DANA/BCA) ke chat ini.\n\n"
        "Aku akan baca otomatis: merchant, nominal, tanggal → tinggal konfirmasi.\n"
        "💡 Tips: foto rata, terang, dan seluruh struk terlihat agar hasil lebih akurat.",
    )


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
# v3: rate limiting / activity log helpers (db/16_activity_log.sql)
# ============================================================
def _chat_id_of(msg, cb):
    if msg:
        return msg["chat"]["id"]
    if cb:
        return cb["message"]["chat"]["id"]
    return None


def _action_label(msg, cb):
    if cb:
        return f"callback:{cb.get('data', '?')}"
    if msg and "text" in msg:
        t = msg["text"]
        return f"command:{t.split()[0]}" if t.startswith("/") else "message"
    if msg and "photo" in msg:
        return "photo"
    if msg and "document" in msg:
        return "document"
    return "unknown"


# ============================================================
# v3: budget alert (real-time, throttled) + anomaly warning (anti-abuse)
# ============================================================
def _month_spend(account_code, year, month):
    res = (
        db().table("journal_lines")
        .select("debit_amount, transactions!inner(period_year, period_month, status)")
        .eq("account_code", account_code)
        .eq("transactions.period_year", year)
        .eq("transactions.period_month", month)
        .eq("transactions.status", "POSTED")
        .execute()
    )
    return sum(r["debit_amount"] or 0 for r in res.data)


def check_budget_alert(chat_id, account_code):
    """Dipanggil setelah exp_post: kalau kategori ini punya budget & sudah kelampauan
    (dan alert terakhir sudah > throttle menit lalu), kirim notifikasi."""
    b = db().table("budgets").select("*").eq("account_code", account_code).execute()
    if not b.data:
        return
    row = b.data[0]
    today = today_wib()
    spent = _month_spend(account_code, today.year, today.month)
    limit = row["monthly_limit"]
    if spent < limit:
        return
    throttle_mins = int(setting("budget_alert_throttle_mins", "120"))
    last_alert = row.get("last_alert_at")
    if last_alert and datetime.now(timezone.utc) - datetime.fromisoformat(last_alert) < timedelta(minutes=throttle_mins):
        return
    pct = round(spent / limit * 100) if limit else 0
    tg.send_message(
        chat_id,
        f"⚠️ <b>Budget terlampaui!</b>\n{acc_name(account_code)}: {rupiah(spent)} / {rupiah(limit)} ({pct}%)",
    )
    db().table("budgets").update(
        {"last_alert_at": datetime.now(timezone.utc).isoformat()}
    ).eq("account_code", account_code).execute()


def anomaly_warning(account_code, amount):
    """Anti-abuse (bukan blocking): kalau amount menyimpang jauh (z-score) dari histori
    nominal kategori ini, tambahkan satu baris warning ke preview — user tetap yang
    memutuskan lanjut posting atau tidak."""
    res = (
        db().table("journal_lines")
        .select("debit_amount, transactions!inner(status)")
        .eq("account_code", account_code)
        .eq("transactions.status", "POSTED")
        .execute()
    )
    history = [r["debit_amount"] for r in res.data if r["debit_amount"]]
    if len(history) < 5:
        return ""
    sensitivity = setting("alert_sensitivity", "normal")
    if activity.flag_large_amount(amount, history, sensitivity):
        return "\n\n⚠️ <i>Nominal ini jauh dari rata-rata pengeluaran kategori ini — pastikan sudah benar.</i>"
    return ""


# ============================================================
# OCR struk/nota (v2) — foto → parse → konfirmasi → transaksi
# ============================================================
def receipt_expense_account(merchant):
    """Map nama merchant → akun beban via bot_aliases (substring). Fallback ke default."""
    default = setting("receipt_default_expense", "9999")
    if not merchant:
        return default
    m = merchant.lower()
    res = db().table("bot_aliases").select("alias, account_code").execute()
    # Alias terpanjang menang → 'grabfood'(makan) atas 'grab'(transport), dst.
    for row in sorted(res.data or [], key=lambda r: -len(r["alias"])):
        if row["alias"] in m:
            return row["account_code"]
    return default


def _pick_photo_file_id(sizes):
    """Pilih PhotoSize terbesar yang masih di bawah limit OCR (pakai metadata file_size,
    tanpa perlu download dulu). Fallback: ukuran terkecil."""
    ok = [s for s in sizes if s.get("file_size", 0) <= ocr.MAX_BYTES]
    chosen = ok[-1] if ok else sizes[0]
    return chosen["file_id"]


def handle_photo(chat_id, user_id, msg):
    """Foto struk (compressed) → OCR."""
    process_receipt_image(chat_id, user_id, _pick_photo_file_id(msg["photo"]), msg.get("caption"))


def handle_document(chat_id, user_id, msg):
    """Struk dikirim sebagai FILE ('Kirim sebagai file') — image/* atau PDF."""
    doc = msg["document"]
    mime = doc.get("mime_type") or ""
    if not (mime.startswith("image/") or mime == "application/pdf"):
        return tg.send_message(chat_id, "📎 File itu bukan gambar/PDF. Kirim foto struk (JPG/PNG) atau PDF, ya.")
    process_receipt_image(chat_id, user_id, doc["file_id"], msg.get("caption"))


def process_receipt_image(chat_id, user_id, file_id, caption=None):
    """OCR → parse → simpan pending → tawarkan konfirmasi (confirmation loop)."""
    tg.send_message(chat_id, "🧾 Memproses struk… (beberapa detik)")
    try:
        image = tg.download_file(file_id)
        raw = retry(lambda: ocr.extract_text(image))
    except ocr.OCRError as e:
        return tg.send_message(chat_id, f"⚠️ {e}\nKetik /menu untuk input manual.")
    except Exception as e:
        return tg.send_message(chat_id, f"⚠️ Gagal proses gambar: {e}\nKetik /menu untuk input manual.")

    p = parse_receipt(raw)
    note = (caption or "").strip() or None
    rid = (
        db().table("receipts").insert(
            {
                "telegram_file_id": file_id,
                "telegram_chat_id": chat_id,
                "raw_ocr_text": raw,
                "parsed_merchant": p["merchant"],
                "parsed_amount": p["amount"],
                "parsed_date": p["date"],
                "confidence_score": p["confidence"],
                "parse_source": "receipt",
                "note": note,
                "status": "pending",
            }
        ).execute().data[0]["id"]
    )

    threshold = int(setting("receipt_min_confidence", "50"))
    if not p["amount"] or p["confidence"] < threshold:
        db().table("receipts").update({"status": "manual"}).eq("id", rid).execute()
        return tg.send_message(
            chat_id,
            f"🤔 Struk kurang jelas (confidence {p['confidence']}%).\n"
            "Coba foto lebih terang/rata, atau input manual: /menu",
        )

    acc = receipt_expense_account(p["merchant"])
    text = (
        f"🧾 <b>Struk terbaca</b> (confidence {p['confidence']}%)\n\n"
        f"🏪 Merchant: <b>{p['merchant'] or '-'}</b>\n"
        f"💵 Nominal: <b>{rupiah(p['amount'])}</b>\n"
        f"📅 Tgl struk: {p['date'] or '-'}\n"
        f"📂 Kategori: {acc_name(acc)} ({acc})\n"
        + (f"📝 Catatan: {note}\n" if note else "")
        + "\nSimpan sebagai pengeluaran?"
    )
    kb = [[tg.btn("✅ Simpan", f"rcp:save:{rid}"), tg.btn("✖️ Batal", f"rcp:cancel:{rid}")]]
    tg.send_message(chat_id, text, keyboard=kb)


def handle_receipt_action(chat_id, user_id, mid, action, rid):
    res = db().table("receipts").select("*").eq("id", rid).execute()
    if not res.data:
        return tg.edit_message(chat_id, mid, "⚠️ Data struk tidak ditemukan.")
    r = res.data[0]

    if action == "cancel":
        db().table("receipts").update({"status": "rejected"}).eq("id", rid).execute()
        return tg.edit_message(chat_id, mid, "❌ Struk dibatalkan.")

    if action == "save":
        if r["status"] == "confirmed":
            return tg.edit_message(chat_id, mid, "ℹ️ Struk ini sudah tercatat.")
        if not r["parsed_amount"]:
            return tg.edit_message(chat_id, mid, "⚠️ Nominal struk tidak terbaca. Input manual: /menu")
        # Prefill account_code + amount + desc; sisakan 1 pertanyaan (sumber dana)
        # → masuk ke alur expense yang sudah ada (exp_src → preview → exp_post).
        set_state(
            user_id,
            "EXPENSE_SOURCE",
            {
                "account_code": receipt_expense_account(r["parsed_merchant"]),
                "amount": r["parsed_amount"],
                "desc": r.get("note") or r["parsed_merchant"],
                "receipt_id": rid,
            },
        )
        kb = tg.rows([tg.btn(a["account_name"], f"exp_src:{a['code']}") for a in cash_accounts()], 2)
        return tg.edit_message(chat_id, mid, "🏦 Bayar dari akun mana?", keyboard=kb)


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
        "/scan — cara input dari foto struk/nota\n"
        "/saldo — saldo semua akun\n"
        "/hari — ringkasan hari ini\n"
        "/bulan [YYYY-MM] — ringkasan bulan\n"
        "/recent [n] — transaksi terakhir\n"
        "/undo — batalkan 1 transaksi terakhir\n"
        "/getlink — link login dashboard\n"
        "/lock YYYY-MM — kunci periode\n"
        "/setup — saldo awal (sekali)\n"
        "/reverse DOC — batalkan transaksi\n"
        "/reset — batalkan input berjalan\n\n"
        "<b>v3:</b>\n"
        "/budget kode limit · /budgets — atur & lihat budget\n"
        "/goal · /goals — target tabungan\n"
        "/recurring [list] — transaksi berulang\n"
        "/bill · /bills — tagihan\n"
        "/tag doc nama1,nama2 · /tags — tag transaksi\n"
        "/kategori add nama — kategori beban custom\n"
        "/convert jumlah DARI KE — konversi mata uang\n"
        "/nabung — cek & tabung sisa bulan ini",
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


def cmd_undo(chat_id):
    """Shortcut: reverse SATU transaksi paling baru, tanpa perlu buka /recent dulu."""
    res = (
        db().table("transactions")
        .select("doc_number, description, doc_type")
        .eq("status", "POSTED")
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )
    if not res.data:
        return tg.send_message(chat_id, "Tidak ada transaksi untuk di-undo.")
    t = res.data[0]
    kb = [[tg.btn("↩️ Ya, undo", f"rv:{t['doc_number']}"), tg.btn("✖️ Batal", "act:cancel")]]
    tg.send_message(
        chat_id,
        f"Undo transaksi terakhir?\n\n{t['doc_number']} — {t['description'] or t['doc_type']}",
        keyboard=kb,
    )


# ============================================================
# v3: Budget
# ============================================================
def cmd_budget_set(chat_id, args):
    if len(args) < 2:
        return tg.send_message(chat_id, "Format: /budget <kode_akun> <limit>\nContoh: /budget 5110 500000")
    code, amount_text = args[0], args[1]
    acc = db().table("chart_of_accounts").select("code").eq("code", code).eq("is_header", False).execute()
    if not acc.data:
        return tg.send_message(chat_id, f"⚠️ Kode akun {code} tidak ditemukan / bukan akun postable.")
    try:
        limit = parse_amount(amount_text)
    except AmountError as e:
        return tg.send_message(chat_id, f"⚠️ {e}")
    db().table("budgets").upsert({"account_code": code, "monthly_limit": limit}).execute()
    tg.send_message(chat_id, f"✅ Budget {acc_name(code)} ({code}): {rupiah(limit)}/bulan.")


def cmd_budgets_list(chat_id):
    res = db().table("budgets").select("*").execute()
    if not res.data:
        return tg.send_message(chat_id, "Belum ada budget. /budget <kode_akun> <limit> untuk mulai.")
    today = today_wib()
    lines = ["💰 <b>Budget bulan ini</b>\n"]
    for b in res.data:
        spent = _month_spend(b["account_code"], today.year, today.month)
        pct = round(spent / b["monthly_limit"] * 100) if b["monthly_limit"] else 0
        flag = "🔴" if pct >= 100 else "🟡" if pct >= 80 else "🟢"
        lines.append(f"{flag} {acc_name(b['account_code'])}: {rupiah(spent)} / {rupiah(b['monthly_limit'])} ({pct}%)")
    tg.send_message(chat_id, "\n".join(lines))


# ============================================================
# v3: Goal wizard (GOAL_NAME -> GOAL_AMOUNT -> pilih akun via callback goal_acc:)
# ============================================================
def cmd_goal_start(chat_id, user_id):
    set_state(user_id, "GOAL_NAME", {})
    tg.send_message(chat_id, '🎯 Nama goal (mis. "Laptop baru"):')


def handle_goal_input(chat_id, user_id, state, text):
    d = get_state(user_id)["state_data"]
    if state == "GOAL_NAME":
        d["name"] = text
        set_state(user_id, "GOAL_AMOUNT", d)
        return tg.send_message(chat_id, "💵 Target nominal (mis. 10jt):")
    if state == "GOAL_AMOUNT":
        try:
            d["target_amount"] = parse_amount(text)
        except AmountError as e:
            return tg.send_message(chat_id, f"⚠️ {e}")
        set_state(user_id, "GOAL_ACCOUNT", d)
        kb = tg.rows([tg.btn(a["account_name"], f"goal_acc:{a['code']}") for a in cash_accounts()], 2)
        return tg.send_message(chat_id, "🏦 Progress goal dihitung dari saldo akun mana?", keyboard=kb)


def cmd_goals_list(chat_id):
    res = db().table("goals").select("*").eq("is_active", True).execute()
    if not res.data:
        return tg.send_message(chat_id, "Belum ada goal. /goal untuk mulai.")
    lines = ["🎯 <b>Goals</b>"]
    for g in res.data:
        cur = balance_of(g["account_code"]) if g["account_code"] else 0
        pct = min(round(cur / g["target_amount"] * 100), 100) if g["target_amount"] else 0
        bar = "█" * (pct // 10) + "░" * (10 - pct // 10)
        lines.append(f"\n<b>{g['name']}</b>\n{rupiah(cur)} / {rupiah(g['target_amount'])}\n{bar} {pct}%")
    tg.send_message(chat_id, "\n".join(lines))


# ============================================================
# v3: Recurring transaction wizard
# (RECURRING_DESC -> pilih kategori/akun beban [reuse exp flow, prefix "rec"] ->
#  RECURRING_SOURCE -> RECURRING_AMOUNT -> pilih frekuensi via callback rec_freq:)
# ============================================================
def cmd_recurring_start(chat_id, user_id):
    set_state(user_id, "RECURRING_DESC", {})
    tg.send_message(chat_id, '🔁 Nama/keterangan transaksi berulang (mis. "Langganan Netflix"):')


def cmd_recurring_list(chat_id):
    res = db().table("recurring_transactions").select("*").eq("is_active", True).execute()
    if not res.data:
        return tg.send_message(chat_id, "Belum ada transaksi berulang. /recurring untuk mulai.")
    lines = ["🔁 <b>Transaksi Berulang</b>\n"]
    for r in res.data:
        total = sum(l.get("debit") or 0 for l in r["lines"])
        lines.append(f"#{r['id']} {r['description']} — {rupiah(total)}/{r['frequency']} (berikutnya {r['next_run']})")
    tg.send_message(chat_id, "\n".join(lines))


# ============================================================
# v3: Bill wizard (BILL_NAME -> BILL_AMOUNT -> BILL_DUE)
# ============================================================
def cmd_bill_start(chat_id, user_id):
    set_state(user_id, "BILL_NAME", {})
    tg.send_message(chat_id, '🧾 Nama tagihan (mis. "Listrik PLN"):')


def handle_bill_input(chat_id, user_id, state, text):
    d = get_state(user_id)["state_data"]
    if state == "BILL_NAME":
        d["name"] = text
        set_state(user_id, "BILL_AMOUNT", d)
        return tg.send_message(chat_id, "💵 Nominal tagihan:")
    if state == "BILL_AMOUNT":
        try:
            d["amount"] = parse_amount(text)
        except AmountError as e:
            return tg.send_message(chat_id, f"⚠️ {e}")
        set_state(user_id, "BILL_DUE", d)
        return tg.send_message(chat_id, "📅 Tanggal jatuh tempo tiap bulan (1-31):")
    if state == "BILL_DUE":
        try:
            due_day = int(text)
            if not (1 <= due_day <= 31):
                raise ValueError
        except ValueError:
            return tg.send_message(chat_id, "⚠️ Ketik angka 1-31.")
        db().table("bills").insert(
            {"name": d["name"], "amount": d["amount"], "due_day": due_day, "is_recurring": True}
        ).execute()
        reset_state(user_id)
        return tg.send_message(chat_id, f"✅ Tagihan \"{d['name']}\" dibuat, jatuh tempo tgl {due_day} tiap bulan.")


def cmd_bills_list(chat_id):
    res = db().table("bills").select("*").eq("is_active", True).execute()
    if not res.data:
        return tg.send_message(chat_id, "Belum ada tagihan. /bill untuk mulai.")
    lines = ["🧾 <b>Tagihan</b>\n"]
    for b in res.data:
        due = f"tgl {b['due_day']}" if b.get("due_day") else str(b.get("due_date"))
        lines.append(f"#{b['id']} {b['name']}: {rupiah(b['amount'])} ({due})")
    tg.send_message(chat_id, "\n".join(lines))


# ============================================================
# v3: Tags
# ============================================================
def cmd_tag(chat_id, args):
    if len(args) < 2:
        return tg.send_message(chat_id, "Format: /tag <doc_number> <tag1,tag2,...>")
    doc, tag_str = args[0], args[1]
    names = [t.strip() for t in tag_str.split(",") if t.strip()]
    tx = db().table("transactions").select("doc_number").eq("doc_number", doc).execute()
    if not tx.data:
        return tg.send_message(chat_id, f"⚠️ Dokumen {doc} tidak ditemukan.")
    for name in names:
        existing = db().table("tags").select("id").eq("name", name).execute()
        tag_id = existing.data[0]["id"] if existing.data else db().table("tags").insert({"name": name}).execute().data[0]["id"]
        db().table("transaction_tags").upsert({"doc_number": doc, "tag_id": tag_id}).execute()
    tg.send_message(chat_id, f"✅ Tag {', '.join(names)} ditambahkan ke {doc}.")


def cmd_tags_list(chat_id):
    res = db().table("tags").select("name, emoji").execute()
    if not res.data:
        return tg.send_message(chat_id, "Belum ada tag. /tag <doc_number> <nama> untuk mulai.")
    tg.send_message(chat_id, "🏷️ Tags: " + ", ".join(f"{t.get('emoji') or ''}{t['name']}" for t in res.data))


# ============================================================
# v3: Custom category — kode auto dari slot kosong 5940-5980 (grup 5900, lihat COA).
# ============================================================
def cmd_kategori_add(chat_id, args):
    if len(args) < 2 or args[0].lower() != "add":
        return tg.send_message(chat_id, "Format: /kategori add <nama>")
    name = " ".join(args[1:])
    existing = db().table("chart_of_accounts").select("code").like("code", "59%").execute()
    used = {r["code"] for r in existing.data}
    code = next((str(c) for c in range(5940, 5990, 10) if str(c) not in used), None)
    if not code:
        return tg.send_message(chat_id, "⚠️ Slot kategori custom penuh.")
    db().table("chart_of_accounts").insert(
        {
            "code": code,
            "parent_code": "5900",
            "level": 3,
            "account_name": name,
            "account_type": "beban",
            "normal_balance": "debit",
            "is_header": False,
            "is_active": True,
            "is_custom": True,
        }
    ).execute()
    tg.send_message(chat_id, f"✅ Kategori \"{name}\" dibuat ({code}).")


# ============================================================
# v3: Currency conversion (frankfurter.app, gratis tanpa API key)
# ============================================================
def cmd_convert(chat_id, args):
    if len(args) < 3:
        return tg.send_message(chat_id, "Format: /convert <jumlah> <DARI> <KE>\nContoh: /convert 100 USD IDR")
    try:
        amount = float(args[0].replace(",", "."))
    except ValueError:
        return tg.send_message(chat_id, "⚠️ Jumlah tidak valid.")
    try:
        result = fx_convert(amount, args[1], args[2])
    except FxError as e:
        return tg.send_message(chat_id, f"⚠️ {e}")
    tg.send_message(chat_id, f"💱 {amount:g} {args[1].upper()} ≈ {result:,.2f} {args[2].upper()}")


# ============================================================
# v3: /nabung — trigger manual versi prompt akhir bulan (cron job=daily juga
# ngirim ini otomatis di hari terakhir bulan, lihat api/cron/index.py
# _check_end_of_month). User bisa cek & nabung kapan saja, tidak perlu nunggu.
# ============================================================
def cmd_nabung(chat_id):
    today = today_wib()
    income, expense = month_totals(db(), today.year, today.month)
    net = income - expense
    if net <= 0:
        return tg.send_message(chat_id, f"Belum ada sisa bulan ini ({rupiah(net)}). Coba lagi nanti ya.")
    savings_code = setting("savings_account", "1140")
    kb = [[tg.btn(f"✅ Tabung {rupiah(net)}", f"eom_save:{net}"), tg.btn("❌ Nanti saja", "eom_skip")]]
    tg.send_message(
        chat_id,
        f"💰 Sisa bulan ini (s.d. hari ini): <b>{rupiah(net)}</b>\n"
        f"Mau ditabung ke {acc_name(savings_code)} ({savings_code})?",
        keyboard=kb,
    )


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


def send_categories(chat_id, ctype, prefix):
    """Sama seperti show_categories tapi kirim pesan baru (bukan edit) — dipakai wizard
    yang mulai dari input teks (mis. /recurring), bukan dari tombol menu utama."""
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
    tg.send_message(chat_id, "Pilih kategori beban:", keyboard=kb)


def expense_preview(chat_id, user_id):
    d = get_state(user_id)["state_data"]
    amt = d["amount"]
    text = (
        f"📝 <b>Preview Pengeluaran</b>\n\n"
        f"Dr {d['account_code']} {acc_name(d['account_code'])}: {rupiah(amt)}\n"
        f"Cr {d['source']} {acc_name(d['source'])}: {rupiah(amt)}\n\n"
        f"Ket: {d.get('desc') or '-'}"
        + anomaly_warning(d["account_code"], amt)
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
    if data == "act:scan":
        return cmd_scan(chat_id)
    if data == "act:menu":
        return tg.send_message(chat_id, "📲 Menu utama:", keyboard=main_menu())
    # v3: tombol menu utama -> list read-only; nambah baru tetap via command
    # (/budget, /goal, /recurring, /bill, /kategori) karena butuh wizard teks.
    if data == "act:budgets":
        return cmd_budgets_list(chat_id)
    if data == "act:goals":
        return cmd_goals_list(chat_id)
    if data == "act:recurring":
        return cmd_recurring_list(chat_id)
    if data == "act:bills":
        return cmd_bills_list(chat_id)

    # Receipt OCR actions (v2): rcp:save:<id> | rcp:cancel:<id>
    if data.startswith("rcp:"):
        _, action, rid = data.split(":")
        return handle_receipt_action(chat_id, user_id, mid, action, int(rid))

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
            # Link struk (kalau expense ini berasal dari OCR) → status confirmed.
            if d.get("receipt_id"):
                db().table("receipts").update(
                    {"status": "confirmed", "doc_number": doc}
                ).eq("id", d["receipt_id"]).execute()
            reset_state(user_id)
            tg.send_message(
                chat_id,
                f"✅ Tercatat {doc}. Saldo {d['source']}: {rupiah(balance_of(d['source']))}",
                keyboard=continue_keyboard(),
            )
        except Exception as e:
            tg.send_message(chat_id, f"⚠️ Gagal: {e}")
            return
        try:
            # Best-effort: transaksi SUDAH tercatat di atas, jangan sampai budget-check
            # gagal bikin user kira posting-nya gagal (lihat komentar do_POST soal ini).
            check_budget_alert(chat_id, d["account_code"])
        except Exception as e:
            print(f"[webhook] check_budget_alert gagal (non-fatal): {e!r}")
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
            tg.send_message(
                chat_id,
                f"✅ Tercatat {doc}. Saldo {d['dest']}: {rupiah(balance_of(d['dest']))}",
                keyboard=continue_keyboard(),
            )
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
            tg.send_message(chat_id, f"✅ Transfer tercatat {doc}.", keyboard=continue_keyboard())
        except Exception as e:
            tg.send_message(chat_id, f"⚠️ Gagal: {e}")
        return

    # v3: Prompt akhir bulan (dikirim dari api/cron/index.py job=daily) — "nabung
    # sisa bulan?". Reuse alur transfer ke tabungan yang sudah ada.
    if data.startswith("eom_save:"):
        try:
            amount = int(data.split(":", 1)[1])
        except ValueError:
            return tg.edit_message(chat_id, mid, "⚠️ Nominal tidak valid.")
        bni = "1120"
        savings = setting("savings_account", "1140")
        fee = fee_rule(bni, savings)
        lines, _ = build_transfer_lines(bni, savings, amount, fee)
        set_state(user_id, "TRANSFER_PREVIEW", {"lines": lines, "desc": "Nabung sisa bulan"})
        tg.edit_message(chat_id, mid, "👍 Oke, konfirmasi transfernya:")
        return transfer_preview(chat_id, user_id)
    if data == "eom_skip":
        return tg.edit_message(chat_id, mid, "👌 Oke, sisanya dibiarkan dulu. Bisa /goal atau kelola manual kapan saja.")

    # v3: Goal wizard — nama & target sudah di state_data, tinggal pilih akun acuan progress.
    if data.startswith("goal_acc:"):
        d = get_state(user_id)["state_data"]
        code = data.split(":")[1]
        db().table("goals").insert(
            {"name": d["name"], "target_amount": d["target_amount"], "account_code": code}
        ).execute()
        reset_state(user_id)
        return tg.edit_message(chat_id, mid, f"✅ Goal \"{d['name']}\" dibuat — target {rupiah(d['target_amount'])}.")

    # v3: Recurring transaction wizard — reuse category/account picker milik alur expense.
    if data.startswith("rec_cat:"):
        return show_accounts(chat_id, mid, int(data.split(":")[1]), "rec")
    if data.startswith("rec_acc:"):
        d = get_state(user_id)["state_data"]
        d["account_code"] = data.split(":")[1]
        set_state(user_id, "RECURRING_SOURCE", d)
        kb = tg.rows([tg.btn(a["account_name"], f"rec_src:{a['code']}") for a in cash_accounts()], 2)
        return tg.edit_message(chat_id, mid, "🏦 Sumber dana:", keyboard=kb)
    if data.startswith("rec_src:"):
        d = get_state(user_id)["state_data"]
        d["source"] = data.split(":")[1]
        set_state(user_id, "RECURRING_AMOUNT", d)
        return tg.edit_message(chat_id, mid, "💵 Nominal per transaksi:")
    if data.startswith("rec_freq:"):
        d = get_state(user_id)["state_data"]
        freq = data.split(":")[1]
        today = today_wib()
        lines = [
            {"account_code": d["account_code"], "debit": d["amount"], "credit": 0},
            {"account_code": d["source"], "debit": 0, "credit": d["amount"]},
        ]
        db().table("recurring_transactions").insert(
            {
                "doc_type": "KK",
                "description": d["desc"],
                "lines": lines,
                "frequency": freq,
                "next_run": today.isoformat(),
            }
        ).execute()
        reset_state(user_id)
        return tg.edit_message(
            chat_id, mid, f"✅ Recurring \"{d['desc']}\" dibuat ({freq}), mulai {fmt_date(today)}."
        )

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

    st = get_state(user_id)
    state = st["state"]
    d = st["state_data"]

    # Blindspot fix: /skip waktu ngisi keterangan HARUS ditangani state machine di
    # bawah (skip keterangan), bukan di-intercept command-router generik seperti
    # command lain — sebelumnya "/skip" selalu ditangkap duluan oleh
    # text.startswith("/") dan berakhir di handle_command's "/skip" fallback
    # ("Tidak ada yang di-skip."), jadi /skip TIDAK PERNAH benar-benar melewati
    # keterangan walau pesan bantuan menjanjikannya.
    skipping_desc = text == "/skip" and state in ("EXPENSE_DESC", "INCOME_DESC")
    if text.startswith("/") and not skipping_desc:
        return handle_command(chat_id, user_id, text)

    if state.startswith("SETUP_"):
        return handle_setup_input(chat_id, user_id, state, text)

    # v3: wizard states
    if state.startswith("GOAL_"):
        return handle_goal_input(chat_id, user_id, state, text)
    if state.startswith("BILL_"):
        return handle_bill_input(chat_id, user_id, state, text)
    if state == "RECURRING_DESC":
        d["desc"] = text
        set_state(user_id, "RECURRING_CATEGORY", d)
        return send_categories(chat_id, "expense", "rec")
    if state == "RECURRING_AMOUNT":
        try:
            d["amount"] = parse_amount(text)
        except AmountError as e:
            return tg.send_message(chat_id, f"⚠️ {e}")
        set_state(user_id, "RECURRING_FREQ", d)
        kb = [[tg.btn("Harian", "rec_freq:daily"), tg.btn("Mingguan", "rec_freq:weekly"), tg.btn("Bulanan", "rec_freq:monthly")]]
        return tg.send_message(chat_id, "🔁 Frekuensi:", keyboard=kb)

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
    if cmd == "/scan":
        return cmd_scan(chat_id)
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
        return tg.send_message(chat_id, "Tidak ada yang di-skip.")

    # v3 commands
    if cmd == "/undo":
        return cmd_undo(chat_id)
    if cmd == "/budget":
        return cmd_budget_set(chat_id, parts[1:])
    if cmd == "/budgets":
        return cmd_budgets_list(chat_id)
    if cmd == "/goal":
        return cmd_goal_start(chat_id, user_id)
    if cmd == "/goals":
        return cmd_goals_list(chat_id)
    if cmd == "/recurring":
        if len(parts) > 1 and parts[1].lower() == "list":
            return cmd_recurring_list(chat_id)
        return cmd_recurring_start(chat_id, user_id)
    if cmd == "/bill":
        return cmd_bill_start(chat_id, user_id)
    if cmd == "/bills":
        return cmd_bills_list(chat_id)
    if cmd == "/tag":
        return cmd_tag(chat_id, parts[1:])
    if cmd == "/tags":
        return cmd_tags_list(chat_id)
    if cmd == "/kategori":
        return cmd_kategori_add(chat_id, parts[1:])
    if cmd == "/convert":
        return cmd_convert(chat_id, parts[1:])
    if cmd == "/nabung":
        return cmd_nabung(chat_id)

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

        # v3: rate limiting + activity log (db/16_activity_log.sql).
        # Kegagalan di sini TIDAK boleh menghentikan bot utamanya — cuma best-effort.
        chat_id = _chat_id_of(msg, cb)
        if from_id and chat_id:
            try:
                rate_limit = int(setting("rate_limit_per_minute", "20"))
                if activity.count_recent(from_id, 60) >= rate_limit:
                    tg.send_message(chat_id, "⏳ Terlalu banyak pesan dalam 1 menit terakhir, tunggu sebentar ya.")
                    return send_json(self, 200, {"ok": True})
                activity.log(from_id, _action_label(msg, cb))
            except Exception as e:
                print(f"[webhook] rate-limit/activity-log gagal (lanjut tanpa itu): {e!r}")

        try:
            if cb:
                handle_callback(cb)
            elif msg and "photo" in msg:
                handle_photo(msg["chat"]["id"], from_id, msg)
            elif msg and "document" in msg:
                handle_document(msg["chat"]["id"], from_id, msg)
            elif msg and "text" in msg:
                handle_text(msg["chat"]["id"], from_id, msg["text"])
        except Exception as e:
            # Blindspot fix: pesan error mentah (str(e)) bisa bocorin detail teknis ke
            # user. Detail asli di-log ke stdout (masuk Vercel function logs); user cuma
            # lihat pesan ramah. Jangan biarkan Telegram retry storm — tetap balas 200.
            if msg:
                print(f"[webhook] unhandled error: {e!r}")
                tg.send_message(msg["chat"]["id"], "⚠️ Terjadi kesalahan. Coba lagi, atau ketik /menu untuk mulai ulang.")

        send_json(self, 200, {"ok": True})
