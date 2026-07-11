import { useState } from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { toast } from "sonner";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";
import { BillFormSchema, type BillFormValues } from "../types/api";
import { Card, CardTitle } from "../components/ui/card";
import { Button } from "../components/ui/button";
import { Input } from "../components/ui/input";
import { Label } from "../components/ui/label";
import { Skeleton } from "../components/ui/skeleton";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../components/ui/table";

export default function Bills() {
  const queryClient = useQueryClient();
  // See Budgets.tsx for why required string fields are seeded as "" rather than left undefined.
  const [form, setForm] = useState<Partial<BillFormValues>>({ name: "" });
  const [errors, setErrors] = useState<Partial<Record<keyof BillFormValues, string>>>({});
  const [saving, setSaving] = useState(false);

  const billsQuery = useQuery({ queryKey: ["bills"], queryFn: api.bills });

  const save = async () => {
    const parsed = BillFormSchema.safeParse(form);
    if (!parsed.success) {
      const flat = parsed.error.flatten().fieldErrors;
      const errs: typeof errors = {};
      (Object.keys(flat) as (keyof BillFormValues)[]).forEach((k) => {
        if (flat[k]?.[0]) errs[k] = flat[k]![0];
      });
      setErrors(errs);
      return;
    }
    setErrors({});
    setSaving(true);
    try {
      await api.saveBill(parsed.data);
      await queryClient.invalidateQueries({ queryKey: ["bills"] });
      setForm({});
      toast.success("Tagihan tersimpan.");
    } catch (e) {
      toast.error("Gagal menyimpan: " + (e as Error).message);
    } finally {
      setSaving(false);
    }
  };

  const remove = async (id: number) => {
    try {
      await api.deleteBill(id);
      await queryClient.invalidateQueries({ queryKey: ["bills"] });
      toast.success("Tagihan dihapus.");
    } catch (e) {
      toast.error("Gagal menghapus: " + (e as Error).message);
    }
  };

  return (
    <div className="space-y-4">
      <h2 className="text-white text-xl font-bold m-0">Tagihan</h2>

      <Card>
        <CardTitle>Tambah Tagihan</CardTitle>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 mt-3">
          <div className="flex flex-col gap-1">
            <Label htmlFor="bill-name">Nama</Label>
            <Input
              id="bill-name"
              placeholder="Listrik PLN"
              value={form.name || ""}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
            />
            {errors.name && <span className="text-red text-xs">{errors.name}</span>}
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="bill-amount">Nominal (Rp)</Label>
            <Input
              id="bill-amount"
              type="number"
              value={form.amount ?? ""}
              onChange={(e) => setForm((f) => ({ ...f, amount: Number(e.target.value) }))}
            />
            {errors.amount && <span className="text-red text-xs">{errors.amount}</span>}
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="bill-due">Tanggal jatuh tempo (1-31)</Label>
            <Input
              id="bill-due"
              type="number"
              min={1}
              max={31}
              value={form.due_day ?? ""}
              onChange={(e) => setForm((f) => ({ ...f, due_day: Number(e.target.value) }))}
            />
            {errors.due_day && <span className="text-red text-xs">{errors.due_day}</span>}
          </div>
        </div>
        <Button className="mt-3" onClick={save} disabled={saving}>
          {saving ? "Menyimpan…" : "Simpan"}
        </Button>
      </Card>

      <Card>
        <CardTitle>Daftar Tagihan</CardTitle>
        {billsQuery.error && <p className="text-red text-sm mt-2">Gagal memuat: {(billsQuery.error as Error).message}</p>}
        {billsQuery.isLoading ? (
          <Skeleton className="h-32 mt-3" />
        ) : !billsQuery.data?.bills.length ? (
          <p className="text-muted text-sm mt-2">Belum ada tagihan.</p>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Nama</TableHead>
                <TableHead className="text-right">Nominal</TableHead>
                <TableHead>Jatuh Tempo</TableHead>
                <TableHead />
              </TableRow>
            </TableHeader>
            <TableBody>
              {billsQuery.data.bills.map((b) => (
                <TableRow key={b.id}>
                  <TableCell>{b.name}</TableCell>
                  <TableCell className="text-right tabular-nums">{formatRupiah(b.amount)}</TableCell>
                  <TableCell>{b.due_day ? `Tgl ${b.due_day}` : b.due_date || "-"}</TableCell>
                  <TableCell>
                    <Button variant="ghost" size="sm" onClick={() => remove(b.id)}>
                      Hapus
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </Card>
    </div>
  );
}
