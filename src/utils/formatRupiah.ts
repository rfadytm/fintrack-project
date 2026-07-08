// Blindspot fix: negative amounts used to render "Rp -50.000" (sign trapped
// after the currency prefix). The minus now goes in front of "Rp".
export function formatRupiah(amount: number | null | undefined): string {
  const n = Number(amount || 0);
  const sign = n < 0 ? "-" : "";
  return `${sign}Rp ${Math.abs(n).toLocaleString("id-ID")}`;
}

export function formatNumber(amount: number | null | undefined): string {
  return Number(amount || 0).toLocaleString("id-ID");
}
