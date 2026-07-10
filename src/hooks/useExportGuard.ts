import { useState } from "react";
import { useAuth } from "./useAuth";

/** Guards export actions (xlsx/csv/json/pdf) behind login. Not a security
 * boundary by itself — the underlying data is already masked to null
 * server-side for unauthenticated requests (see shared/masking.py), so
 * this only prevents downloading a file full of empty/zeroed values,
 * which serves no one. The real protection lives in the API responses.
 *
 * `loading` mirrors useAuth's — while the auth check is in flight,
 * `loggedIn` defaults to false, so callers that need to avoid a false
 * "not logged in" flash before the check resolves should gate on it. */
export function useExportGuard() {
  const { loading, loggedIn } = useAuth();
  const [dialogOpen, setDialogOpen] = useState(false);

  function guard(run: () => void) {
    if (!loggedIn) {
      setDialogOpen(true);
      return;
    }
    run();
  }

  return { guard, dialogOpen, setDialogOpen, loading };
}
