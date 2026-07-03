# Deploying pointly.app (Cloudflare Pages)

The site is the static files in this `website/` folder. It deploys to
Cloudflare Pages, and the `pointly.app` domain (already on Cloudflare DNS)
is attached as a custom domain.

## One-time setup

1. **Log in** (opens a browser to authorize the Cloudflare account that owns `pointly.app`):
   ```bash
   npm run login
   ```

2. **First deploy** — creates the Pages project named `pointly`:
   ```bash
   npm run deploy
   ```
   If prompted to create the project, accept the defaults (production branch `main`).

3. **Attach the custom domain** (once, in the dashboard):
   - Cloudflare Dashboard → **Workers & Pages** → **pointly** → **Custom domains**
   - Add `pointly.app` and `www.pointly.app`
   - Cloudflare creates the DNS records automatically (both are on this account).
   - Wait for the certificate to go "Active" (usually a minute or two).

## Every deploy after that

```bash
npm run deploy
```

Pushes the current `website/` contents to production.

## Verify it's live (App Store Connect needs this reachable)

```bash
curl -sI https://pointly.app/privacy.html | head -1   # expect: HTTP/2 200
```

## Local preview

```bash
npm run dev
```
