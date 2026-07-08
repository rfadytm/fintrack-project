import { useQuery } from "@tanstack/react-query";

// Thin wrapper kept so callers don't need to change shape mid-migration —
// React Query itself now owns the caching/dedup/staleness that the old
// hand-rolled `Map` cache (B12) used to do.
export function useReport<T>(key: string, loader: () => Promise<T>, _deps: unknown[] = []) {
  const query = useQuery({
    queryKey: [key],
    queryFn: loader,
  });
  return {
    loading: query.isLoading,
    data: query.data ?? null,
    error: query.isError ? (query.error as Error).message : null,
  };
}
