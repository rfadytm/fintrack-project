import { useEffect, useRef, useState } from "react";
import { NavLink } from "react-router-dom";
import { Menu, X } from "lucide-react";
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
  const [open, setOpen] = useState(false);
  const wrapperRef = useRef<HTMLDivElement>(null);

  // Tutup menu kalau klik di luar dropdown atau tekan Escape — pola dropdown
  // standar, bukan cuma bisa ditutup dengan klik tombolnya lagi.
  useEffect(() => {
    if (!open) return;
    const onClickOutside = (e: MouseEvent) => {
      if (wrapperRef.current && !wrapperRef.current.contains(e.target as Node)) setOpen(false);
    };
    const onEscape = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("mousedown", onClickOutside);
    document.addEventListener("keydown", onEscape);
    return () => {
      document.removeEventListener("mousedown", onClickOutside);
      document.removeEventListener("keydown", onEscape);
    };
  }, [open]);

  return (
    <nav className="sticky top-0 z-40 flex items-center justify-between gap-3 bg-[#16161a]/60 backdrop-blur-xl border-b border-white/[0.06] text-white px-4 sm:px-6 py-3 shadow-lg shadow-black/20">
      <NavLink
        to="/dashboard"
        className="flex items-center gap-2 font-bold text-lg text-white no-underline shrink-0 hover:opacity-85"
      >
        <img src="/logo.png" alt="FinTrack" className="h-8 w-8 object-contain" />
        <span>FinTrack</span>
      </NavLink>

      <div className="relative" ref={wrapperRef}>
        <button
          type="button"
          onClick={() => setOpen((o) => !o)}
          aria-expanded={open}
          aria-haspopup="true"
          className="inline-flex items-center gap-2 h-11 md:h-9 px-3.5 rounded-lg bg-white/5 border border-white/[0.06] text-white hover:bg-white/10 transition-colors"
        >
          {open ? <X className="h-4 w-4" /> : <Menu className="h-4 w-4" />}
          <span className="text-sm font-medium">Menu</span>
        </button>

        {open && (
          <div className="absolute right-0 mt-2 w-56 rounded-2xl border border-white/[0.06] bg-[#16161a]/95 backdrop-blur-xl shadow-[0_8px_32px_rgba(0,0,0,0.4)] py-2 flex flex-col">
            {links.map(([to, label]) => (
              <NavLink
                key={to}
                to={to}
                onClick={() => setOpen(false)}
                className={({ isActive }) =>
                  cn(
                    "px-4 py-2.5 text-sm text-[#cdd9ec] no-underline hover:bg-white/5 transition-colors",
                    isActive && "text-white font-semibold bg-white/5"
                  )
                }
              >
                {label}
              </NavLink>
            ))}
          </div>
        )}
      </div>
    </nav>
  );
}
