export type RateLimitResult = {
  allowed: boolean;
  limit: number;
  remaining: number;
  resetAt: Date;
};

export interface RateLimiter {
  check(key: string, limit: number, windowMs: number): Promise<RateLimitResult>;
}

const buckets = new Map<string, { count: number; resetAt: number }>();

export const memoryRateLimiter: RateLimiter = {
  async check(key, limit, windowMs) {
    const now = Date.now();
    const bucket = buckets.get(key);

    if (!bucket || bucket.resetAt <= now) {
      const resetAt = now + windowMs;
      buckets.set(key, { count: 1, resetAt });
      return { allowed: true, limit, remaining: limit - 1, resetAt: new Date(resetAt) };
    }

    bucket.count += 1;
    return {
      allowed: bucket.count <= limit,
      limit,
      remaining: Math.max(0, limit - bucket.count),
      resetAt: new Date(bucket.resetAt),
    };
  },
};
