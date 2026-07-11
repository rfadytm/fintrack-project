import { NavLink } from "react-router-dom";
import { cn } from "../lib/utils";

const links: [string, string][] = [
  ["/dashboard", "Dashboard"],
  ["/journal", "Jurnal"],
  ["/ledger", "Buku Besar"],
  ["/reports", "Laporan"],
  ["/coa", "COA"],
  ["/budgets", "Budget"],
  ["/goals", "Goals"],
  ["/recurring", "Berulang"],
  ["/bills", "Tagihan"],
  ["/settings", "Pengaturan"],
];

export default function Navbar() {
  return (
    <nav className="sticky top-0 z-40 flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-6 bg-[#16161a]/60 backdrop-blur-xl border-b border-white/[0.06] text-white px-4 sm:px-6 py-3 shadow-lg shadow-black/20">
      <NavLink
        to="/dashboard"
        className="flex items-center gap-2 font-bold text-lg text-white no-underline shrink-0 hover:opacity-85"
      >
        <img src="/logo.png" alt="FinTrack" className="h-8 w-8 object-contain" />
        <span>FinTrack</span>
      </NavLink>
      <div className="flex gap-3.5 flex-nowrap sm:flex-wrap overflow-x-auto scrollbar-thin -mx-1 px-1 sm:mx-0 sm:px-0">
        {links.map(([to, label]) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              cn(
                "text-sm whitespace-nowrap text-[#cdd9ec] no-underline py-1",
                isActive && "text-white font-semibold"
              )
            }
          >
            {label}
          </NavLink>
        ))}
      </div>
    </nav>
  );
}
