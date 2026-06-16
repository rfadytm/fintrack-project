import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../utils/api";
import { invalidateCache } from "../hooks/useTransactions";

const ACCOUNT_FIELDS = [
  ["default_expense_source", "Sumber default pengeluaran"],
  ["default_income_dest", "Tujuan default pemasukan"],
  ["kas_kecil_source", "Sumber pengisian kas kecil"],
  ["savings_account", "Akun tabungan"],
];
const NUMBER_FIELDS = [
  ["kas_kecil_target", "Target kas kecil (Rp)"],
  ["bi_fast_fee", "Biaya BI-Fast (Rp)"],
];

export default function Settings() {
  const navigate = useNavigate();
  const [cash, setCash] = useState([]);
  const [values, setValues] = useState({});
  const [status, setStatus] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    Promise.all([api.accounts("?postable_only=true"), api.settings()])
      .then(([a, s]) => {
        setCash((a.accounts || []).filter((x) => x.code.startsWith("11")));
        const map = {};
        (s.settings || []).forEach((r) => (map[r.key] = r.value));
        setValues(map);
      })
      .catch(() => {});
  }, []);

  const set = (k, v) => setValues((p) => ({ ...p, [k]: v }));

  const save = async () => {
    setSaving(true);
    setStatus("");
    try {
      const payload = {};
      [...ACCOUNT_FIELDS, ...NUMBER_FIELDS].forEach(([k]) => (payload[k] = values[k]));
      await api.updateSettings(payload);
      invalidateCache();
      setStatus("Tersimpan ✓");
    } catch (e) {
      setStatus("Gagal: " + e.message);
    } finally {
      setSaving(false);
    }
  };

  const logout = async () => {
    try {
      await api.logout();
    } catch {
      /* ignore */
    }
    navigate("/login", { replace: true });
  };

  return (
    <div className="page">
      <h2>Pengaturan</h2>

      <div className="card">
        <h3>Default Akun</h3>
        <p className="muted">Akun & nilai default yang dipakai bot saat input cepat.</p>
        {ACCOUNT_FIELDS.map(([k, label]) => (
          <div className="field" key={k}>
            <label>{label}</label>
            <select value={values[k] || ""} onChange={(e) => set(k, e.target.value)}>
              <option value="">— pilih —</option>
              {cash.map((a) => (
                <option key={a.code} value={a.code}>
                  {a.code} — {a.account_name}
                </option>
              ))}
            </select>
          </div>
        ))}
        {NUMBER_FIELDS.map(([k, label]) => (
          <div className="field" key={k}>
            <label>{label}</label>
            <input type="number" value={values[k] || ""} onChange={(e) => set(k, e.target.value)} />
          </div>
        ))}
        <div className="field-actions">
          <button className="btn-primary" onClick={save} disabled={saving}>
            {saving ? "Menyimpan…" : "Simpan"}
          </button>
          {status && <span className="save-status">{status}</span>}
        </div>
      </div>

      <div className="card">
        <h3>Sesi</h3>
        <p className="muted">Keluar dari dashboard di perangkat ini. Login lagi via /getlink di bot.</p>
        <button className="btn-danger" onClick={logout}>Logout</button>
      </div>

      <div className="card">
        <h3>Tentang</h3>
        <p className="muted">FinTrack v1.0 — Personal Accounting System.</p>
        <p className="muted">Input via Telegram bot, monitoring & laporan via dashboard. Daftar akun lengkap ada di menu COA.</p>
      </div>
    </div>
  );
}
