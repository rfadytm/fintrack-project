import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import CategoryChart from "./CategoryChart";

describe("CategoryChart", () => {
  it("shows an empty-state message when there is no data", () => {
    render(<CategoryChart data={[]} />);
    expect(screen.getByText("Tidak ada data beban.")).toBeInTheDocument();
  });
});
