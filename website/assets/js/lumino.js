/*
 * BeatFinder — Lumino subscription checkout integration.
 *
 * The BeatFinder iOS app opens this site when the user taps "Upgrade".
 * Flow:
 *   app → /pricing.html (pick a plan)
 *       → /checkout.html?plan=<id>[&uid=<user>] (warp animation, then redirect)
 *       → Lumino hosted checkout
 *       → /success.html or /cancel.html
 *
 * Configure the Lumino checkout by either:
 *   1. Setting LUMINO_CONFIG.checkoutBase to your Lumino hosted-checkout
 *      endpoint (price IDs are passed as ?price=...), or
 *   2. Setting a full per-plan checkoutUrl (e.g. a Lumino payment link),
 *      which takes precedence when present.
 */
(function (global) {
  "use strict";

  const LUMINO_CONFIG = {
    // Lumino hosted checkout endpoint. Replace with your live Lumino
    // checkout URL (from the Lumino dashboard) before going to production.
    checkoutBase: "https://checkout.lumino.com/subscribe",

    // Lumino customer portal for managing/cancelling a subscription.
    portalUrl: "https://billing.lumino.com/portal",

    // Where Lumino sends the customer back after checkout.
    successUrl: "success.html",
    cancelUrl: "cancel.html",

    plans: {
      starter: {
        id: "starter",
        name: "Starter",
        price: "$4.99",
        period: "/month",
        // Lumino price identifier for the Starter subscription.
        luminoPriceId: "price_beatfinder_starter_monthly",
        checkoutUrl: "",
      },
      premium: {
        id: "premium",
        name: "Premium",
        price: "$9.99",
        period: "/month",
        luminoPriceId: "price_beatfinder_premium_monthly",
        checkoutUrl: "",
      },
      pro: {
        id: "pro",
        name: "Pro",
        price: "$19.99",
        period: "/month",
        luminoPriceId: "price_beatfinder_pro_monthly",
        checkoutUrl: "",
      },
    },
  };

  function getParam(name) {
    return new URLSearchParams(global.location.search).get(name);
  }

  function absoluteUrl(relative) {
    return new URL(relative, global.location.href).toString();
  }

  /** Resolve a plan id (from ?plan=) to its config, defaulting to premium. */
  function resolvePlan(planId) {
    const key = (planId || "").toLowerCase();
    return LUMINO_CONFIG.plans[key] || null;
  }

  /** Build the Lumino hosted-checkout URL for a plan. */
  function buildCheckoutUrl(plan, uid) {
    if (plan.checkoutUrl) return plan.checkoutUrl;
    const url = new URL(LUMINO_CONFIG.checkoutBase);
    url.searchParams.set("price", plan.luminoPriceId);
    url.searchParams.set("success_url", absoluteUrl(LUMINO_CONFIG.successUrl + "?plan=" + plan.id));
    url.searchParams.set("cancel_url", absoluteUrl(LUMINO_CONFIG.cancelUrl + "?plan=" + plan.id));
    if (uid) url.searchParams.set("client_reference_id", uid);
    return url.toString();
  }

  /** Remember the chosen plan locally so success/account pages can show it. */
  function rememberPlan(plan) {
    try {
      localStorage.setItem("bf_plan", plan.id);
      localStorage.setItem("bf_plan_started", new Date().toISOString());
    } catch (e) { /* storage unavailable (private mode) — non-fatal */ }
  }

  function storedPlan() {
    try {
      const id = localStorage.getItem("bf_plan");
      return id ? resolvePlan(id) : null;
    } catch (e) {
      return null;
    }
  }

  function clearStoredPlan() {
    try {
      localStorage.removeItem("bf_plan");
      localStorage.removeItem("bf_plan_started");
    } catch (e) { /* ignore */ }
  }

  global.BeatFinderLumino = {
    config: LUMINO_CONFIG,
    getParam: getParam,
    resolvePlan: resolvePlan,
    buildCheckoutUrl: buildCheckoutUrl,
    rememberPlan: rememberPlan,
    storedPlan: storedPlan,
    clearStoredPlan: clearStoredPlan,
  };
})(window);
