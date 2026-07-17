/* ============================================================
   TopNotchRentalz — customer site interactions (Phase 2)
   Request-to-Book pipeline · Excel sync · no auto-confirm
   ============================================================ */

const $ = (s, c) => (c || document).querySelector(s);
const $$ = (s, c) => Array.from((c || document).querySelectorAll(s));

/* ---------- icons ---------- */
const ICONS = {
  pin: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></svg>',
  cal: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><rect x="3" y="4" width="18" height="18" rx="3"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>',
  nav: '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polygon points="3 11 22 2 13 21 11 13 3 11"/></svg>',
  truck: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2"/><path d="M15 18H9"/><path d="M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.62l-3.48-4.35A1 1 0 0 0 17.52 8H14"/><circle cx="17" cy="18" r="2"/><circle cx="7" cy="18" r="2"/></svg>',
  key: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="7.5" cy="15.5" r="5.5"/><path d="m21 2-9.6 9.6"/><path d="m15.5 7.5 3 3L22 7l-3-3"/></svg>',
  check: '<svg width="38" height="38" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>',
  user: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-6 8-6s8 2 8 6"/></svg>',
  phone: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.36 1.9.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.34 1.85.57 2.81.7A2 2 0 0 1 22 16.92z"/></svg>',
  bolt: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>',
  gauge: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 14l4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/></svg>',
  seat2: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-6 8-6s8 2 8 6"/></svg>',
  fuel: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><line x1="3" y1="22" x2="15" y2="22"/><path d="M4 22V4a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v18"/><path d="M14 10h2a2 2 0 0 1 2 2v3.5a1.5 1.5 0 0 0 3 0V9l-3-3"/><rect x="6" y="5" width="6" height="5" rx="1"/></svg>',
  toll: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="3" width="14" height="18" rx="2"/><circle cx="12" cy="10" r="3"/><path d="M12 8.5v3"/></svg>',
  clock: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><polyline points="12 7 12 12 15.5 14"/></svg>',
  clean: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12h18"/><path d="M5 12V7a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v5"/><path d="M5 12v5a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-5"/></svg>',
  seat: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4a2 2 0 0 1 4 0v6h6a4 4 0 0 1 4 4v2a4 4 0 0 1-4 4H10a4 4 0 0 1-4-4z"/></svg>',
  wa: '<svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2Zm5.5 14.2c-.23.65-1.35 1.24-1.86 1.28-.5.05-.97.23-3.26-.68-2.76-1.09-4.5-3.9-4.64-4.08-.13-.18-1.1-1.47-1.1-2.8 0-1.34.7-2 .95-2.27.25-.27.54-.34.72-.34h.52c.17 0 .4-.06.62.47.23.55.77 1.9.84 2.03.07.14.11.3.02.48-.09.18-.13.29-.27.45-.13.16-.29.36-.41.48-.14.14-.28.28-.12.55.16.27.7 1.16 1.5 1.88 1.04.92 1.9 1.2 2.18 1.34.27.14.43.11.59-.07.16-.18.68-.8.86-1.07.18-.27.36-.23.6-.14.25.09 1.58.75 1.85.88.27.14.45.2.52.32.06.11.06.65-.16 1.29Z"/></svg>'
};

/* ============================================================
   API CLIENT — the backend owns all data, secrets and webhooks.
   localStorage is only an offline demo fallback when no server
   is running (e.g. opening index.html directly from disk).
   ============================================================ */
