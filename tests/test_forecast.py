"""Offline tests untuk shared/forecast.py (murni stdlib, tanpa DB). Jalankan: python -m pytest tests/"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from shared.forecast import is_anomaly, linear_forecast, threshold_for, zscore


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
