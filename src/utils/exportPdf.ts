// Export ke .pdf — client-side (jsPDF + jspdf-autotable), dynamic import saat
// tombol diklik (sama pola dengan exportXlsx.ts) agar bundle awal tetap kecil.
import { toast } from "sonner";
import type { XlsxRow } from "./exportXlsx";

export async function exportPdf(filename: string, title: string, rows: XlsxRow[]) {
  if (!rows || !rows.length) {
    toast.error("Tidak ada data untuk diexport.");
    return;
  }
  const [{ jsPDF }, { default: autoTable }] = await Promise.all([
    import("jspdf"),
    import("jspdf-autotable"),
  ]);
  const doc = new jsPDF();
  doc.setFontSize(14);
  doc.text(title, 14, 16);

  const headers = Object.keys(rows[0]);
  autoTable(doc, {
    startY: 22,
    head: [headers],
    body: rows.map((row) => headers.map((h) => String(row[h] ?? ""))),
    styles: { fontSize: 8 },
    headStyles: { fillColor: [31, 56, 100] }, // navy brand color
  });

  doc.save(filename);
}
