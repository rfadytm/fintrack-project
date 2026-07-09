import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useApp } from "../context/AppContext";
import { useReport } from "../hooks/useReports";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { namaBulan } from "../utils/dateHelpers";
import { exportRows } from "../utils/exportXlsx";
import { Card, CardHeader, CardTitle } from "../components/ui/card";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Skeleton } from "../components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../components/ui/tabs";
import type { ForecastTier } from "../types/api";

export default function Reports() {
  const { period, setPeriod } = useApp();

  return (
    <div className="space-y-4">
      <h2 className="text-navy text-xl font-bold m-0">Laporan Keuangan</h2>
      <div className="flex gap-3 items-center flex-wrap">
        <Input
          type="month"
          className="w-auto"
          value={`${period.year}-${String(period.month).padStart(2, "0")}`}
          onChange={(e) => {
            const [y, m] = e.target.value.split("-");
            setPeriod({ year: +y, month: +m });
          }}
        />
        <Tabs defaultValue="is">
          <TabsList>
            <TabsTrigger value="is">Laba Rugi</TabsTrigger>
            <TabsTrigger value="tb">Trial Balance</TabsTrigger>
            <TabsTrigger value="range">Rentang Tanggal</TabsTrigger>
            <TabsTrigger value="forecast">Forecast</TabsTrigger>
          </TabsList>
          <TabsContent value="is">
            <IncomeStatement {...period} />
          </TabsContent>
          <TabsContent value="tb">
            <TrialBalance {...period} />
          </TabsContent>
          <TabsContent value="range">
            <RangeAnalysis />
          </TabsContent>
          <TabsContent value="forecast">
            <ForecastCard />
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}

function RangeAnalysis() {
  const today = new Date().toISOString().slice(0, 10);
  const [dateFrom, setDateFrom] = useState(today);
  const [dateTo, setDateTo] = useState(today);
  const [applied, setApplied] = useState<{ from: string; to: string } | null>(null);

  const rangeQuery = useQuery({
    queryKey: ["reports", "range", applied?.from, applied?.to],
    queryFn: () => api.reportRange(applied!.from, applied!.to),
    enabled: !!applied,
  });

  return (
    <Card>
      <CardHeader>
        <CardTitle>Analisis Rentang Tanggal Bebas</CardTitle>
      </CardHeader>
      <div className="flex gap-3 items-end flex-wrap mb-3">
        <div className="flex flex-col gap-1">
          <label className="text-xs text-muted">Dari</label>
          <Input type="date" value={dateFrom} onChange={(e) => setDateFrom(e.target.value)} />
        </div>
        <div className="flex flex-col gap-1">
          <label className="text-xs text-muted">Sampai</label>
          <Input type="date" value={dateTo} onChange={(e) => setDateTo(e.target.value)} />
        </div>
        <Button onClick={() => setApplied({ from: dateFrom, to: dateTo })}>Tampilkan</Button>
      </div>
      {rangeQuery.isLoading && <Skeleton className="h-48" />}
      {rangeQuery.error && <p className="text-red text-sm">{(rangeQuery.error as Error).message}</p>}
      {rangeQuery.data && (
        <>
          <Section title="Pendapatan" rows={rangeQuery.data.revenue} total={rangeQuery.data.total_revenue} />
          <Section title="Beban" rows={rangeQuery.data.expense} total={rangeQuery.data.total_expense} />
          <div className={`mt-4 font-bold text-lg ${(rangeQuery.data.net_income || 0) >= 0 ? "text-green" : "text-red"}`}>
            Net: {formatRupiah(rangeQuery.data.net_income)}
          </div>
        </>
      )}
    </Card>
  );
}

function ForecastTierCard({ tier }: { tier: ForecastTier }) {
  const locked = tier.income == null;
  return (
    <div className="rounded-xl border border-navy/10 p-3">
      <div className="text-navy text-sm font-semibold">{tier.label}</div>
      {locked ? (
        <p className="text-muted text-xs mt-2">
          Belum cukup data — butuh minimal {tier.min_real_months} bulan penuh riwayat transaksi.
        </p>
      ) : (
        <div className="mt-2 space-y-2">
          <div>
            <div className="text-muted text-xs">Proyeksi Pemasukan</div>
            <div className="font-bold text-green">{formatRupiah(tier.income)}</div>
          </div>
          <div>
            <div className="text-muted text-xs">Proyeksi Pengeluaran</div>
            <div className="font-bold text-red">{formatRupiah(tier.expense)}</div>
          </div>
        </div>
      )}
    </div>
  );
}

function ForecastCard() {
  const forecastQuery = useQuery({ queryKey: ["reports", "forecast"], queryFn: () => api.forecast(6) });
  if (forecastQuery.isLoading) return <Skeleton className="h-64" />;
  if (forecastQuery.error) return <p className="text-red text-sm">{(forecastQuery.error as Error).message}</p>;
  const d = forecastQuery.data;
  if (!d) return null;
  return (
    <Card>
      <CardHeader>
        <CardTitle>Proyeksi Keuangan</CardTitle>
      </CardHeader>
      <p className="text-muted text-xs mb-3">
        Berdasarkan {d.real_months_available} bulan riwayat transaksi LENGKAP (bulan berjalan tidak
        dihitung). Makin panjang horizonnya, makin banyak bulan lengkap yang disyaratkan sebelum
        ditampilkan — supaya proyeksi tidak menebak dari data yang belum cukup.
      </p>
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-4">
        <ForecastTierCard tier={d.short_term} />
        <ForecastTierCard tier={d.medium_term} />
        <ForecastTierCard tier={d.long_term} />
      </div>
      {d.top_categories.length > 0 && (
        <>
          <h4 className="text-navy mb-1">Tren kategori tertinggi</h4>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Kategori</TableHead>
                <TableHead className="text-right">Proyeksi</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {d.top_categories.map((c) => (
                <TableRow key={c.code}>
                  <TableCell>{c.account_name || c.code}</TableCell>
                  <TableCell className="text-right tabular-nums">{formatRupiah(c.forecast)}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </>
      )}
    </Card>
  );
}

function IncomeStatement({ year, month }: { year: number; month: number }) {
  const { loading, data, error } = useReport(`is:${year}:${month}`, () => api.incomeStatement(year, month), [
    year,
    month,
  ]);
  if (loading) return <Skeleton className="h-64" />;
  if (error) return <p className="text-red text-sm">{error}</p>;
  const d = data || {};
  const exportIS = () =>
    exportRows(
      `fintrack_labarugi_${year}-${String(month).padStart(2, "0")}.xlsx`,
      "Laba Rugi",
      [
        // Blindspot fix: export dulu cuma dump baris per-akun tanpa subtotal —
        // kalau d.revenue kosong (mis. bulan tanpa pendapatan sungguhan, hanya
        // modal awal yang sengaja dikecualikan dari Laba Rugi), Excel-nya jadi
        // sama sekali tidak punya baris "Pendapatan", langsung loncat ke Beban.
        // Sekarang selalu ada baris Total Pendapatan/Total Beban, sama seperti
        // yang ditampilkan di layar (komponen Section di bawah).
        ...(d.revenue || []).map((r) => ({ Kode: r.code, Akun: r.account_name, Tipe: "Pendapatan", Jumlah: r.amount })),
        { Kode: "", Akun: "Total Pendapatan", Tipe: "Pendapatan", Jumlah: d.total_revenue || 0 },
        ...(d.expense || []).map((r) => ({ Kode: r.code, Akun: r.account_name, Tipe: "Beban", Jumlah: r.amount })),
        { Kode: "", Akun: "Total Beban", Tipe: "Beban", Jumlah: d.total_expense || 0 },
        { Kode: "", Akun: "NET LABA/RUGI", Tipe: "", Jumlah: d.net_income || 0 },
      ]
    );

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          Laba Rugi — {namaBulan(month)} {year}
        </CardTitle>
        <Button variant="outline" size="sm" onClick={exportIS}>
          ⬇️ Export .xlsx
        </Button>
      </CardHeader>
      <Section title="Pendapatan" rows={d.revenue} total={d.total_revenue} />
      <Section title="Beban" rows={d.expense} total={d.total_expense} />
      <div className={`mt-4 font-bold text-lg ${(d.net_income || 0) >= 0 ? "text-green" : "text-red"}`}>
        Net {(d.net_income || 0) >= 0 ? "Laba" : "Rugi"}: {formatRupiah(d.net_income)}
      </div>
    </Card>
  );
}

function Section({
  title,
  rows = [],
  total,
}: {
  title: string;
  rows?: { code: string; account_name: string; amount: number }[];
  total?: number | null;
}) {
  return (
    <>
      <h4 className="text-navy mb-1">{title}</h4>
      <Table>
        <TableBody>
          {rows.map((r) => (
            <TableRow key={r.code}>
              <TableCell>{r.code}</TableCell>
              <TableCell>{r.account_name}</TableCell>
              <TableCell className="text-right tabular-nums">{formatRupiah(r.amount)}</TableCell>
            </TableRow>
          ))}
          <TableRow className="font-bold border-t-2 border-navy">
            <TableCell colSpan={2}>Total {title}</TableCell>
            <TableCell className="text-right tabular-nums">{formatRupiah(total)}</TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </>
  );
}

function TrialBalance({ year, month }: { year: number; month: number }) {
  const { loading, data, error } = useReport(`tb:${year}:${month}`, () => api.trialBalance(year, month), [
    year,
    month,
  ]);
  if (loading) return <Skeleton className="h-64" />;
  if (error) return <p className="text-red text-sm">{error}</p>;
  const d = data || {};
  const exportTB = () =>
    exportRows(
      `fintrack_trialbalance_${year}-${String(month).padStart(2, "0")}.xlsx`,
      "Trial Balance",
      [
        ...(d.accounts || []).map((r) => ({
          Kode: r.code,
          Akun: r.account_name,
          Debit: r.total_debit || 0,
          Kredit: r.total_credit || 0,
        })),
        // Blindspot fix (sama pola dengan Laba Rugi): export dulu cuma dump
        // baris per-akun tanpa baris TOTAL yang ditampilkan di layar — jadi
        // tidak ada cara verifikasi debit=kredit dari file Excel-nya sendiri.
        {
          Kode: "",
          Akun: d.balanced ? "TOTAL (Balance)" : "TOTAL (Tidak Balance)",
          Debit: d.total_debit || 0,
          Kredit: d.total_credit || 0,
        },
      ]
    );

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          Trial Balance s.d. {namaBulan(month)} {year}
        </CardTitle>
        <Button variant="outline" size="sm" onClick={exportTB}>
          ⬇️ Export .xlsx
        </Button>
      </CardHeader>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Kode</TableHead>
            <TableHead>Akun</TableHead>
            <TableHead className="text-right">Debit</TableHead>
            <TableHead className="text-right">Kredit</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {(d.accounts || []).map((r) => (
            <TableRow key={r.code}>
              <TableCell>{r.code}</TableCell>
              <TableCell>{r.account_name}</TableCell>
              <TableCell className="text-right tabular-nums">
                {r.total_debit ? formatRupiah(r.total_debit) : "-"}
              </TableCell>
              <TableCell className="text-right tabular-nums">
                {r.total_credit ? formatRupiah(r.total_credit) : "-"}
              </TableCell>
            </TableRow>
          ))}
          <TableRow className="font-bold border-t-2 border-navy">
            <TableCell colSpan={2}>TOTAL {d.balanced ? "✅ Balance" : "⚠️ Tidak balance"}</TableCell>
            <TableCell className="text-right tabular-nums">{formatRupiah(d.total_debit)}</TableCell>
            <TableCell className="text-right tabular-nums">{formatRupiah(d.total_credit)}</TableCell>
          </TableRow>
        </TableBody>
      </Table>
    </Card>
  );
}
