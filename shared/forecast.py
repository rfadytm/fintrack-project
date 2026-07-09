"""Statistik ringan tanpa numpy/pandas (B7: requirements.txt sengaja minimal).

- zscore/is_anomaly: deteksi nilai yang menyimpang jauh dari rata-rata historis.
- linear_forecast: proyeksi bulan depan via Holt's linear trend exponential
  smoothing (bukan regresi OLS polos — lihat docstring linear_forecast soal
  kenapa ini lebih tepat untuk deret pendek & rawan outlier seperti
  income/expense bulanan personal).
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


def linear_forecast(history: list[float]) -> float | None:
    """Proyeksi bulan depan via Holt's linear trend exponential smoothing.

    Kenapa bukan regresi OLS (versi sebelumnya): OLS menarik SATU garis lurus
    lewat SEMUA titik dengan bobot yang sama — untuk deret pendek (baru
    beberapa bulan data) dan rawan satu bulan outlier (belanja besar
    tak-berulang), itu gampang membengkok jauh dan gampang mengekstrapolasi
    ekstrem. Holt's method (level + trend, diperbarui tiap titik dengan
    pembobotan eksponensial) adalah teknik standar forecasting deret waktu
    pendek yang masih punya tren tapi noisy — observasi terbaru dapat bobot
    lebih besar, dan hasilnya tidak overreact ke satu titik ekstrem seperti
    OLS. Dikombinasikan dengan winsorizing (_winsorize) sebelum smoothing,
    supaya satu bulan anomali tidak mendistorsi tren jangka panjang.

    history[0] = titik terlama, history[-1] = titik terbaru. Return proyeksi
    untuk titik SETELAH history (mis. history = 6 bulan terakhir -> proyeksi
    bulan ke-7). None kalau history < 2 titik. Hasil selalu >= 0 (nominal
    uang tidak masuk akal negatif).
    """
    n = len(history)
    if n < 2:
        return None
    smoothed = _winsorize(history)

    alpha, beta = 0.4, 0.3  # bobot level vs tren — nilai umum dipakai Holt's method
    level = smoothed[0]
    trend = smoothed[1] - smoothed[0]
    for y in smoothed[1:]:
        new_level = alpha * y + (1 - alpha) * (level + trend)
        trend = beta * (new_level - level) + (1 - beta) * trend
        level = new_level

    return max(0.0, level + trend)
