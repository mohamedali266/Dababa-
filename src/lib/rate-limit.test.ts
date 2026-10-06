import { describe, expect, it } from "vitest";
import { memoryRateLimiter } from "./rate-limit";

describe("memoryRateLimiter", () => {
  it("blocks after the configured limit", async () => {
    const key = `test-${crypto.randomUUID()}`;
    expect((await memoryRateLimiter.check(key, 1, 1000)).allowed).toBe(true);
    expect((await memoryRateLimiter.check(key, 1, 1000)).allowed).toBe(false);
  });
});
