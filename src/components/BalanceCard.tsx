import { motion } from "framer-motion";
import { formatRupiah } from "../utils/formatRupiah";
import { Card } from "./ui/card";
import { AnimatedNumber } from "./ui/animated-number";

interface BalanceCardProps {
  name: string;
  balance: number;
  type: "aset" | "liabilitas";
}

export default function BalanceCard({ name, balance, type }: BalanceCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.25 }}
      className="flex-1 min-w-[160px]"
    >
      <Card className={type === "liabilitas" ? "border-red/20" : undefined}>
        <div className="text-muted text-xs">{name}</div>
        <div className="text-xl font-bold text-navy mt-1">
          <AnimatedNumber value={balance} format={formatRupiah} />
        </div>
      </Card>
    </motion.div>
  );
}
