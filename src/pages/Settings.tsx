import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { toast } from "sonner";
import { api } from "../utils/api";
import { queryClient } from "../lib/queryClient";
import { SettingsFormSchema, type SettingsFormValues } from "../types/api";
import { Card, CardTitle } from "../components/ui/card";
import { Label } from "../components/ui/label";
import { Select } from "../components/ui/select";
import { Input } from "../components/ui/input";
import { Button } from "../components/ui/button";
import { Badge } from "../components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "../components/ui/dialog";

type FieldKey = keyof SettingsFormValues;

const ACCOUNT_FIELDS: [FieldKey, string][] = [
  ["default_expense_source", "Sumber default pengeluaran"],
  ["default_income_dest", "Tujuan default pemasukan"],
  ["kas_kecil_source", "Sumber pengisian kas kecil"],
  ["savings_account", "Akun tabungan"],
];
const NUMBER_FIELDS: [FieldKey, string][] = [
  ["kas_kecil_target", "Target kas kecil (Rp)"],
  ["bi_fast_fee", "Biaya BI-Fast (Rp)"],
];

export default function Settings() {
  const navigate = useNavigate();
  const [values, setValues] = useState<Record<FieldKey, string>>({
    default_expense_source: "",
    default_income_dest: "",
    kas_kecil_source: "",
    savings_account: "",
    kas_kecil_target: "",
    bi_fast_fee: "",
  });
  const [fieldErrors, setFieldErrors] = useState<Partial<Record<FieldKey, string>>>({});
  const [status, setStatus] = useState("");
  const [saving, setSaving] = useState(false);
  const [logoutOpen, setLogoutOpen] = useState(false);

  const accountsQuery = useQuery({
    queryKey: ["accounts", "?postable_only=true"],
    queryFn: () => api.accounts("?postable_only=true"),
  });
  const settingsQuery = useQuery({ queryKey: ["settings"], queryFn: api.settings });
  const cash = (accountsQuery.data?.accounts || []).filter((x) => x.code.startsWith("11"));

  useEffect(() => {
    if (!settingsQuery.data) return;
    setValues((prev) => {
      const next = { ...prev };
      settingsQuery.data.settings.forEach((r) => {
        if (r.key in next) next[r.key as FieldKey] = String(r.value ?? "");
      });
      return next;
    });
  }, [settingsQuery.data]);

  const set = (k: FieldKey, v: string) => setValues((p) => ({ ...p, [k]: v }));

  const save = async () => {
    setStatus("");
    // Blindspot fix: numeric fields used to go to the API as raw strings with
    // no check they were even numeric, and required selects could be saved empty.
    const parsed = SettingsFormSchema.safeParse(values);
    if (!parsed.success) {
      const flat = parsed.error.flatten().fieldErrors;
      const errs: Partial<Record<FieldKey, string>> = {};
      (Object.keys(flat) as FieldKey[]).forEach((k) => {
        const msgs = flat[k];
        if (msgs && msgs[0]) errs[k] = msgs[0];
      });
      setFieldErrors(errs);
      toast.error("Periksa kembali isian yang ditandai.");
      return;
    }
    setFieldErrors({});
    setSaving(true);
    try {
      await api.updateSettings(parsed.data);
      await queryClient.invalidateQueries();
      setStatus("Tersimpan ✓");
      toast.success("Pengaturan tersimpan.");
    } catch (e) {
      const msg = (e as Error).message;
      setStatus("Gagal: " + msg);
      toast.error("Gagal menyimpan: " + msg);
    } finally {
      setSaving(false);
    }
  };

  const logout = async () => {
    try {
      await api.logout();
    } catch {
      /* ignore — logging out locally still makes sense even if the request failed */
    }
    queryClient.clear();
    navigate("/login", { replace: true });
  };

  // v3: preferences (currency/timezone/report toggles/alert sensitivity/rate limit) —
  // separate small form since these aren't covered by SettingsFormSchema's strict
  // validation (they're free-form/optional, unlike the required account selects above).
  const [prefs, setPrefs] = useState<Record<string, string>>({
    currency_preference: "IDR",
    timezone: "Asia/Jakarta",
    daily_report_enabled: "true",
    weekly_report_enabled: "true",
    alert_sensitivity: "normal",
    rate_limit_per_minute: "20",
    budget_alert_throttle_mins: "120",
  });
  const [savingPrefs, setSavingPrefs] = useState(false);

  useEffect(() => {
    if (!settingsQuery.data) return;
    setPrefs((prev) => {
      const next = { ...prev };
      settingsQuery.data.settings.forEach((r) => {
        if (r.key in next) next[r.key] = String(r.value ?? "");
      });
      return next;
    });
  }, [settingsQuery.data]);

  const savePrefs = async () => {
    setSavingPrefs(true);
    try {
      await api.updateSettings(prefs);
      await queryClient.invalidateQueries({ queryKey: ["settings"] });
      toast.success("Preferensi tersimpan.");
    } catch (e) {
      toast.error("Gagal menyimpan: " + (e as Error).message);
    } finally {
      setSavingPrefs(false);
    }
  };

  // v3: tags management
  const tagsQuery = useQuery({ queryKey: ["tags"], queryFn: api.tags });
  const [newTag, setNewTag] = useState("");
  const addTag = async () => {
    const name = newTag.trim();
    if (!name) return;
    try {
      await api.createTag(name);
      await queryClient.invalidateQueries({ queryKey: ["tags"] });
      setNewTag("");
    } catch (e) {
      toast.error("Gagal menambah tag: " + (e as Error).message);
    }
  };
  const removeTag = async (id: number) => {
    try {
      await api.deleteTag(id);
      await queryClient.invalidateQueries({ queryKey: ["tags"] });
    } catch (e) {
      toast.error("Gagal menghapus tag: " + (e as Error).message);
    }
  };

  return (
    <div className="space-y-4">
      <h2 className="text-navy text-xl font-bold m-0">Pengaturan</h2>

      <Card>
        <CardTitle>Default Akun</CardTitle>
        <p className="text-muted text-sm mt-1">Akun & nilai default yang dipakai bot saat input cepat.</p>
        {accountsQuery.error && (
          <p className="text-red text-sm">Gagal memuat akun: {(accountsQuery.error as Error).message}</p>
        )}
        {settingsQuery.error && (
          <p className="text-red text-sm">Gagal memuat pengaturan: {(settingsQuery.error as Error).message}</p>
        )}
        <div className="space-y-3 mt-3 max-w-md">
          {ACCOUNT_FIELDS.map(([k, label]) => (
            <div key={k} className="flex flex-col gap-1">
              <Label htmlFor={`settings-${k}`}>{label}</Label>
              <Select id={`settings-${k}`} value={values[k] || ""} onChange={(e) => set(k, e.target.value)}>
                <option value="">— pilih —</option>
                {cash.map((a) => (
                  <option key={a.code} value={a.code}>
                    {a.code} — {a.account_name}
                  </option>
                ))}
              </Select>
              {fieldErrors[k] && <span className="text-red text-xs">{fieldErrors[k]}</span>}
            </div>
          ))}
          {NUMBER_FIELDS.map(([k, label]) => (
            <div key={k} className="flex flex-col gap-1">
              <Label htmlFor={`settings-${k}`}>{label}</Label>
              <Input
                id={`settings-${k}`}
                type="number"
                value={values[k] || ""}
                onChange={(e) => set(k, e.target.value)}
              />
              {fieldErrors[k] && <span className="text-red text-xs">{fieldErrors[k]}</span>}
            </div>
          ))}
          <div className="flex items-center gap-3 pt-1">
            <Button onClick={save} disabled={saving}>
              {saving ? "Menyimpan…" : "Simpan"}
            </Button>
            {status && <span className="text-green text-sm">{status}</span>}
          </div>
        </div>
      </Card>

      <Card>
        <CardTitle>Preferensi</CardTitle>
        <p className="text-muted text-sm mt-1">Mata uang, timezone, laporan terjadwal, dan sensitivitas alert.</p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-3 max-w-lg">
          <div className="flex flex-col gap-1">
            <Label htmlFor="pref-currency">Mata uang</Label>
            <Input
              id="pref-currency"
              value={prefs.currency_preference}
              onChange={(e) => setPrefs((p) => ({ ...p, currency_preference: e.target.value.toUpperCase() }))}
            />
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="pref-tz">Timezone</Label>
            <Input
              id="pref-tz"
              value={prefs.timezone}
              onChange={(e) => setPrefs((p) => ({ ...p, timezone: e.target.value }))}
            />
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="pref-daily">Laporan harian</Label>
            <Select
              id="pref-daily"
              value={prefs.daily_report_enabled}
              onChange={(e) => setPrefs((p) => ({ ...p, daily_report_enabled: e.target.value }))}
            >
              <option value="true">Aktif</option>
              <option value="false">Nonaktif</option>
            </Select>
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="pref-weekly">Laporan mingguan</Label>
            <Select
              id="pref-weekly"
              value={prefs.weekly_report_enabled}
              onChange={(e) => setPrefs((p) => ({ ...p, weekly_report_enabled: e.target.value }))}
            >
              <option value="true">Aktif</option>
              <option value="false">Nonaktif</option>
            </Select>
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="pref-sensitivity">Sensitivitas deteksi anomali</Label>
            <Select
              id="pref-sensitivity"
              value={prefs.alert_sensitivity}
              onChange={(e) => setPrefs((p) => ({ ...p, alert_sensitivity: e.target.value }))}
            >
              <option value="strict">Ketat</option>
              <option value="normal">Normal</option>
              <option value="relaxed">Longgar</option>
            </Select>
          </div>
          <div className="flex flex-col gap-1">
            <Label htmlFor="pref-ratelimit">Rate limit (pesan/menit)</Label>
            <Input
              id="pref-ratelimit"
              type="number"
              value={prefs.rate_limit_per_minute}
              onChange={(e) => setPrefs((p) => ({ ...p, rate_limit_per_minute: e.target.value }))}
            />
          </div>
        </div>
        <Button className="mt-3" onClick={savePrefs} disabled={savingPrefs}>
          {savingPrefs ? "Menyimpan…" : "Simpan Preferensi"}
        </Button>
      </Card>

      <Card>
        <CardTitle>Tags</CardTitle>
        <p className="text-muted text-sm mt-1">Kelola tag untuk memberi label transaksi (mis. "kerja", "pajak").</p>
        <div className="flex gap-2 mt-3 max-w-md">
          <Input
            placeholder="Nama tag baru"
            value={newTag}
            onChange={(e) => setNewTag(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && addTag()}
          />
          <Button onClick={addTag} disabled={!newTag.trim()}>
            Tambah
          </Button>
        </div>
        <div className="flex flex-wrap gap-2 mt-3">
          {(tagsQuery.data?.tags || []).map((t) => (
            <Badge key={t.id} variant="neutral" className="cursor-pointer" onClick={() => removeTag(t.id)}>
              {t.emoji || ""} {t.name} ✕
            </Badge>
          ))}
          {!tagsQuery.data?.tags.length && <span className="text-muted text-sm">Belum ada tag.</span>}
        </div>
      </Card>

      <Card>
        <CardTitle>Sesi</CardTitle>
        <p className="text-muted text-sm mt-1">Keluar dari dashboard di perangkat ini. Login lagi via /getlink di bot.</p>
        <Dialog open={logoutOpen} onOpenChange={setLogoutOpen}>
          <DialogTrigger asChild>
            <Button variant="destructive">Logout</Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>Yakin logout?</DialogTitle>
              <DialogDescription>
                Kamu perlu ketik /getlink di bot Telegram lagi untuk masuk kembali.
              </DialogDescription>
            </DialogHeader>
            <DialogFooter>
              <Button variant="ghost" onClick={() => setLogoutOpen(false)}>
                Batal
              </Button>
              <Button variant="destructive" onClick={logout}>
                Ya, logout
              </Button>
            </DialogFooter>
          </DialogContent>
        </Dialog>
      </Card>

      <Card>
        <CardTitle>Tentang</CardTitle>
        <p className="text-muted text-sm mt-1">FinTrack v1.0 — Personal Accounting System.</p>
        <p className="text-muted text-sm">
          Input via Telegram bot, monitoring & laporan via dashboard. Daftar akun lengkap ada di menu COA.
        </p>
      </Card>
    </div>
  );
}
