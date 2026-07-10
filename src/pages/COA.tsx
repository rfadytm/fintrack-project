import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { Card, CardTitle } from "../components/ui/card";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Skeleton } from "../components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";
import { cn } from "../lib/utils";

export default function COA() {
  const queryClient = useQueryClient();
  const [newCategory, setNewCategory] = useState("");
  const [adding, setAdding] = useState(false);
  const accountsQuery = useQuery({ queryKey: ["accounts", ""], queryFn: () => api.accounts() });
  const balanceQuery = useQuery({ queryKey: ["balance", ""], queryFn: () => api.balance() });

  const accounts = accountsQuery.data?.accounts || [];
  // number | null: balance is masked to null for unauthenticated public-demo
  // viewers (see shared/masking.py) — the `balances[a.code] ?` truthy check
  // below already treats null the same as "no balance to show".
  const balances: Record<string, number | null> = {};
  (balanceQuery.data?.balances || []).forEach((x) => (balances[x.code] = x.balance));

  const error = accountsQuery.error || balanceQuery.error;
  const loading = accountsQuery.isLoading || balanceQuery.isLoading;

  const addCategory = async () => {
    const name = newCategory.trim();
    if (!name) return;
    setAdding(true);
    try {
      await api.createCategory(name);
      await queryClient.invalidateQueries({ queryKey: ["accounts"] });
      setNewCategory("");
      toast.success(`Kategori "${name}" dibuat.`);
    } catch (e) {
      toast.error("Gagal membuat kategori: " + (e as Error).message);
    } finally {
      setAdding(false);
    }
  };

  return (
    <div className="space-y-4">
      <h2 className="text-navy text-xl font-bold m-0">Chart of Accounts</h2>

      <Card>
        <CardTitle>Tambah Kategori Beban Custom</CardTitle>
        <div className="flex gap-2 mt-3 max-w-md">
          <Input
            placeholder="Nama kategori (mis. Hobi)"
            value={newCategory}
            onChange={(e) => setNewCategory(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && addCategory()}
          />
          <Button onClick={addCategory} disabled={adding || !newCategory.trim()}>
            {adding ? "Menyimpan…" : "Tambah"}
          </Button>
        </div>
      </Card>

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
