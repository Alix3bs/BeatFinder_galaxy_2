/* Branded customer + internal emails. Delivery order of preference:
   1) RESEND_API_KEY (from-address: bookings@topnotchrentalz.com once
      the domain is verified in Resend)
   2) NOTIFY_EMAIL_WEBHOOK_URL (Power Automate "Send an email" flow)
   3) recorded in the notifications table (nothing is lost)
   Sensitive data policy: emails never include license/insurance
   documents or payment details — only status + a tracking link. */
const { db } = require("./db");

const ORANGE = "#ff6a00";
function shell(title, body, settings) {
  const s = settings || {};
  return `<!DOCTYPE html><html><body style="margin:0;background:#0a0a0a;font-family:Arial,Helvetica,sans-serif;color:#f2f2f2">
  <div style="max-width:560px;margin:0 auto;padding:32px 20px">
    <div style="border-bottom:2px solid ${ORANGE};padding-bottom:14px;margin-bottom:22px">
      <span style="font-size:20px;font-weight:900;letter-spacing:2px">TOPNOTCH<span style="color:${ORANGE}">RENTALZ</span></span>
    </div>
    <h1 style="font-size:19px;color:${ORANGE};margin:0 0 14px">${title}</h1>
    <div style="font-size:14px;line-height:1.7;color:#d9d9d9">${body}</div>
    <div style="margin-top:28px;padding-top:14px;border-top:1px solid #262626;font-size:11px;color:#8a8a8a">
      ${s.business_name || "TopNotchRentalz"} · ${s.city || "Miami, FL"} · ${s.phone || ""}<br>
      Questions? Reply to this email or WhatsApp us. Submitting a request does not guarantee availability or approval.
    </div>
  </div></body></html>`;
}
const btn = (url, label) => `<p style="margin:20px 0"><a href="${url}" style="background:${ORANGE};color:#000;text-decoration:none;font-weight:800;padding:12px 26px;border-radius:999px">${label}</a></p>`;

