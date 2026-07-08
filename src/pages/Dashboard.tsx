import { motion } from "framer-motion";
import BalanceCard from "../components/BalanceCard";
import CategoryChart from "../components/CategoryChart";
import TimelineChart from "../components/TimelineChart";
import TransactionTable from "../components/TransactionTable";
import { Card, CardTitle } from "../components/ui/card";
import { Button } from "../components/ui/button";
import { Skeleton } from "../components/ui/skeleton";
import { useApp } from "../context/AppContext";
import { useReport } from "../hooks/useReports";
import { useTransactions } from "../hooks/useTransactions";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { namaBulan } from "../utils/dateHelpers";
import type { BalanceRow } from "../types/api";

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
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-3 flex-wrap">
        <h2 className="text-navy text-xl font-bold m-0">Dashboard</h2>
        <div className="flex items-center gap-2.5 font-semibold text-navy">
          <Button variant="outline" size="icon" aria-label="Bulan sebelumnya" onClick={prev}>
            ◀
          </Button>
          <span>
            {namaBulan(period.month)} {period.year}
          </span>
          <Button variant="outline" size="icon" aria-label="Bulan berikutnya" onClick={next}>
            ▶
          </Button>
        </div>
      </div>

      {bal.error && <p className="text-red text-sm">Gagal memuat saldo: {bal.error}</p>}
      <div className="flex gap-4 flex-wrap">
        {bal.loading
          ? [1, 2].map((i) => <Skeleton key={i} className="h-20 flex-1 min-w-[160px]" />)
          : cash.map((c: BalanceRow) => (
              <BalanceCard key={c.code} name={c.account_name} balance={c.balance} type="aset" />
            ))}
      </div>

      {monthly.error && <p className="text-red text-sm">Gagal memuat ringkasan bulanan: {monthly.error}</p>}
      <motion.div
        className="grid grid-cols-1 sm:grid-cols-3 gap-4"
        initial="hidden"
        animate="show"
        variants={{ show: { transition: { staggerChildren: 0.08 } } }}
      >
        {[
          { label: "Pemasukan", value: m.income, color: "text-green" },
          { label: "Pengeluaran", value: m.expense, color: "text-red" },
          { label: "Net", value: m.net, color: "text-navy" },
        ].map((s) => (
          <motion.div
            key={s.label}
            variants={{ hidden: { opacity: 0, y: 8 }, show: { opacity: 1, y: 0 } }}
          >
            <Card>
              <div className="text-muted text-xs">{s.label}</div>
              <div className={`text-xl font-bold mt-1 ${s.color}`}>{formatRupiah(s.value)}</div>
            </Card>
          </motion.div>
        ))}
      </motion.div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <Card>
          <CardTitle>Beban per Kategori</CardTitle>
          <ExpenseChart year={period.year} month={period.month} />
        </Card>
        <Card>
          <CardTitle>Akumulasi Pengeluaran Harian</CardTitle>
          <TimelineSection year={period.year} month={period.month} />
        </Card>
      </div>

      <Card>
        <CardTitle>Transaksi Terakhir</CardTitle>
        <div className="mt-3">
          {tx.error && <p className="text-red text-sm">Gagal memuat transaksi: {tx.error}</p>}
          {tx.loading ? <Skeleton className="h-32" /> : <TransactionTable transactions={tx.transactions} />}
        </div>
      </Card>
    </div>
  );
}

function ExpenseChart({ year, month }: { year: number; month: number }) {
  const is = useReport(`is:${year}:${month}`, () => api.incomeStatement(year, month), [year, month]);
  if (is.loading) return <Skeleton className="h-64" />;
  if (is.error) return <p className="text-red text-sm">{is.error}</p>;
  return <CategoryChart data={is.data?.expense || []} />;
}

function TimelineSection({ year, month }: { year: number; month: number }) {
  const t = useReport(
    `timeline:${year}:${month}`,
    async () => {
      const [tx, acc] = await Promise.all([
        api.transactions(`?year=${year}&month=${month}&limit=500`),
        api.accounts("?postable_only=true"),
      ]);
      const isExpense: Record<string, boolean> = {};
      (acc.accounts || []).forEach((a) => (isExpense[a.code] = a.account_type === "beban"));
      const byDay: Record<number, number> = {};
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
      const series: { label: string; value: number }[] = [];
      for (let d = 1; d <= lastDay; d++) {
        cum += byDay[d] || 0;
        series.push({ label: String(d), value: cum });
      }
      return series;
    },
    [year, month]
  );
  if (t.loading) return <Skeleton className="h-64" />;
  if (t.error) return <p className="text-red text-sm">{t.error}</p>;
  return <TimelineChart data={t.data || []} />;
}
