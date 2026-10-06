import { describe, expect, it } from "vitest";
import { formatDate, formatNumber } from "./format";

describe("locale format helpers", () => {
  it("uses Latin digits for Arabic numbers", () => {
    expect(formatNumber("ar", 12345)).toContain("12");
  });

  it("formats dates in the Cairo timezone", () => {
    expect(formatDate("en", "2026-10-06T21:30:00.000Z")).toContain("2026");
  });
});
