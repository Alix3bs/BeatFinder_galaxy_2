/* ============================================================
   Payment-provider adapter. One interface, three backends:

   · lumino — PRIMARY. Adapter is ready but generic: endpoint
     paths, auth header and webhook signature scheme are driven
     by env vars because Lumino's merchant API docs/credentials
     are not yet on hand. Nothing is simulated: without
     credentials it reports "not configured" and the UI falls
     back to manual methods. See docs/LUMINO-INTEGRATION.md.
   · stripe — kept from Phase 4, OFF unless an admin enables it
     in Settings AND keys exist in env.
   · mock — staging/tests only (never in production): a local
     hosted-checkout page + signed webhooks so the full
     hold → popup → webhook → booking pipeline is testable.

   Credentials live ONLY in env. Card/bank data never touches
   this server on any adapter.
   ============================================================ */
const crypto = require("node:crypto");
const { db } = require("./db");
const legacyStripe = require("./stripe");

const CATEGORIES = ["reservation-payment", "rental-payment", "security-deposit", "remaining-balance",
  "delivery-fee", "chauffeur-service", "premium-addons", "mileage-charge", "fuel-charge",
  "cleaning-charge", "damage-charge", "toll-ticket-reimbursement", "refund"];
const POST_RENTAL = ["mileage-charge", "fuel-charge", "cleaning-charge", "damage-charge", "toll-ticket-reimbursement"];

const S = k => db.prepare("SELECT value FROM settings WHERE key=?").get(k)?.value || "";
const baseUrl = () => process.env.TN_BASE_URL || "http://localhost:" + (process.env.PORT || 8902);

