import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { renderHook, waitFor, act } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { ReactNode } from "react";
import { useExportGuard } from "./useExportGuard";

function wrapper({ children }: { children: ReactNode }) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("useExportGuard", () => {
  it("runs the export directly when logged in, dialog stays closed", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ status: 200, ok: true, json: async () => ({ logged_in: true }) })
    );
    const { result } = renderHook(() => useExportGuard(), { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));

    const run = vi.fn();
    act(() => result.current.guard(run));

    expect(run).toHaveBeenCalledOnce();
    expect(result.current.dialogOpen).toBe(false);
  });

  it("no-ops while the auth check is still in flight, does not flash the owner-only dialog", async () => {
    let resolveFetch!: (value: unknown) => void;
    const pending = new Promise((resolve) => {
      resolveFetch = resolve;
    });
    vi.stubGlobal("fetch", vi.fn().mockReturnValue(pending));
    const { result } = renderHook(() => useExportGuard(), { wrapper });

    expect(result.current.loading).toBe(true);
    const run = vi.fn();
    act(() => result.current.guard(run));

    expect(run).not.toHaveBeenCalled();
    expect(result.current.dialogOpen).toBe(false);

    act(() => resolveFetch({ status: 200, ok: true, json: async () => ({ logged_in: true }) }));
    await waitFor(() => expect(result.current.loading).toBe(false));
  });

  it("blocks the export and opens the dialog when not logged in", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue({ status: 200, ok: true, json: async () => ({ logged_in: false }) })
    );
    const { result } = renderHook(() => useExportGuard(), { wrapper });
    await waitFor(() => expect(result.current.loading).toBe(false));

    const run = vi.fn();
    act(() => result.current.guard(run));

    expect(run).not.toHaveBeenCalled();
    expect(result.current.dialogOpen).toBe(true);
  });
});
