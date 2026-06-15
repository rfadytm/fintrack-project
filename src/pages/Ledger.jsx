import { useEffect, useState } from "react";
import { useApp } from "../context/AppContext";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { formatTanggal } from "../utils/dateHelpers";

export default function Ledger() {
  const { period } = useApp();
  const [accounts, setAccounts] = useState([]);
  const [account, setAccount] = useState("1120");
  const [data, setData] = useState({ loading: false, lines: [] });

  useEffect(() => {
    api.accounts("?postable_only=true").then((r) => setAccounts(r.accounts)).catch(() => {});
  }, []);

  useEffect(() => {
    if (!account) return;
    setData({ loading: true, lines: [] });
    api
      .ledger(account, period.year, period.month)
      .then((r) => setData({ loading: false, lines: r.lines }))
      .catch(() => setData({ loading: false, lines: [] }));
  }, [account, period.year, period.month]);

  return (
    <div className="page">
      <h2>Buku Besar</h2>
      <div className="toolbar">
        <select value={account} onChange={(e) => setAccount(e.target.value)}>
          {accounts.map((a) => (
            <option key={a.code} value={a.code}>{a.code} — {a.account_name}</option>
          ))}
        </select>
      </div>
      {data.loading ? (
        <p className="muted">Memuat…</p>
      ) : (
        <div className="table-wrap">
        <table className="table">
          <thead>
            <tr><th>Tanggal</th><th>Dokumen</th><th>Ket</th><th className="num">Debit</th><th className="num">Kredit</th><th className="num">Saldo</th></tr>
          </thead>
          <tbody>
            {data.lines.map((l) => (
              <tr key={l.id}>
                <td>{formatTanggal(l.transactions.transaction_date)}</td>
                <td>{l.transactions.doc_number}</td>
                <td>{l.transactions.description || "-"}</td>
                <td className="num">{l.debit_amount ? formatRupiah(l.debit_amount) : "-"}</td>
                <td className="num">{l.credit_amount ? formatRupiah(l.credit_amount) : "-"}</td>
                <td className="num">{formatRupiah(l.running_balance)}</td>
              </tr>
            ))}
          </tbody>
        </table>
        </div>
      )}
    </div>
  );
}
