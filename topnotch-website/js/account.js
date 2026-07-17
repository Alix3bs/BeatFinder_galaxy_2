/* ============================================================
   Account page — customer auth + dashboard.
   Contains ZERO secrets. All identity comes from the HttpOnly
   session cookie; customer_id is never sent from the browser.
   State-changing calls carry the x-csrf header (double-submit).
   ============================================================ */
(function () {
  const csrf = () => (document.cookie.split(/;\s*/).find(c => c.startsWith("tn_cust_csrf=")) || "").slice(13);
  async function capi(path, body, method) {
    const res = await fetch("/api/customer" + path, {
      method: method || (body !== undefined ? "POST" : "GET"),
      headers: {
        ...(body !== undefined ? { "Content-Type": "application/json" } : {}),
        ...(csrf() ? { "x-csrf": csrf() } : {})
      },
      credentials: "same-origin",
      body: body !== undefined ? JSON.stringify(body) : undefined
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || "HTTP " + res.status);
    return data;
  }

  const gate = $("#acctGate"), dash = $("#acctDash");
  const show = card => { $$("#acctGate .acct-card").forEach(c => c.hidden = true); $(card).hidden = false; };
  let ME = null;

  function esc(s) { return String(s ?? "").replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])); }

  async function boot() {
    /* deep links from account emails */
    if (location.hash.startsWith("#verify=")) {
      const token = location.hash.slice(8); history.replaceState(null, "", "account.html");
      try { await capi("/verify/complete", { token }); toast("Email verified — thank you!"); }
      catch (e) { toast(e.message); }
    }
    if (location.hash.startsWith("#reset=")) {
      gate.hidden = false; show("#resetCard");
      const token = location.hash.slice(7); history.replaceState(null, "", "account.html");
      $("#rsBtn").addEventListener("click", async () => {
        try {
          await capi("/reset/complete", { token, password: $("#rsPass").value });
          $("#resetMsg").textContent = "Password saved. Sign in with your new password — every other session was signed out.";
          setTimeout(() => { show("#signinCard"); }, 1600);
        } catch (e) { $("#resetMsg").textContent = e.message; }
      });
      return;
    }
    try {
      const { me } = await capi("/me");
      ME = me; renderDash();
    } catch (e) {
      gate.hidden = false; dash.hidden = true; show("#signinCard");
    }
  }

  /* ---------- gate wiring ---------- */
  $("#showCreate").addEventListener("click", e => { e.preventDefault(); show("#createCard"); });
  $("#showForgot").addEventListener("click", e => { e.preventDefault(); show("#forgotCard"); });
  $("#backSignin").addEventListener("click", e => { e.preventDefault(); show("#signinCard"); });
  $("#backSignin2").addEventListener("click", e => { e.preventDefault(); show("#signinCard"); });

  $("#siBtn").addEventListener("click", async () => {
    $("#gateMsg").textContent = "";
    try {
      const { me } = await capi("/login", { email: $("#siEmail").value.trim(), password: $("#siPass").value });
      ME = me; renderDash();
    } catch (e) { $("#gateMsg").textContent = e.message; }
  });
  $("#crBtn").addEventListener("click", async () => {
    $("#createMsg").textContent = "";
    try {
      const out = await capi("/register", {
        name: $("#crName").value.trim(), phone: $("#crPhone").value.trim(),
        email: $("#crEmail").value.trim(), password: $("#crPass").value
      });
      ME = out.me; renderDash();
      toast("Account created — check your email to verify your address.");
    } catch (e) { $("#createMsg").textContent = e.message; }
  });
  $("#fgBtn").addEventListener("click", async () => {
    const out = await capi("/reset/request", { email: $("#fgEmail").value.trim() }).catch(e => ({ message: e.message }));
    $("#forgotMsg").textContent = out.message || "If that account exists, instructions have been sent.";
  });

  /* ---------- dashboard ---------- */
  async function renderDash() {
    gate.hidden = true; dash.hidden = false;
    $("#pfName").textContent = ME.name;
    $("#pfPhone").textContent = ME.phone;
    $("#pfEmail").textContent = ME.email;
    $("#verBadge").textContent = ME.emailVerified ? "email verified" : "email not verified";
    $("#resendVer").hidden = !!ME.emailVerified;
    const radios = document.querySelectorAll('input[name="aiPref"]');
    radios.forEach(r => { r.checked = r.value === ME.aiConsent; });
    paintAi();
    try {
      const t = await capi("/trips");
      $("#histRequests").innerHTML = t.requests.length ? t.requests.map(r => `
        <div class="hist-item"><b>${esc(r.request_id)}</b> — ${esc(r.vehicle_requested)}<span class="badge2">${esc(r.status)}</span>
          <div class="sub2">${esc(r.start_date)} → ${esc(r.end_date)} · ${esc(r.option)} · ${r.quote_amount ? "$" + Number(r.quote_amount).toLocaleString() : "quote pending"}</div>
          <div class="sub2"><a style="color:var(--orange)" href="track.html?id=${encodeURIComponent(r.request_id)}">Track</a></div></div>`).join("")
        : '<p class="fineprint">No requests linked to this account yet. Requests you submit while signed in appear here automatically.</p>';
      $("#histTrips").innerHTML = t.rentals.length ? t.rentals.map(r => `
        <div class="hist-item"><b>${esc(r.rental_id)}</b> — ${esc(r.vehicle)}
          <div class="sub2">${esc(r.pickup_date)} → ${esc(r.return_date)} · pickup ${esc(r.pickup_status)} · return ${esc(r.return_status)}</div></div>`).join("")
        : '<p class="fineprint">No completed trips yet.</p>';
    } catch (e) { $("#histRequests").innerHTML = `<p class="fineprint">${esc(e.message)}</p>`; }
  }

  function paintAi() {
    const val = document.querySelector('input[name="aiPref"]:checked')?.value;
    $("#optHuman").classList.toggle("on", val === "human");
    $("#optAi").classList.toggle("on", val === "ai");
  }
  document.querySelectorAll('input[name="aiPref"]').forEach(r => r.addEventListener("change", async () => {
    paintAi();
    try {
      const out = await capi("/me", { aiConsent: r.value }, "PATCH");
      ME = out.me;
      $("#aiMsg").textContent = r.value === "ai"
        ? "AI-assisted service enabled. You can withdraw this permission here at any time."
        : "Human-only service saved. No contact or booking information is sent to third-party AI.";
    } catch (e) { $("#aiMsg").textContent = e.message; }
  }));

  $("#editBtn").addEventListener("click", async () => {
    const name = prompt("Name:", ME.name); if (name === null) return;
    const phone = prompt("Phone:", ME.phone); if (phone === null) return;
    try { const out = await capi("/me", { name, phone }, "PATCH"); ME = out.me; renderDash(); }
    catch (e) { $("#pfMsg").textContent = e.message; }
  });
  $("#resendVer").addEventListener("click", async () => {
    try { await capi("/verify/request", {}); $("#pfMsg").textContent = "Verification email sent."; }
    catch (e) { $("#pfMsg").textContent = e.message; }
  });
  $("#outBtn").addEventListener("click", async () => { await capi("/logout", {}); location.reload(); });
  $("#outAllBtn").addEventListener("click", async () => {
    try { const out = await capi("/logout-all", {}); toast(`Signed out of ${out.revoked} session(s).`); location.reload(); }
    catch (e) { $("#secMsg").textContent = e.message; }
  });
  $("#pwBtn").addEventListener("click", async () => {
    const out = await capi("/reset/request", { email: ME.email }).catch(e => ({ message: e.message }));
    $("#secMsg").textContent = out.message || "If that account exists, instructions have been sent.";
  });
  $("#delBtn").addEventListener("click", async () => {
    if (!confirm("Permanently delete your account? This cannot be undone.")) return;
    try {
      const out = await capi("/me", { password: $("#delPass").value }, "DELETE");
      alert(out.message || "Account deleted.");
      location.href = "index.html";
    } catch (e) { $("#delMsg").textContent = e.message; }
  });

  boot();
})();
