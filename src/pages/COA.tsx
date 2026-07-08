import { useQuery } from "@tanstack/react-query";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { Skeleton } from "../components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";
import { cn } from "../lib/utils";

export default function COA() {
  const accountsQuery = useQuery({ queryKey: ["accounts", ""], queryFn: () => api.accounts() });
  const balanceQuery = useQuery({ queryKey: ["balance", ""], queryFn: () => api.balance() });

  const accounts = accountsQuery.data?.accounts || [];
  const balances: Record<string, number> = {};
  (balanceQuery.data?.balances || []).forEach((x) => (balances[x.code] = x.balance));

  const error = accountsQuery.error || balanceQuery.error;
  const loading = accountsQuery.isLoading || balanceQuery.isLoading;

  return (
    <div className="space-y-4">
      <h2 className="text-navy text-xl font-bold m-0">Chart of Accounts</h2>
      {error && <p className="text-red text-sm">Gagal memuat data: {(error as Error).message}</p>}
      {loading ? (
        <Skeleton className="h-96" />
      ) : (
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Kode</TableHead>
              <TableHead>Nama</TableHead>
              <TableHead>Tipe</TableHead>
              <TableHead>NB</TableHead>
              <TableHead className="text-right">Saldo</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {accounts.map((a) => (
              <TableRow key={a.code} className={cn(a.is_header && "bg-navy/[0.04]")}>
                <TableCell>{a.code}</TableCell>
                <TableCell style={{ paddingLeft: `${(a.level - 1) * 16}px` }}>
                  {a.is_header ? <b>{a.account_name}</b> : a.account_name}
                </TableCell>
                <TableCell>{a.account_type}</TableCell>
                <TableCell>{a.normal_balance === "debit" ? "D" : "K"}</TableCell>
                <TableCell className="text-right tabular-nums">
                  {!a.is_header && balances[a.code] ? formatRupiah(balances[a.code]) : ""}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      )}
    </div>
  );
}
