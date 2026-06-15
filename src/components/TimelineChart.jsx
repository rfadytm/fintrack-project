import { CartesianGrid, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { formatRupiah } from "../utils/formatRupiah";

export default function TimelineChart({ data = [] }) {
  if (!data.length) return <p className="muted">Tidak ada data timeline.</p>;
  return (
    <ResponsiveContainer width="100%" height={280}>
      <LineChart data={data}>
        <CartesianGrid strokeDasharray="3 3" stroke="#eee" />
        <XAxis dataKey="label" />
        <YAxis tickFormatter={(v) => `${v / 1000}rb`} />
        <Tooltip formatter={(v) => formatRupiah(v)} />
        <Line type="monotone" dataKey="value" stroke="#2E75B6" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}
