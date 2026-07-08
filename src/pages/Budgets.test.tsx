import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import Budgets from "./Budgets";

function renderWithClient() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <Budgets />
    </QueryClientProvider>
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("Budgets page", () => {
  it("shows the empty-state message when there are no budgets yet", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockImplementation((url: string) => {
        const body = url.includes("/budgets") ? { budgets: [] } : { accounts: [] };
        return Promise.resolve({ status: 200, ok: true, json: async () => body });
      })
    );
    renderWithClient();
    await waitFor(() => expect(screen.getByText("Belum ada budget.")).toBeInTheDocument());
  });
});
