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
