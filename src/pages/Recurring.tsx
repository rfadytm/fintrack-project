import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { RecurringFormSchema, type RecurringFormValues } from "../types/api";
import { Card, CardTitle } from "../components/ui/card";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { Select } from "../components/ui/select";
import { Skeleton } from "../components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

const FREQ_LABEL: Record<string, string> = { daily: "Harian", weekly: "Mingguan", monthly: "Bulanan" };

export default function Recurring() {
  const queryClient = useQueryClient();
  // See Budgets.tsx for why required string fields are seeded as "" rather than left undefined.
  const [form, setForm] = useState<Partial<RecurringFormValues>>({
    frequency: "monthly",
    description: "",
    account_code: "",
    source: "",
  });
  const [errors, setErrors] = useState<Partial<Record<keyof RecurringFormValues, string>>>({});
  const [saving, setSaving] = useState(false);

  const recurringQuery = useQuery({ queryKey: ["recurring"], queryFn: api.recurring });
  const expenseAccountsQuery = useQuery({
    queryKey: ["accounts", "?type=beban&postable_only=true"],
    queryFn: () => api.accounts("?type=beban&postable_only=true"),
  });
  const cashAccountsQuery = useQuery({
    queryKey: ["accounts", "?type=aset&postable_only=true"],
    queryFn: () => api.accounts("?type=aset&postable_only=true"),
  });

  const save = async () => {
    const parsed = RecurringFormSchema.safeParse(form);
    if (!parsed.success) {
      const flat = parsed.error.flatten().fieldErrors;
      const errs: typeof errors = {};
      (Object.keys(flat) as (keyof RecurringFormValues)[]).forEach((k) => {
        if (flat[k]?.[0]) errs[k] = flat[k]![0];
      });
      setErrors(errs);
      return;
    }
    setErrors({});
    setSaving(true);
    try {
      await api.saveRecurring({
        doc_type: "KK",
        description: parsed.data.description,
        frequency: parsed.data.frequency,
        lines: [
          { account_code: parsed.data.account_code, debit: parsed.data.amount, credit: 0 },
          { account_code: parsed.data.source, debit: 0, credit: parsed.data.amount },
        ],
      });
      await queryClient.invalidateQueries({ queryKey: ["recurring"] });
      setForm({ frequency: "monthly" });
      toast.success("Transaksi berulang tersimpan.");
    } catch (e) {
      toast.error("Gagal menyimpan: " + (e as Error).message);
    } finally {
      setSaving(false);
    }
  };

  const remove = async (id: number) => {
    try {
      await api.deleteRecurring(id);
      await queryClient.invalidateQueries({ queryKey: ["recurring"] });
      toast.success("Dihentikan.");
    } catch (e) {
      toast.error("Gagal: " + (e as Error).message);
    }
  };

  return (
    <div className="space-y-4">
      <h2 className="text-navy text-xl font-bold m-0">Transaksi Berulang</h2>

      <Card>
        <CardTitle>Tambah</CardTitle>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-3">
          <div className="flex flex-col gap-1 sm:col-span-2">
            <Label htmlFor="rec-desc">Nama/keterangan</Label>
            <Input
              id="rec-desc"
              placeholder="Langganan Netflix"
              value={form.description || ""}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
            />
            {errors.description && <span className="text-red text-xs">{errors.description}</span>}
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="rec-account">Kategori beban</Label>
            <Select
              id="rec-account"
              value={form.account_code || ""}
              onChange={(e) => setForm((f) => ({ ...f, account_code: e.target.value }))}
            >
              <option value="">— pilih —</option>
              {(expenseAccountsQuery.data?.accounts || []).map((a) => (
                <option key={a.code} value={a.code}>
                  {a.code} — {a.account_name}
                </option>
              ))}
            </Select>
            {errors.account_code && <span className="text-red text-xs">{errors.account_code}</span>}
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="rec-source">Sumber dana</Label>
            <Select
              id="rec-source"
              value={form.source || ""}
              onChange={(e) => setForm((f) => ({ ...f, source: e.target.value }))}
            >
              <option value="">— pilih —</option>
              {(cashAccountsQuery.data?.accounts || []).map((a) => (
                <option key={a.code} value={a.code}>
                  {a.code} — {a.account_name}
                </option>
              ))}
            </Select>
            {errors.source && <span className="text-red text-xs">{errors.source}</span>}
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="rec-amount">Nominal per transaksi (Rp)</Label>
            <Input
              id="rec-amount"
              type="number"
              value={form.amount ?? ""}
              onChange={(e) => setForm((f) => ({ ...f, amount: Number(e.target.value) }))}
            />
            {errors.amount && <span className="text-red text-xs">{errors.amount}</span>}
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="rec-freq">Frekuensi</Label>
            <Select
              id="rec-freq"
              value={form.frequency || "monthly"}
              onChange={(e) => setForm((f) => ({ ...f, frequency: e.target.value as RecurringFormValues["frequency"] }))}
            >
              <option value="daily">Harian</option>
              <option value="weekly">Mingguan</option>
              <option value="monthly">Bulanan</option>
            </Select>
          </div>
        </div>
        <Button className="mt-3" onClick={save} disabled={saving}>
          {saving ? "Menyimpan…" : "Simpan"}
        </Button>
      </Card>

      <Card>
        <CardTitle>Aktif</CardTitle>
        {recurringQuery.error && (
          <p className="text-red text-sm mt-2">Gagal memuat: {(recurringQuery.error as Error).message}</p>
        )}
        {recurringQuery.isLoading ? (
          <Skeleton className="h-32 mt-3" />
        ) : !recurringQuery.data?.recurring.length ? (
          <p className="text-muted text-sm mt-2">Belum ada transaksi berulang.</p>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Nama</TableHead>
                <TableHead className="text-right">Nominal</TableHead>
                <TableHead>Frekuensi</TableHead>
                <TableHead>Berikutnya</TableHead>
                <TableHead />
              </TableRow>
            </TableHeader>
            <TableBody>
              {recurringQuery.data.recurring.map((r) => {
                const total = r.lines.reduce((s, l) => s + (l.debit || 0), 0);
                return (
                  <TableRow key={r.id}>
                    <TableCell>{r.description || "-"}</TableCell>
                    <TableCell className="text-right tabular-nums">{formatRupiah(total)}</TableCell>
                    <TableCell>{FREQ_LABEL[r.frequency] || r.frequency}</TableCell>
                    <TableCell>{r.next_run}</TableCell>
                    <TableCell>
                      <Button variant="ghost" size="sm" onClick={() => remove(r.id)}>
                        Hentikan
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
