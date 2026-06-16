import { useState } from "react";
import TransactionTable from "../components/TransactionTable";
import { useTransactions } from "../hooks/useTransactions";
import { api } from "../utils/api";
import { exportRows, stamp } from "../utils/exportXlsx";
import { formatTanggal } from "../utils/dateHelpers";

export default function Journal() {
  const [type, setType] = useState("");
  const [page, setPage] = useState(0);
  const [exporting, setExporting] = useState(false);
  const limit = 25;
  const qs = `?limit=${limit}&offset=${page * limit}${type ? `&type=${type}` : ""}`;
  const { loading, transactions, total } = useTransactions(qs);
  const pages = Math.ceil((total || 0) / limit);

  const handleExport = async () => {
    setExporting(true);
    try {
      const [txRes, accRes] = await Promise.all([
        api.transactions(`?limit=2000${type ? `&type=${type}` : ""}`),
        api.accounts(),
      ]);
      const nameByCode = {};
      (accRes.accounts || []).forEach((a) => (nameByCode[a.code] = a.account_name));
      const rows = [];
      (txRes.transactions || []).forEach((t) => {
        (t.journal_lines || [])
          .sort((a, b) => a.line_order - b.line_order)
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
      alert("Gagal export: " + e.message);
    } finally {
      setExporting(false);
    }
  };

  return (
    <div className="page">
      <h2>Jurnal</h2>
      <div className="toolbar">
        <select value={type} onChange={(e) => { setType(e.target.value); setPage(0); }}>
          <option value="">Semua tipe</option>
          {["OB", "KK", "KM", "TR", "JU", "RV"].map((t) => (
            <option key={t} value={t}>{t}</option>
          ))}
        </select>
        <button className="btn-export" onClick={handleExport} disabled={exporting}>
          {exporting ? "Mengexport…" : "⬇️ Export .xlsx"}
        </button>
      </div>
      {loading ? <p className="muted">Memuat…</p> : <TransactionTable transactions={transactions} />}
      <div className="pager">
        <button disabled={page === 0} onClick={() => setPage((p) => p - 1)}>◀️</button>
        <span>{page + 1} / {pages || 1}</span>
        <button disabled={page + 1 >= pages} onClick={() => setPage((p) => p + 1)}>▶️</button>
      </div>
    </div>
  );
}
