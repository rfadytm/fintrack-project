import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";
import { formatRupiah } from "../utils/formatRupiah";

// Apple system-color palette (dark-mode variants) — reads clearly against the
// dark obsidian card background, unlike the old navy/blue tones tuned for a
// light card.
const COLORS = ["#0A84FF", "#30D158", "#FF9F0A", "#BF5AF2", "#FF375F", "#64D2FF", "#5E5CE6", "#FFD60A"];

interface CategoryDatum {
  account_name: string;
  amount: number | null;
}

export default function CategoryChart({ data = [] }: { data?: CategoryDatum[] }) {
  if (!data.length) return <p className="text-muted text-sm">Tidak ada data beban.</p>;
  // amount masked to null for public-demo viewers (shared/masking.py) —
  // coerced to 0 here so the pie chart always gets real numbers, never null
  // (recharts' handling of a null slice value is not something to rely on).
  // Blindspot fix: on-slice labels (leader lines + raw numbers) used to
  // overlap the legend and get clipped at the top of the container. Removed
  // in favor of a clean list below the chart — sorted biggest-first so the
  // list itself carries most of the "which category matters" information.
  const chartData = data
    .map((d) => ({ name: d.account_name, value: d.amount ?? 0 }))
    .sort((a, b) => b.value - a.value);

  return (
    <div>
      <ResponsiveContainer width="100%" height={240}>
        <PieChart margin={{ top: 8, right: 8, bottom: 8, left: 8 }}>
          <Pie data={chartData} dataKey="value" nameKey="name" outerRadius={95}>
            {chartData.map((_, i) => (
              <Cell key={i} fill={COLORS[i % COLORS.length]} />
            ))}
          </Pie>
          <Tooltip
            formatter={(v: number) => formatRupiah(v)}
            contentStyle={{
              background: "#16161a",
              border: "1px solid rgba(255,255,255,0.08)",
              borderRadius: 12,
              color: "#f5f5f7",
            }}
          />
        </PieChart>
      </ResponsiveContainer>
      <ul className="mt-3 space-y-1.5">
        {chartData.map((d, i) => (
          <li key={d.name} className="flex items-center justify-between gap-2 text-sm">
            <span className="flex items-center gap-2 min-w-0">
              <span
                className="w-2.5 h-2.5 rounded-full shrink-0"
                style={{ backgroundColor: COLORS[i % COLORS.length] }}
              />
              <span className="truncate">{d.name}</span>
            </span>
            <span className="tabular-nums font-medium text-white shrink-0">{formatRupiah(d.value)}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
