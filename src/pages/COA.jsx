import { useEffect, useState } from "react";
import { api } from "../utils/api";
import { formatRupiah } from "../utils/formatRupiah";

export default function COA() {
  const [accounts, setAccounts] = useState([]);
  const [balances, setBalances] = useState({});

  useEffect(() => {
    Promise.all([api.accounts(), api.balance()])
      .then(([a, b]) => {
        setAccounts(a.accounts);
        const map = {};
        (b.balances || []).forEach((x) => (map[x.code] = x.balance));
        setBalances(map);
      })
      .catch(() => {});
  }, []);

  return (
    <div className="page">
      <h2>Chart of Accounts</h2>
      <table className="table">
        <thead>
          <tr><th>Kode</th><th>Nama</th><th>Tipe</th><th>NB</th><th className="num">Saldo</th></tr>
        </thead>
        <tbody>
          {accounts.map((a) => (
            <tr key={a.code} className={a.is_header ? "header-row" : ""}>
              <td>{a.code}</td>
              <td style={{ paddingLeft: `${(a.level - 1) * 16}px` }}>
                {a.is_header ? <b>{a.account_name}</b> : a.account_name}
              </td>
              <td>{a.account_type}</td>
              <td>{a.normal_balance === "debit" ? "D" : "K"}</td>
              <td className="num">{!a.is_header && balances[a.code] ? formatRupiah(balances[a.code]) : ""}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
