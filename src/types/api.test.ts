import { describe, expect, it } from "vitest";
import { SettingsFormSchema } from "./api";

const validValues = {
  default_expense_source: "1120",
  default_income_dest: "1110",
  kas_kecil_source: "1120",
  savings_account: "1130",
  kas_kecil_target: "500000",
  bi_fast_fee: "2500",
};

describe("SettingsFormSchema", () => {
  it("accepts valid values and coerces numeric strings to numbers", () => {
    const parsed = SettingsFormSchema.safeParse(validValues);
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.kas_kecil_target).toBe(500000);
      expect(parsed.data.bi_fast_fee).toBe(2500);
    }
  });

  it("rejects an empty required account select", () => {
    const parsed = SettingsFormSchema.safeParse({ ...validValues, default_expense_source: "" });
    expect(parsed.success).toBe(false);
  });

  it("rejects a negative number field", () => {
    const parsed = SettingsFormSchema.safeParse({ ...validValues, bi_fast_fee: "-100" });
    expect(parsed.success).toBe(false);
  });

  it("rejects a non-numeric number field", () => {
    const parsed = SettingsFormSchema.safeParse({ ...validValues, kas_kecil_target: "abc" });
    expect(parsed.success).toBe(false);
  });
});
