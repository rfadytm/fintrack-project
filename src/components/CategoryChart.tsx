import { Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip } from "recharts";
import { formatRupiah } from "../utils/formatRupiah";

const COLORS = ["#1F3864", "#2E75B6", "#5B9BD5", "#9DC3E6", "#BDD7EE", "#C55A11", "#ED7D31", "#FFC000"];

interface CategoryDatum {
  account_name: string;
  amount: number | null;
}

export default function CategoryChart({ data = [] }: { data?: CategoryDatum[] }) {
  if (!data.length) return <p className="text-muted text-sm">Tidak ada data beban.</p>;
  // amount masked to null for public-demo viewers (shared/masking.py) —
  // coerced to 0 here so the pie chart always gets real numbers, never null
  // (recharts' handling of a null slice value is not something to rely on).
  const chartData = data.map((d) => ({ name: d.account_name, value: d.amount ?? 0 }));
  return (
    <ResponsiveContainer width="100%" height={280}>
      <PieChart>
        <Pie data={chartData} dataKey="value" nameKey="name" outerRadius={100} label>
          {chartData.map((_, i) => (
            <Cell key={i} fill={COLORS[i % COLORS.length]} />
          ))}
        </Pie>
        <Tooltip formatter={(v: number) => formatRupiah(v)} />
        <Legend />
      </PieChart>
    </ResponsiveContainer>
  );
}