async function api(path, body, method) {
  const res = await fetch(API_BASE + path, {
    method: method || (body ? "POST" : "GET"),
    headers: body ? { "Content-Type": "application/json" } : undefined,
    credentials: "same-origin",
    body: body ? JSON.stringify(body) : undefined
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || ("HTTP " + res.status));
  return data;
}

/* local storage is used ONLY to keep a copy of unsent form data for
   recovery — it is never a fake database and never produces request IDs */
const DB = {
  read(key) { try { return JSON.parse(localStorage.getItem(key) || "[]"); } catch (e) { return []; } },
  append(key, row) { const rows = DB.read(key); rows.push(row); localStorage.setItem(key, JSON.stringify(rows)); }
};
/* preview mode exists ONLY behind an explicit development flag and
   never pretends a request was sent */
const PREVIEW_MODE = new URLSearchParams(location.search).get("preview") === "dev";

/* signed-in customer state (identity lives in an HttpOnly cookie;
   this is display/prefill data only) */
window.TN_CUST = null;
const custCsrf = () => (document.cookie.split(/;\s*/).find(c => c.startsWith("tn_cust_csrf=")) || "").slice(13);
fetch(API_BASE + "/customer/me", { credentials: "same-origin" })
  .then(r => r.ok ? r.json() : null)
  .then(d => { if (d && d.me) { window.TN_CUST = d.me; paintAccountNav(); } })
  .catch(() => {});
function paintAccountNav() {
  const label = window.TN_CUST ? window.TN_CUST.name.split(" ")[0] + " ✦" : "Account";
  const a = $("#navAccount"); if (a) a.textContent = label;
  const m = $("#mobAccount"); if (m) m.textContent = window.TN_CUST ? "Account — " + label : "Account";
}

/* signature services catalog — stable IDs from the server */
window.TN_SERVICES = [];
fetch(API_BASE + "/public/services").then(r => r.json())
  .then(d => { window.TN_SERVICES = d.services || []; }).catch(() => {});

/* live availability for the fleet grid */
api("/public/availability").then(m => { window.TN_AVAIL = m; renderFleet(); }).catch(() => {});

/* live company settings (Admin → Settings) override the JS defaults */
window.TN_POLICY_VERSION = "";
api("/public/settings").then(s => {
  if (s.businessName) BUSINESS.name = s.businessName;
  if (s.phone) BUSINESS.phone = s.phone;
  if (s.whatsapp) BUSINESS.whatsapp = s.whatsapp;
  if (s.email) BUSINESS.email = s.email;
  if (s.address) BUSINESS.address = s.address;
  if (s.city) BUSINESS.city = s.city;
  if (s.hours) BUSINESS.hours = s.hours;
  window.TN_POLICY_VERSION = s.policyVersion || "";
  /* refresh anything already rendered from defaults */
  const fp = $("#footPhone");
  if (fp) { fp.textContent = BUSINESS.phone; fp.href = "tel:" + BUSINESS.phone.replace(/\D/g, ""); }
  const fa = $("#footAddress"); if (fa) fa.textContent = BUSINESS.address + ", " + BUSINESS.city;
  const fh = $("#footHours"); if (fh) fh.textContent = BUSINESS.hours;
  const wa = $(".cf-wa"); if (wa) wa.href = `https://wa.me/${BUSINESS.whatsapp}?text=Hi%20TopNotchRentalz%2C%20I%27d%20like%20to%20book%20a%20car`;
  const ph = $(".cf-ph"); if (ph) ph.href = "tel:" + BUSINESS.phone.replace(/\D/g, "");
}).catch(() => {});

/* ============================================================
   NAV
   ============================================================ */
const navIsland = $("#navIsland");
if (navIsland) {
  addEventListener("scroll", () => {
    navIsland.classList.toggle("scrolled", scrollY > 40);
  }, { passive: true });
}
const burger = $("#navBurger");
const mobileMenu = $("#mobileMenu");
if (burger) {
  burger.addEventListener("click", () => {
    burger.classList.toggle("open");
    mobileMenu.classList.toggle("open");
  });
  $$("#mobileMenu a").forEach(a => a.addEventListener("click", () => {
    burger.classList.remove("open");
    mobileMenu.classList.remove("open");
  }));
}

/* floating WhatsApp + phone buttons on every customer page */
(function contactFloat() {
  if (document.body.dataset.noFloat !== undefined) return;
  const wrap = document.createElement("div");
  wrap.className = "contact-float";
  wrap.innerHTML = `
    <a class="cf-btn cf-wa" href="https://wa.me/${BUSINESS.whatsapp}?text=Hi%20TopNotchRentalz%2C%20I%27d%20like%20to%20book%20a%20car" target="_blank" rel="noopener" aria-label="WhatsApp">${ICONS.wa}</a>
    <a class="cf-btn cf-ph" href="tel:${BUSINESS.phone.replace(/\D/g, "")}" aria-label="Call">${ICONS.phone}</a>`;
  document.body.appendChild(wrap);
})();

/* ============================================================
   HERO scroll sequence
   ============================================================ */
const hero = $("#hero");
if (hero) {
  const ext = $("#sceneExterior");
  const int = $("#sceneInterior");
  const copy = $("#heroCopy");
  const hint = $("#scrollHint");
  const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
  const ease = t => t * t * (3 - 2 * t);

  const onScroll = () => {
    const r = hero.getBoundingClientRect();
    const total = r.height - innerHeight;
    const prog = clamp(-r.top / total, 0, 1);
    const zoom = ease(clamp((prog - 0.18) / 0.42, 0, 1));
    ext.style.transform = `scale(${1 + prog * 0.12 + zoom * 1.15}) translateX(${zoom * -6}%)`;
    ext.style.opacity = 1 - ease(clamp((prog - 0.34) / 0.28, 0, 1));
    ext.style.filter = `blur(${zoom * 6}px)`;
    const arrive = ease(clamp((prog - 0.42) / 0.34, 0, 1));
    int.style.opacity = arrive;
    int.style.transform = `scale(${1.28 - arrive * 0.28})`;
    copy.classList.toggle("flip", prog > 0.52);
    if (hint) hint.style.opacity = prog > 0.05 ? 0 : 1;
  };
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  const vid = $("#heroVideo");
  if (vid) {
    vid.addEventListener("loadeddata", () => vid.classList.add("live"));
    vid.addEventListener("error", () => vid.remove(), true);
  }
}

/* ============================================================
   CATEGORY ISLANDS
   ============================================================ */
const islandsEl = $("#islands");
let activeCat = "all";

function renderIslands() {
  if (!islandsEl) return;
  islandsEl.innerHTML = CATEGORIES.map(c => {
    const count = c.type === "filter"
      ? (c.id === "all" ? FLEET.length : FLEET.filter(f => f.brand === c.id).length) + " vehicles"
      : (c.vip ? "Premium access" : "Concierge");
    const cls = `island${c.id === activeCat ? " active" : ""}${c.vip ? " island-vip" : ""}`;
    return `<button class="${cls}" data-cat="${c.id}" data-type="${c.type}" data-href="${c.href || ""}">
      <span class="isl-icon">${c.icon}</span>
      <span class="isl-name">${c.name}</span>
      <span class="isl-count">${count}</span>
    </button>`;
  }).join("");

  $$(".island", islandsEl).forEach(btn => {
    btn.addEventListener("click", () => {
      if (islandsEl.dataset.dragged === "1") return;
      const type = btn.dataset.type;
      if (type === "link") { location.href = btn.dataset.href; return; }
      if (type === "anchor") { $(btn.dataset.href)?.scrollIntoView({ behavior: "smooth" }); return; }
      activeCat = btn.dataset.cat;
      $$(".island", islandsEl).forEach(b => b.classList.toggle("active", b === btn));
      renderFleet();
      $("#fleet")?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  });
}

function makeDraggable(el) {
  if (!el) return;
  let down = false, startX = 0, startL = 0, moved = 0;
  el.addEventListener("pointerdown", e => {
    down = true; moved = 0;
    startX = e.clientX; startL = el.scrollLeft;
    el.classList.add("dragging");
  });
  addEventListener("pointermove", e => {
    if (!down) return;
    const dx = e.clientX - startX;
    moved = Math.max(moved, Math.abs(dx));
    el.scrollLeft = startL - dx;
  });
  addEventListener("pointerup", () => {
    if (!down) return;
    down = false;
    el.classList.remove("dragging");
    el.dataset.dragged = moved > 6 ? "1" : "0";
    setTimeout(() => (el.dataset.dragged = "0"), 50);
  });
}
makeDraggable(islandsEl);

/* ============================================================
   FLEET GRID
   ============================================================ */
const fleetGrid = $("#fleetGrid");

function renderFleet() {
  if (!fleetGrid) return;
  const list = activeCat === "all" ? FLEET : FLEET.filter(f => f.brand === activeCat);
  fleetGrid.innerHTML = list.map((car, i) => {
    const st = vehicleStatus(car.id);
    const tag = st !== "available"
      ? '<span class="card-tag hot">On Request</span>'
      : (car.hot ? '<span class="card-tag hot">In Demand</span>' : `<span class="card-tag">${car.cat}</span>`);
    return `
    <article class="car-card reveal in" data-id="${car.id}" style="transition-delay:${i * 0.04}s">
      <div class="card-media">${tag}${emptySlot()}</div>
      <div class="card-body">
        <h3 class="card-name">${car.name}</h3>
        <div class="card-meta">
          <span>${car.hp}</span><span>0–60 ${car.zero60}</span><span>${car.seats} seats</span>
        </div>
        <div class="card-foot">
          <div class="card-price"><strong>$${car.price.toLocaleString()}</strong><em>per day</em></div>
          <span class="card-cta">→</span>
        </div>
      </div>
    </article>`;
  }).join("");

  $$(".car-card", fleetGrid).forEach(card =>
    card.addEventListener("click", () => openDetail("car", card.dataset.id)));
}

/* ============================================================
   SERVICES
   ============================================================ */
const servicesEl = $("#servicesBand");
function renderServices() {
  if (!servicesEl) return;
  servicesEl.innerHTML = SERVICES.map(s => `
    <article class="service-card reveal" data-id="${s.id}">
      <div class="svc-art">${s.art()}</div>
      <div class="svc-overlay"></div>
      <div class="svc-body">
        <h3>${s.name}</h3>
        <p>${s.desc}</p>
        <div class="svc-price">${s.priceLabel}</div>
      </div>
    </article>`).join("");
  $$(".service-card", servicesEl).forEach(card =>
    card.addEventListener("click", () => openDetail("service", card.dataset.id)));
}

/* ============================================================
   MODAL SHELL
   ============================================================ */
const modalRoot = $("#modalRoot");
let bookingContext = null;

function openModal(html, wide) {
  modalRoot.innerHTML = `
    <div class="modal-backdrop" id="mBackdrop">
      <div class="modal${wide ? " modal-wide" : ""}">
        <button class="modal-close" id="mClose" aria-label="Close">✕</button>
        ${html}
      </div>
    </div>`;
  requestAnimationFrame(() => $("#mBackdrop").classList.add("open"));
  $("#mClose").addEventListener("click", closeModal);
  $("#mBackdrop").addEventListener("click", e => { if (e.target.id === "mBackdrop") closeModal(); });
  document.body.style.overflow = "hidden";
}
function closeModal() {
  const b = $("#mBackdrop");
  if (!b) return;
  b.classList.remove("open");
  document.body.style.overflow = "";
  setTimeout(() => (modalRoot.innerHTML = ""), 350);
}
function swapModal(html) {
  const m = $("#mBackdrop .modal");
  m.scrollTop = 0;
  m.innerHTML = `<button class="modal-close" id="mClose" aria-label="Close">✕</button>${html}`;
  $("#mClose").addEventListener("click", closeModal);
}
addEventListener("keydown", e => { if (e.key === "Escape") closeModal(); });

/* step progress header for the wizard */
function stepsBar(n) {
  return `<div class="steps-bar">${[1, 2, 3, 4].map(i =>
    `<span class="step-dot${i === n ? " on" : i < n ? " done" : ""}"></span>`).join("")}
    <span class="steps-label">Step ${n} of 4</span></div>`;
}

/* ============================================================
   DETAIL POPUPS
   ============================================================ */
function openDetail(kind, id) {
  if (kind === "car") return openCarDetail(id);

  const s = SERVICES.find(x => x.id === id);
  bookingContext = { kind, id, title: s.name, price: s.price, unit: s.unit, extras: [], premium: [], form: {} };
  openModal(`
    <div class="detail-media">${s.art()}</div>
    <div class="modal-pad">
      <div class="detail-head">
        <div>
          <h3>${s.name}</h3>
          <div class="d-cat">Concierge Service</div>
        </div>
        <div class="price-chip"><strong>$${s.price.toLocaleString()}</strong><span>per ${s.unit}</span></div>
      </div>
      <div class="spec-grid">${s.specs.map(x => `<div class="spec"><b>${x[0]}</b><i>${x[1]}</i></div>`).join("")}</div>
      <ul class="detail-notes">${s.notes.map(n => `<li>${n}</li>`).join("")}</ul>
      <button class="btn btn-primary btn-block" id="rentNow">Request to Book</button>
    </div>`);
  $("#rentNow").addEventListener("click", () => startBooking());
}

function openCarDetail(id) {
  const c = FLEET.find(f => f.id === id);
  const st = vehicleStatus(id);
  bookingContext = { kind: "car", id, title: c.name, price: c.price, unit: "day", extras: [], premium: [], form: {} };
  const mile = extraMileRate(c.price);

  const altBanner = st !== "available" ? `
      <div class="alt-banner">
        <b>${st === "on-request" ? "Availability on request." : `This vehicle is currently ${st === "booked" ? "on rent" : "in service"}.`}</b>
        ${st === "on-request"
          ? "We're re-verifying this unit with the provider, so instant quoting is paused — submit a request and we'll confirm personally."
          : "You can still submit a request — our team confirms real-time availability with the provider before anything is promised."} Or start with a comparable car:
        <div class="alt-row">
          ${comparableAlternatives(c, 2).map(a => `
            <button class="alt-chip" data-alt="${a.id}">
              <b>${a.name}</b><span>$${a.price.toLocaleString()}/day</span>
            </button>`).join("")}
        </div>
      </div>` : "";

  openModal(`
    <div class="detail-media">${emptySlot()}</div>
    <div class="modal-pad" style="padding-bottom:16px">
      <div class="detail-head">
        <div>
          <h3>${c.name}</h3>
          <div class="d-cat">${c.cat}</div>
        </div>
      </div>
      ${altBanner}
      <div class="price-pills">
        <span class="pill">$${c.price.toLocaleString()}<small>/day</small></span>
        <span class="pill alt">$${weeklyRate(c.price).toLocaleString()}<small>/week</small></span>
        <span class="pill chrome">$${monthlyRate(c.price).toLocaleString()}<small>/month</small></span>
      </div>

      <div class="rate-table">
        <div class="rate-row"><span class="rk">Distance included</span><span class="rv">${RENTAL_TERMS.mileageIncluded} mi / day</span></div>
        <div class="rate-row"><span class="rk">Additional mileage</span><span class="rv">$${mile} per mile</span></div>
        <div class="rate-row"><span class="rk">Security deposit</span><span class="rv hl">from $${c.deposit.toLocaleString()}</span></div>
        <div class="rate-row"><span class="rk">Minimum rental</span><span class="rv">${RENTAL_TERMS.minDays} day</span></div>
        <div class="rate-row"><span class="rk">Delivery / pickup fee</span><span class="rv">$${RENTAL_TERMS.deliveryFee} · free for VIP</span></div>
        <div class="rate-row"><span class="rk">Minimum driver age</span><span class="rv">${RENTAL_TERMS.minAge}+</span></div>
      </div>

      <div class="block-label">Features</div>
      <div class="features-grid">
        <div class="feature-tile"><span class="ft-ico">${ICONS.bolt}</span><span><i>Engine Horsepower</i><b>${c.hp}</b></span></div>
        <div class="feature-tile"><span class="ft-ico">${ICONS.gauge}</span><span><i>0–60 / Top Speed</i><b>${c.zero60} · ${c.top}</b></span></div>
        <div class="feature-tile"><span class="ft-ico">${ICONS.seat2}</span><span><i>Seats</i><b>${c.seats}</b></span></div>
        <div class="feature-tile"><span class="ft-ico">${ICONS.fuel}</span><span><i>Vehicle Fuel Type</i><b>Gasoline</b></span></div>
      </div>

      <div class="block-label">Extras</div>
      <div class="extras-list" id="extrasList">
        ${EXTRAS.map(e => `
          <div class="extra-card" data-ex="${e.id}">
            <span class="ex-ico">${ICONS[e.ico] || ICONS.pin}</span>
            <span class="ex-body"><b>${e.name}</b><p>${e.desc}</p></span>
            <span class="ex-price">+$${e.price}<small>/${e.per}</small></span>
            <span class="ex-tick">✓</span>
          </div>`).join("")}
      </div>
      <p class="fineprint">Requirements: ${RENTAL_TERMS.minAge}+ · ${RENTAL_TERMS.license.toLowerCase()} ·
      ${RENTAL_TERMS.insurance.toLowerCase()}. <a href="policies.html">Full rental requirements →</a></p>
    </div>

    <div class="modal-rentbar">
      <div class="total"><b id="rentTotal">$${c.price.toLocaleString()}</b><span>per day · deposit separate</span></div>
      <button class="btn btn-primary" id="rentNow">Request to Book</button>
    </div>`);

  $$(".alt-chip").forEach(chip => chip.addEventListener("click", () => openCarDetail(chip.dataset.alt)));

  const updateTotal = () => {
    const perDay = c.price + bookingContext.extras
      .map(x => EXTRAS.find(e => e.id === x)).filter(e => e.per === "day")
      .reduce((s, e) => s + e.price, 0);
    const oneTime = bookingContext.extras
      .map(x => EXTRAS.find(e => e.id === x)).filter(e => e.per === "trip")
      .reduce((s, e) => s + e.price, 0);
    $("#rentTotal").textContent = `$${perDay.toLocaleString()}` + (oneTime ? ` +$${oneTime}` : "");
    bookingContext.price = perDay;
  };

  $$(".extra-card").forEach(card => card.addEventListener("click", () => {
    const ex = card.dataset.ex;
    card.classList.toggle("on");
    bookingContext.extras = card.classList.contains("on")
      ? [...bookingContext.extras, ex]
      : bookingContext.extras.filter(x => x !== ex);
    updateTotal();
  }));

  $("#rentNow").addEventListener("click", () => startBooking());
}

/* ============================================================
   REQUEST-TO-BOOK WIZARD
   Step 1: delivery or pickup   Step 2: location + dates
   Step 3: driver & budget      Step 4: occasion, add-ons, contact
   ============================================================ */
function saveInputs(ids) {
  ids.forEach(i => {
    const el = $("#" + i);
    if (!el) return;
    bookingContext.form[i] = el.type === "checkbox" ? el.checked : el.value.trim();
  });
}
function v(id) { return bookingContext.form[id] || ""; }

/* ---------- booking auth gate ----------
   Signed-out customers choose: sign in, create account, or continue
   as guest. Guests get identical price, fleet access, priority and
   signature-service access — an account only adds convenience. */
function startBooking() {
  if (window.TN_CUST || sessionStorage.getItem("tn_guest") === "1") return renderStep1();
  renderAuthChoice();
}

async function custApi(path, body, method) {
  const res = await fetch(API_BASE + "/customer" + path, {
    method: method || (body !== undefined ? "POST" : "GET"),
    headers: { ...(body !== undefined ? { "Content-Type": "application/json" } : {}), ...(custCsrf() ? { "x-csrf": custCsrf() } : {}) },
    credentials: "same-origin",
    body: body !== undefined ? JSON.stringify(body) : undefined
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || "HTTP " + res.status);
  return data;
}

function renderAuthChoice() {
  swapModal(`
    <div class="modal-pad">
      <h3 class="opt-title">Book as a <span style="color:var(--orange)">member</span> or guest?</h3>
      <p class="opt-sub">Guests get the same cars, the same price and the same priority.
      An account saves your details, keeps trip history and remembers your privacy choices.</p>
      <div style="display:flex;flex-direction:column;gap:10px;margin-top:18px">
        <button class="btn btn-primary btn-block" id="acSignin">Sign in</button>
        <button class="btn btn-ghost btn-block" id="acCreate">Create account</button>
        <button class="btn btn-ghost btn-block" id="acGuest">Continue as guest</button>
      </div>
      <div id="acForm" style="margin-top:16px"></div>
      <p class="fineprint" id="acMsg" style="text-align:center"></p>
    </div>`);
  $("#acGuest").addEventListener("click", () => { sessionStorage.setItem("tn_guest", "1"); renderStep1(); });
  $("#acSignin").addEventListener("click", () => {
    $("#acForm").innerHTML = `
      <div class="f-label">Email</div><input class="f-input" id="acEmail" type="email">
      <div class="f-label">Password</div><input class="f-input" id="acPass" type="password">
      <button class="btn btn-primary btn-block" id="acGo" style="margin-top:14px">Sign In & Continue</button>`;
    $("#acGo").addEventListener("click", async () => {
      try {
        const out = await custApi("/login", { email: $("#acEmail").value.trim(), password: $("#acPass").value });
        window.TN_CUST = out.me; paintAccountNav(); renderStep1();
      } catch (e) { $("#acMsg").textContent = e.message; }
    });
  });
  $("#acCreate").addEventListener("click", () => {
    $("#acForm").innerHTML = `
      <div class="f-label">Full name</div><input class="f-input" id="acName">
      <div class="f-label">Phone</div><input class="f-input" id="acPhone" type="tel">
      <div class="f-label">Email</div><input class="f-input" id="acEmail" type="email">
      <div class="f-label">Password (min 10 characters)</div><input class="f-input" id="acPass" type="password">
      <button class="btn btn-primary btn-block" id="acGo" style="margin-top:14px">Create Account & Continue</button>`;
    $("#acGo").addEventListener("click", async () => {
      try {
        const out = await custApi("/register", { name: $("#acName").value.trim(), phone: $("#acPhone").value.trim(), email: $("#acEmail").value.trim(), password: $("#acPass").value });
        window.TN_CUST = out.me; paintAccountNav(); toast("Account created — a verification email is on its way.");
        renderStep1();
      } catch (e) { $("#acMsg").textContent = e.message; }
    });
  });
}

function renderStep1() {
  swapModal(`
    <div class="modal-pad">
      ${stepsBar(1)}
      <h3 class="opt-title">How do you want your <span style="color:var(--orange)">${bookingContext.kind === "car" ? "car" : "booking"}</span>?</h3>
      <p class="opt-sub">${bookingContext.title} — this is a booking <b>request</b>; nothing is charged until our team confirms availability and price.</p>
      <div class="opt-grid">
        <button class="opt-card" id="optDelivery">
          <span class="opt-ico">${ICONS.truck}</span>
          <b>Delivery</b>
          <span>We bring it to your door, hotel or airport</span>
        </button>
        <button class="opt-card" id="optPickup">
          <span class="opt-ico">${ICONS.key}</span>
          <b>Drop-off &amp; Pickup</b>
          <span>Collect and return at our showroom</span>
        </button>
      </div>
    </div>`);
  $("#optDelivery").addEventListener("click", () => { bookingContext.form.option = "delivery"; renderStep2(); });
  $("#optPickup").addEventListener("click", () => { bookingContext.form.option = "pickup"; renderStep2(); });
}

function renderStep2() {
  const isDelivery = bookingContext.form.option === "delivery";
  swapModal(`
    <div class="modal-pad">
      ${stepsBar(2)}
      <div class="bk-section-head">
        <span class="bk-ico">${isDelivery ? ICONS.pin : ICONS.key}</span>
        <div><h3>${isDelivery ? "Select Location" : "Showroom Pickup"}</h3>
        <p>${isDelivery ? "Choose your delivery and return locations" : "Collect your keys at our location"}</p></div>
      </div>

      ${isDelivery ? `
        <div class="f-label">${ICONS.pin} Delivery location</div>
        <div class="f-field">${ICONS.pin}
          <input class="f-input with-ico" id="locInput" value="${v("locInput")}" placeholder="City, airport, address or hotel">
        </div>
        <button class="geo-btn" id="geoBtn">${ICONS.nav} Use my current location</button>
        <label class="f-check" id="diffReturn">
          <input type="checkbox" id="diffReturnCb" ${v("diffReturnCb") ? "checked" : ""}><span class="box">✓</span>
          Different return location
        </label>
        <div class="return-loc ${v("diffReturnCb") ? "show" : ""}" id="returnLoc">
          <div class="f-field">${ICONS.pin}
            <input class="f-input with-ico" id="returnInput" value="${v("returnInput")}" placeholder="Return location">
          </div>
        </div>`
      : `
        <div class="addr-card">
          <b>${BUSINESS.name}</b>
          <p>${BUSINESS.address}<br>${BUSINESS.city}</p>
          <div class="hours">Hours: <span>${BUSINESS.hours}</span> · ${BUSINESS.phone}</div>
        </div>`}

      ${datesBlock()}
      <div class="wizard-nav">
        <button class="btn btn-ghost btn-sm" id="backBtn">← Back</button>
        <button class="btn btn-primary" id="nextBtn">Continue</button>
      </div>
    </div>`);

  if (isDelivery) {
    $("#diffReturnCb").addEventListener("change", e =>
      $("#returnLoc").classList.toggle("show", e.target.checked));
    $("#geoBtn").addEventListener("click", () => {
      if (!navigator.geolocation) return toast("Location not supported on this device");
      toast("Locating you…");
      navigator.geolocation.getCurrentPosition(
        pos => {
          $("#locInput").value = `Current location (${pos.coords.latitude.toFixed(4)}, ${pos.coords.longitude.toFixed(4)})`;
          toast("Location captured");
        },
        () => toast("Couldn't get your location — type it in instead"));
    });
  }
  $("#backBtn").addEventListener("click", renderStep1);
  $("#nextBtn").addEventListener("click", () => {
    saveInputs(["locInput", "diffReturnCb", "returnInput", "dateStart", "timeStart", "dateEnd", "timeEnd"]);
    if (isDelivery && !v("locInput")) return toast("Please enter a delivery location");
    if (!v("dateStart") || !v("dateEnd")) return toast("Please pick your dates");
    renderStep3();
  });
}

function datesBlock() {
  const today = new Date();
  const fmt = d => d.toISOString().slice(0, 10);
  const s = v("dateStart") || fmt(today);
  const e = v("dateEnd") || fmt(new Date(today.getTime() + 2 * 864e5));
  return `
    <div class="f-label">${ICONS.cal} ${bookingContext.kind === "car" ? "Pick-up" : "Start"} date and time</div>
    <div class="f-row"><input class="f-input" type="date" id="dateStart" value="${s}"><input class="f-input" type="time" id="timeStart" value="${v("timeStart") || "10:00"}"></div>
    <div class="f-label">${ICONS.cal} Return date and time</div>
    <div class="f-row"><input class="f-input" type="date" id="dateEnd" value="${e}"><input class="f-input" type="time" id="timeEnd" value="${v("timeEnd") || "10:00"}"></div>`;
}

function renderStep3() {
  swapModal(`
    <div class="modal-pad">
      ${stepsBar(3)}
      <div class="bk-section-head">
        <span class="bk-ico">${ICONS.user}</span>
        <div><h3>Driver &amp; Budget</h3><p>Quick checks so we can approve you faster</p></div>
      </div>

      <div class="f-row2">
        <div>
          <div class="f-label">Driver age</div>
          <select class="f-select" id="drvAge">
            ${["25–29", "30–39", "40+", "Under 25"].map(o => `<option ${v("drvAge") === o ? "selected" : ""}>${o}</option>`).join("")}
          </select>
        </div>
        <div>
          <div class="f-label">Budget (per day)</div>
          <select class="f-select" id="budget">
            ${["Under $500", "$500–$1,000", "$1,000–$1,500", "$1,500+"].map(o => `<option ${v("budget") === o ? "selected" : ""}>${o}</option>`).join("")}
          </select>
        </div>
      </div>

      <label class="f-check"><input type="checkbox" id="hasLicense" ${v("hasLicense") ? "checked" : ""}><span class="box">✓</span>
        I have a valid driver's license in my name</label>
      <label class="f-check"><input type="checkbox" id="hasInsurance" ${v("hasInsurance") ? "checked" : ""}><span class="box">✓</span>
        I carry full-coverage insurance</label>
      <label class="f-check"><input type="checkbox" id="depositReady" ${v("depositReady") ? "checked" : ""}><span class="box">✓</span>
        I'm ready to place the security deposit</label>

      <div class="f-label">Backup vehicle (optional)</div>
      <select class="f-select" id="backupVehicle">
        <option value="">No backup — this car only</option>
        ${FLEET.filter(f => f.id !== bookingContext.id).map(f =>
          `<option ${v("backupVehicle") === f.name ? "selected" : ""}>${f.name}</option>`).join("")}
      </select>

      <div class="wizard-nav">
        <button class="btn btn-ghost btn-sm" id="backBtn">← Back</button>
        <button class="btn btn-primary" id="nextBtn">Continue</button>
      </div>
    </div>`);

  $("#backBtn").addEventListener("click", renderStep2);
  $("#nextBtn").addEventListener("click", () => {
    saveInputs(["drvAge", "budget", "hasLicense", "hasInsurance", "depositReady", "backupVehicle"]);
    if (v("drvAge") === "Under 25") return toast("Drivers must be 25+ for our fleet");
    if (!v("hasLicense")) return toast("A valid license is required");
    renderStep4();
  });
}

function renderStep4() {
  swapModal(`
    <div class="modal-pad">
      ${stepsBar(4)}
      <div class="bk-section-head">
        <span class="bk-ico">✦</span>
        <div><h3>Finish Your Request</h3><p>Occasion, premium touches and how to reach you</p></div>
      </div>

      <div class="f-label">Occasion (optional)</div>
      <select class="f-select" id="occasion">
        ${["Just driving", "Birthday", "Wedding", "Anniversary", "Business trip", "Vacation", "Content shoot", "Other"]
          .map(o => `<option ${v("occasion") === o ? "selected" : ""}>${o}</option>`).join("")}
      </select>

      <div class="f-label">Premium experience (optional)</div>
      <div class="prem-grid">
        ${PREMIUM_ADDONS.map(p => `
          <label class="prem-chip${bookingContext.premium.includes(p.id) ? " on" : ""}" data-prem="${p.id}">
            <b>${p.name}</b><span>${p.price}</span>
          </label>`).join("")}
      </div>

      <div class="f-label">Signature services (optional)</div>
      <p class="fineprint" style="margin-top:2px">Every signature service is a <b>request — confirmed separately</b>.
      Pricing is quoted after our team confirms details and vendors; nothing is promised or charged
      until you approve it.</p>
      <div class="prem-grid" id="sigGrid">
        ${(window.TN_SERVICES || []).map(s => `
          <label class="prem-chip${(bookingContext.services || []).includes(s.id) ? " on" : ""}" data-sig="${s.id}" title="${s.desc.replace(/"/g, "&quot;")}">
            <b>${s.name}</b><span>Request — confirmed separately</span>
          </label>`).join("") || '<p class="fineprint">Signature services are loading…</p>'}
      </div>

      <div class="f-label">Notes / special requests</div>
      <input class="f-input" id="notes" value="${v("notes")}" placeholder="Color preference, timing, surprises…">

      <div class="f-label">${ICONS.user} Contact</div>
      <input class="f-input" id="cName" value="${v("cName") || (window.TN_CUST ? window.TN_CUST.name : "")}" placeholder="Full name" style="margin-bottom:10px">
      <div class="f-row2">
        <input class="f-input" id="cPhone" type="tel" value="${v("cPhone") || (window.TN_CUST ? window.TN_CUST.phone : "")}" placeholder="Phone number">
        <input class="f-input" id="cEmail" type="email" value="${v("cEmail") || (window.TN_CUST ? window.TN_CUST.email : "")}" placeholder="Email">
      </div>
      ${window.TN_CUST ? `<p class="fineprint" style="margin-top:6px">Booking as <b style="color:var(--orange)">${window.TN_CUST.name}</b> — this request will appear in your account history.</p>` : ""}

      <div class="f-label">AI privacy choice</div>
      <p class="fineprint" style="margin-top:2px">Either choice gives you the same access, price and booking
      priority. AI never decides availability, payments, deposits, damage, refunds, provider payouts or
      provider approval.</p>
      <div class="consent-box">
        <label class="f-check" style="margin-top:10px;font-size:13px">
          <input type="radio" name="aiChoice" id="aiHuman" value="human" ${bookingContext.form.aiChoice === "ai" ? "" : "checked"}>
          <span class="box">✓</span>
          <span><b>HUMAN-ONLY SERVICE</b> — No contact or booking information is sent to third-party AI.
          You receive the same access, price and booking priority.</span>
        </label>
        <label class="f-check" style="margin-top:10px;font-size:13px">
          <input type="radio" name="aiChoice" id="aiAssist" value="ai" ${bookingContext.form.aiChoice === "ai" ? "checked" : ""}>
          <span class="box">✓</span>
          <span><b>ALLOW AI-ASSISTED SERVICE</b> — TopNotch Autopilot may send your contact and booking
          details to OpenAI only to organize your request, summarize conversations and draft replies.
          AI does not decide availability, payments, deposits, damage, refunds, provider payouts or
          provider approval. You can withdraw this permission in Account settings.</span>
        </label>
      </div>
      <input id="hpWebsite" name="website" tabindex="-1" autocomplete="off" style="position:absolute;left:-9999px" aria-hidden="true">

      <div class="f-label">Required agreements</div>
      <div class="consent-box">
        ${[
          ["cTerms", 'I agree to the <a href="policies.html#terms" target="_blank">Terms &amp; Conditions</a>'],
          ["cPrivacy", 'I agree to the <a href="policies.html#privacy" target="_blank">Privacy Policy</a>'],
          ["cCancel", 'I accept the <a href="policies.html#cancellation" target="_blank">Cancellation Policy</a>'],
          ["cDeposit", 'I accept the <a href="policies.html#deposit" target="_blank">Deposit &amp; Refund Policy</a>'],
          ["cRules", 'I accept the vehicle rules (<a href="policies.html#damage" target="_blank">damage</a>, <a href="policies.html#tickets" target="_blank">tickets/tolls</a>, <a href="policies.html#mileage" target="_blank">mileage</a>, <a href="policies.html#smoking" target="_blank">smoking</a>, <a href="policies.html#fuel" target="_blank">fuel</a>)'],
          ["cComms", "I consent to booking updates by text, WhatsApp and email"],
          ["cDocs", "I consent to my license &amp; insurance being processed to verify this booking"]
        ].map(([id, label]) => `
          <label class="f-check" style="margin-top:10px;font-size:13px">
            <input type="checkbox" id="${id}"><span class="box">✓</span><span>${label}</span>
          </label>`).join("")}
      </div>

      <div class="wizard-nav">
        <button class="btn btn-ghost btn-sm" id="backBtn">← Back</button>
        <button class="btn btn-primary" id="submitBtn">Submit Request</button>
      </div>
      <p class="fineprint" style="margin-top:14px">Submitting a request does <b>not</b> guarantee vehicle
      availability or booking approval. Your booking is confirmed only after availability, requirements
      and price are verified and payment is completed.</p>
    </div>`);

  $$(".prem-chip[data-prem]").forEach(chip => chip.addEventListener("click", () => {
    const id = chip.dataset.prem;
    chip.classList.toggle("on");
    bookingContext.premium = chip.classList.contains("on")
      ? [...bookingContext.premium, id]
      : bookingContext.premium.filter(x => x !== id);
  }));
  bookingContext.services = bookingContext.services || [];
  $$(".prem-chip[data-sig]").forEach(chip => chip.addEventListener("click", () => {
    const id = chip.dataset.sig;
    chip.classList.toggle("on");
    bookingContext.services = chip.classList.contains("on")
      ? [...bookingContext.services, id]
      : bookingContext.services.filter(x => x !== id);
  }));

  $("#backBtn").addEventListener("click", renderStep3);
  $("#submitBtn").addEventListener("click", submitRequest);
}

const CONSENT_TEXT = "I agree to the TopNotchRentalz Terms & Conditions, Privacy Policy, Cancellation Policy, Deposit & Refund Policy and vehicle rules (damage, tickets/tolls, mileage, smoking, fuel); I consent to booking updates by text/WhatsApp/email and to my license and insurance being processed to verify this booking. I understand that submitting a request does not guarantee vehicle availability or booking approval.";

async function submitRequest() {
  saveInputs(["occasion", "notes", "cName", "cPhone", "cEmail"]);
  if (!v("cName") || !v("cPhone")) return toast("Please add your name and phone number");
  if (!v("cEmail")) return toast("Please add your email");
  const consents = {
    terms: $("#cTerms").checked, privacy: $("#cPrivacy").checked, cancellation: $("#cCancel").checked,
    deposit: $("#cDeposit").checked, vehicleRules: $("#cRules").checked,
    communication: $("#cComms").checked, documents: $("#cDocs").checked
  };
  if (Object.values(consents).some(x => !x)) return toast("Please tick every agreement to continue");

  const f = bookingContext.form;
  const payload = {
    customerName: f.cName,
    phone: f.cPhone,
    email: f.cEmail,
    vehicleRequested: bookingContext.title,
    backupVehicle: f.backupVehicle || "None",
    startDate: `${f.dateStart} ${f.timeStart}`,
    endDate: `${f.dateEnd} ${f.timeEnd}`,
    budget: f.budget,
    driverAge: f.drvAge,
    licenseStatus: f.hasLicense ? "Confirmed by customer" : "Not confirmed",
    insuranceStatus: f.hasInsurance ? "Confirmed by customer" : "Not confirmed",
    option: f.option,
    deliveryLocation: f.option === "delivery" ? f.locInput : `${BUSINESS.address}, ${BUSINESS.city}`,
    returnLocation: f.option === "delivery" && f.diffReturnCb ? f.returnInput : "Same",
    depositReadiness: f.depositReady ? "Ready" : "Needs discussion",
    occasion: f.occasion,
    chauffeurNeeded: bookingContext.premium.includes("chauffeur") ? "Yes" : "No",
    fboPickup: bookingContext.premium.includes("fbo") ? "Yes" : "No",
    addons: bookingContext.extras.map(x => EXTRAS.find(e => e.id === x)?.name)
      .concat(bookingContext.premium.map(p => PREMIUM_ADDONS.find(a => a.id === p)?.name))
      .filter(Boolean).join(", ") || "None",
    specialRequests: f.notes || "None",
    quotedDayRate: `$${bookingContext.price}/${bookingContext.unit}`,
    aiChoice: document.querySelector('input[name="aiChoice"]:checked')?.value === "ai" ? "ai" : "human",
    services: bookingContext.services || [],
    consents,
    consentText: CONSENT_TEXT + (window.TN_POLICY_VERSION ? ` (policy version ${window.TN_POLICY_VERSION})` : ""),
    website: $("#hpWebsite") ? $("#hpWebsite").value : "" // honeypot — humans never fill this
  };

  let out;
  try {
    out = await api("/public/requests", payload);
  } catch (err) {
    if (/HTTP 4|required|Valid|accept|Too many/.test(err.message)) return toast(err.message);

    /* SECURITY: the backend is unreachable. We NEVER invent a request ID,
       never show "Request Received", never open tracking, and never imply
       a provider is reviewing anything. The form data is kept locally,
       clearly labeled UNSENT, purely so the customer can retry. */
    DB.append("tn_unsent_requests", { ...payload, unsent: true, failedAt: new Date().toISOString() });
    if (PREVIEW_MODE) {
      swapModal(`
        <div class="modal-pad success-wrap">
          <h3>Preview — no request was sent.</h3>
          <p class="fineprint">Development preview mode. Nothing was submitted, booked or charged.</p>
          <button class="btn btn-primary btn-sm" id="doneBtn" style="margin-top:18px">Close</button>
        </div>`);
      $("#doneBtn").addEventListener("click", closeModal);
      return;
    }
    swapModal(`
      <div class="modal-pad success-wrap">
        <div class="success-ring" style="border-color:#5c2418;color:#ff8d6b">✕</div>
        <h3>We could not send your request</h3>
        <p><b>Nothing was booked or charged.</b> Please retry or contact TopNotch.</p>
        <p class="fineprint">Your details are saved on this device (marked unsent) so you can try again
        without retyping. No request number exists until the request actually reaches our team.</p>
        <div style="display:flex;gap:10px;justify-content:center;flex-wrap:wrap;margin-top:22px">
          <button class="btn btn-primary btn-sm" id="retryBtn">Try Again</button>
          <a class="btn btn-ghost btn-sm" href="https://wa.me/${BUSINESS.whatsapp}?text=Hi%2C%20my%20booking%20request%20failed%20to%20send" target="_blank" rel="noopener">WhatsApp Us</a>
          <a class="btn btn-ghost btn-sm" href="tel:${BUSINESS.phone.replace(/\D/g, "")}">Call Us</a>
        </div>
      </div>`);
    $("#retryBtn").addEventListener("click", submitRequest);
    return;
  }

  const requestId = out.requestId;
  const note = out.duplicate ? "<br><span style='color:var(--muted);font-size:12px'>Looks like you already have an open request for these dates — our team will merge them.</span>" : "";
  bookingContext.form.lastPhone = f.cPhone;

  swapModal(`
    <div class="modal-pad success-wrap">
      <div class="success-ring">${ICONS.check}</div>
      <h3>Request Received</h3>
      <p><b style="color:var(--orange)">${requestId}</b><br>
      Thank you, ${f.cName.split(" ")[0]}. Our team is checking availability with the provider now —
      expect a text at ${f.cPhone} shortly.${note}</p>
      ${(payload.services || []).length ? `<p class="fineprint">Signature services requested: each is confirmed separately after our checklist and your price approval.</p>` : ""}
      ${statusTimeline(STATUS_FLOW[0])}
      <div style="display:flex;gap:10px;justify-content:center;flex-wrap:wrap;margin-top:22px">
        <a class="btn btn-ghost btn-sm" href="track.html?id=${requestId}&ph=${encodeURIComponent(f.cPhone.slice(-4))}">Track This Request</a>
        <button class="btn btn-primary btn-sm" id="doneBtn">Done</button>
      </div>
    </div>`);
  $("#doneBtn").addEventListener("click", closeModal);
}

/* customer status timeline */
function statusTimeline(current) {
  const idx = Math.max(0, STATUS_FLOW.indexOf(current));
  return `<div class="timeline">${STATUS_FLOW.map((s, i) => `
    <div class="tl-step${i < idx ? " done" : i === idx ? " now" : ""}">
      <span class="tl-dot">${i < idx ? "✓" : ""}</span>
      <span class="tl-name">${s}</span>
    </div>`).join("")}</div>`;
}

/* ============================================================
   TOAST / RIPPLE / REVEAL
   ============================================================ */
let toastTimer;
function toast(msg) {
  let t = $("#toast");
  if (!t) {
    t = document.createElement("div");
    t.id = "toast"; t.className = "toast";
    t.innerHTML = '<span class="t-dot"></span><span class="t-msg"></span>';
    document.body.appendChild(t);
  }
  $(".t-msg", t).textContent = msg;
  t.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove("show"), 2800);
}

document.addEventListener("click", e => {
  const btn = e.target.closest(".btn");
  if (!btn) return;
  const r = btn.getBoundingClientRect();
  const rip = document.createElement("span");
  const size = Math.max(r.width, r.height);
  rip.className = "ripple";
  rip.style.cssText = `width:${size}px;height:${size}px;left:${e.clientX - r.left - size / 2}px;top:${e.clientY - r.top - size / 2}px`;
  btn.appendChild(rip);
  setTimeout(() => rip.remove(), 600);
});

const io = new IntersectionObserver(entries => {
  entries.forEach(en => { if (en.isIntersecting) { en.target.classList.add("in"); io.unobserve(en.target); } });
}, { threshold: 0.12 });
function observeReveals() { $$(".reveal:not(.in)").forEach(el => io.observe(el)); }

/* ============================================================
   INIT
   ============================================================ */
renderIslands();
renderFleet();
renderServices();
observeReveals();

/* VIP page apply flow */
$$("[data-vip-apply]").forEach(btn => btn.addEventListener("click", () => {
  bookingContext = { kind: "vip", id: "vip", title: `VIP ${btn.dataset.vipApply} Membership`, price: btn.dataset.vipPrice || 0, unit: "month", extras: [], premium: [], form: {} };
  openModal(`
    <div class="modal-pad">
      <div class="bk-section-head">
        <span class="bk-ico">✦</span>
        <div><h3>Request Invitation</h3><p>VIP ${btn.dataset.vipApply} — membership is application-only</p></div>
      </div>
      <input class="f-input" id="cName" placeholder="Full name" style="margin-bottom:10px">
      <div class="f-row2">
        <input class="f-input" id="cPhone" type="tel" placeholder="Phone number">
        <input class="f-input" id="cEmail" type="email" placeholder="Email">
      </div>
      <div class="f-label">${ICONS.phone} Anything we should know?</div>
      <input class="f-input" id="vipNote" placeholder="Occasions, favorite cars, travel dates…">
      <label class="f-check" style="margin-top:16px;font-size:13px">
        <input type="checkbox" id="vipConsent"><span class="box">✓</span>
        <span>I agree to the <a href="policies.html" target="_blank" style="color:var(--orange)">policies</a> (terms, privacy, cancellation, deposit, vehicle rules), to booking updates by text/WhatsApp/email, and to document processing for verification.</span>
      </label>
      <button class="btn btn-primary btn-block" id="submitVip" style="margin-top:20px">Submit Application</button>
    </div>`);
  $("#submitVip").addEventListener("click", async () => {
    const name = $("#cName").value.trim(), phone = $("#cPhone").value.trim(), email = $("#cEmail").value.trim();
    if (!name || !phone) return toast("Please add your name and phone number");
    if (!email) return toast("Please add your email");
    if (!$("#vipConsent").checked) return toast("Please accept the policies to continue");
    const all = { terms: true, privacy: true, cancellation: true, deposit: true, vehicleRules: true, communication: true, documents: true };
    const start = new Date(), end = new Date(Date.now() + 30 * 864e5);
    const payload = {
      customerName: name, phone, email, vehicleRequested: bookingContext.title,
      startDate: start.toISOString().slice(0, 10) + " 10:00", endDate: end.toISOString().slice(0, 10) + " 10:00",
      option: "vip", occasion: "VIP application",
      specialRequests: $("#vipNote").value.trim() || "None",
      quotedDayRate: `$${bookingContext.price}/mo`,
      consents: all, consentText: CONSENT_TEXT
    };
    try { await api("/public/requests", payload); }
    catch (err) {
      if (/HTTP 4|required|Valid/.test(err.message)) return toast(err.message);
      DB.append("tn_requests", { ...payload, requestId: newRequestId(), status: STATUS_FLOW[0] });
    }
    swapModal(`
      <div class="modal-pad success-wrap">
        <div class="success-ring">${ICONS.check}</div>
        <h3>Application Received</h3>
        <p>Welcome to the shortlist, ${name.split(" ")[0]}. Our team reviews every application personally — expect a call within 24 hours.</p>
        <button class="btn btn-primary" id="doneBtn">Done</button>
      </div>`);
    $("#doneBtn").addEventListener("click", closeModal);
  });
}));

/* ---- partner inquiry form (partners.html) ---- */
const partnerForm = $("#partnerForm");
if (partnerForm) {
  $("#partnerSubmit").addEventListener("click", async () => {
    const g = id => $("#" + id)?.value.trim() || "";
    if (!g("pCompany") || !g("pPhone")) return toast("Company name and phone are required");
    const row = {
      company: g("pCompany"), contact: g("pContact"), phone: g("pPhone"), email: g("pEmail"),
      market: g("pMarket"), fleetSize: g("pFleet"), notes: g("pNotes")
    };
    try { await api("/public/partner-inquiries", row); }
    catch (err) {
      if (/HTTP 4|required/.test(err.message)) return toast(err.message);
      DB.append("tn_partner_inquiries", { ...row, timestamp: new Date().toISOString() });
    }
    partnerForm.innerHTML = `
      <div class="success-wrap">
        <div class="success-ring">${ICONS.check}</div>
        <h3>Inquiry Received</h3>
        <p>Thanks ${row.contact || row.company} — our partnerships team will reach out within one business day.</p>
      </div>`;
  });
}

/* ---- track page (track.html) — verified against the backend ---- */
const trackBox = $("#trackBox");
if (trackBox) {
  const params = new URLSearchParams(location.search);
  const out = () => $("#trackResult");

  const renderTracked = (r, phone) => {
    const quoteBlock = r.quote && r.quote.internalStatus === "awaiting-acceptance" ? `
      <div class="addr-card" style="margin-top:16px;border-color:var(--orange)">
        <b>Your Official Quote</b>
        <p style="font-size:22px;font-family:var(--font-display);color:var(--orange)">$${Number(r.quote.amount).toLocaleString()}</p>
        <p class="fineprint" style="margin-top:4px">Valid until ${String(r.quote.expires).slice(0, 10)}. Accepting the quote is not a payment —
        your payment/deposit link follows right after.</p>
        <button class="btn btn-primary btn-block" id="acceptQuote" style="margin-top:14px">Accept Quote</button>
      </div>` : (r.quote && r.quote.accepted && r.status === "Approved" ? "" : "");
    out().innerHTML = `
      <div class="addr-card" style="margin-top:22px">
        <b>${r.vehicle}</b>
        <p>${r.startDate} → ${r.endDate}<br>${r.option === "pickup" ? "Showroom pickup" : "Delivery: " + r.deliveryLocation}</p>
        <div class="hours">Request <span>${r.requestId}</span></div>
      </div>
      ${["Declined", "Cancelled"].includes(r.status)
        ? `<p class="fineprint" style="margin-top:16px">Status: <b>${r.status}</b> — message us on WhatsApp if you'd like to rebook.</p>`
        : statusTimeline(r.status)}
      ${quoteBlock}`;
    const acc = $("#acceptQuote");
    if (acc) acc.addEventListener("click", async () => {
      try {
        await api("/public/quote/accept", { requestId: r.requestId, phone });
        toast("Quote accepted — payment link is on the way");
        showResult(r.requestId, phone);
      } catch (e) { toast(e.message); }
    });
  };

  /* ---- Phase 4.1: availability result + payment popup panel ---- */
  let holdTimer;
  const renderPayPanel = async (id, phone) => {
    let po;
    try { po = await api(`/public/payment-options?id=${encodeURIComponent(id)}&phone=${encodeURIComponent(phone)}`); }
    catch (e) { return; }
    let box = $("#payPanel");
    if (!box) { box = document.createElement("div"); box.id = "payPanel"; out().appendChild(box); }
    clearInterval(holdTimer);

    if (po.state === "available") {
      const b = po.breakdown;
      const rowsHtml = [
        ["Vehicle", b.vehicle], ["Dates", b.dates], ["Delivery", b.deliveryLocation],
        ["Rental amount", "$" + b.rentalAmount.toLocaleString()],
        ["Security deposit", "$" + b.securityDeposit.toLocaleString() + " (" + b.depositHandling + ", separate)"],
        ["Delivery fee", "$" + b.deliveryFee.toLocaleString()], ["Add-ons", b.addons],
        ["Taxes / processing", "$" + b.taxesProcessing.toLocaleString()]
      ].map(x => `<div class="rate-row"><span class="rk">${x[0]}</span><span class="rv">${x[1]}</span></div>`).join("");
      const methodBtn = m => `<button class="btn ${m.kind === "online" ? "btn-primary" : "btn-ghost"} btn-block" data-pm="${m.id}" style="margin-top:10px">${m.label}</button>`;
      box.innerHTML = `
        <div class="addr-card" style="margin-top:20px;border-color:var(--orange)">
          <b style="color:var(--orange)">Your vehicle is available for the selected dates ✓</b>
          <p class="fineprint" style="margin-top:4px">Complete payment before the temporary hold expires:
          <b id="holdCountdown" style="color:var(--orange)">--:--</b></p>
          <div class="rate-table" style="margin:14px 0">${rowsHtml}
            <div class="rate-row"><span class="rk"><b>Total due now</b></span><span class="rv hl" style="font-size:18px">$${b.totalDueNow.toLocaleString()}</span></div>
            ${b.remainingBalance ? `<div class="rate-row"><span class="rk">Remaining balance</span><span class="rv">$${b.remainingBalance.toLocaleString()}</span></div>` : ""}
          </div>
          ${po.methods.online.length ? `<div class="f-label">Pay online${po.methods.providerName ? " · " + po.methods.providerName : ""}</div>` + po.methods.online.map(methodBtn).join("") : ""}
          ${po.methods.manual.length ? `<div class="f-label" style="margin-top:16px">Other approved payment options</div>` + po.methods.manual.map(methodBtn).join("") : ""}
          <p class="fineprint">Payments are processed securely — card details never touch our servers. Manual methods confirm after our team verifies receipt.</p>
        </div>`;
      const expiry = new Date(po.holdExpiresAt.replace(" ", "T"));
      const tick = () => {
        const left = expiry - Date.now();
        const el = $("#holdCountdown");
        if (!el) return clearInterval(holdTimer);
        if (left <= 0) { el.textContent = "expired"; clearInterval(holdTimer); renderPayPanel(id, phone); return; }
        el.textContent = `${String(Math.floor(left / 6e4)).padStart(2, "0")}:${String(Math.floor(left / 1e3) % 60).padStart(2, "0")}`;
      };
      tick(); holdTimer = setInterval(tick, 1000);
      $$("[data-pm]", box).forEach(btn => btn.addEventListener("click", async () => {
        btn.disabled = true;
        try {
          const outp = await api("/public/pay", { requestId: id, phone, method: btn.dataset.pm });
          if (outp.state === "redirect") location.href = outp.url;
          else { toast(outp.state === "manual" ? "Instructions below" : outp.message || "Updated"); renderPayPanel(id, phone); if (outp.message) alert(outp.message); }
        } catch (e) { toast(e.message); btn.disabled = false; }
      }));
    } else if (po.state === "unavailable") {
      box.innerHTML = `
        <div class="alt-banner" style="margin-top:20px">
          <b>This vehicle is unavailable for the selected dates.</b>
          ${po.alternatives.length ? "Two approved alternatives — pick one and we'll re-run the check instantly (no new form):" : "Message us on WhatsApp and we'll hunt something comparable."}
          <div class="alt-row">
            ${po.alternatives.map(a => `<button class="alt-chip" data-alt='${JSON.stringify(a.model)}'>
              <b>${a.name}</b><span>$${Number(a.pricePerDay).toLocaleString()}/day · $${Number(a.deposit).toLocaleString()} deposit</span>
              <span style="color:var(--muted);font-weight:600;display:block;font-size:11px">${a.dates} · ${a.delivery}</span></button>`).join("")}
          </div>
        </div>`;
      $$("[data-alt]", box).forEach(chip => chip.addEventListener("click", async () => {
        try {
          await api(`/public/requests/${id}/choose-alternative`, { phone, model: JSON.parse(chip.dataset.alt) });
          toast("Switched — re-checking availability now");
          showResult(id, phone);
        } catch (e) { toast(e.message); }
      }));
    } else if (po.state === "expired") {
      box.innerHTML = `<div class="alt-banner" style="margin-top:20px"><b>Your temporary hold expired.</b>
        The car went back on the market — tap below and we'll re-verify availability with the provider.
        <div class="alt-row"><button class="btn btn-primary btn-sm" id="recheckBtn">Re-check availability</button></div></div>`;
      $("#recheckBtn").addEventListener("click", async () => {
        try { const o = await api("/public/pay", { requestId: id, phone, method: "card" }); toast(o.message || "Re-checking"); showResult(id, phone); }
        catch (e) { toast(e.message); }
      });
    } else if (po.state === "manual-pending") {
      box.innerHTML = `<p class="fineprint" style="margin-top:18px"><b style="color:var(--orange)">Payment verification in progress.</b> ${po.message}</p>`;
    } else if (po.state === "pending") {
      box.innerHTML = `<p class="fineprint" style="margin-top:18px">${po.message}</p>`;
    } else if (po.state === "confirmed") {
      box.innerHTML = `<p class="fineprint" style="margin-top:18px" >✓ ${po.message}</p>`;
    }
  };

  const showResult = async (id, phone) => {
    if (!phone) {
      out().innerHTML = `<p class="fineprint" style="margin-top:18px">Enter the last 4 digits of the phone number on the request so we can verify it's you.</p>`;
      return;
    }
    try {
      const r = await api(`/public/track?id=${encodeURIComponent(id)}&phone=${encodeURIComponent(phone)}`);
      renderTracked(r, phone);
      renderPayPanel(id, phone);
    } catch (e) {
      /* honest failure only — local unsent drafts are NEVER shown as real requests */
      out().innerHTML = `<p class="fineprint" style="margin-top:18px">${e.message === "Request not found"
        ? "No request found for <b>" + id + "</b>."
        : "We couldn't reach our booking system right now (" + e.message + "). Nothing about your request has changed."}
        Message us on WhatsApp and we'll check instantly.</p>`;
    }
  };

  $("#trackBtn").addEventListener("click", () => {
    const id = $("#trackId").value.trim();
    if (!id) return toast("Enter your request number (TN-…)");
    showResult(id, $("#trackPhone").value.trim());
  });
  if (params.get("id")) {
    $("#trackId").value = params.get("id");
    if (params.get("ph")) { $("#trackPhone").value = params.get("ph"); showResult(params.get("id"), params.get("ph")); }
  }
}
