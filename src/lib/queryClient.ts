import { QueryCache, QueryClient } from "@tanstack/react-query";
import { UnauthorizedError } from "../utils/api";

// Blindspot fix: previously only ProtectedRoute checked login, at mount time.
// If the session cookie expired while a tab stayed open, later API calls just
// threw "unauthorized" inline with no redirect. Any query failing with
// UnauthorizedError now runs this handler (wired to `navigate("/login")` in
// AuthErrorHandler, see App.tsx) so an expired session always bounces to /login.
let onUnauthorized: (() => void) | null = null;
export function setUnauthorizedHandler(fn: (() => void) | null) {
  onUnauthorized = fn;
}

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000, // matches the old hand-rolled cache TTL
      retry: false,
    },
  },
  queryCache: new QueryCache({
    onError: (error) => {
      if (error instanceof UnauthorizedError) {
        onUnauthorized?.();
      }
    },
  }),
});
