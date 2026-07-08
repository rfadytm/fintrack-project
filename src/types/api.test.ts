import { describe, expect, it } from "vitest";
import { SettingsFormSchema, BudgetFormSchema, GoalFormSchema, BillFormSchema, RecurringFormSchema } from "./api";

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

describe("BudgetFormSchema", () => {
  it("accepts a valid budget", () => {
    const parsed = BudgetFormSchema.safeParse({ account_code: "5130", monthly_limit: "500000" });
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data.monthly_limit).toBe(500000);
  });

  it("rejects a zero/negative limit", () => {
    expect(BudgetFormSchema.safeParse({ account_code: "5130", monthly_limit: "0" }).success).toBe(false);
    expect(BudgetFormSchema.safeParse({ account_code: "5130", monthly_limit: "-1" }).success).toBe(false);
  });

  it("rejects a missing account_code", () => {
    expect(BudgetFormSchema.safeParse({ account_code: "", monthly_limit: "500000" }).success).toBe(false);
  });
});

describe("GoalFormSchema", () => {
  const valid = { name: "Laptop baru", target_amount: "10000000", account_code: "1130" };

  it("accepts a valid goal", () => {
    expect(GoalFormSchema.safeParse(valid).success).toBe(true);
  });

  it("rejects an empty name", () => {
    expect(GoalFormSchema.safeParse({ ...valid, name: "" }).success).toBe(false);
  });

  it("rejects a non-positive target", () => {
    expect(GoalFormSchema.safeParse({ ...valid, target_amount: "0" }).success).toBe(false);
  });
});

describe("BillFormSchema", () => {
  const valid = { name: "Listrik PLN", amount: "250000", due_day: "20" };

  it("accepts a valid bill", () => {
    const parsed = BillFormSchema.safeParse(valid);
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data.due_day).toBe(20);
  });

  it("rejects due_day out of 1-31 range", () => {
    expect(BillFormSchema.safeParse({ ...valid, due_day: "0" }).success).toBe(false);
    expect(BillFormSchema.safeParse({ ...valid, due_day: "32" }).success).toBe(false);
  });
});

describe("RecurringFormSchema", () => {
  const valid = {
    description: "Langganan Netflix",
    account_code: "5130",
    source: "1130",
    amount: "54000",
    frequency: "monthly",
  };

  it("accepts a valid recurring transaction", () => {
    expect(RecurringFormSchema.safeParse(valid).success).toBe(true);
  });

  it("rejects an invalid frequency", () => {
    expect(RecurringFormSchema.safeParse({ ...valid, frequency: "yearly" }).success).toBe(false);
  });

  it("rejects a missing source account", () => {
    expect(RecurringFormSchema.safeParse({ ...valid, source: "" }).success).toBe(false);
  });
});
