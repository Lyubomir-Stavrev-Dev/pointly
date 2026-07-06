# Deploying trypointly.com (Cloudflare Pages)

The site is the static files in this `website/` folder. It deploys to
Cloudflare Pages (project name `pointly`, served at `pointly.pages.dev`), and
`trypointly.com` is attached as a custom domain.

## One-time setup

1. **Buy the domain on the SAME Cloudflare account as the Pages project.**
   Cloudflare Dashboard → **Domain Registration → Register Domains** → buy
   `trypointly.com`. Registering it here means the DNS zone lands on this
   account, so the next step creates the DNS records automatically.

2. **Log in** (opens a browser to authorize the Cloudflare account):
   ```bash
   npm run login
   ```

3. **First deploy** — creates/updates the Pages project named `pointly`:
   ```bash
   npm run deploy
   ```
   If prompted to create the project, accept the defaults (production branch `main`).

4. **Attach the custom domain:**
   - Cloudflare Dashboard → **Workers & Pages** → **pointly** → **Custom domains**
   - Add `trypointly.com` and `www.trypointly.com`
   - Because the domain is on this same account, Cloudflare creates the CNAME
     records automatically. Wait for the certificate to go "Active"
     (usually a minute or two).

## Every deploy after that

```bash
npm run deploy
```

Pushes the current `website/` contents to production.

## Verify it's live (App Store Connect needs this reachable)

```bash
curl -sI https://trypointly.com/privacy.html | head -1   # expect: HTTP/2 200
```

## Local preview

```bash
npm run dev
```
