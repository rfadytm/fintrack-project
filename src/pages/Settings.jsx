import { useEffect, useState } from "react";
import { api } from "../utils/api";

// v1: baca-saja (alias & default akun dikelola via bot).
export default function Settings() {
  const [accounts, setAccounts] = useState([]);
  useEffect(() => {
    api.accounts("?postable_only=true").then((r) => setAccounts(r.accounts)).catch(() => {});
  }, []);

  return (
    <div className="page">
      <h2>Pengaturan</h2>
      <div className="card">
        <p className="muted">
          v1: pengaturan (alias, default akun, kunci periode, backup) dikelola lewat bot Telegram.
          Halaman ini menampilkan daftar akun postable sebagai referensi.
        </p>
        <ul className="acc-list">
          {accounts.map((a) => (
            <li key={a.code}>
              <code>{a.code}</code> {a.account_name}
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
