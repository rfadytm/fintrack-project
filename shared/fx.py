"""Konversi mata uang via frankfurter.app — gratis, tanpa API key, rate ECB harian.
Dipakai command bot /convert dan preferensi tampilan multi-currency.
"""
import httpx

FX_API_URL = "https://api.frankfurter.app/latest"


class FxError(RuntimeError):
    pass


def convert(amount: float, from_ccy: str, to_ccy: str, timeout: int = 10) -> float:
    """Konversi amount dari from_ccy ke to_ccy. Raise FxError kalau gagal/tidak didukung."""
    from_ccy = from_ccy.upper()
    to_ccy = to_ccy.upper()
    if from_ccy == to_ccy:
        return amount
    try:
        r = httpx.get(
            FX_API_URL,
            params={"amount": amount, "from": from_ccy, "to": to_ccy},
            timeout=timeout,
        )
        r.raise_for_status()
        data = r.json()
    except httpx.HTTPError as e:
        raise FxError(f"Gagal hubungi layanan kurs: {e}") from e
    except ValueError as e:
        raise FxError("Respons kurs bukan JSON valid.") from e

    rates = data.get("rates") or {}
    if to_ccy not in rates:
        raise FxError(f"Mata uang {to_ccy} tidak didukung.")
    return rates[to_ccy]
