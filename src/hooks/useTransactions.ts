import { useQuery } from "@tanstack/react-query";
import { api } from "../utils/api";

export function useTransactions(qs = "") {
  const query = useQuery({
    queryKey: ["transactions", qs],
    queryFn: () => api.transactions(qs),
  });
  return {
    loading: query.isLoading,
    transactions: query.data?.transactions ?? [],
    total: query.data?.total ?? 0,
    error: query.isError ? (query.error as Error).message : null,
  };
}
