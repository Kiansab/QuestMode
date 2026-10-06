# Branded Quest Mode emails (Resend only)

Verification + password-reset mail is sent by **Resend** through the Quest Mode backend.
Firebase Auth still stores accounts and generates the secure link — it does **not** send the email.

## Render env

| Variable | Value |
|---|---|
| `RESEND_API_KEY` | `re_...` from https://resend.com/api-keys |
| `RESEND_FROM` | `Quest Mode <noreply@questmode.app>` after domain is **Verified** |
| `AUTH_CONTINUE_URL` | `https://questmode-298cc.firebaseapp.com` |

## Make Resend deliver to everyone (required)

`onboarding@resend.dev` is **test mode** — only the Resend account owner gets mail. That is why you’re not receiving verification emails.

1. Resend → **Domains** → add **`questmode.app`**
2. Copy every DNS record Resend shows
3. Add them in **Vercel** → Project/Domain for `questmode.app` → DNS  
   (nameservers are already `ns1/ns2.vercel-dns.com`)
4. Wait until Resend shows the domain **Verified**
5. On Render set:
   ```
   RESEND_FROM=Quest Mode <noreply@questmode.app>
   ```
6. Redeploy, then open https://questmode-cjdr.onrender.com/health  
   Expect: `"brandedEmailReady": true`

## Health fields

- `brandedEmail: true` — API key present  
- `brandedEmailReady: true` — safe to email any inbox from your domain  

## App behavior

The iOS app calls `POST /v1/send-auth-email` only (no Firebase mail fallback).
