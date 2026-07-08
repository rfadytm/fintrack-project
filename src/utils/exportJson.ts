// Export ke .json — pure client-side, literal JSON.stringify dari data yang sudah di-fetch.
import { toast } from "sonner";

export function exportJson(filename: string, data: unknown) {
  const isEmpty = Array.isArray(data) ? data.length === 0 : !data;
  if (isEmpty) {
    toast.error("Tidak ada data untuk diexport.");
    return;
  }
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
