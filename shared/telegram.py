"""Telegram Bot API via raw httpx (B7 — tanpa python-telegram-bot, function kecil)."""
import os

import httpx

TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
API = f"https://api.telegram.org/bot{TOKEN}"

_client = httpx.Client(timeout=15)


def _post(method: str, payload: dict) -> dict:
    r = _client.post(f"{API}/{method}", json=payload)
    return r.json()


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
