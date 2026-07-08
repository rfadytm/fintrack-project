// Export ke .csv — pure client-side, sama pola dynamic-import-free karena CSV tidak
// butuh library (cukup string join), konsisten dengan exportXlsx.ts/exportPdf.ts.
import { toast } from "sonner";
import type { XlsxRow } from "./exportXlsx";

function escapeCsvCell(value: string | number): string {
  const s = String(value);
  if (/[",\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

// Exported separately so the string-building logic is unit-testable without
// touching the DOM (jsdom doesn't implement URL.createObjectURL).
export function toCsvString(rows: XlsxRow[]): string {
  const headers = Object.keys(rows[0]);
  const lines = [
    headers.join(","),
    ...rows.map((row) => headers.map((h) => escapeCsvCell(row[h] ?? "")).join(",")),
  ];
  return lines.join("\n");
}

export function exportCsv(filename: string, rows: XlsxRow[]) {
  if (!rows || !rows.length) {
    toast.error("Tidak ada data untuk diexport.");
    return;
  }
  const blob = new Blob(["﻿" + toCsvString(rows)], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
