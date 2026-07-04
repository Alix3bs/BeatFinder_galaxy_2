export type RateLimiterOptions = {
  limit: number;
  windowMs: number;
  now?: () => number;
};

type WindowState = {
  windowStart: number;
  count: number;
};

/**
 * Fixed-window per-key rate limiter for expensive endpoints. In-memory and
 * per-instance by design: it bounds abuse of audio processing on a single
 * container; platform-level limits should back it up for fleets.
 */
export class FixedWindowRateLimiter {
  private readonly limit: number;
  private readonly windowMs: number;
  private readonly now: () => number;
  private readonly windows = new Map<string, WindowState>();

  constructor(options: RateLimiterOptions) {
    this.limit = options.limit;
    this.windowMs = options.windowMs;
    this.now = options.now ?? Date.now;
  }

  allow(key: string): boolean {
    if (this.limit <= 0) {
      return true;
    }
    const timestamp = this.now();
    const state = this.windows.get(key);
    if (!state || timestamp - state.windowStart >= this.windowMs) {
      this.windows.set(key, { windowStart: timestamp, count: 1 });
      this.pruneExpired(timestamp);
      return true;
    }
    if (state.count >= this.limit) {
      return false;
    }
    state.count += 1;
    return true;
  }

  private pruneExpired(timestamp: number): void {
    if (this.windows.size < 10_000) {
      return;
    }
    for (const [key, state] of this.windows) {
      if (timestamp - state.windowStart >= this.windowMs) {
        this.windows.delete(key);
      }
    }
  }
}

export function clientKeyFromHeaders(
  remoteAddress: string | undefined,
  forwardedFor: string | undefined,
): string {
  // Behind a trusted proxy/load balancer the socket address is the proxy;
  // the first X-Forwarded-For hop identifies the client. A direct client
  // could spoof the header, so the socket address is always appended.
  const forwarded = String(forwardedFor || "").split(",")[0].trim();
  const socketAddress = String(remoteAddress || "unknown");
  return forwarded ? `${forwarded}|${socketAddress}` : socketAddress;
}
