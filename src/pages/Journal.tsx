import { useEffect, useState } from "react";
import { toast } from "sonner";
import TransactionTable from "../components/TransactionTable";
import { Button } from "../components/ui/button";
import { Select } from "../components/ui/select";
import { Skeleton } from "../components/ui/skeleton";
import { useTransactions } from "../hooks/useTransactions";
import { api } from "../utils/api";
import { exportRows, stamp } from "../utils/exportXlsx";
import { formatTanggal } from "../utils/dateHelpers";

const DOC_TYPES = ["OB", "KK", "KM", "TR", "JU", "RV"];

export default function Journal() {
  const [type, setType] = useState("");
  const [page, setPage] = useState(0);
  const [exporting, setExporting] = useState(false);
  const limit = 25;
  const qs = `?limit=${limit}&offset=${page * limit}${type ? `&type=${type}` : ""}`;
  const { loading, transactions, total, error } = useTransactions(qs);
  const pages = Math.ceil((total || 0) / limit);

  // Blindspot fix: if a filter change shrinks `total`, the current page could
  // be left past the new last page (pager showing an empty table with no way back).
  useEffect(() => {
    if (!loading && pages > 0 && page >= pages) setPage(pages - 1);
  }, [loading, pages, page]);

  const handleExport = async () => {
    setExporting(true);
    try {
      const [txRes, accRes] = await Promise.all([
        api.transactions(`?limit=2000${type ? `&type=${type}` : ""}`),
        api.accounts(),
      ]);
      const nameByCode: Record<string, string> = {};
      (accRes.accounts || []).forEach((a) => (nameByCode[a.code] = a.account_name));
      const rows: Record<string, string | number>[] = [];
      (txRes.transactions || []).forEach((t) => {
        (t.journal_lines || [])
          .slice()
          .sort((a, b) => (a.line_order || 0) - (b.line_order || 0))
          .forEach((l) => {
            rows.push({
              Dokumen: t.doc_number,
              Tanggal: formatTanggal(t.transaction_date),
              Tipe: t.doc_type,
              Keterangan: t.description || "",
              Status: t.status,
              Kode: l.account_code,
              Akun: nameByCode[l.account_code] || "",
              Debit: l.debit_amount || 0,
              Kredit: l.credit_amount || 0,
            });
          });
      });
      await exportRows(`fintrack_jurnal_${stamp()}.xlsx`, "Jurnal", rows);
    } catch (e) {
      toast.error("Gagal export: " + (e as Error).message);
    } finally {
      setExporting(false);
    }
  };

  return (
    <div className="space-y-4">
      <h2 className="text-navy text-xl font-bold m-0">Jurnal</h2>
      <div className="flex gap-3 items-center flex-wrap">
        <Select
          className="w-auto"
          value={type}
          onChange={(e) => {
            setType(e.target.value);
            setPage(0);
          }}
        >
          <option value="">Semua tipe</option>
          {DOC_TYPES.map((t) => (
            <option key={t} value={t}>
              {t}
            </option>
          ))}
        </Select>
        <Button variant="outline" size="sm" onClick={handleExport} disabled={exporting}>
          {exporting ? "Mengexport…" : "⬇️ Export .xlsx"}
        </Button>
      </div>
      {error && <p className="text-red text-sm">Gagal memuat jurnal: {error}</p>}
      {loading ? <Skeleton className="h-64" /> : <TransactionTable transactions={transactions} />}
      <div className="flex items-center justify-center gap-3">
        <Button
          variant="outline"
          size="icon"
          aria-label="Halaman sebelumnya"
          disabled={page === 0}
          onClick={() => setPage((p) => p - 1)}
        >
          ◀️
        </Button>
        <span className="text-sm text-muted">
          {page + 1} / {pages || 1}
        </span>
        <Button
          variant="outline"
          size="icon"
          aria-label="Halaman berikutnya"
          disabled={page + 1 >= pages}
          onClick={() => setPage((p) => p + 1)}
        >
          ▶️
        </Button>
      </div>
    </div>
  );
}
