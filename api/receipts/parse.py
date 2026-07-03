"""POST /api/receipts/parse — OCR struk/nota -> field transaksi (belum di-posting).

Auth: session cookie (dashboard) ATAU header X-API-Key (project lain).
Body JSON (salah satu sumber gambar):
  {"telegram_file_id": "AgAC..."}         # ambil dari Telegram servers
  {"image_base64": "<base64 JPEG/PNG>"}   # kirim gambar langsung

Return:
  {
    "receipt_id": 12,
    "parsed": {"merchant": "Indomaret", "amount": 45000,
               "date": "2026-07-03", "confidence": 100},
    "raw_ocr_text": "..."
  }

Endpoint ini TIDAK memposting transaksi — ia mengembalikan hasil parse sebagai
building block. Caller lalu POST /api/transactions untuk membukukannya.
"""
import base64
import os as _os, sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))))
from http.server import BaseHTTPRequestHandler

from shared import ocr, telegram as tg
from shared.db import get_client
from shared.http import read_json, require_auth, send_json
from shared.receipt_parser import parse_receipt


class handler(BaseHTTPRequestHandler):
    def do_POST(self):
        auth = require_auth(self)
        if not auth:
            return
        body = read_json(self)

        file_id = body.get("telegram_file_id")
        img_b64 = body.get("image_base64")
        source = body.get("source", "receipt")
        if source not in ("receipt", "ewallet"):
            source = "receipt"

        # 1) Ambil bytes gambar
        try:
            if file_id:
                image = tg.download_file(file_id)
            elif img_b64:
                image = base64.b64decode(img_b64)
                file_id = file_id or "inline"
            else:
                return send_json(self, 400, {"error": "wajib telegram_file_id atau image_base64"})
        except Exception as e:
            return send_json(self, 400, {"error": f"gagal ambil gambar: {e}"})

        # 2) OCR
        try:
            raw_text = ocr.extract_text(image)
        except ocr.OCRError as e:
            return send_json(self, 502, {"error": str(e)})

        # 3) Parse
        parsed = parse_receipt(raw_text)

        # 4) Simpan ke receipts (status pending)
        try:
            chat_id = int(body.get("telegram_chat_id") or 0)
        except (ValueError, TypeError):
            chat_id = 0
        note = (body.get("note") or "").strip() or None
        row = {
            "telegram_file_id": file_id or "inline",
            "telegram_chat_id": chat_id,
            "raw_ocr_text": raw_text,
            "parsed_merchant": parsed["merchant"],
            "parsed_amount": parsed["amount"],
            "parsed_date": parsed["date"],
            "confidence_score": parsed["confidence"],
            "parse_source": source,
            "note": note,
            "status": "pending",
        }
        res = get_client().table("receipts").insert(row).execute()
        receipt_id = res.data[0]["id"] if res.data else None

        send_json(
            self,
            200,
            {
                "receipt_id": receipt_id,
                "parsed": {
                    "merchant": parsed["merchant"],
                    "amount": parsed["amount"],
                    "date": parsed["date"],
                    "confidence": parsed["confidence"],
                },
                "raw_ocr_text": raw_text,
            },
        )
