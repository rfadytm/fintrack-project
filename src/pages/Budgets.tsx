import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { BudgetFormSchema, type BudgetFormValues } from "../types/api";
import { Card, CardTitle } from "../components/ui/card";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { Select } from "../components/ui/select";
import { Skeleton } from "../components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

export default function Budgets() {
  const queryClient = useQueryClient();
  // Blindspot fix: an untouched required string field is `undefined`, not "" — Zod's
  // base type check (not the .min() refinement) rejects that with a generic message,
  // never showing the friendly "Wajib dipilih" text. Seeding "" here (like
  // Settings.tsx's `values` state) ensures the .min(1, "...") refinement is what
  // actually fires, and its custom message is what the user sees.
  const [form, setForm] = useState<Partial<BudgetFormValues>>({ account_code: "" });
  const [errors, setErrors] = useState<Partial<Record<keyof BudgetFormValues, string>>>({});
  const [saving, setSaving] = useState(false);

  const budgetsQuery = useQuery({ queryKey: ["budgets"], queryFn: api.budgets });
  const accountsQuery = useQuery({
    queryKey: ["accounts", "?type=beban&postable_only=true"],
    queryFn: () => api.accounts("?type=beban&postable_only=true"),
  });

  const budgeted = new Set((budgetsQuery.data?.budgets || []).map((b) => b.account_code));
  const selectableAccounts = (accountsQuery.data?.accounts || []).filter((a) => !budgeted.has(a.code));

  const save = async () => {
    const parsed = BudgetFormSchema.safeParse(form);
    if (!parsed.success) {
      const flat = parsed.error.flatten().fieldErrors;
      const errs: typeof errors = {};
      (Object.keys(flat) as (keyof BudgetFormValues)[]).forEach((k) => {
        if (flat[k]?.[0]) errs[k] = flat[k]![0];
      });
      setErrors(errs);
      return;
    }
    setErrors({});
    setSaving(true);
    try {
      await api.saveBudget(parsed.data.account_code, parsed.data.monthly_limit);
      await queryClient.invalidateQueries({ queryKey: ["budgets"] });
      setForm({});
      toast.success("Budget tersimpan.");
    } catch (e) {
      toast.error("Gagal menyimpan: " + (e as Error).message);
    } finally {
      setSaving(false);
    }
  };

  const remove = async (code: string) => {
    try {
      await api.deleteBudget(code);
      await queryClient.invalidateQueries({ queryKey: ["budgets"] });
      toast.success("Budget dihapus.");
    } catch (e) {
      toast.error("Gagal menghapus: " + (e as Error).message);
    }
  };

  return (
    <div className="space-y-4">
      <h2 className="text-white text-xl font-bold m-0">Budget</h2>

      <Card>
        <CardTitle>Tambah Budget</CardTitle>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-3 items-end">
          <div className="flex flex-col gap-1">
            <Label htmlFor="budget-account">Kategori beban</Label>
            <Select
              id="budget-account"
              value={form.account_code || ""}
              onChange={(e) => setForm((f) => ({ ...f, account_code: e.target.value }))}
            >
              <option value="">— pilih —</option>
              {selectableAccounts.map((a) => (
                <option key={a.code} value={a.code}>
                  {a.code} — {a.account_name}
                </option>
              ))}
            </Select>
            {errors.account_code && <span className="text-red text-xs">{errors.account_code}</span>}
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="budget-limit">Limit bulanan (Rp)</Label>
            <Input
              id="budget-limit"
              type="number"
              value={form.monthly_limit ?? ""}
              onChange={(e) => setForm((f) => ({ ...f, monthly_limit: Number(e.target.value) }))}
            />
            {errors.monthly_limit && <span className="text-red text-xs">{errors.monthly_limit}</span>}
          </div>
          <Button onClick={save} disabled={saving}>
            {saving ? "Menyimpan…" : "Simpan"}
          </Button>
        </div>
      </Card>

      <Card>
        <CardTitle>Budget Bulan Ini</CardTitle>
        {budgetsQuery.error && (
          <p className="text-red text-sm mt-2">Gagal memuat: {(budgetsQuery.error as Error).message}</p>
        )}
        {budgetsQuery.isLoading ? (
          <Skeleton className="h-32 mt-3" />
        ) : !budgetsQuery.data?.budgets.length ? (
          <p className="text-muted text-sm mt-2">Belum ada budget.</p>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Kategori</TableHead>
                <TableHead className="text-right">Terpakai</TableHead>
                <TableHead className="text-right">Limit</TableHead>
                <TableHead>Progress</TableHead>
                <TableHead />
              </TableRow>
            </TableHeader>
            <TableBody>
              {budgetsQuery.data.budgets.map((b) => {
                const pct = b.monthly_limit
                  ? Math.min(Math.round(((b.spent ?? 0) / b.monthly_limit) * 100), 999)
                  : 0;
                const color = pct >= 100 ? "bg-red" : pct >= 80 ? "bg-amber-500" : "bg-green";
                return (
                  <TableRow key={b.account_code}>
                    <TableCell>{b.account_name || b.account_code}</TableCell>
                    <TableCell className="text-right tabular-nums">{formatRupiah(b.spent)}</TableCell>
                    <TableCell className="text-right tabular-nums">{formatRupiah(b.monthly_limit)}</TableCell>
                    <TableCell>
                      <div className="w-32 h-2 rounded-full bg-white/10 overflow-hidden">
                        <div className={`h-full ${color}`} style={{ width: `${Math.min(pct, 100)}%` }} />
                      </div>
                      <span className="text-xs text-muted">{pct}%</span>
                    </TableCell>
                    <TableCell>
                      <Button variant="ghost" size="sm" onClick={() => remove(b.account_code)}>
                        Hapus
                      </Button>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        )}
      </Card>
    </div>
  );
}
