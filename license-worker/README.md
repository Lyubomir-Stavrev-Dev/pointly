# Pointly licensing service (Cloudflare Worker)

Issues and validates license keys for the **direct/website** build, backed by
Stripe (merchant of record — Stripe handles EU VAT). Stripe has no native license
keys; this Worker fills that gap.

- **Deployed:** https://pointly-licenses.lyubomirstavrev02.workers.dev
- **KV namespace:** `LICENSES` (id in `wrangler.toml`)
- **Code:** `src/index.js`
- Redeploy after edits: `cd license-worker && npx wrangler deploy`

## Flow
1. Buyer clicks Buy on trypointly.com/buy → Stripe Payment Link (Managed Payments).
2. After paying, Stripe redirects to `trypointly.com/success?session_id=…`.
3. `success.html` calls `GET /api/key?session_id=…`; the Worker verifies the session
   is paid via the Stripe API and returns a freshly minted key (idempotent).
4. Buyer pastes the key into the app → `POST /api/activate` → Pro unlocks.
5. Refund / subscription-cancel webhook → key revoked.

## One-time setup you must do (needs your Stripe dashboard)

### 1. Get your Stripe secret key
Stripe Dashboard → Developers → API keys → copy the **Secret key** (`sk_live_…`).
```bash
cd license-worker
echo "sk_live_XXXX" | npx wrangler secret put STRIPE_SECRET_KEY
```

### 2. Add the webhook (for refunds/cancellations)
Stripe Dashboard → Developers → Webhooks → Add endpoint:
- URL: `https://pointly-licenses.lyubomirstavrev02.workers.dev/api/stripe-webhook`
- Events: `charge.refunded`, `charge.dispute.created`, `customer.subscription.deleted`
- Copy the signing secret (`whsec_…`):
```bash
echo "whsec_XXXX" | npx wrangler secret put STRIPE_WEBHOOK_SECRET
```

### 3. On each of the two products, set the metadata + success URL
When creating the **Payment Link** for each product (Payments → Payment Links → New):
- Under **After payment** → choose **"Don't show confirmation page — redirect"**,
  set URL to: `https://trypointly.com/success?session_id={CHECKOUT_SESSION_ID}`
- Add **metadata**: key `plan`, value `annual` (for the $12.99 product) or
  `lifetime` (for the $39.99 product). *(Optional — the Worker also infers plan
  from the amount, but explicit is better.)*

### 4. Paste the two Payment Link URLs into the site
Edit `website/buy.html`: replace `STRIPE_ANNUAL_LINK` and `STRIPE_LIFETIME_LINK`
with the two payment-link URLs, then from repo root:
```bash
npm run deploy
```

## Test the whole chain
Use Stripe **test mode** first: put a `sk_test_…` secret, make test payment links,
pay with card `4242 4242 4242 4242`, confirm the success page shows a key and the
app activates it. Then switch to live keys/links.

## Admin (manual key, e.g. a colleague or comp)
```bash
# mint a key by hand
curl -XPOST https://pointly-licenses.lyubomirstavrev02.workers.dev/api/activate ...
# — or add a KV entry directly:
npx wrangler kv key put --binding=LICENSES "key:POINTLY-TEST-1234-5678-90AB" \
  '{"plan":"lifetime","email":"friend@x.com","status":"active","seatLimit":5,"activations":[],"createdAt":0}'
```
