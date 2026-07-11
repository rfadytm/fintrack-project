import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import CategoryChart from "./CategoryChart";

describe("CategoryChart", () => {
  it("shows an empty-state message when there is no data", () => {
    render(<CategoryChart data={[]} />);
    expect(screen.getByText("Tidak ada data beban.")).toBeInTheDocument();
  });

  it("renders a sorted list of categories with formatted amounts", () => {
    render(
      <CategoryChart
        data={[
          { account_name: "Makan Harian", amount: 100_000 },
          { account_name: "Kiriman ke Keluarga", amount: 500_000 },
        ]}
      />
    );
    const items = screen.getAllByText(/Makan Harian|Kiriman ke Keluarga/);
    // Blindspot fix regression guard: list is sorted biggest-first.
    expect(items[0]).toHaveTextContent("Kiriman ke Keluarga");
    expect(screen.getByText("Rp 500.000")).toBeInTheDocument();
    expect(screen.getByText("Rp 100.000")).toBeInTheDocument();
  });
});
