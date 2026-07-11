import { motion } from "framer-motion";
import { formatRupiah } from "../utils/formatRupiah";
import { Card } from "./ui/card";
import { AnimatedNumber } from "./ui/animated-number";
import { cn } from "../lib/utils";

interface BalanceCardProps {
  name: string;
  balance: number | null;
  type: "aset" | "liabilitas";
  masked?: boolean;
}

export default function BalanceCard({ name, balance, type, masked = false }: BalanceCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.25 }}
      className="flex-1 min-w-[160px]"
    >
      <Card className={type === "liabilitas" ? "border-red/20" : undefined}>
        <div className="text-muted text-xs">{name}</div>
        <div className={cn("text-xl font-bold text-white mt-1", masked && "blur-md select-none")}>
          <AnimatedNumber value={balance} format={formatRupiah} />
        </div>
      </Card>
    </motion.div>
  );
}
