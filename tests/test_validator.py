"""Offline tests untuk amount parsing (tanpa DB). Jalankan: python -m pytest tests/"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest

from shared.validator import AmountError, parse_amount


@pytest.mark.parametrize(
    "inp,exp",
    [
        ("25000", 25000),
        ("25.000", 25000),
        ("25,000", 25000),
        ("25k", 25000),
        ("25rb", 25000),
        ("25jt", 25_000_000),
        ("2,5jt", 2_500_000),
        ("1.234.567", 1_234_567),
    ],
)
def test_valid(inp, exp):
    assert parse_amount(inp) == exp


@pytest.mark.parametrize("inp", ["0", "-25000", "dua puluh lima", ""])
def test_invalid(inp):
    with pytest.raises(AmountError):
        parse_amount(inp)
