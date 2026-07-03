"""Telegram Bot API via raw httpx (B7 — tanpa python-telegram-bot, function kecil)."""
import os

import httpx

TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
API = f"https://api.telegram.org/bot{TOKEN}"
FILE_API = f"https://api.telegram.org/file/bot{TOKEN}"

_client = httpx.Client(timeout=15)


def _post(method: str, payload: dict) -> dict:
    r = _client.post(f"{API}/{method}", json=payload)
    return r.json()


def get_file_path(file_id: str) -> str | None:
    """Resolve file_id -> file_path via getFile (langkah 1 download)."""
    res = _post("getFile", {"file_id": file_id})
    if not res.get("ok"):
        return None
    return res["result"].get("file_path")


def download_file(file_id: str, timeout: int = 30) -> bytes:
    """Unduh file (mis. foto struk) dari Telegram servers via file_id.

    2 GET httpx saja (getFile -> download) — cukup, tanpa python-telegram-bot (B7).
    Raise RuntimeError kalau file_id tidak bisa di-resolve.
    """
    path = get_file_path(file_id)
    if not path:
        raise RuntimeError("Tidak bisa resolve file_id ke file_path (getFile gagal).")
    r = httpx.get(f"{FILE_API}/{path}", timeout=timeout)
    r.raise_for_status()
    return r.content


def send_message(chat_id, text, keyboard=None, parse_mode="HTML"):
    payload = {"chat_id": chat_id, "text": text, "parse_mode": parse_mode}
    if keyboard is not None:
        payload["reply_markup"] = {"inline_keyboard": keyboard}
    return _post("sendMessage", payload)


def edit_message(chat_id, message_id, text, keyboard=None, parse_mode="HTML"):
    payload = {
        "chat_id": chat_id,
        "message_id": message_id,
        "text": text,
        "parse_mode": parse_mode,
    }
    if keyboard is not None:
        payload["reply_markup"] = {"inline_keyboard": keyboard}
    return _post("editMessageText", payload)


def answer_callback(callback_id, text=None):
    payload = {"callback_query_id": callback_id}
    if text:
        payload["text"] = text
    return _post("answerCallbackQuery", payload)


def btn(text, data):
    """Inline button (callback)."""
    return {"text": text, "callback_data": data}


def url_btn(text, url):
    return {"text": text, "url": url}


def rows(buttons, per_row=2):
    """Pecah list button jadi rows of N."""
    return [buttons[i : i + per_row] for i in range(0, len(buttons), per_row)]
