"""Statistik ringan tanpa numpy/pandas (B7: requirements.txt sengaja minimal).

- zscore/is_anomaly: deteksi nilai yang menyimpang jauh dari rata-rata historis.
- holt_forecast/linear_forecast: proyeksi 1..N periode ke depan via Holt's
  linear trend exponential smoothing (bukan regresi OLS polos — lihat
  docstring holt_forecast soal kenapa ini lebih tepat untuk deret pendek &
  rawan outlier seperti income/expense bulanan personal). Dipakai untuk
  forecast jangka pendek/menengah/panjang di api/reports/index.py.
"""
import math
from statistics import mean, pstdev


def zscore(value: float, history: list[float]) -> float | None:
    """Z-score value relatif terhadap history. None kalau history < 2 titik atau stdev=0."""
    if len(history) < 2:
        return None
    mu = mean(history)
    sigma = pstdev(history)
    if sigma == 0:
        return None
    return (value - mu) / sigma


def is_anomaly(value: float, history: list[float], threshold: float = 2.0) -> bool:
    z = zscore(value, history)
    return z is not None and abs(z) >= threshold


SENSITIVITY_THRESHOLDS = {"strict": 1.5, "normal": 2.0, "relaxed": 2.5}


def threshold_for(sensitivity: str) -> float:
    return SENSITIVITY_THRESHOLDS.get(sensitivity, SENSITIVITY_THRESHOLDS["normal"])


def _winsorize(history: list[float], threshold: float = 2.5) -> list[float]:
    """Redam (bukan buang) titik yang menyimpang ekstrem sebelum forecasting —
    satu bulan dengan pembelian besar tak berulang (mis. beli laptop, servis
    mobil mahal sekali) bukan pola bulanan dan tidak boleh membengkokkan
    proyeksi tren untuk bulan-bulan berikutnya secara permanen. Sama
    prinsipnya dengan pemisahan "pembelian besar" di grafik Dashboard (lihat
    §9.5/9.8 doc.txt) — titik di-cap ke ±threshold*stdev dari rata-rata TITIK
    LAIN, bukan dihapus (jumlah titik & jaraknya tidak berubah).

    Sengaja pakai z-score "leave-one-out" (rata-rata & stdev dihitung dari
    titik-titik LAIN, tidak termasuk titik yang sedang diuji) — bukan z-score
    biasa terhadap seluruh deret. Kalau titik yang diuji ikut dihitung ke
    rata-rata/stdev-nya sendiri, satu outlier ekstrem bisa "menutupi jejaknya
    sendiri" dengan menggelembungkan stdev sampai z-score-nya tidak pernah
    lewat threshold berapa pun besarnya outlier itu (classic masking effect
    di statistik) — makin ekstrem nilainya, makin besar juga stdev yang
    dipakai untuk menilainya, sehingga BATAS ATAS z-score-nya terjebak di
    sekitar sqrt(n-1) untuk satu outlier di antara n titik, tidak peduli
    seberapa ekstrem nilainya. Leave-one-out menghindari ini karena titik yang
    diuji tidak pernah ikut menentukan skala pembandingnya sendiri.

    Deret <4 titik dibiarkan apa adanya — statistik leave-one-out tidak
    reliable dengan sedikit data.
    """
    n = len(history)
    if n < 4:
        return list(history)
    result = []
    for i, v in enumerate(history):
        rest = history[:i] + history[i + 1 :]
        mu = mean(rest)
        cap = threshold * pstdev(rest)
        deviation = v - mu
        result.append(mu + math.copysign(cap, deviation) if abs(deviation) > cap else v)
    return result


def holt_forecast(history: list[float], steps: int = 1) -> list[float]:
    """Proyeksi `steps` periode ke depan via Holt's linear trend exponential
    smoothing — dipakai untuk forecast jangka pendek (1 bulan), menengah
    (mis. 3 bulan), dan panjang (mis. 12 bulan) dari model tren yang SAMA,
    bukan model terpisah per horizon.

    Kenapa bukan regresi OLS (versi sebelumnya): OLS menarik SATU garis lurus
    lewat SEMUA titik dengan bobot yang sama — untuk deret pendek (baru
    beberapa bulan data) dan rawan satu bulan outlier (belanja besar
    tak-berulang), itu gampang membengkok jauh dan gampang mengekstrapolasi
    ekstrem. Holt's method (level + tren, diperbarui tiap titik dengan
    pembobotan eksponensial) adalah teknik standar forecasting deret waktu
    pendek yang masih punya tren tapi noisy — observasi terbaru dapat bobot
    lebih besar, dan hasilnya tidak overreact ke satu titik ekstrem seperti
    OLS. Dikombinasikan dengan winsorizing (_winsorize) sebelum smoothing,
    supaya satu bulan anomali tidak mendistorsi tren jangka panjang.

    history[0] = titik terlama, history[-1] = titik terbaru — HARUS cuma
    berisi bulan yang benar-benar sudah lengkap/ada datanya (caller yang
    tanggung jawab tidak mem-padding bulan sebelum user mulai pakai sistem
    dengan nol — nol palsu itu bikin winsorizing salah kira satu-satunya
    bulan asli sebagai outlier, lihat catatan _winsorize & diskusi user soal
    ini). Return list kosong kalau history kosong. 1 titik -> proyeksi flat
    (bawa nilai sama ke depan, trend=0) karena belum cukup untuk hitung
    tren — LEBIH BAIK dari tidak ada forecast sama sekali begitu user punya
    1 bulan lengkap (landasan minimal yang disepakati), tapi confidence-nya
    jelas lebih rendah dari 2+ titik. Tiap elemen hasil di-floor ke 0
    (nominal uang tidak masuk akal negatif).
    """
    n = len(history)
    if n < 1 or steps < 1:
        return []
    if n == 1:
        return [max(0.0, history[0])] * steps

    smoothed = _winsorize(history)
    alpha, beta = 0.4, 0.3  # bobot level vs tren — nilai umum dipakai Holt's method
    level = smoothed[0]
    trend = smoothed[1] - smoothed[0]
    for y in smoothed[1:]:
        new_level = alpha * y + (1 - alpha) * (level + trend)
        trend = beta * (new_level - level) + (1 - beta) * trend
        level = new_level

    return [max(0.0, level + trend * h) for h in range(1, steps + 1)]


def linear_forecast(history: list[float]) -> float | None:
    """Proyeksi 1 periode ke depan — alias 1-step dari holt_forecast(),
    dipertahankan untuk caller lama (mis. forecast per kategori). None kalau
    history kosong."""
    result = holt_forecast(history, steps=1)
    return result[0] if result else None
