import BalanceCard from "../components/BalanceCard";
import CategoryChart from "../components/CategoryChart";
import TransactionTable from "../components/TransactionTable";
import { useApp } from "../context/AppContext";
import { useReport } from "../hooks/useReports";
import { useTransactions } from "../hooks/useTransactions";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { namaBulan } from "../utils/dateHelpers";

const CASH = ["1110", "1120", "1130", "1140"];

export default function Dashboard() {
  const { period } = useApp();
  const bal = useReport("balance", () => api.balance(), []);
  const monthly = useReport(
    `monthly:${period.year}:${period.month}`,
    () => api.monthly(period.year, period.month),
    [period.year, period.month]
  );
  const tx = useTransactions("?limit=10");

  const cash = (bal.data?.balances || []).filter((b) => CASH.includes(b.code));
  const m = monthly.data || {};

  return (
    <div className="page">
      <h2>Dashboard — {namaBulan(period.month)} {period.year}</h2>

      <div className="cards">
        {cash.map((c) => (
          <BalanceCard key={c.code} name={c.account_name} balance={c.balance} type="aset" />
        ))}
      </div>

      <div className="cards">
        <div className="card stat green">
          <div className="card-label">Pemasukan</div>
          <div className="card-value">{formatRupiah(m.income)}</div>
        </div>
        <div className="card stat red">
          <div className="card-label">Pengeluaran</div>
          <div className="card-value">{formatRupiah(m.expense)}</div>
        </div>
        <div className="card stat">
          <div className="card-label">Net</div>
          <div className="card-value">{formatRupiah(m.net)}</div>
        </div>
      </div>

      <div className="grid-2">
        <div className="card">
          <h3>Beban per Kategori</h3>
          <ExpenseChart year={period.year} month={period.month} />
        </div>
        <div className="card">
          <h3>Transaksi Terakhir</h3>
          {tx.loading ? <p className="muted">Memuat…</p> : <TransactionTable transactions={tx.transactions} />}
        </div>
      </div>
    </div>
  );
}

function ExpenseChart({ year, month }) {
  const is = useReport(`is:${year}:${month}`, () => api.incomeStatement(year, month), [year, month]);
  if (is.loading) return <p className="muted">Memuat…</p>;
  return <CategoryChart data={is.data?.expense || []} />;
}
