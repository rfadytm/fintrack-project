import { useState } from "react";
import { useApp } from "../context/AppContext";
import { useReport } from "../hooks/useReports";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { namaBulan } from "../utils/dateHelpers";
import { exportRows, stamp } from "../utils/exportXlsx";

export default function Reports() {
  const { period, setPeriod } = useApp();
  const [tab, setTab] = useState("is");

  return (
    <div className="page">
      <h2>Laporan Keuangan</h2>
      <div className="toolbar">
        <input
          type="month"
          value={`${period.year}-${String(period.month).padStart(2, "0")}`}
          onChange={(e) => {
            const [y, m] = e.target.value.split("-");
            setPeriod({ year: +y, month: +m });
          }}
        />
        <div className="tabs">
          <button className={tab === "is" ? "active" : ""} onClick={() => setTab("is")}>Laba Rugi</button>
          <button className={tab === "tb" ? "active" : ""} onClick={() => setTab("tb")}>Trial Balance</button>
        </div>
      </div>
      {tab === "is" ? <IncomeStatement {...period} /> : <TrialBalance {...period} />}
    </div>
  );
}

function IncomeStatement({ year, month }) {
  const { loading, data } = useReport(`is:${year}:${month}`, () => api.incomeStatement(year, month), [year, month]);
  if (loading) return <p className="muted">Memuat…</p>;
  const d = data || {};
  const exportIS = () =>
    exportRows(
      `fintrack_labarugi_${year}-${String(month).padStart(2, "0")}.xlsx`,
      "Laba Rugi",
      [
        ...(d.revenue || []).map((r) => ({ Kode: r.code, Akun: r.account_name, Tipe: "Pendapatan", Jumlah: r.amount })),
        ...(d.expense || []).map((r) => ({ Kode: r.code, Akun: r.account_name, Tipe: "Beban", Jumlah: r.amount })),
        { Kode: "", Akun: "NET LABA/RUGI", Tipe: "", Jumlah: d.net_income },
      ]
    );

  return (
    <div className="card">
      <div className="card-head">
        <h3>Laba Rugi — {namaBulan(month)} {year}</h3>
        <button className="btn-export" onClick={exportIS}>⬇️ Export .xlsx</button>
      </div>
      <Section title="Pendapatan" rows={d.revenue} total={d.total_revenue} />
      <Section title="Beban" rows={d.expense} total={d.total_expense} />
      <div className={`net ${d.net_income >= 0 ? "green" : "red"}`}>
        Net {d.net_income >= 0 ? "Laba" : "Rugi"}: {formatRupiah(d.net_income)}
      </div>
    </div>
  );
}

function Section({ title, rows = [], total }) {
  return (
    <>
      <h4>{title}</h4>
      <div className="table-wrap">
      <table className="table">
        <tbody>
          {rows.map((r) => (
            <tr key={r.code}>
              <td>{r.code}</td>
              <td>{r.account_name}</td>
              <td className="num">{formatRupiah(r.amount)}</td>
            </tr>
          ))}
          <tr className="subtotal">
            <td colSpan={2}>Total {title}</td>
            <td className="num">{formatRupiah(total)}</td>
          </tr>
        </tbody>
      </table>
      </div>
    </>
  );
}

function TrialBalance({ year, month }) {
  const { loading, data } = useReport(`tb:${year}:${month}`, () => api.trialBalance(year, month), [year, month]);
  if (loading) return <p className="muted">Memuat…</p>;
  const d = data || {};
  const exportTB = () =>
    exportRows(
      `fintrack_trialbalance_${year}-${String(month).padStart(2, "0")}.xlsx`,
      "Trial Balance",
      (d.accounts || []).map((r) => ({
        Kode: r.code,
        Akun: r.account_name,
        Debit: r.total_debit || 0,
        Kredit: r.total_credit || 0,
      }))
    );

  return (
    <div className="card">
      <div className="card-head">
        <h3>Trial Balance s.d. {namaBulan(month)} {year}</h3>
        <button className="btn-export" onClick={exportTB}>⬇️ Export .xlsx</button>
      </div>
      <div className="table-wrap">
      <table className="table">
        <thead>
          <tr><th>Kode</th><th>Akun</th><th className="num">Debit</th><th className="num">Kredit</th></tr>
        </thead>
        <tbody>
          {(d.accounts || []).map((r) => (
            <tr key={r.code}>
              <td>{r.code}</td>
              <td>{r.account_name}</td>
              <td className="num">{r.total_debit ? formatRupiah(r.total_debit) : "-"}</td>
              <td className="num">{r.total_credit ? formatRupiah(r.total_credit) : "-"}</td>
            </tr>
          ))}
          <tr className="subtotal">
            <td colSpan={2}>TOTAL {d.balanced ? "✅ Balance" : "⚠️ Tidak balance"}</td>
            <td className="num">{formatRupiah(d.total_debit)}</td>
            <td className="num">{formatRupiah(d.total_credit)}</td>
          </tr>
        </tbody>
      </table>
      </div>
    </div>
  );
}
