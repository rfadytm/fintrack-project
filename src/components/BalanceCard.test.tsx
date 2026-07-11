import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import BalanceCard from "./BalanceCard";

describe("BalanceCard", () => {
  it("renders the account name and formatted balance", () => {
    render(<BalanceCard name="Kas Kecil" balance={125000} type="aset" />);
    expect(screen.getByText("Kas Kecil")).toBeInTheDocument();
    expect(screen.getByText("Rp 125.000")).toBeInTheDocument();
  });

  it("blurs the balance when privacy mode is on, without hiding the account name", () => {
    render(<BalanceCard name="Kas Kecil" balance={125000} type="aset" masked />);
    expect(screen.getByText("Kas Kecil")).toBeInTheDocument();
    // AnimatedNumber renders the text in its own inner <span>; the blur class
    // lives on the wrapping div (CSS filter applies to the whole subtree either way).
    expect(screen.getByText("Rp 125.000").closest("div")).toHaveClass("blur-md");
  });
});