/* customer-facing templates keyed by event */
const TEMPLATES = {
  REQUEST_RECEIVED: (d, s) => [`Request received — ${d.requestId}`,
    shell("We got your request", `Hi ${d.firstName},<br><br>Your request for the <b>${d.vehicle}</b> (${d.dates}) is in.
    Our team is checking real-time availability with the provider now — nothing is charged at this stage.
    ${btn(d.trackUrl, "Track your request")}Request number: <b>${d.requestId}</b>`, s)],
  AVAILABILITY_CHECK: (d, s) => [`Checking availability — ${d.requestId}`,
    shell("Availability being confirmed", `Hi ${d.firstName},<br><br>We're confirming the <b>${d.vehicle}</b> with the provider for ${d.dates}. Expect an update shortly.${btn(d.trackUrl, "Track your request")}`, s)],
  VEHICLE_UNAVAILABLE: (d, s) => [`Update on your request — ${d.requestId}`,
    shell("That vehicle is unavailable", `Hi ${d.firstName},<br><br>The <b>${d.vehicle}</b> isn't available for ${d.dates}. Our team is lining up comparable options and will text you.${btn(d.trackUrl, "See status")}`, s)],
  ALTERNATIVE_OFFERED: (d, s) => [`A comparable option — ${d.requestId}`,
    shell("We found you an alternative", `Hi ${d.firstName},<br><br>We can offer the <b>${d.altVehicle}</b> for your dates instead. Check your tracking page or reply to talk it through.${btn(d.trackUrl, "View option")}`, s)],
  QUOTE_ISSUED: (d, s) => [`Your official quote — ${d.requestId}`,
    shell("Your quote is ready", `Hi ${d.firstName},<br><br>Your official quote for the <b>${d.vehicle}</b> (${d.dates}) is <b style="color:${ORANGE}">$${d.amount}</b>, valid until <b>${d.expires}</b>. Accepting is not a payment — the payment link follows.${btn(d.trackUrl, "View & accept quote")}`, s)],
  QUOTE_EXPIRING: (d, s) => [`Your quote expires soon — ${d.requestId}`,
    shell("Quote expiring", `Hi ${d.firstName},<br><br>Your $${d.amount} quote for the <b>${d.vehicle}</b> expires <b>${d.expires}</b>. Lock it in before it goes.${btn(d.trackUrl, "Accept quote")}`, s)],
  QUOTE_ACCEPTED: (d, s) => [`Quote accepted — ${d.requestId}`,
    shell("Quote accepted", `Hi ${d.firstName},<br><br>You accepted the $${d.amount} quote for the <b>${d.vehicle}</b>. Your payment/deposit link is on the way.${btn(d.trackUrl, "Status")}`, s)],
  PAYMENT_REQUIRED: (d, s) => [`Payment link — ${d.requestId}`,
    shell("Deposit / payment required", `Hi ${d.firstName},<br><br>To confirm the <b>${d.vehicle}</b>, complete your ${d.category || "payment"} of <b style="color:${ORANGE}">$${d.amount}</b>. Payments are processed securely by Stripe — we never see your card.${d.payUrl ? btn(d.payUrl, "Pay securely") : ""}`, s)],
  BOOKING_CONFIRMED: (d, s) => [`Booking confirmed — ${d.requestId}`,
    shell("You're booked. 🖤🧡", `Hi ${d.firstName},<br><br>The <b>${d.vehicle}</b> is confirmed for ${d.dates}.<br>${d.handover}.<br><br>Bring your license and insurance at handover.${btn(d.trackUrl, "Booking details")}`, s)],
  DELIVERY_REMINDER: (d, s) => [`Tomorrow: your ${d.vehicle}`,
    shell("Delivery reminder", `Hi ${d.firstName},<br><br>Your <b>${d.vehicle}</b> arrives ${d.when}. Have your license and insurance ready — handover takes ~10 minutes.`, s)],
  RETURN_REMINDER: (d, s) => [`Return reminder — ${d.vehicle}`,
    shell("Return coming up", `Hi ${d.firstName},<br><br>The <b>${d.vehicle}</b> is due back ${d.when}. Return it full (premium fuel) unless you added pre-paid fuel.`, s)],
  DEPOSIT_STATUS: (d, s) => [`Deposit update — ${d.requestId}`,
    shell("Deposit status", `Hi ${d.firstName},<br><br>${d.message}`, s)],
  VEHICLE_AVAILABLE: (d, s) => [`Available — complete payment · ${d.requestId}`,
    shell("Your vehicle is available 🔥", `Hi ${d.firstName},<br><br>The <b>${d.vehicle}</b> is confirmed available for ${d.dates} and we're holding it for you.
    <b>Complete payment before the temporary hold expires (${d.expires})</b> to lock it in.
    Total: <b style="color:${ORANGE}">$${Number(d.amount || 0).toLocaleString()}</b>.${btn(d.trackUrl, "Choose payment method")}`, s)],
  HOLD_EXPIRING: (d, s) => [`Your hold expires soon — ${d.requestId}`,
    shell("Hold expiring", `Hi ${d.firstName},<br><br>Your temporary hold on the <b>${d.vehicle}</b> expires at <b>${d.expires}</b>.
    After that the car goes back on the market and availability must be re-verified.${btn(d.trackUrl, "Complete payment now")}`, s)],
  PAYMENT_SUCCESS: (d, s) => [`Payment received — ${d.requestId}`,
    shell("Payment received ✓", `Hi ${d.firstName},<br><br>We received your payment${d.amount ? ` of <b style="color:${ORANGE}">$${Number(d.amount).toLocaleString()}</b>` : ""} for the <b>${d.vehicle}</b>. Your booking is confirmed — details on your tracking page.${btn(d.trackUrl, "View booking")}`, s)],
  PAYMENT_FAILED: (d, s) => [`Payment didn't go through — ${d.requestId}`,
    shell("Payment failed", `Hi ${d.firstName},<br><br>Your payment for the <b>${d.vehicle}</b> didn't complete. Your hold is still active for now — try again from your tracking page or WhatsApp us and we'll sort it.${btn(d.trackUrl, "Try again")}`, s)],
  REVIEW_REQUEST: (d, s) => [`How was the ${d.vehicle}?`,
    shell("Tell us how it went", `Hi ${d.firstName},<br><br>Hope the <b>${d.vehicle}</b> treated you right. A 30-second review helps us more than you know — reply with your thoughts or drop them on Instagram ${d.instagram || "@topnotchrentalz"}.`, s)]
};

function settings() {
  const rows = db.prepare("SELECT key, value FROM settings").all();
  return Object.fromEntries(rows.map(r => [r.key, r.value]));
}

async function sendEmail(to, subject, html) {
  const s = settings();
  const from = `${s.business_name || "TopNotchRentalz"} <${process.env.EMAIL_FROM || s.email || "bookings@topnotchrentalz.com"}>`;
  if (process.env.RESEND_API_KEY) {
    try {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { Authorization: "Bearer " + process.env.RESEND_API_KEY, "Content-Type": "application/json" },
        body: JSON.stringify({ from, to, subject, html, reply_to: s.email || "bookings@topnotchrentalz.com" }),
        signal: AbortSignal.timeout(10000)
      });
      if (res.ok) return "emailed";
    } catch (e) { /* fall through */ }
  }
  if (process.env.NOTIFY_EMAIL_WEBHOOK_URL) {
    try {
      const res = await fetch(process.env.NOTIFY_EMAIL_WEBHOOK_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-TN-Secret": process.env.NOTIFY_WEBHOOK_SECRET || "" },
        body: JSON.stringify({ to, subject, html, from }),
        signal: AbortSignal.timeout(10000)
      });
      if (res.ok) return "emailed";
    } catch (e) { /* fall through */ }
  }
  return "recorded";
}

/* send a branded customer email + always record it */
async function customerEmail(event, to, data) {
  const t = TEMPLATES[event];
  if (!t || !to) return;
  const s = settings();
  const [subject, html] = t(data, s);
  const delivery = await sendEmail(to, subject, html);
  db.prepare("INSERT INTO notifications (audience_role, type, title, body, delivery) VALUES (NULL, ?, ?, ?, ?)")
    .run("CUSTOMER_" + event, subject, `to ${to}`, delivery);
  return delivery;
}

module.exports = { customerEmail, sendEmail, TEMPLATES };