/* ---------------- lumino ---------------- */
const lumino = {
  name: "lumino",
  configured: () => !!(process.env.LUMINO_API_KEY && process.env.LUMINO_API_BASE),
  /* authorization-and-capture deposits stay OFF until Lumino confirms
     support in writing for this merchant account — never simulated */
  supports: () => ({ card: true, ach: process.env.LUMINO_SUPPORTS_ACH === "1",
    bnpl: process.env.LUMINO_SUPPORTS_BNPL === "1", link: true, invoice: true,
    authorization: process.env.LUMINO_SUPPORTS_AUTH_CAPTURE === "1", refunds: true }),
  async request(pathname, body) {
    const res = await fetch(process.env.LUMINO_API_BASE.replace(/\/$/, "") + pathname, {
      method: "POST",
      headers: {
        [process.env.LUMINO_AUTH_HEADER || "Authorization"]:
          (process.env.LUMINO_AUTH_PREFIX || "Bearer ") + process.env.LUMINO_API_KEY,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(15000)
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.message || data.error || "Lumino error " + res.status);
    return data;
  },
  async createCheckout({ requestId, category, amount, description, customerEmail }) {
    const d = await this.request(process.env.LUMINO_CHECKOUT_PATH || "/v1/checkout-sessions", {
      amount: Math.round(amount * 100), currency: "usd", description,
      customer_email: customerEmail, metadata: { requestId, category },
      success_url: `${baseUrl()}/track.html?id=${requestId}&paid=1`,
      cancel_url: `${baseUrl()}/track.html?id=${requestId}`
    });
    return { url: d.url || d.checkout_url || d.payment_url, ref: d.id || d.session_id };
  },
  async createInvoice(args) {
    const d = await this.request(process.env.LUMINO_INVOICE_PATH || "/v1/invoices", {
      amount: Math.round(args.amount * 100), currency: "usd",
      description: args.description, customer_email: args.customerEmail,
      metadata: { requestId: args.requestId, category: args.category }
    });
    return { url: d.url || d.invoice_url, ref: d.id };
  },
  async status(ref) {
    const d = await this.request((process.env.LUMINO_STATUS_PATH || "/v1/payments/") + ref, {});
    return d.status;
  },
  async refund({ ref, amount }) {
    const d = await this.request(process.env.LUMINO_REFUND_PATH || "/v1/refunds", {
      payment: ref, amount: Math.round(amount * 100) });
    return { ref: d.id, status: d.status || "pending" };
  },
  /* HMAC-SHA256 of raw body, hex, in LUMINO_SIGNATURE_HEADER — adjust via env
     once Lumino's docs specify their exact scheme */
  verifyWebhook(rawBody, headers) {
    const secret = process.env.LUMINO_WEBHOOK_SECRET;
    if (!secret) return false;
    const given = headers[(process.env.LUMINO_SIGNATURE_HEADER || "x-lumino-signature").toLowerCase()] || "";
    const want = crypto.createHmac("sha256", secret).update(rawBody).digest("hex");
    const a = Buffer.from(want), b = Buffer.from(String(given).padEnd(want.length, "0").slice(0, want.length));
    return a.length === b.length && crypto.timingSafeEqual(a, b);
  },
  parseEvent(body) {
    return { eventId: body.id || body.event_id, type: body.type || body.event,
      requestId: body.data?.metadata?.requestId || body.metadata?.requestId,
      category: body.data?.metadata?.category || body.metadata?.category || "rental-payment",
      amount: (body.data?.amount ?? body.amount ?? 0) / 100,
      ref: body.data?.payment_id || body.data?.id || body.payment_id,
      succeeded: /succeeded|paid|completed|success/i.test(body.type || body.event || ""),
      failed: /failed|canceled|cancelled|expired/i.test(body.type || body.event || "") };
  }
};

/* ---------------- mock (staging/tests only) ---------------- */
const MOCK_SECRET = () => process.env.MOCK_PAY_SECRET || "mock-pay-secret";
const mock = {
  name: "mock",
  configured: () => (process.env.TN_ENV || "staging") !== "production",
  supports: () => ({ card: true, ach: true, bnpl: true, link: true, invoice: true, authorization: false, refunds: true }),
  async createCheckout({ requestId, category, amount }) {
    const token = crypto.randomBytes(8).toString("hex");
    return { url: `${baseUrl()}/api/payments/mock-checkout?token=${token}&requestId=${requestId}&category=${category}&amount=${amount}`, ref: "mockpay_" + token };
  },
  async createInvoice(args) { return this.createCheckout(args); },
  async status() { return "pending"; },
  async refund({ ref }) { return { ref: "mockref_" + ref, status: "refunded" }; },
  verifyWebhook(rawBody, headers) {
    const want = crypto.createHmac("sha256", MOCK_SECRET()).update(rawBody).digest("hex");
    const given = String(headers["x-mock-signature"] || "");
    return given.length === want.length && crypto.timingSafeEqual(Buffer.from(want), Buffer.from(given));
  },
  signBody(rawBody) { return crypto.createHmac("sha256", MOCK_SECRET()).update(rawBody).digest("hex"); },
  parseEvent(body) {
    return { eventId: body.id, type: body.type, requestId: body.metadata?.requestId,
      category: body.metadata?.category || "rental-payment", amount: body.amount,
      ref: body.payment_id, succeeded: body.type === "payment.succeeded", failed: /failed|canceled/.test(body.type) };
  }
};

/* ---------------- stripe (optional, admin-enabled) ---------------- */
const stripeAdapter = {
  name: "stripe",
  configured: () => S("stripe_enabled") === "1" && legacyStripe.configured(),
  supports: () => ({ card: true, ach: false, bnpl: false, link: true, invoice: false, authorization: true, refunds: true }),
  async createCheckout(args) {
    const out = await legacyStripe.createCheckout(args);
    return { url: out.url, ref: out.sessionId };
  },
  async createInvoice() { throw new Error("Invoices not enabled on the Stripe adapter"); },
  async status() { return "pending"; },
  async refund() { throw new Error("Record Stripe refunds from the Stripe dashboard, then log them here manually"); },
  verifyWebhook(rawBody, headers) { return legacyStripe.verifySignature(rawBody, headers["stripe-signature"]); },
  parseEvent(body) {
    const s = body.data?.object || {};
    return { eventId: body.id, type: body.type, requestId: s.metadata?.requestId,
      category: s.metadata?.category || "rental-payment", amount: (s.amount_total || 0) / 100,
      ref: s.payment_intent || s.id, succeeded: body.type === "checkout.session.completed",
      failed: /expired|failed/.test(body.type || "") };
  }
};

const ADAPTERS = { lumino, mock, stripe: stripeAdapter };

/* active adapter: the configured preference, else mock outside production */
function active() {
  const pref = S("payment_provider") || "lumino";
  const a = ADAPTERS[pref];
  if (a && a.configured()) return a;
  if (pref !== "stripe" && stripeAdapter.configured()) return stripeAdapter;
  if (mock.configured()) return mock;
  return null; // production with no provider → manual methods only
}

function health() {
  return {
    active: active()?.name || "none (manual methods only)",
    lumino: { configured: lumino.configured(), webhookSecret: !!process.env.LUMINO_WEBHOOK_SECRET,
      apiBase: process.env.LUMINO_API_BASE ? "set" : "missing" },
    stripe: { enabledInSettings: S("stripe_enabled") === "1", keys: legacyStripe.configured() },
    mock: { available: mock.configured() }
  };
}

/* idempotency across all providers */
function seenEvent(provider, eventId, type, requestId) {
  try {
    db.prepare("INSERT INTO payment_events (provider, event_id, type, request_id) VALUES (?,?,?,?)")
      .run(provider, String(eventId), type || "", requestId || null);
    return false;
  } catch (e) { return true; }
}

/* payment methods the customer may see (settings ∩ provider support) */
function enabledMethods() {
  const a = active();
  const sup = a ? a.supports() : {};
  const online = [];
  if (a) {
    if (S("methods_card") === "1" && sup.card) online.push({ id: "card", label: "Credit / debit card", kind: "online" });
    if (S("methods_ach") === "1" && sup.ach) online.push({ id: "ach", label: "Bank / ACH payment", kind: "online" });
    if (S("methods_bnpl") === "1" && sup.bnpl) online.push({ id: "bnpl", label: "Payment plan (BNPL)", kind: "online" });
    if (S("methods_link") === "1" && sup.link) online.push({ id: "link", label: "Secure payment link", kind: "online" });
    if (S("methods_invoice") === "1" && sup.invoice) online.push({ id: "invoice", label: "Emailed invoice", kind: "online" });
  }
  const manual = [];
  if (S("methods_bank") === "1") manual.push({ id: "bank", label: "Manual bank transfer", kind: "manual" });
  if (S("methods_zelle") === "1") manual.push({ id: "zelle", label: "Zelle", kind: "manual" });
  if (S("methods_cash") === "1") manual.push({ id: "cash", label: "Cash", kind: "manual" });
  if (S("methods_other") === "1") manual.push({ id: "other", label: "Other approved method", kind: "manual" });
  return { providerName: a ? a.name : null, online, manual };
}

module.exports = { CATEGORIES, POST_RENTAL, ADAPTERS, active, health, seenEvent, enabledMethods, mock };
