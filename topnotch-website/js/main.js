/* ============================================================
   TOPNOTCH — interactions
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
  seat: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 4a2 2 0 0 1 4 0v6h6a4 4 0 0 1 4 4v2a4 4 0 0 1-4 4H10a4 4 0 0 1-4-4z"/></svg>'
};

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

/* ============================================================
   HERO scroll sequence (exterior -> around -> interior)
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

    // exterior: subtle drift then zoom-through
    const zoom = ease(clamp((prog - 0.18) / 0.42, 0, 1));
    ext.style.transform = `scale(${1 + prog * 0.12 + zoom * 1.15}) translateX(${zoom * -6}%)`;
    ext.style.opacity = 1 - ease(clamp((prog - 0.34) / 0.28, 0, 1));
    ext.style.filter = `blur(${zoom * 6}px)`;

    // interior: settle in
    const arrive = ease(clamp((prog - 0.42) / 0.34, 0, 1));
    int.style.opacity = arrive;
    int.style.transform = `scale(${1.28 - arrive * 0.28})`;

    copy.classList.toggle("flip", prog > 0.52);
    if (hint) hint.style.opacity = prog > 0.05 ? 0 : 1;
  };
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* hero interior video: fades in over the starlight art once
     img/hero-interior.mp4 exists and has loaded */
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

/* drag-to-swipe for the islands row */
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
  fleetGrid.innerHTML = list.map((car, i) => `
    <article class="car-card reveal in" data-id="${car.id}" style="transition-delay:${i * 0.04}s">
      <div class="card-media">
        ${car.hot ? '<span class="card-tag hot">In Demand</span>' : `<span class="card-tag">${car.cat}</span>`}
        ${emptySlot()}
      </div>
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
    </article>`).join("");

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
   DETAIL MODAL (price + specs + requirements + Rent Now)
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
addEventListener("keydown", e => { if (e.key === "Escape") closeModal(); });

function openDetail(kind, id) {
  if (kind === "car") return openCarDetail(id);

  const s = SERVICES.find(x => x.id === id);
  bookingContext = { kind, id, title: s.name, price: s.price, unit: s.unit };
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
      <button class="btn btn-primary btn-block" id="rentNow">Book Now</button>
    </div>`);
  $("#rentNow").addEventListener("click", () => renderOptionStep());
}

/* ---- car detail: pills + rates + features + extras + sticky bar ---- */
function openCarDetail(id) {
  const c = FLEET.find(f => f.id === id);
  bookingContext = { kind: "car", id, title: c.name, price: c.price, unit: "day", extras: [] };
  const mile = extraMileRate(c.price);

  openModal(`
    <div class="detail-media">${emptySlot()}</div>
    <div class="modal-pad" style="padding-bottom:16px">
      <div class="detail-head">
        <div>
          <h3>${c.name}</h3>
          <div class="d-cat">${c.cat}</div>
        </div>
      </div>

      <div class="price-pills">
        <span class="pill">$${c.price.toLocaleString()}<small>/day</small></span>
        <span class="pill alt">$${weeklyRate(c.price).toLocaleString()}<small>/week</small></span>
        <span class="pill chrome">$${monthlyRate(c.price).toLocaleString()}<small>/month</small></span>
      </div>

      <div class="rate-table">
        <div class="rate-row"><span class="rk">Distance included</span><span class="rv">100 mi / day</span></div>
        <div class="rate-row"><span class="rk">Additional mileage</span><span class="rv">$${mile} per mile</span></div>
        <div class="rate-row"><span class="rk">Security deposit</span><span class="rv hl">from $${c.deposit.toLocaleString()}</span></div>
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
    </div>

    <div class="modal-rentbar">
      <div class="total"><b id="rentTotal">$${c.price.toLocaleString()}</b><span>per day · deposit separate</span></div>
      <button class="btn btn-primary" id="rentNow">Rent Now</button>
    </div>`);

  const updateTotal = () => {
    const perDay = c.price + bookingContext.extras
      .map(x => EXTRAS.find(e => e.id === x))
      .filter(e => e.per === "day")
      .reduce((s, e) => s + e.price, 0);
    const oneTime = bookingContext.extras
      .map(x => EXTRAS.find(e => e.id === x))
      .filter(e => e.per === "trip")
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

  $("#rentNow").addEventListener("click", () => renderOptionStep());
}

/* ============================================================
   BOOKING FLOW — step 1: Delivery vs Pickup (with exit ✕)
   ============================================================ */
function swapModal(html) {
  const m = $("#mBackdrop .modal");
  m.innerHTML = `<button class="modal-close" id="mClose" aria-label="Close">✕</button>${html}`;
  $("#mClose").addEventListener("click", closeModal);
}

function renderOptionStep() {
  swapModal(`
    <div class="modal-pad">
      <h3 class="opt-title">How do you want your <span style="color:var(--orange)">${bookingContext.kind === "car" ? "car" : "booking"}</span>?</h3>
      <p class="opt-sub">${bookingContext.title}</p>
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
  $("#optDelivery").addEventListener("click", () => renderLocationStep("delivery"));
  $("#optPickup").addEventListener("click", () => renderPickupStep());
}

