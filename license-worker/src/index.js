// Pointly licensing service (Cloudflare Worker + KV).
// Stripe is the merchant of record (Managed Payments handles VAT). Stripe has no
// native license keys, so this Worker issues + validates them:
//   GET  /api/key?session_id=…  → success page fetches the buyer's key
//                                 (verifies the Stripe session is paid, idempotent)
//   POST /api/activate          → the app activates a key on a machine
//   POST /api/validate          → the app re-checks a key (offline-tolerant client side)
//   POST /api/stripe-webhook    → refunds / subscription cancels revoke the key
//   GET  /api/health            → liveness
//
// KV schema:
//   key:<KEY>       → { plan, email, sessionId, status, seatLimit, activations[], createdAt }
//   session:<SID>   → <KEY>            (idempotency + success-page lookup)
//
// Secrets (wrangler secret put):  STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET
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

// GET /api/key?session_id=…  — called by the success page after checkout.
async function handleKeyLookup(url, env) {
  const sid = url.searchParams.get("session_id");
  if (!sid) return json({ error: "missing_session_id" }, 400);
  if (!env.STRIPE_SECRET_KEY) return json({ error: "stripe_not_configured" }, 503);

  // Idempotent: return the key already minted for this session, if any.
  const existing = await env.LICENSES.get("session:" + sid);
  if (existing) {
    const rec = JSON.parse(await env.LICENSES.get("key:" + existing));
    return json({ key: existing, plan: rec.plan, email: rec.email });
  }

  const session = await stripeGet(env, "checkout/sessions/" + encodeURIComponent(sid));
  if (session.error) return json({ error: "invalid_session" }, 400);
  if (session.payment_status !== "paid")
    return json({ error: "not_paid", payment_status: session.payment_status }, 402);

  const key = newKey();
  const rec = {
    plan: planFromSession(session),
    email: (session.customer_details && session.customer_details.email) || "",
    sessionId: sid,
    status: "active",
    seatLimit: SEAT_LIMIT,
    activations: [],
    createdAt: Date.now(),
  };
  await env.LICENSES.put("key:" + key, JSON.stringify(rec));
  await env.LICENSES.put("session:" + sid, key);
  return json({ key, plan: rec.plan, email: rec.email });
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
