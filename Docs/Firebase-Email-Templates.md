# Branded Quest Mode emails (looks like the app)

Firebase **locks** the verification email body (anti-spam). To send a polished dark graphite + soft-white email that matches the app, Quest Mode sends mail through your backend with **Resend**.

Until Resend is production-ready, the **iOS app automatically falls back to Firebase’s default verification email** so sign-up is not blocked.

## What you get

- Dark card, soft-white pill button, Quest Mode typography — same language as login / verification UI
- Verification + password reset
- App falls back to Firebase’s default mail if Resend isn’t ready (unverified domain, `resend.dev` test FROM, missing key)

## One-time setup (≈5 minutes)

### 1. Create a free Resend account
1. Go to https://resend.com/signup  
2. **API Keys** → create a key  
3. Copy it (`re_...`)

### 2. Add env vars on Render (`questmode-cjdr.onrender.com`)
| Variable | Value |
|---|---|
| `RESEND_API_KEY` | your `re_...` key |
| `RESEND_FROM` | `Quest Mode <onboarding@resend.dev>` *(owner-only tests)* **or** `Quest Mode <noreply@questmode.app>` after DNS is **Verified** |
| `AUTH_CONTINUE_URL` | `https://questmode-298cc.firebaseapp.com` *(default; must be a Firebase authorized domain)* |

Redeploy / restart the service after saving.

### 3. Confirm it’s live
Open: https://questmode-cjdr.onrender.com/health  

You should see:
- `"brandedEmail": true` — API key is present
- `"brandedEmailReady": true` — domain verified and safe to send to any inbox

If `brandedEmailReady` is **false**, read `brandedEmailReason`. The app will use **Firebase** mail until this is true.

### 4. Test
Sign up with a real inbox → open the message (check Junk/Spam on Hotmail/Outlook) → tap **Verify email** → return to the app (it polls / has **I’ve verified**).

## Looking fully professional (custom domain)

`onboarding@resend.dev` is **test mode**: Resend only delivers to the Resend account owner. The backend treats that as **not ready** so the app uses Firebase for everyone else.

For production branded mail:

1. In Resend → **Domains** → add `questmode.app`  
2. Add **all** DNS records Resend shows (DKIM / SPF / etc.) at your DNS host (currently Vercel DNS for `questmode.app`)  
3. Wait until Resend shows the domain as **Verified** (not Pending)  
4. On Render set:
   ```
   RESEND_FROM=Quest Mode <noreply@questmode.app>
   ```
5. Redeploy, then confirm `/health` shows `"brandedEmailReady": true`

Your Info.plist already lists `support@questmode.app` — use the same domain for mail once DNS is verified.

### DNS check (should be non-empty after setup)
```bash
dig +short CNAME resend._domainkey.questmode.app
dig +short TXT questmode.app
```

As of the last investigation, **no Resend DNS records** were published for `questmode.app` — that is why branded mail cannot go out from `@questmode.app`.

## Optional: nicer “You're verified” browser page

1. Firebase Console → Authentication → Settings → **Authorized domains** → add `questmode-cjdr.onrender.com`  
2. Render env:
   ```
   AUTH_CONTINUE_URL=https://questmode-cjdr.onrender.com/auth/verified
   ```
3. Redeploy  

(The default Firebase continue URL works for verification even if the root page 404s after success.)

## Firebase Console templates

You can leave Firebase’s verification body alone (it’s locked). Branded mail comes from Resend only when `brandedEmailReady` is true. Password-reset branding uses the same path.
