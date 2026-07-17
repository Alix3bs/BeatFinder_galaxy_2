/* ============================================================
   Signature Services — stable IDs, honest pricing, ops checklist.

   Rules enforced HERE (deterministic server code):
   - services are stored by stable ID, never display text alone
   - no fixed price is ever shown or stored as "confirmed" until a
     vendor price exists AND the customer approved it
   - a selected service can NOT become promised/chargeable until the
     full operations checklist passes
   - alcohol is never included by default anywhere in the catalog
   ============================================================ */
const { db } = require("./db");
const U = require("./util");

const SERVICES = [
  { id: "arrival-reset-kit", name: "Arrival Reset Kit", desc: "Chilled water, cold towels, phone chargers and essentials staged in the vehicle before handoff." },
  { id: "welcome-basket", name: "South Florida Welcome Basket", desc: "Locally sourced snacks and refreshments arranged in the vehicle. Alcohol is never included by default." },
  { id: "golden-hour-drive", name: "Golden-Hour Drive Plan", desc: "A curated sunset route with timed departure, scenic stops and photo points." },
  { id: "proposal-drop", name: "Proposal / Surprise Drop", desc: "Coordinated surprise staging — flowers, signage or a planned reveal moment at your location." },
  { id: "hotel-valet-handoff", name: "Hotel Valet Handoff", desc: "We coordinate directly with your hotel's valet so the car is waiting when you walk out." },
  { id: "fbo-tarmac-keys", name: "FBO Tarmac-to-Keys", desc: "Private-aviation arrival: the vehicle meets you at the FBO, subject to facility permission." },
  { id: "content-run", name: "South Florida Content Run", desc: "A route and timing plan built for photos and video, with the best backdrops in the city." },
  { id: "night-out-chauffeur", name: "Night-Out Chauffeur / Vehicle Retrieval", desc: "A professional driver for your evening, or next-day vehicle retrieval so nobody drives impaired. We never encourage driving after drinking." },
  { id: "family-arrival", name: "Family Arrival Setup", desc: "Child seats fitted to your children's sizes, stroller space planned, family essentials staged." },
  { id: "rain-proof-kit", name: "Rain-Proof Miami Kit", desc: "Umbrellas, covered handoff planning and a wet-weather route/backup plan." }
];
const SERVICE_IDS = new Set(SERVICES.map(s => s.id));

/* the 11 operations checklist items — every one must be true (or "n/a"
   where marked conditional) before a service may be approved/charged */
const CHECKLIST = [
  { key: "request_received", label: "Service request received" },
  { key: "safety_questions", label: "Safety questions completed" },
  { key: "allergy_requirements", label: "Allergy requirements completed" },
  { key: "child_seat_size", label: "Child-seat size completed", conditional: true },
  { key: "location_permission", label: "Property/hotel/FBO permission received" },
  { key: "vendor_assigned", label: "Vendor assigned" },
  { key: "vendor_price_confirmed", label: "Vendor price confirmed" },
  { key: "customer_approved_price", label: "Customer approved price" },
  { key: "timing_confirmed", label: "Timing confirmed" },
  { key: "fulfillment_owner", label: "Fulfillment owner assigned" },
  { key: "completion_evidence", label: "Completion evidence uploaded" }
];

db.exec(`
CREATE TABLE IF NOT EXISTS service_orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  request_id TEXT NOT NULL,
  service_id TEXT NOT NULL,
  status TEXT DEFAULT 'requested' CHECK (status IN ('requested','in-progress','approved','fulfilled','cancelled')),
  checklist_json TEXT DEFAULT '{}',
  vendor TEXT DEFAULT '',
  vendor_price REAL,
  fulfillment_owner TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);
`);

const freshChecklist = () => Object.fromEntries(CHECKLIST.map(i => [i.key, i.key === "request_received"]));

/* called from the public booking pipeline — IDs validated against the catalog */
function createOrders(requestId, serviceIds) {
  const created = [];
  for (const sid of [...new Set(serviceIds || [])]) {
    if (!SERVICE_IDS.has(sid)) continue;               // unknown IDs silently dropped, never stored as free text
    db.prepare("INSERT INTO service_orders (request_id, service_id, checklist_json) VALUES (?,?,?)")
      .run(requestId, sid, JSON.stringify(freshChecklist()));
    created.push(sid);
  }
  return created;
}

function checklistPasses(checklist) {
  return CHECKLIST.every(i => checklist[i.key] === true || (i.conditional && checklist[i.key] === "n/a"));
}

/* staff update — the ONLY path a service can advance through.
   'approved' (promised/chargeable) is refused until the checklist passes. */
function updateOrder(id, patch, actor) {
  const o = db.prepare("SELECT * FROM service_orders WHERE id=?").get(id);
  if (!o) return { error: "Service order not found" };
  const checklist = { ...JSON.parse(o.checklist_json || "{}") };
  if (patch.checklist) {
    for (const [k, v] of Object.entries(patch.checklist)) {
      const item = CHECKLIST.find(i => i.key === k);
      if (!item) return { error: "Unknown checklist item: " + k };
      if (v === "n/a" && !item.conditional) return { error: `'${item.label}' cannot be n/a` };
      checklist[k] = v === true ? true : v === "n/a" ? "n/a" : false;
    }
  }
  const next = {
    vendor: patch.vendor !== undefined ? U.strip(patch.vendor) : o.vendor,
    vendor_price: patch.vendorPrice !== undefined ? Number(patch.vendorPrice) : o.vendor_price,
    fulfillment_owner: patch.fulfillmentOwner !== undefined ? U.strip(patch.fulfillmentOwner) : o.fulfillment_owner,
    notes: patch.notes !== undefined ? U.stripLong(patch.notes) : o.notes,
    status: patch.status !== undefined ? patch.status : o.status
  };
  if (!["requested", "in-progress", "approved", "fulfilled", "cancelled"].includes(next.status))
    return { error: "Invalid status" };
  if (["approved", "fulfilled"].includes(next.status) && !checklistPasses(checklist))
    return { error: "This service cannot be promised or charged yet — the operations checklist is incomplete", blocked: true };
  db.prepare(`UPDATE service_orders SET status=?, checklist_json=?, vendor=?, vendor_price=?,
      fulfillment_owner=?, notes=?, updated_at=datetime('now') WHERE id=?`)
    .run(next.status, JSON.stringify(checklist), next.vendor, next.vendor_price,
      next.fulfillment_owner, next.notes, id);
  U.audit(actor, "service.update", "service_order", id, "status", o.status, next.status, o.request_id);
  return { ok: true, checklistPassed: checklistPasses(checklist) };
}

module.exports = { SERVICES, CHECKLIST, createOrders, updateOrder, checklistPasses };
