"""Masking angka sensitif untuk viewer publik (demo live di portfolio).

Representasi mask = None (bukan string semacam "***"). Alasan: hampir
semua field yang di-mask di sini dipakai untuk ARITMATIKA/PERBANDINGAN di
frontend (jumlah kumulatif grafik timeline, perbandingan > threshold,
animasi angka, dst — lihat Dashboard.tsx TimelineSection). String sentinel
seperti "***" akan lolos ke operasi matematis itu dan MERUSAK data secara
diam-diam (mis. `"0" + "***"` di JS jadi concat string "0***", bukan error
yang kelihatan). None aman karena seluruh kodebase INI SUDAH punya pola
`value ?? 0` / `value || 0` di mana-mana untuk state "belum ada data" —
masking dengan None otomatis lewat jalur yang sudah teruji itu, bukan
jalur baru yang belum pernah ditangani di manapun.

Trade-off yang disadari: field yang di-mask jadi tidak bisa dibedakan
dari "memang belum ada data" (mis. tier forecast yang terkunci karena
riwayat kurang, vs. tier yang sebenarnya ada nilainya tapi disembunyikan
— keduanya sama-sama tampil None). Untuk tujuan demo publik ini diterima:
prioritasnya "angka asli tidak pernah bocor", bukan "keliatan persis
kenapa kosongnya". Lihat doc.txt untuk diskusi lengkapnya.

Prinsip lain yang tetap dipegang: mask dengan MENGGANTI nilai field
secara eksplisit di titik respons dibuat, bukan lewat penelusuran
generik/rekursif struktur data — tiap baris gampang diaudit satu-satu.

PENTING buat yang nambah report/endpoint baru: field di-mask dengan cara
DIGANTI isinya (row[key] = None), BUKAN ditambah field baru di sampingnya
(mis. jangan `row["amount_masked"] = None` sambil `row["amount"]` masih
ada). Kalau field asli tetap ada di payload, fitur export (xlsx/csv/json/
pdf) yang men-dump seluruh objek apa adanya akan tetap membocorkan angka
aslinya walau tampilan dashboard-nya kelihatan aman.
"""


def mask_amount(value):
    """Satu nilai numerik sensitif -> None, apapun nilai aslinya (termasuk
    kalau sudah None dari sononya — hasilnya tetap None, no-op)."""
    return None


def mask_number_list(values: list) -> list:
    """Array angka polos, mis. income_history/expense_history."""
    return [None for _ in values]


def mask_row(row: dict, fields: set) -> dict:
    """Copy dari `row` dengan tiap key di `fields` diganti None kalau ada
    di row. Field lain (kode akun, nama, tanggal, tipe, boolean) dibiarkan
    apa adanya."""
    out = dict(row)
    for f in fields:
        if f in out:
            out[f] = None
    return out


def mask_rows(rows: list, fields: set) -> list:
    return [mask_row(r, fields) for r in rows]


def is_public(viewer: dict) -> bool:
    return viewer.get("via") == "public"
