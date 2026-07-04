import assert from "node:assert/strict";
import { test } from "node:test";

import { FixedWindowRateLimiter, clientKeyFromHeaders } from "./rate_limit.ts";

test("allows requests under the limit", () => {
  const limiter = new FixedWindowRateLimiter({ limit: 3, windowMs: 60_000, now: () => 1_000 });
  assert.equal(limiter.allow("a"), true);
  assert.equal(limiter.allow("a"), true);
  assert.equal(limiter.allow("a"), true);
});

test("blocks requests over the limit within the window", () => {
  const limiter = new FixedWindowRateLimiter({ limit: 2, windowMs: 60_000, now: () => 1_000 });
  limiter.allow("a");
  limiter.allow("a");
  assert.equal(limiter.allow("a"), false);
});

test("keys are independent", () => {
  const limiter = new FixedWindowRateLimiter({ limit: 1, windowMs: 60_000, now: () => 1_000 });
  assert.equal(limiter.allow("a"), true);
  assert.equal(limiter.allow("b"), true);
  assert.equal(limiter.allow("a"), false);
});

test("window resets after it elapses", () => {
  let clock = 0;
  const limiter = new FixedWindowRateLimiter({ limit: 1, windowMs: 1_000, now: () => clock });
  assert.equal(limiter.allow("a"), true);
  assert.equal(limiter.allow("a"), false);
  clock = 1_500;
  assert.equal(limiter.allow("a"), true);
});

test("zero limit disables limiting", () => {
  const limiter = new FixedWindowRateLimiter({ limit: 0, windowMs: 1_000, now: () => 0 });
  for (let index = 0; index < 100; index += 1) {
    assert.equal(limiter.allow("a"), true);
  }
});

test("client key prefers forwarded-for but keeps socket address", () => {
  assert.equal(clientKeyFromHeaders("10.0.0.1", undefined), "10.0.0.1");
  assert.equal(clientKeyFromHeaders("10.0.0.1", "203.0.113.9, 172.16.0.1"), "203.0.113.9|10.0.0.1");
  assert.equal(clientKeyFromHeaders(undefined, undefined), "unknown");
});
