// Pointly licensing service (Cloudflare Worker + KV).
// Stripe is the merchant of record (Managed Payments handles VAT). Stripe has no
// native license keys, so this Worker issues + validates them:
//   GET  /api/key?session_id=…  → success page fetches the buyer's key
//                                 (verifies the Stripe session is paid, idempotent)
//   POST /api/activate          → the app activates a key on a machine
//   POST /api/validate          → the app re-checks a key (offline-tolerant client side)
//   POST /api/recover           → email a buyer their key(s) again
//   POST /api/stripe-webhook    → mint+email on purchase; revoke on refund/cancel
//   GET  /api/health            → liveness
//
// KV schema:
//   key:<KEY>       → { plan, email, sessionId, status, seatLimit, activations[], createdAt }
//   session:<SID>   → <KEY>            (idempotency + success-page lookup)
//   email:<addr>    → [<KEY>, …]       (recovery lookup)
//
// Secrets (wrangler secret put):  STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, RESEND_API_KEY
// Vars (wrangler.toml):           FROM_EMAIL (e.g. "Pointly <keys@trypointly.com>")
// Binding:  LICENSES (KV namespace)

const SEAT_LIMIT = 5; // machines per key — generous for individuals

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json", ...cors },
  });

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return new Response(null, { headers: cors });

    try {
      switch (url.pathname) {
        case "/api/health":         return json({ ok: true });
        case "/api/key":            return handleKeyLookup(url, env);
        case "/api/activate":       return handleActivate(request, env);
        case "/api/validate":       return handleValidate(request, env);
        case "/api/recover":        return handleRecover(request, env);
        case "/api/stripe-webhook": return handleWebhook(request, env);
        default:                    return json({ error: "not_found" }, 404);
      }
    } catch (e) {
      return json({ error: "server_error", detail: String(e) }, 500);
    }
  },
};

// ---- key generation (Crockford base32, no ambiguous chars) ----
function newKey() {
  const alpha = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
  const bytes = crypto.getRandomValues(new Uint8Array(20));
  let s = "";
  for (const b of bytes) s += alpha[b & 31];
  return "POINTLY-" + s.match(/.{1,5}/g).join("-"); // POINTLY-XXXXX-XXXXX-XXXXX-XXXXX
}

// ---- Stripe helpers ----
async function stripeGet(env, path) {
  const r = await fetch("https://api.stripe.com/v1/" + path, {
    headers: { Authorization: "Bearer " + env.STRIPE_SECRET_KEY },
  });
  return r.json();
}

function planFromSession(session) {
  // Payment links set metadata.plan; fall back to amount, then to "pro".
  const m = session.metadata && session.metadata.plan;
  if (m) return m;
  const amt = session.amount_total || 0;
  if (amt >= 3000) return "lifetime";
  if (amt > 0) return "annual";
  return "pro";
}

// Idempotently mint a key for a paid Stripe session, index it, and email it.
// Shared by /api/key (success page) and the checkout.session.completed webhook,
// so delivery is reliable even if the buyer never sees the success page.
async function mintKey(env, session) {
  const sid = session.id;
  const existing = await env.LICENSES.get("session:" + sid);
  if (existing) {
    const rec = JSON.parse(await env.LICENSES.get("key:" + existing));
    return { key: existing, plan: rec.plan, email: rec.email, isNew: false };
  }
  const key = newKey();
  const email = (session.customer_details && session.customer_details.email) || "";
  const rec = {
    plan: planFromSession(session),
    email,
    sessionId: sid,
    status: "active",
    seatLimit: SEAT_LIMIT,
    activations: [],
    createdAt: Date.now(),
  };
  await env.LICENSES.put("key:" + key, JSON.stringify(rec));
  await env.LICENSES.put("session:" + sid, key);
  if (email) {
    const idxKey = "email:" + email.toLowerCase();
    const list = JSON.parse((await env.LICENSES.get(idxKey)) || "[]");
    if (!list.includes(key)) list.push(key);
    await env.LICENSES.put(idxKey, JSON.stringify(list));
    await sendKeyEmail(env, email, key, rec.plan);
  }
  return { key, plan: rec.plan, email, isNew: true };
}

// GET /api/key?session_id=…  — called by the success page after checkout.
async function handleKeyLookup(url, env) {
  const sid = url.searchParams.get("session_id");
  if (!sid) return json({ error: "missing_session_id" }, 400);
  if (!env.STRIPE_SECRET_KEY) return json({ error: "stripe_not_configured" }, 503);

  const existing = await env.LICENSES.get("session:" + sid);
  if (existing) {
    const rec = JSON.parse(await env.LICENSES.get("key:" + existing));
    return json({ key: existing, plan: rec.plan, email: rec.email });
  }

  const session = await stripeGet(env, "checkout/sessions/" + encodeURIComponent(sid));
  if (session.error) return json({ error: "invalid_session" }, 400);
  if (session.payment_status !== "paid")
    return json({ error: "not_paid", payment_status: session.payment_status }, 402);

  const { key, plan, email } = await mintKey(env, session);
  return json({ key, plan, email });
}

// POST /api/recover  { email }  — re-email a buyer their key(s).
// Always returns generic success so it can't be used to probe who bought.
async function handleRecover(request, env) {
  const { email } = await request.json();
  const generic = json({ ok: true });
  if (!email) return generic;
  const list = JSON.parse((await env.LICENSES.get("email:" + email.toLowerCase())) || "[]");
  for (const key of list) {
    const rec = JSON.parse((await env.LICENSES.get("key:" + key)) || "null");
    if (rec && rec.status === "active") await sendKeyEmail(env, email, key, rec.plan, true);
  }
  return generic;
}