/* ---- step 2a: pickup — show business address ---- */
function renderPickupStep() {
  swapModal(`
    <div class="modal-pad">
      <div class="bk-section-head">
        <span class="bk-ico">${ICONS.key}</span>
        <div><h3>Showroom Pickup</h3><p>Collect your keys at our location</p></div>
      </div>
      <div class="addr-card">
        <b>${BUSINESS.name}</b>
        <p>${BUSINESS.address}<br>${BUSINESS.city}</p>
        <div class="hours">Hours: <span>${BUSINESS.hours}</span> · ${BUSINESS.phone}</div>
      </div>
      ${datesBlock()}
      ${contactBlock()}
      <button class="btn btn-primary btn-block" id="submitBooking" style="margin-top:24px">Confirm Request</button>
    </div>`);
  wireForm("pickup");
}

/* ---- step 2b: delivery — Select Location (reference popup, orange) ---- */
function renderLocationStep() {
  swapModal(`
    <div class="modal-pad">
      <div class="bk-section-head">
        <span class="bk-ico">${ICONS.pin}</span>
        <div><h3>Select Location</h3><p>Choose your delivery and return locations</p></div>
      </div>

      <div class="f-label">${ICONS.pin} Delivery location</div>
      <div class="f-field">${ICONS.pin}
        <input class="f-input with-ico" id="locInput" placeholder="City, airport, address or hotel">
      </div>
      <button class="geo-btn" id="geoBtn">${ICONS.nav} Use my current location</button>

      <label class="f-check" id="diffReturn">
        <input type="checkbox" id="diffReturnCb"><span class="box">✓</span>
        Different return location
      </label>
      <div class="return-loc" id="returnLoc">
        <div class="f-field">${ICONS.pin}
          <input class="f-input with-ico" id="returnInput" placeholder="Return location">
        </div>
      </div>

      ${datesBlock()}
      ${contactBlock()}
      <button class="btn btn-primary btn-block" id="submitBooking" style="margin-top:24px">${ICONS.pin} Confirm Request</button>
    </div>`);

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
      () => toast("Couldn't get your location — type it in instead")
    );
  });

  wireForm("delivery");
}

function datesBlock() {
  const today = new Date();
  const fmt = d => d.toISOString().slice(0, 10);
  const start = fmt(today);
  const end = fmt(new Date(today.getTime() + 2 * 864e5));
  return `
    <div class="f-label">${ICONS.cal} ${bookingContext.kind === "car" ? "Pick-up" : "Start"} date and time</div>
    <div class="f-row"><input class="f-input" type="date" id="dateStart" value="${start}"><input class="f-input" type="time" id="timeStart" value="10:00"></div>
    <div class="f-label">${ICONS.cal} Return date and time</div>
    <div class="f-row"><input class="f-input" type="date" id="dateEnd" value="${end}"><input class="f-input" type="time" id="timeEnd" value="10:00"></div>`;
}

