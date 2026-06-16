import BalanceCard from "../components/BalanceCard";
import CategoryChart from "../components/CategoryChart";
import TimelineChart from "../components/TimelineChart";
import TransactionTable from "../components/TransactionTable";
import { useApp } from "../context/AppContext";
import { useReport } from "../hooks/useReports";
import { useTransactions } from "../hooks/useTransactions";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { namaBulan } from "../utils/dateHelpers";

const CASH = ["1110", "1120", "1130", "1140"];

export default function Dashboard() {
  const { period, setPeriod } = useApp();
  const bal = useReport("balance", () => api.balance(), []);
  const monthly = useReport(
    `monthly:${period.year}:${period.month}`,
    () => api.monthly(period.year, period.month),
    [period.year, period.month]
  );
  const tx = useTransactions("?limit=10");

  const cash = (bal.data?.balances || []).filter((b) => CASH.includes(b.code));
  const m = monthly.data || {};

  const prev = () =>
    setPeriod((p) => (p.month === 1 ? { year: p.year - 1, month: 12 } : { year: p.year, month: p.month - 1 }));
  const next = () =>
    setPeriod((p) => (p.month === 12 ? { year: p.year + 1, month: 1 } : { year: p.year, month: p.month + 1 }));

  return (
    <div className="page">
      <div className="card-head">
        <h2>Dashboard</h2>
        <div className="period-nav">
          <button onClick={prev}>◀</button>
          <span>{namaBulan(period.month)} {period.year}</span>
          <button onClick={next}>▶</button>
        </div>
      </div>

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
          <h3>Akumulasi Pengeluaran Harian</h3>
          <TimelineSection year={period.year} month={period.month} />
        </div>
      </div>

      <div className="card">
        <h3>Transaksi Terakhir</h3>
        {tx.loading ? <p className="muted">Memuat…</p> : <TransactionTable transactions={tx.transactions} />}
      </div>
    </div>
  );
}

function ExpenseChart({ year, month }) {
  const is = useReport(`is:${year}:${month}`, () => api.incomeStatement(year, month), [year, month]);
  if (is.loading) return <p className="muted">Memuat…</p>;
  return <CategoryChart data={is.data?.expense || []} />;
}

function TimelineSection({ year, month }) {
  const t = useReport(
    `timeline:${year}:${month}`,
    async () => {
      const [tx, acc] = await Promise.all([
        api.transactions(`?year=${year}&month=${month}&limit=500`),
        api.accounts("?postable_only=true"),
      ]);
      const isExpense = {};
      (acc.accounts || []).forEach((a) => (isExpense[a.code] = a.account_type === "beban"));
      const byDay = {};
      (tx.transactions || [])
        .filter((x) => x.status === "POSTED")
        .forEach((x) => {
          const day = new Date(x.transaction_date).getDate();
          let amt = 0;
          (x.journal_lines || []).forEach((l) => {
            if (isExpense[l.account_code]) amt += l.debit_amount || 0;
          });
          byDay[day] = (byDay[day] || 0) + amt;
        });
      const lastDay = new Date(year, month, 0).getDate();
      let cum = 0;
      const series = [];
      for (let d = 1; d <= lastDay; d++) {
        cum += byDay[d] || 0;
        series.push({ label: String(d), value: cum });
      }
      return series;
    },
    [year, month]
  );
  if (t.loading) return <p className="muted">Memuat…</p>;
  return <TimelineChart data={t.data || []} />;
}
