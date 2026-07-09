"""Offline tests untuk shared/forecast.py (murni stdlib, tanpa DB). Jalankan: python -m pytest tests/"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from shared.forecast import _winsorize, is_anomaly, linear_forecast, threshold_for, zscore


def test_zscore_none_with_insufficient_history():
    assert zscore(100, []) is None
    assert zscore(100, [50]) is None


def test_zscore_none_when_no_variance():
    assert zscore(100, [50, 50, 50]) is None


def test_zscore_basic():
    # history rata2=50, stdev(pop)=0 kalau semua sama; pakai variasi kecil.
    history = [40, 50, 60]
    z = zscore(100, history)
    assert z is not None and z > 2


def test_is_anomaly_flags_large_outlier():
    history = [30000, 32000, 28000, 31000, 29500]
    assert is_anomaly(500000, history, threshold=2.0) is True
    assert is_anomaly(31500, history, threshold=2.0) is False


def test_threshold_for_sensitivity():
    assert threshold_for("strict") == 1.5
    assert threshold_for("normal") == 2.0
    assert threshold_for("relaxed") == 2.5
    assert threshold_for("unknown") == 2.0  # fallback ke normal


def test_linear_forecast_flat_series():
    # Nilai konstan -> proyeksi = nilai konstan.
    assert linear_forecast([100, 100, 100, 100]) == 100


def test_linear_forecast_increasing_trend():
    # 10, 20, 30, 40 -> proyeksi titik ke-5 = 50.
    assert linear_forecast([10, 20, 30, 40]) == 50


def test_linear_forecast_insufficient_history():
    assert linear_forecast([]) is None
    assert linear_forecast([42]) is None


def test_linear_forecast_dampens_single_outlier_month():
    """Ilmu akuntansi: satu bulan belanja besar tak-berulang (mis. beli laptop)
    bukan pola bulanan dan tidak boleh dianggap sebagai tren baru. Naive OLS
    lama akan menarik proyeksi ke arah 3jt; Holt's + winsorizing harus tetap
    dekat baseline ~100."""
    history = [100, 90, 3_000_000, 110, 95, 105]
    forecast = linear_forecast(history)
    assert forecast is not None
    assert forecast < 1000  # jauh dari magnitude outlier, dekat baseline


def test_linear_forecast_never_negative():
    # Tren turun tajam yang secara naif akan mengekstrapolasi ke negatif —
    # nominal uang tidak masuk akal negatif.
    assert linear_forecast([100, 60, 20]) == 0.0


def test_winsorize_leaves_short_series_untouched():
    # <4 titik: leave-one-out tidak reliable, dibiarkan apa adanya.
    assert _winsorize([100, 100, 100_000]) == [100, 100, 100_000]


def test_winsorize_caps_extreme_point_leaves_normal_points_alone():
    history = [90, 110, 95, 3_000_000, 105, 100]
    capped = _winsorize(history)
    assert capped[3] < 1000  # outlier redam jauh dari nilai aslinya
    assert capped[0] == 90 and capped[1] == 110 and capped[2] == 95  # titik normal tak tersentuh


def test_winsorize_not_fooled_by_masking_effect():
    """Regression guard: pendekatan z-score naif (rata-rata & stdev dari SELURUH
    deret termasuk titik yang diuji) gagal mendeteksi outlier ini sama sekali
    karena outlier menggelembungkan stdev-nya sendiri (masking effect) — z-score
    naif untuk 1 outlier di antara 5 titik identik selalu mentok di sqrt(4)=2.0,
    di bawah threshold manapun yang masuk akal. Leave-one-out (dipakai di sini)
    harus tetap menangkapnya."""
    history = [100, 100, 100, 100, 10_000]
    capped = _winsorize(history)
    assert capped[-1] < 5000
