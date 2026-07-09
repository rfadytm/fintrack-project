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
import { niceCeiling } from "../utils/niceScale";

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
            <stop offset="5%" stopColor="#2E75B6" stopOpacity={0.35} />
            <stop offset="95%" stopColor="#2E75B6" stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="#eee" />
        <XAxis dataKey="label" />
        <YAxis domain={[0, ceiling]} tickFormatter={(v: number) => `${v / 1000}rb`} />
        <Tooltip formatter={(v: number) => formatRupiah(v)} />
        <Area type="monotone" dataKey="value" stroke="#2E75B6" strokeWidth={2} fill="url(#timelineFill)" />
      </AreaChart>
    </ResponsiveContainer>
  );
}
