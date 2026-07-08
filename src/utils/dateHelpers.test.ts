import { describe, expect, it } from "vitest";
import { formatTanggal, namaBulan } from "./dateHelpers";

describe("namaBulan", () => {
  it("maps 1-12 to Indonesian month names", () => {
    expect(namaBulan(1)).toBe("Januari");
    expect(namaBulan(12)).toBe("Desember");
  });

  it("returns empty string for out-of-range months", () => {
    expect(namaBulan(0)).toBe("");
    expect(namaBulan(13)).toBe("");
  });
});

describe("formatTanggal", () => {
  it("formats an ISO date string", () => {
    expect(formatTanggal("2026-07-08")).toBe("8 Jul 2026");
  });

  it("returns a dash for missing input", () => {
    expect(formatTanggal(null)).toBe("-");
    expect(formatTanggal(undefined)).toBe("-");
  });
});
