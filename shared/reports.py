"""Helper laporan kecil yang dipakai LINTAS api/ (bot + cron) — supaya command
manual (/nabung) dan job cron (job=daily, cek akhir bulan) tidak duplikasi query
yang sama persis.
"""


def month_totals_from_rows(rows):
    """Aggregasi income/expense dari baris monthly_summary yang SUDAH di-fetch
    (dipakai kalau caller sudah butuh raw rows-nya juga, biar tidak query 2x)."""
    income = expense = 0
    for r in rows:
        if r["account_type"] == "pendapatan":
            income += r["total_credit"] - r["total_debit"]
        elif r["account_type"] == "beban":
            expense += r["total_debit"] - r["total_credit"]
    return income, expense


def month_totals(db, year, month):
    """Total income (pendapatan) & expense (beban) bulan berjalan dari monthly_summary."""
    res = db.table("monthly_summary").select("*").eq("period_year", year).eq("period_month", month).execute()
    return month_totals_from_rows(res.data)
