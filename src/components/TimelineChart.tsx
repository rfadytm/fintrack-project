import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { formatRupiah } from "../utils/formatRupiah";
import { formatChartAxis, niceCeiling } from "../utils/niceScale";

// Apple red/rose — this chart tracks EXPENSE accumulation, so it uses the
// same semantic color as the rest of the app's expense figures (text-red).
const EXPENSE_COLOR = "#ff3b30";
const AXIS_TICK = { fill: "#98989d", fontSize: 12 };

interface TimelineDatum {
  label: string;
  value: number;
}

export default function TimelineChart({ data = [] }: { data?: TimelineDatum[] }) {
  if (!data.length) return <p className="text-muted text-sm">Tidak ada data timeline.</p>;
  // Blindspot fix: batas atas grafik dihitung dari puncak NYATA periode ini (bukan
  // skala tetap) supaya selalu ada ruang lega di atas titik tertinggi — lihat
  // niceCeiling untuk aturan pembulatannya.
  const ceiling = niceCeiling(Math.max(...data.map((d) => d.value)));
  return (
    <ResponsiveContainer width="100%" height={280}>
      <AreaChart data={data}>
        <defs>
          <linearGradient id="timelineFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor={EXPENSE_COLOR} stopOpacity={0.2} />
            <stop offset="95%" stopColor={EXPENSE_COLOR} stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.06)" />
        <XAxis dataKey="label" tick={AXIS_TICK} axisLine={{ stroke: "rgba(255,255,255,0.1)" }} />
        <YAxis
          domain={[0, ceiling]}
          tickFormatter={formatChartAxis}
          tick={AXIS_TICK}
          axisLine={{ stroke: "rgba(255,255,255,0.1)" }}
        />
        <Tooltip
          formatter={(v: number) => formatRupiah(v)}
          contentStyle={{
            background: "#16161a",
            border: "1px solid rgba(255,255,255,0.08)",
            borderRadius: 12,
            color: "#f5f5f7",
          }}
          labelStyle={{ color: "#98989d" }}
        />
        <Area type="monotone" dataKey="value" stroke={EXPENSE_COLOR} strokeWidth={2} fill="url(#timelineFill)" />
      </AreaChart>
    </ResponsiveContainer>
  );
}
