/* Stripe integration via hosted Checkout — card details never touch
   this server. Only ids/status/amount/currency/timestamps are stored.
   Zero-dependency: raw HTTPS calls + manual webhook signature check. */
const crypto = require("node:crypto");
const { db } = require("./db");

const CATEGORIES = [
  "booking-deposit", "rental-payment", "security-deposit", "remaining-balance",
  "addons", "damage-charge", "mileage-charge", "toll-ticket-reimbursement"
];
/* post-rental charges need documented authorization + admin review */
const POST_RENTAL = ["damage-charge", "mileage-charge", "toll-ticket-reimbursement"];

const configured = () => !!process.env.STRIPE_SECRET_KEY;

async function createCheckout({ requestId, category, amount, description, customerEmail, mode }) {
  if (!configured()) throw new Error("Stripe is not configured (STRIPE_SECRET_KEY missing)");
  if (!CATEGORIES.includes(category)) throw new Error("Unknown payment category");
  const params = new URLSearchParams({
    mode: mode || "payment",
    "line_items[0][quantity]": "1",
    "line_items[0][price_data][currency]": "usd",
    "line_items[0][price_data][unit_amount]": String(Math.round(amount * 100)),
    "line_items[0][price_data][product_data][name]": description || `TopNotchRentalz — ${category}`,
    success_url: (process.env.TN_BASE_URL || "http://localhost:8902") + "/track.html?id=" + requestId + "&paid=1",
    cancel_url: (process.env.TN_BASE_URL || "http://localhost:8902") + "/track.html?id=" + requestId,
    customer_email: customerEmail || "",
    "metadata[requestId]": requestId,
    "metadata[category]": category
  });
  if (category === "security-deposit") {
    /* authorization-style hold: manual capture */
    params.set("payment_intent_data[capture_method]", "manual");
  }
  const res = await fetch("https://api.stripe.com/v1/checkout/sessions", {
    method: "POST",
    headers: {
      Authorization: "Bearer " + process.env.STRIPE_SECRET_KEY,
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: params.toString(),
    signal: AbortSignal.timeout(15000)
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error?.message || "Stripe error " + res.status);
  return { url: data.url, sessionId: data.id };
}

/* Stripe-Signature: t=...,v1=hmacSHA256(`${t}.${payload}`, endpointSecret) */
function verifySignature(rawBody, sigHeader) {
  const secret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!secret) return false;
  const parts = Object.fromEntries((sigHeader || "").split(",").map(kv => kv.split("=")));
  if (!parts.t || !parts.v1) return false;
  if (Math.abs(Date.now() / 1000 - Number(parts.t)) > 300) return false; // 5-min tolerance
  const expected = crypto.createHmac("sha256", secret).update(`${parts.t}.${rawBody}`).digest("hex");
  const a = Buffer.from(expected), b = Buffer.from(parts.v1);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/* idempotency: each Stripe event id is processed exactly once */
function seenEvent(eventId, type, requestId) {
  try {
    db.prepare("INSERT INTO stripe_events (event_id, type, request_id, status) VALUES (?,?,?, 'processed')")
      .run(eventId, type, requestId || null);
    return false;
  } catch (e) { return true; } // PK collision → duplicate delivery
}

module.exports = { CATEGORIES, POST_RENTAL, configured, createCheckout, verifySignature, seenEvent };