// ---- email (Resend) ----
async function sendKeyEmail(env, to, key, plan, isRecovery = false) {
  if (!env.RESEND_API_KEY) return; // email not configured yet — silent no-op
  const from = env.FROM_EMAIL || "Pointly <keys@trypointly.com>";
  const planName = plan === "lifetime" ? "Pointly Pro+ (Lifetime)" : "Pointly Pro (Annual)";
  const subject = isRecovery ? "Your Pointly license key" : "Your Pointly Pro license key 🎉";
  const html = `
  <div style="font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;max-width:520px;margin:0 auto;color:#111">
    <h2 style="margin:0 0 4px">${isRecovery ? "Here's your license key" : "Thank you for buying " + planName + "!"}</h2>
    <p style="color:#555;font-size:14px;margin:0 0 20px">Use this key to unlock every Pro tool in Pointly.</p>
    <div style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:18px;font-weight:600;
                background:#f4f4f6;border:1px solid #e5e5ea;border-radius:10px;padding:16px;text-align:center;letter-spacing:.5px">
      ${key}
    </div>
    <ol style="color:#333;font-size:14px;line-height:1.7;margin:22px 0">
      <li>Download Pointly for Mac: <a href="https://trypointly.com/buy">trypointly.com/buy</a></li>
      <li>Open it, pick any Pro tool, and paste this key into the <b>License key</b> field.</li>
      <li>Click <b>Activate</b> — Pro unlocks instantly, on up to 5 of your Macs.</li>
    </ol>
    <p style="color:#999;font-size:12px">Keep this email — it's your proof of purchase. Questions? Just reply, or email lyubomirstavrev02@gmail.com.</p>
  </div>`;
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: "Bearer " + env.RESEND_API_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ from, to, subject, html }),
  });
}

// POST /api/activate  { license_key, instance_name }
async function handleActivate(request, env) {
  const { license_key, instance_name } = await request.json();
  if (!license_key) return json({ activated: false, error: "Missing license key." }, 400);

  const raw = await env.LICENSES.get("key:" + license_key.trim());
  if (!raw) return json({ activated: false, error: "This license key was not found." }, 404);
  const rec = JSON.parse(raw);
  if (rec.status !== "active")
    return json({ activated: false, error: "This license key is no longer active." }, 403);

  const id = crypto.randomUUID();
  rec.activations.push({ id, name: instance_name || "Mac", ts: Date.now() });
  // Trim oldest beyond the seat limit rather than hard-blocking (individual-friendly).
  if (rec.activations.length > rec.seatLimit)
    rec.activations = rec.activations.slice(-rec.seatLimit);
  await env.LICENSES.put("key:" + license_key.trim(), JSON.stringify(rec));

  return json({ activated: true, instance: { id }, plan: rec.plan });
}

// POST /api/validate  { license_key, instance_id }
async function handleValidate(request, env) {
  const { license_key } = await request.json();
  if (!license_key) return json({ valid: false }, 400);
  const raw = await env.LICENSES.get("key:" + license_key.trim());
  if (!raw) return json({ valid: false });
  const rec = JSON.parse(raw);
  return json({ valid: rec.status === "active", plan: rec.plan });
}

// POST /api/stripe-webhook  — revoke on refund / subscription cancellation.
async function handleWebhook(request, env) {
  const payload = await request.text();
  const sig = request.headers.get("stripe-signature") || "";
  if (!(await verifyStripeSig(payload, sig, env.STRIPE_WEBHOOK_SECRET)))
    return json({ error: "bad_signature" }, 400);

  const event = JSON.parse(payload);
  const revokeBySession = async (sid) => {
    if (!sid) return;
    const key = await env.LICENSES.get("session:" + sid);
    if (!key) return;
    const rec = JSON.parse(await env.LICENSES.get("key:" + key));
    rec.status = "revoked";
    await env.LICENSES.put("key:" + key, JSON.stringify(rec));
  };

  switch (event.type) {
    case "checkout.session.completed": {
      // Reliable delivery: mint + email the key server-side even if the buyer
      // closed the browser before the success page loaded.
      const s = event.data.object;
      if (s.payment_status === "paid") {
        const full = await stripeGet(env, "checkout/sessions/" + s.id); // ensure customer_details
        await mintKey(env, full.error ? s : full);
      }
      break;
    }
    case "charge.refunded":
    case "charge.dispute.created": {
      // find the session for this payment_intent
      const pi = event.data.object.payment_intent;
      if (pi) {
        const list = await stripeGet(env, "checkout/sessions?payment_intent=" + pi);
        if (list.data && list.data[0]) await revokeBySession(list.data[0].id);
      }
      break;
    }
    case "customer.subscription.deleted": {
      // annual cancellation — revoke via the subscription's latest session
      const sub = event.data.object.id;
      const list = await stripeGet(env, "checkout/sessions?subscription=" + sub);
      if (list.data && list.data[0]) await revokeBySession(list.data[0].id);
      break;
    }
  }
  return json({ received: true });
}

// Stripe signature verification (HMAC-SHA256 over "t.payload"), Web Crypto.
async function verifyStripeSig(payload, header, secret) {
  if (!secret || !header) return false;
  const parts = Object.fromEntries(header.split(",").map((p) => p.split("=")));
  const t = parts.t, v1 = parts.v1;
  if (!t || !v1) return false;
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(t + "." + payload));
  const hex = [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
  // constant-time-ish compare
  if (hex.length !== v1.length) return false;
  let diff = 0;
  for (let i = 0; i < hex.length; i++) diff |= hex.charCodeAt(i) ^ v1.charCodeAt(i);
  return diff === 0;
}
