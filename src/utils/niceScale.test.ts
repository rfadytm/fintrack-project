import { describe, expect, it } from "vitest";
import { formatChartAxis, niceCeiling } from "./niceScale";

describe("niceCeiling", () => {
  it("rounds a ~800rb peak up to 1jt with headroom", () => {
    expect(niceCeiling(800_000)).toBe(1_000_000);
  });

  it("rounds a ~600rb peak up to 1jt with headroom", () => {
    expect(niceCeiling(600_000)).toBe(1_000_000);
  });

  it("keeps the ceiling above a mid-month spike to 3jt", () => {
    expect(niceCeiling(3_000_000)).toBe(5_000_000);
  });

  it("never returns exactly the peak — always leaves headroom", () => {
    expect(niceCeiling(250_000)).toBeGreaterThan(250_000);
    expect(niceCeiling(1_000_000)).toBeGreaterThan(1_000_000);
    expect(niceCeiling(2_500_000)).toBeGreaterThan(2_500_000);
  });

  it("falls back to a sane default for zero/negative/non-finite input", () => {
    expect(niceCeiling(0)).toBe(100_000);
    expect(niceCeiling(-500)).toBe(100_000);
    expect(niceCeiling(NaN)).toBe(100_000);
  });

  it("scales down for small peaks too", () => {
    expect(niceCeiling(50)).toBe(100);
  });
});

describe("formatChartAxis", () => {
  it("keeps values under 1jt in rb", () => {
    expect(formatChartAxis(500_000)).toBe("500rb");
    expect(formatChartAxis(0)).toBe("0rb");
  });

  it("switches to 'juta' at 1jt and above, dropping trailing .0", () => {
    expect(formatChartAxis(1_000_000)).toBe("1 juta");
    expect(formatChartAxis(2_000_000)).toBe("2 juta");
  });

  it("uses a comma decimal for fractional millions", () => {
    expect(formatChartAxis(1_500_000)).toBe("1,5 juta");
  });
});
