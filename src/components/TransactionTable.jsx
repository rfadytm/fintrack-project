import { formatRupiah } from "../utils/formatRupiah";
import { formatTanggal } from "../utils/dateHelpers";

export default function TransactionTable({ transactions = [] }) {
  if (!transactions.length) return <p className="muted">Belum ada transaksi.</p>;
  return (
    <div className="table-wrap">
    <table className="table">
      <thead>
        <tr>
          <th>Dokumen</th>
          <th>Tanggal</th>
          <th>Keterangan</th>
          <th className="num">Jumlah</th>
          <th>Status</th>
        </tr>
      </thead>
      <tbody>
        {transactions.map((t) => {
          const total = (t.journal_lines || []).reduce((s, l) => s + (l.debit_amount || 0), 0);
          return (
            <tr key={t.doc_number} className={t.status === "REVERSED" ? "reversed" : ""}>
              <td>{t.doc_number}</td>
              <td>{formatTanggal(t.transaction_date)}</td>
              <td>{t.description || "-"}</td>
              <td className="num">{formatRupiah(total)}</td>
              <td>
                <span className={`badge ${t.status === "REVERSED" ? "red" : "green"}`}>
                  {t.status}
                </span>
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
    </div>
  );
}
