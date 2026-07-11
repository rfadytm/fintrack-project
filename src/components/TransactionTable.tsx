import { FileX } from "lucide-react";
import { formatRupiah } from "../utils/formatRupiah";
import { formatTanggal } from "../utils/dateHelpers";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "./ui/table";
import { Badge } from "./ui/badge";
import type { Transaction } from "../types/api";

export default function TransactionTable({ transactions = [] }: { transactions?: Transaction[] }) {
  if (!transactions.length) {
    return (
      <div className="bg-white/[0.02] border border-dashed border-white/[0.08] p-8 text-center rounded-2xl">
        <FileX className="h-8 w-8 mx-auto text-muted mb-2" />
        <p className="text-white text-sm">Belum ada transaksi.</p>
        <p className="text-muted text-xs mt-1">Catat pengeluaran/pemasukan lewat bot Telegram.</p>
      </div>
    );
  }
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Dokumen</TableHead>
          <TableHead>Tanggal</TableHead>
          <TableHead>Keterangan</TableHead>
          <TableHead className="text-right">Jumlah</TableHead>
          <TableHead>Status</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {transactions.map((t) => {
          const total = (t.journal_lines || []).reduce((s, l) => s + (l.debit_amount || 0), 0);
          return (
            <TableRow key={t.doc_number} className={t.status === "REVERSED" ? "opacity-50 line-through" : undefined}>
              <TableCell>{t.doc_number}</TableCell>
              <TableCell>{formatTanggal(t.transaction_date)}</TableCell>
              <TableCell>{t.description || "-"}</TableCell>
              <TableCell className="text-right tabular-nums">{formatRupiah(total)}</TableCell>
              <TableCell>
                <Badge variant={t.status === "REVERSED" ? "red" : "green"}>{t.status}</Badge>
              </TableCell>
            </TableRow>
          );
        })}
      </TableBody>
    </Table>
  );
}
