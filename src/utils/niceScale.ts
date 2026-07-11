// Blindspot fix: chart Y-axis used to auto-scale flush against the actual peak
// (Recharts' 'auto' domain has no headroom), so a new high point could render
// right at the very top edge. This picks a round, human-friendly ceiling with
// headroom above `max`, recalculated per period from that period's own peak —
// not a fixed cap — using the standard 1/2/2.5/5/10 "nice number" progression.
const NICE_STEPS = [1, 2, 2.5, 5, 10];

export function niceCeiling(max: number): number {
  if (!Number.isFinite(max) || max <= 0) return 100_000;
  const magnitude = 10 ** Math.floor(Math.log10(max));
  const normalized = max / magnitude;
  const step = NICE_STEPS.find((s) => s > normalized + 1e-9) ?? NICE_STEPS[0] * 10;
  return Math.round(step * magnitude);
}

// Blindspot fix: nilai >= 1 juta ditampilkan sebagai "1000rb"/"1500rb" —
// benar tapi tidak wajar dibaca orang Indonesia, harusnya "1 juta"/"1,5 juta".
// Di bawah 1 juta tetap "rb" (500rb, bukan "0,5 juta").
export function formatChartAxis(value: number): string {
  if (!Number.isFinite(value)) return "0rb";
  if (Math.abs(value) >= 1_000_000) {
    const juta = value / 1_000_000;
    const rounded = Math.round(juta * 10) / 10; // 1 desimal
    const label = Number.isInteger(rounded) ? String(rounded) : rounded.toString().replace(".", ",");
    return `${label} juta`;
  }
  return `${value / 1000}rb`;
}
