"""Offline tests untuk shared/fx.py — httpx di-mock, tidak ada network call asli.
Jalankan: python -m pytest tests/
"""
import os
import sys
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import httpx
import pytest

from shared.fx import FxError, convert


def test_convert_same_currency_no_network_call():
    with patch("shared.fx.httpx.get") as mock_get:
        assert convert(100, "IDR", "IDR") == 100
        mock_get.assert_not_called()


def test_convert_success():
    mock_resp = MagicMock()
    mock_resp.json.return_value = {"amount": 100, "rates": {"IDR": 1580000.0}}
    mock_resp.raise_for_status.return_value = None
    with patch("shared.fx.httpx.get", return_value=mock_resp) as mock_get:
        result = convert(100, "usd", "idr")
        assert result == 1580000.0
        mock_get.assert_called_once()


def test_convert_unsupported_currency_raises_fxerror():
    mock_resp = MagicMock()
    mock_resp.json.return_value = {"amount": 100, "rates": {}}
    mock_resp.raise_for_status.return_value = None
    with patch("shared.fx.httpx.get", return_value=mock_resp):
        with pytest.raises(FxError):
            convert(100, "USD", "XXX")


def test_convert_http_error_raises_fxerror():
    with patch("shared.fx.httpx.get", side_effect=httpx.ConnectError("boom")):
        with pytest.raises(FxError):
            convert(100, "USD", "IDR")


def test_convert_bad_json_raises_fxerror():
    mock_resp = MagicMock()
    mock_resp.raise_for_status.return_value = None
    mock_resp.json.side_effect = ValueError("bad json")
    with patch("shared.fx.httpx.get", return_value=mock_resp):
        with pytest.raises(FxError):
            convert(100, "USD", "IDR")
