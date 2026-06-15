export function formatRupiah(amount) {
  const n = Number(amount || 0);
  return "Rp " + n.toLocaleString("id-ID");
}

export function formatNumber(amount) {
  return Number(amount || 0).toLocaleString("id-ID");
}
