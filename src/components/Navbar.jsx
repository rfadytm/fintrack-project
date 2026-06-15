import { NavLink } from "react-router-dom";

const links = [
  ["/dashboard", "Dashboard"],
  ["/journal", "Jurnal"],
  ["/ledger", "Buku Besar"],
  ["/reports", "Laporan"],
  ["/coa", "COA"],
  ["/settings", "Pengaturan"],
];

export default function Navbar() {
  return (
    <nav className="navbar">
      <NavLink to="/dashboard" className="brand">💰 FinTrack</NavLink>
      <div className="navlinks">
        {links.map(([to, label]) => (
          <NavLink key={to} to={to} className={({ isActive }) => (isActive ? "active" : "")}>
            {label}
          </NavLink>
        ))}
      </div>
    </nav>
  );
}
