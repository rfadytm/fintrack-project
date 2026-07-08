import { useQuery } from "@tanstack/react-query";
import { api } from "../utils/api";

export function useAuth() {
  const query = useQuery({
    queryKey: ["auth"],
    queryFn: api.me,
    retry: false,
  });
  return {
    loading: query.isLoading,
    loggedIn: query.data?.logged_in ?? false,
  };
}
