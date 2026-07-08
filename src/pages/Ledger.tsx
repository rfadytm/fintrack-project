import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { useApp } from "../context/AppContext";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { formatTanggal } from "../utils/dateHelpers";
import { exportRows, stamp } from "../utils/exportXlsx";
import { Select } from "../components/ui/select";
import { Label } from "../components/ui/label";
import { Button } from "../components/ui/button";
import { Skeleton } from "../components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

// 7 kelas akun berdasarkan digit awal kode.
const CLASSES: [string, string][] = [
  ["1", "Aset"],
  ["2", "Liabilitas"],
  ["3", "Ekuitas"],
  ["4", "Pendapatan"],
  ["5", "Beban Personal"],
  ["6", "Beban Usaha"],
  ["9", "Lain-lain"],
];

export default function Ledger() {
  const { period } = useApp();
  const [account, setAccount] = useState("1120");

  const accountsQuery = useQuery({
    queryKey: ["accounts", "?postable_only=true"],
    queryFn: () => api.accounts("?postable_only=true"),
  });
  const accounts = accountsQuery.data?.accounts || [];

  const ledgerQuery = useQuery({
    queryKey: ["ledger", account, period.year, period.month],
    queryFn: () => api.ledger(account, period.year, period.month),
    enabled: !!account,
  });
  const lines = ledgerQuery.data?.lines || [];

  return (
    <div className="space-y-4">
      <h2 className="text-navy text-xl font-bold m-0">Buku Besar</h2>
      {accountsQuery.error && (
        <p className="text-red text-sm">Gagal memuat daftar akun: {(accountsQuery.error as Error).message}</p>
      )}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        {CLASSES.map(([digit, label]) => {
          const opts = accounts.filter((a) => a.code.startsWith(digit));
          return (
            <div key={digit} className="flex flex-col gap-1">
              <Label htmlFor={`ledger-class-${digit}`}>{label}</Label>
              <Select
                id={`ledger-class-${digit}`}
                value={account.startsWith(digit) ? account : ""}
                onChange={(e) => e.target.value && setAccount(e.target.value)}
              >
                <option value="">— pilih —</option>
                {opts.map((a) => (
                  <option key={a.code} value={a.code}>
                    {a.code} — {a.account_name}
                  </option>
                ))}
              </Select>
            </div>
          );
        })}
      </div>
      <div className="flex items-center gap-3 flex-wrap">
        <span className="text-muted text-sm">
          Akun aktif: <b className="text-navy">{account}</b>
        </span>
        <Button
          variant="outline"
          size="sm"
          disabled={!lines.length}
          onClick={() =>
            exportRows(
              `fintrack_bukubesar_${account}_${stamp()}.xlsx`,
              `Akun ${account}`,
              lines.map((l) => ({
                Tanggal: formatTanggal(l.transactions?.transaction_date),
                Dokumen: l.transactions?.doc_number || "",
                Keterangan: l.transactions?.description || "",
                Debit: l.debit_amount || 0,
                Kredit: l.credit_amount || 0,
                Saldo: l.running_balance || 0,
              }))
            )
          }
        >
          ⬇️ Export .xlsx
        </Button>
      </div>
      {ledgerQuery.error && (
        <p className="text-red text-sm">Gagal memuat buku besar: {(ledgerQuery.error as Error).message}</p>
      )}
      {ledgerQuery.isLoading ? (
        <Skeleton className="h-64" />
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Tanggal</TableHead>
              <TableHead>Dokumen</TableHead>
              <TableHead>Ket</TableHead>
              <TableHead className="text-right">Debit</TableHead>
              <TableHead className="text-right">Kredit</TableHead>
              <TableHead className="text-right">Saldo</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {lines.map((l, i) => (
              <TableRow key={l.id ?? i}>
                <TableCell>{formatTanggal(l.transactions?.transaction_date)}</TableCell>
                <TableCell>{l.transactions?.doc_number}</TableCell>
                <TableCell>{l.transactions?.description || "-"}</TableCell>
                <TableCell className="text-right tabular-nums">
                  {l.debit_amount ? formatRupiah(l.debit_amount) : "-"}
                </TableCell>
                <TableCell className="text-right tabular-nums">
                  {l.credit_amount ? formatRupiah(l.credit_amount) : "-"}
                </TableCell>
                <TableCell className="text-right tabular-nums">{formatRupiah(l.running_balance)}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </div>
  );
}
