import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { GoalFormSchema, type GoalFormValues } from "../types/api";
import { Card, CardTitle } from "../components/ui/card";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { Select } from "../components/ui/select";
import { Skeleton } from "../components/ui/skeleton";

export default function Goals() {
  const queryClient = useQueryClient();
  // See Budgets.tsx for why required string fields are seeded as "" rather than left undefined.
  const [form, setForm] = useState<Partial<GoalFormValues>>({ name: "", account_code: "" });
  const [errors, setErrors] = useState<Partial<Record<keyof GoalFormValues, string>>>({});
  const [saving, setSaving] = useState(false);

  const goalsQuery = useQuery({ queryKey: ["goals"], queryFn: api.goals });
  const accountsQuery = useQuery({
    queryKey: ["accounts", "?type=aset&postable_only=true"],
    queryFn: () => api.accounts("?type=aset&postable_only=true"),
  });

  const save = async () => {
    const parsed = GoalFormSchema.safeParse(form);
    if (!parsed.success) {
      const flat = parsed.error.flatten().fieldErrors;
      const errs: typeof errors = {};
      (Object.keys(flat) as (keyof GoalFormValues)[]).forEach((k) => {
        if (flat[k]?.[0]) errs[k] = flat[k]![0];
      });
      setErrors(errs);
      return;
    }
    setErrors({});
    setSaving(true);
    try {
      await api.saveGoal(parsed.data);
      await queryClient.invalidateQueries({ queryKey: ["goals"] });
      setForm({});
      toast.success("Goal tersimpan.");
    } catch (e) {
      toast.error("Gagal menyimpan: " + (e as Error).message);
    } finally {
      setSaving(false);
    }
  };

  const remove = async (id: number) => {
    try {
      await api.deleteGoal(id);
      await queryClient.invalidateQueries({ queryKey: ["goals"] });
      toast.success("Goal dihapus.");
    } catch (e) {
      toast.error("Gagal menghapus: " + (e as Error).message);
    }
  };

  return (
    <div className="space-y-4">
      <h2 className="text-navy text-xl font-bold m-0">Goals</h2>

      <Card>
        <CardTitle>Tambah Goal</CardTitle>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-3 max-w-lg">
          <div className="flex flex-col gap-1 sm:col-span-2">
            <Label htmlFor="goal-name">Nama goal</Label>
            <Input
              id="goal-name"
              placeholder="Laptop baru"
              value={form.name || ""}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
            />
            {errors.name && <span className="text-red text-xs">{errors.name}</span>}
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="goal-target">Target (Rp)</Label>
            <Input
              id="goal-target"
              type="number"
              value={form.target_amount ?? ""}
              onChange={(e) => setForm((f) => ({ ...f, target_amount: Number(e.target.value) }))}
            />
            {errors.target_amount && <span className="text-red text-xs">{errors.target_amount}</span>}
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="goal-account">Progress dari akun</Label>
            <Select
              id="goal-account"
              value={form.account_code || ""}
              onChange={(e) => setForm((f) => ({ ...f, account_code: e.target.value }))}
            >
              <option value="">— pilih —</option>
              {(accountsQuery.data?.accounts || []).map((a) => (
                <option key={a.code} value={a.code}>
                  {a.code} — {a.account_name}
                </option>
              ))}
            </Select>
            {errors.account_code && <span className="text-red text-xs">{errors.account_code}</span>}
          </div>
        </div>
        <Button className="mt-3" onClick={save} disabled={saving}>
          {saving ? "Menyimpan…" : "Simpan"}
        </Button>
      </Card>

      {goalsQuery.error && <p className="text-red text-sm">Gagal memuat: {(goalsQuery.error as Error).message}</p>}
      {goalsQuery.isLoading ? (
        <Skeleton className="h-32" />
      ) : !goalsQuery.data?.goals.length ? (
        <p className="text-muted text-sm">Belum ada goal.</p>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {goalsQuery.data.goals.map((g) => {
            const pct = g.target_amount ? Math.min(Math.round((g.current_amount / g.target_amount) * 100), 100) : 0;
            return (
              <Card key={g.id}>
                <div className="flex items-center justify-between gap-2">
                  <CardTitle>{g.name}</CardTitle>
                  <Button variant="ghost" size="sm" onClick={() => remove(g.id)}>
                    Hapus
                  </Button>
                </div>
                <p className="text-sm text-muted mt-1">
                  {formatRupiah(g.current_amount)} / {formatRupiah(g.target_amount)}
                </p>
                <div className="w-full h-2.5 rounded-full bg-navy/10 overflow-hidden mt-2">
                  <div className="h-full bg-blue" style={{ width: `${pct}%` }} />
                </div>
                <p className="text-xs text-muted mt-1">{pct}%</p>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
