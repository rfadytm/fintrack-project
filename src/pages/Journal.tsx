import { useEffect, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { toast } from "sonner";
import TransactionTable from "../components/TransactionTable";
import { Button } from "../components/ui/button";
import { Select } from "../components/ui/select";
import { Skeleton } from "../components/ui/skeleton";
import { useTransactions } from "../hooks/useTransactions";
import { api } from "../utils/api";
import { exportRows, stamp, type XlsxRow } from "../utils/exportXlsx";
import { exportCsv } from "../utils/exportCsv";
import { exportJson } from "../utils/exportJson";
import { exportPdf } from "../utils/exportPdf";
import { formatTanggal } from "../utils/dateHelpers";

const DOC_TYPES = ["OB", "KK", "KM", "TR", "JU", "RV"];

export default function Journal() {
  const [type, setType] = useState("");
  const [tag, setTag] = useState("");
  const [page, setPage] = useState(0);
  const [exporting, setExporting] = useState(false);
  const limit = 25;
  const qs = `?limit=${limit}&offset=${page * limit}${type ? `&type=${type}` : ""}${tag ? `&tag=${encodeURIComponent(tag)}` : ""}`;
  const { loading, transactions, total, error } = useTransactions(qs);
  const pages = Math.ceil((total || 0) / limit);
  const tagsQuery = useQuery({ queryKey: ["tags"], queryFn: api.tags });

  // Blindspot fix: if a filter change shrinks `total`, the current page could
  // be left past the new last page (pager showing an empty table with no way back).
  useEffect(() => {
    if (!loading && pages > 0 && page >= pages) setPage(pages - 1);
  }, [loading, pages, page]);

  const buildRows = async (): Promise<XlsxRow[]> => {
    const filterQs = `?limit=2000${type ? `&type=${type}` : ""}${tag ? `&tag=${encodeURIComponent(tag)}` : ""}`;
    const [txRes, accRes] = await Promise.all([api.transactions(filterQs), api.accounts()]);
    const nameByCode: Record<string, string> = {};
    (accRes.accounts || []).forEach((a) => (nameByCode[a.code] = a.account_name));
    const rows: XlsxRow[] = [];
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
    return rows;
  };

  const handleExport = async (format: "xlsx" | "csv" | "json" | "pdf") => {
    setExporting(true);
    try {
      const rows = await buildRows();
      const base = `fintrack_jurnal_${stamp()}`;
      if (format === "xlsx") await exportRows(`${base}.xlsx`, "Jurnal", rows);
      else if (format === "csv") exportCsv(`${base}.csv`, rows);
      else if (format === "json") exportJson(`${base}.json`, rows);
      else await exportPdf(`${base}.pdf`, "Jurnal", rows);
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
        <Select
          className="w-auto"
          value={tag}
          onChange={(e) => {
            setTag(e.target.value);
            setPage(0);
          }}
        >
          <option value="">Semua tag</option>
          {(tagsQuery.data?.tags || []).map((t) => (
            <option key={t.id} value={t.name}>
              {t.emoji || ""} {t.name}
            </option>
          ))}
        </Select>
        <Button variant="outline" size="sm" onClick={() => handleExport("xlsx")} disabled={exporting}>
          {exporting ? "…" : "⬇️ Excel"}
        </Button>
        <Button variant="outline" size="sm" onClick={() => handleExport("csv")} disabled={exporting}>
          ⬇️ CSV
        </Button>
        <Button variant="outline" size="sm" onClick={() => handleExport("json")} disabled={exporting}>
          ⬇️ JSON
        </Button>
        <Button variant="outline" size="sm" onClick={() => handleExport("pdf")} disabled={exporting}>
          ⬇️ PDF
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
