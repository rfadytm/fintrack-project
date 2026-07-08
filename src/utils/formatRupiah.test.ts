import { describe, expect, it } from "vitest";
import { formatNumber, formatRupiah } from "./formatRupiah";

describe("formatRupiah", () => {
  it("formats a positive amount", () => {
    expect(formatRupiah(50000)).toBe("Rp 50.000");
  });

  it("treats null/undefined as zero", () => {
    expect(formatRupiah(null)).toBe("Rp 0");
    expect(formatRupiah(undefined)).toBe("Rp 0");
  });

  it("puts the minus sign before Rp for negative amounts", () => {
    expect(formatRupiah(-50000)).toBe("-Rp 50.000");
  });
});

describe("formatNumber", () => {
  it("formats with id-ID thousands separators", () => {
    expect(formatNumber(1234567)).toBe("1.234.567");
  });

  it("treats null/undefined as zero", () => {
    expect(formatNumber(null)).toBe("0");
  });
});
