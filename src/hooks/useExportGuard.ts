import { useState } from "react";
import { useAuth } from "./useAuth";

/** Guards export actions (xlsx/csv/json/pdf) behind login. Not a security
 * boundary by itself — the underlying data is already masked to null
 * server-side for unauthenticated requests (see shared/masking.py), so
 * this only prevents downloading a file full of empty/zeroed values,
 * which serves no one. The real protection lives in the API responses.
 *
 * `guard` no-ops while useAuth's check is still in flight (`loggedIn`
 * defaults to false during that window) instead of showing the "owner
 * only" dialog — otherwise a genuinely logged-in owner who clicks export
 * right after page load briefly sees a false "not logged in" dialog. This
 * used to be the caller's responsibility (gate on the returned `loading`);
 * moved inside `guard` itself after an audit found none of the three call
 * sites actually did it. `loading` is still exposed in case a caller wants
 * to disable the export button visually during that window. */
export function useExportGuard() {
  const { loading, loggedIn } = useAuth();
  const [dialogOpen, setDialogOpen] = useState(false);

  function guard(run: () => void) {
    if (loading) return;
    if (!loggedIn) {
      setDialogOpen(true);
      return;
    }
    run();
  }

  return { guard, dialogOpen, setDialogOpen, loading };
}
