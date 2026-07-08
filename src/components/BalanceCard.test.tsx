import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import BalanceCard from "./BalanceCard";

describe("BalanceCard", () => {
  it("renders the account name and formatted balance", () => {
    render(<BalanceCard name="Kas Kecil" balance={125000} type="aset" />);
    expect(screen.getByText("Kas Kecil")).toBeInTheDocument();
    expect(screen.getByText("Rp 125.000")).toBeInTheDocument();
  });
});
