import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import TransactionTable from "./TransactionTable";
import type { Transaction } from "../types/api";

describe("TransactionTable", () => {
  it("shows an empty-state message when there are no transactions", () => {
    render(<TransactionTable transactions={[]} />);
    expect(screen.getByText("Belum ada transaksi.")).toBeInTheDocument();
  });

  it("renders a row with the summed debit total and status badge", () => {
    const tx: Transaction[] = [
      {
        doc_number: "KK-0001",
        transaction_date: "2026-07-01",
        doc_type: "KK",
        description: "Belanja",
        status: "POSTED",
        journal_lines: [
          { account_code: "5130", debit_amount: 30000, credit_amount: null },
          { account_code: "1120", debit_amount: null, credit_amount: 30000 },
        ],
      },
    ];
    render(<TransactionTable transactions={tx} />);
    expect(screen.getByText("KK-0001")).toBeInTheDocument();
    expect(screen.getByText("Rp 30.000")).toBeInTheDocument();
    expect(screen.getByText("POSTED")).toBeInTheDocument();
  });

  it("marks a REVERSED transaction visually", () => {
    const tx: Transaction[] = [
      {
        doc_number: "KK-0002",
        transaction_date: "2026-07-02",
        doc_type: "KK",
        description: null,
        status: "REVERSED",
        journal_lines: [],
      },
    ];
    render(<TransactionTable transactions={tx} />);
    const row = screen.getByText("KK-0002").closest("tr");
    expect(row).toHaveClass("line-through");
  });
});
