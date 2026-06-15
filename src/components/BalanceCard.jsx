import { formatRupiah } from "../utils/formatRupiah";

export default function BalanceCard({ name, balance, type }) {
  return (
    <div className={`card balance-card ${type}`}>
      <div className="card-label">{name}</div>
      <div className="card-value">{formatRupiah(balance)}</div>
    </div>
  );
}
