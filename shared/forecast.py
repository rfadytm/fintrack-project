"""Statistik ringan tanpa numpy/pandas (B7: requirements.txt sengaja minimal).

- zscore/is_anomaly: deteksi nilai yang menyimpang jauh dari rata-rata historis.
- linear_forecast: proyeksi linear sederhana (least squares) buat prediksi bulan depan.
"""
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


def linear_forecast(history: list[float]) -> float | None:
    """Proyeksi nilai titik berikutnya via regresi linear least-squares sederhana.

    history[0] = titik terlama, history[-1] = titik terbaru. Return proyeksi untuk
    titik setelah history (mis. history = 6 bulan terakhir -> return proyeksi bulan ke-7).
    None kalau history < 2 titik.
    """
    n = len(history)
    if n < 2:
        return None
    xs = list(range(n))
    x_mean = mean(xs)
    y_mean = mean(history)
    denominator = sum((x - x_mean) ** 2 for x in xs)
    if denominator == 0:
        return y_mean
    slope = sum((x - x_mean) * (y - y_mean) for x, y in zip(xs, history)) / denominator
    intercept = y_mean - slope * x_mean
    return slope * n + intercept
