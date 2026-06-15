import { useState } from "react";
import TransactionTable from "../components/TransactionTable";
import { useTransactions } from "../hooks/useTransactions";

export default function Journal() {
  const [type, setType] = useState("");
  const [page, setPage] = useState(0);
  const limit = 25;
  const qs = `?limit=${limit}&offset=${page * limit}${type ? `&type=${type}` : ""}`;
  const { loading, transactions, total } = useTransactions(qs);
  const pages = Math.ceil((total || 0) / limit);

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
