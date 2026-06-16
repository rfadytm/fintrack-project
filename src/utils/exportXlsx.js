// Export ke .xlsx. Library di-load dinamis (hanya saat tombol diklik) agar tidak membebani bundle awal.

export async function exportRows(filename, sheetName, rows) {
  if (!rows || !rows.length) {
    alert("Tidak ada data untuk diexport.");
    return;
  }
  const XLSX = await import("xlsx");
  const ws = XLSX.utils.json_to_sheet(rows);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, sheetName.slice(0, 31));
  XLSX.writeFile(wb, filename);
}

export async function exportSheets(filename, sheets) {
  const XLSX = await import("xlsx");
  const wb = XLSX.utils.book_new();
  let any = false;
  for (const s of sheets) {
    if (!s.rows || !s.rows.length) continue;
    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(s.rows), s.name.slice(0, 31));
    any = true;
  }
  if (!any) {
    alert("Tidak ada data untuk diexport.");
    return;
  }
  XLSX.writeFile(wb, filename);
}

export function stamp() {
  return new Date().toISOString().slice(0, 10);
}