function contactBlock() {
  return `
    <div class="f-label">${ICONS.user} Your details</div>
    <div class="f-row2">
      <input class="f-input" id="cName" placeholder="Full name">
      <input class="f-input" id="cPhone" type="tel" placeholder="Phone number">
    </div>`;
}

/* ---- submit ---- */
function wireForm(mode) {
  $("#submitBooking").addEventListener("click", async () => {
    const name = $("#cName").value.trim();
    const phone = $("#cPhone").value.trim();
    if (mode === "delivery" && !$("#locInput").value.trim()) return toast("Please enter a delivery location");
    if (!name || !phone) return toast("Please add your name and phone number");

    const payload = {
      timestamp: new Date().toISOString(),
      item: bookingContext.title,
      type: bookingContext.kind,
      pricePerUnit: `$${bookingContext.price}/${bookingContext.unit}`,
      option: mode,
      location: mode === "delivery" ? $("#locInput").value.trim() : `${BUSINESS.address}, ${BUSINESS.city}`,
      returnLocation: mode === "delivery" && $("#diffReturnCb").checked ? $("#returnInput").value.trim() : "same",
      start: `${$("#dateStart").value} ${$("#timeStart").value}`,
      end: `${$("#dateEnd").value} ${$("#timeEnd").value}`,
      extras: (bookingContext.extras || []).map(x => EXTRAS.find(e => e.id === x)?.name).join(", ") || "none",
      name, phone
    };

    /* Phase 2: this webhook writes the row into the booking
       spreadsheet and notifies the AI concierge agent, which
       messages the owner with the request details. */
    if (BUSINESS.bookingWebhook) {
      try {
        await fetch(BUSINESS.bookingWebhook, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload)
        });
      } catch (err) { console.warn("Webhook unavailable, stored locally", err); }
    }
    const q = JSON.parse(localStorage.getItem("topnotch_requests") || "[]");
    q.push(payload);
    localStorage.setItem("topnotch_requests", JSON.stringify(q));

    swapModal(`
      <div class="modal-pad success-wrap">
        <div class="success-ring">${ICONS.check}</div>
        <h3>Request Received</h3>
        <p>Thank you, ${name.split(" ")[0]}. Your ${mode} request for the <b>${bookingContext.title}</b> is in.
        Our concierge will text you at ${phone} shortly to confirm.</p>
        <button class="btn btn-primary" id="doneBtn">Done</button>
      </div>`);
    $("#doneBtn").addEventListener("click", closeModal);
  });
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

/* VIP page apply button */
$$("[data-vip-apply]").forEach(btn => btn.addEventListener("click", () => {
  bookingContext = { kind: "vip", id: "vip", title: `VIP ${btn.dataset.vipApply} Membership`, price: btn.dataset.vipPrice || 0, unit: "month" };
  openModal(`
    <div class="modal-pad">
      <div class="bk-section-head">
        <span class="bk-ico">✦</span>
        <div><h3>Request Invitation</h3><p>VIP ${btn.dataset.vipApply} — membership is application-only</p></div>
      </div>
      ${contactBlock()}
      <div class="f-label">${ICONS.phone} Anything we should know?</div>
      <input class="f-input" id="vipNote" placeholder="Occasions, favorite cars, travel dates…">
      <button class="btn btn-primary btn-block" id="submitBooking" style="margin-top:24px">Submit Application</button>
    </div>`);
  $("#submitBooking").addEventListener("click", () => {
    const name = $("#cName").value.trim(), phone = $("#cPhone").value.trim();
    if (!name || !phone) return toast("Please add your name and phone number");
    const q = JSON.parse(localStorage.getItem("topnotch_requests") || "[]");
    q.push({ timestamp: new Date().toISOString(), item: bookingContext.title, type: "vip", name, phone, note: $("#vipNote").value.trim() });
    localStorage.setItem("topnotch_requests", JSON.stringify(q));
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
