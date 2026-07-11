import { useEffect, useMemo, useState } from "react";
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
import { useExportGuard } from "../hooks/useExportGuard";
import { OwnerOnlyDialog } from "../components/OwnerOnlyDialog";
import type { Transaction } from "../types/api";

const DOC_TYPES = ["OB", "KK", "KM", "TR", "JU", "RV"];

type SortKey = "date_desc" | "date_asc" | "amount_desc" | "amount_asc";
const SORT_LABELS: Record<SortKey, string> = {
  date_desc: "Tanggal terbaru",
  date_asc: "Tanggal terlama",
  amount_desc: "Nominal terbesar",
  amount_asc: "Nominal terkecil",
};
const txTotal = (t: Transaction) => (t.journal_lines || []).reduce((s, l) => s + (l.debit_amount || 0), 0);

export default function Journal() {
  const [type, setType] = useState("");
  const [tag, setTag] = useState("");
  const [sortBy, setSortBy] = useState<SortKey>("date_desc");
  const [page, setPage] = useState(0);
  const [exporting, setExporting] = useState(false);
  const { guard, dialogOpen, setDialogOpen } = useExportGuard();
  const limit = 25;
  const qs = `?limit=${limit}&offset=${page * limit}${type ? `&type=${type}` : ""}${tag ? `&tag=${encodeURIComponent(tag)}` : ""}`;
  const { loading, transactions, total, error } = useTransactions(qs);
  const pages = Math.ceil((total || 0) / limit);
  const tagsQuery = useQuery({ queryKey: ["tags"], queryFn: api.tags });

  // Sort dilakukan di sisi client atas halaman yang sudah di-fetch (server
  // tetap urutkan created_at desc) — cukup untuk kebutuhan "urutkan tampilan
  // per halaman" tanpa perlu ubah endpoint.
  const sortedTransactions = useMemo(() => {
    const rows = [...transactions];
    switch (sortBy) {
      case "date_asc":
        return rows.sort((a, b) => a.transaction_date.localeCompare(b.transaction_date));
      case "amount_desc":
        return rows.sort((a, b) => txTotal(b) - txTotal(a));
      case "amount_asc":
        return rows.sort((a, b) => txTotal(a) - txTotal(b));
      case "date_desc":
      default:
        return rows.sort((a, b) => b.transaction_date.localeCompare(a.transaction_date));
    }
  }, [transactions, sortBy]);

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
      <h2 className="text-white text-xl font-bold m-0">Jurnal</h2>
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
        <Select className="w-auto" value={sortBy} onChange={(e) => setSortBy(e.target.value as SortKey)}>
          {(Object.keys(SORT_LABELS) as SortKey[]).map((key) => (
            <option key={key} value={key}>
              Urutkan: {SORT_LABELS[key]}
            </option>
          ))}
        </Select>
        <Button variant="outline" size="sm" onClick={() => guard(() => handleExport("xlsx"))} disabled={exporting}>
          {exporting ? "…" : "⬇️ Excel"}
        </Button>
        <Button variant="outline" size="sm" onClick={() => guard(() => handleExport("csv"))} disabled={exporting}>
          ⬇️ CSV
        </Button>
        <Button variant="outline" size="sm" onClick={() => guard(() => handleExport("json"))} disabled={exporting}>
          ⬇️ JSON
        </Button>
        <Button variant="outline" size="sm" onClick={() => guard(() => handleExport("pdf"))} disabled={exporting}>
          ⬇️ PDF
        </Button>
      </div>
      {error && <p className="text-red text-sm">Gagal memuat jurnal: {error}</p>}
      {loading ? <Skeleton className="h-64" /> : <TransactionTable transactions={sortedTransactions} />}
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
      <OwnerOnlyDialog open={dialogOpen} onOpenChange={setDialogOpen} />
    </div>
  );
}
