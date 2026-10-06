# Branded Quest Mode emails (looks like the app)

Firebase **locks** the verification email body (anti-spam). To send a polished dark graphite + soft-white email that matches the app, Quest Mode sends mail through your backend with **Resend**.

## What you get

- Dark card, soft-white pill button, Quest Mode typography — same language as login / verification UI
- Verification + password reset
- App falls back to Firebase’s default mail if Resend isn’t set up yet

## One-time setup (≈5 minutes)

### 1. Create a free Resend account
1. Go to https://resend.com/signup  
2. **API Keys** → create a key  
3. Copy it (`re_...`)

### 2. Add env vars on Render (your `questmode.onrender.com` service)
| Variable | Value |
|---|---|
| `RESEND_API_KEY` | your `re_...` key |
| `RESEND_FROM` | `Quest Mode <onboarding@resend.dev>` *(works immediately for testing)* |
| `AUTH_CONTINUE_URL` | `https://questmode-298cc.firebaseapp.com` *(optional; already the default)* |

Redeploy / restart the service after saving.

### 3. Confirm it’s live
Open: https://questmode.onrender.com/health  

You should see `"brandedEmail": true`.

### 4. Test
Sign up with a real inbox → you should get the dark Quest Mode email. Tap **Verify email**.

## Looking fully professional (custom domain)

`onboarding@resend.dev` is fine for testing. For production:

1. In Resend → **Domains** → add `questmode.app` (or whatever you own)  
2. Add the DNS records Resend shows  
3. Change env:
   ```
   RESEND_FROM=Quest Mode <noreply@questmode.app>
   ```
4. Redeploy

Your Info.plist already lists `support@questmode.app` — use the same domain for mail once DNS is verified.

## Firebase Console templates

You can leave Firebase’s verification body alone (it’s locked). Branded mail now comes from Resend. Password-reset branding also goes through the backend when Resend is configured.
