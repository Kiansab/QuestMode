# Production email checklist (Resend only)

Verification and password-reset mail go through **Resend** on the Quest Mode backend.
Firebase Auth stores accounts and **Admin SDK generates the secure links** — Firebase does **not** send the email.

There is **no** Firebase mail fallback and **no** owner-only test path for launch.
Mail works for everyone only when the steps below are done.

## Required Render env

| Variable | Value |
|---|---|
| `RESEND_API_KEY` | `re_...` from https://resend.com/api-keys |
| `RESEND_FROM` | `Quest Mode <noreply@questmode.app>` |
| `AUTH_CONTINUE_URL` | `https://questmode-298cc.firebaseapp.com` |

Do **not** set `RESEND_FROM` to any `@resend.dev` address. That is Resend test mode and only delivers to the Resend account owner.

## Launch checklist (in order)

1. **Resend** → Domains → add **`questmode.app`**
2. Copy every DNS record Resend shows (TXT / CNAME / etc.)
3. Add those records in **Vercel** → Domains → `questmode.app` → DNS  
   (nameservers should already be `ns1.vercel-dns.com` / `ns2.vercel-dns.com`)
4. Wait until Resend shows the domain status **Verified**
5. On **Render** set exactly:
   ```
   RESEND_FROM=Quest Mode <noreply@questmode.app>
   ```
   (and keep `RESEND_API_KEY` set)
6. **Redeploy** the backend
7. Open https://questmode-cjdr.onrender.com/health  
   Expect:
   ```json
   "brandedEmailReady": true,
   "productionEmailReady": true
   ```
   If either is `false`, read `brandedEmailReason` — do not ship.

## Health fields

| Field | Meaning |
|---|---|
| `brandedEmail: true` | `RESEND_API_KEY` is present |
| `brandedEmailReady: true` | FROM domain is **Verified** in Resend — safe for every inbox |
| `productionEmailReady` | Same gate as `brandedEmailReady` (launch checklist alias) |
| `brandedEmailFromIsTestAddress: true` | Still on `@resend.dev` — **not** launch-ready |
| `brandedEmailReason` | Human-readable blocker when not ready |

## App behavior

The iOS app calls `POST /v1/send-auth-email` only.
The backend refuses to send until `brandedEmailReady` is true (HTTP 503), so users get a clear error instead of silent owner-only delivery.
