# Quest Mode — pre-release checklist

Use this before you upload a **Release** build or submit for App Review. Check boxes as you go.

---

## 1. Version & build (Xcode)

- [ ] **Marketing version** (`MARKETING_VERSION`, e.g. `1.0`) is what users see on the App Store.
- [ ] **Build number** (`CURRENT_PROJECT_VERSION`) **increments** for every upload to App Store Connect (even if marketing version stays `1.0`).
- [ ] **About** screen in the app shows the expected version/build (reads from the bundle).

**In Xcode:** Project → **QuestMode** target → **General** → Version / Build.

---

## 2. Signing & capabilities

- [ ] **Team** selected; **Signing Certificate** valid; **Provisioning** resolves without errors for **Release**.
- [ ] **Bundle ID** matches App Store Connect: main app **`com.kian.QuestMode`**, widget **`com.kian.QuestMode.widget`** (if the widget ships).
- [ ] **In-App Purchase** capability enabled for the app target if Xcode shows it (StoreKit subscriptions).

---

## 3. App Store Connect (must match the binary)

- [ ] **Subscriptions** created with **exact** product IDs:
  - `com.kian.QuestMode.pro.monthly`
  - `com.kian.QuestMode.pro.yearly`
- [ ] Prices, localizations, and (optional) **free trial / intro offer** set in ASC only.
- [ ] **Paid Applications Agreement**, **banking**, and **tax** completed if selling subscriptions.
- [ ] **Privacy Policy URL** (public HTTPS) filled in ASC.
- [ ] **App Privacy** questionnaire completed to match real behavior (Firebase, analytics, crash, AI, etc.).

---

## 4. Info.plist & configuration (`QuestMode/Info.plist`)

- [ ] **`QuestModeSupportEmail`** — real support email (same one you’ll show on the App Store if required).
- [ ] **`QuestModePublicTermsURL`** / **`QuestModePublicPrivacyURL`** — optional until you host pages; fill with **https://** URLs when ready.
- [ ] **`ITSAppUsesNonExemptEncryption`** = **NO** (correct if you only use standard HTTPS; change only if counsel says otherwise).
- [ ] **Backend URL** (`QuestModeQuestBackendURL`) — confirm **`https://questmode-cjdr.onrender.com`** is your **production** server (or update before release).
- [ ] **`QuestModeFallbackFromProxyToDirectOpenAI`** = **NO** (production uses server OpenAI key only).
- [ ] **Auth email (launch blocker until green):** Resend domain `questmode.app` **Verified**, Render `RESEND_FROM=Quest Mode <noreply@questmode.app>`, redeploy, then https://questmode-cjdr.onrender.com/health shows **`brandedEmailReady`: true**. See `Docs/Firebase-Email-Templates.md`.
- [ ] **Firebase:** `GoogleService-Info.plist` is the **production** Firebase project (not a dev/staging plist by mistake).
- [ ] **Firestore rules** are **published** for that same project (`PROJECT_ID` in the plist). The repo’s rules live in `firebase/firestore.rules` (allows each signed-in user `users/{uid}` only). From the repo root, with Firebase CLI logged in: `firebase deploy --only firestore:rules`. **If rules still say “deny all” (`if false`) in the console, cloud sync will always fail with “missing or insufficient permissions” — internet connection is not the cause.**
- [ ] **App Check:** The app configures Firebase App Check before startup. If **Firestore** (or other products) have **App Check enforcement** on in the Firebase Console, **Debug** and **Simulator** builds must register the **App Check debug token** (printed in the Xcode console when the app runs) under **Firebase Console → App Check → your iOS app → Manage debug tokens**. Release builds use App Attest (add the **App Attest** capability in Xcode if Apple prompts). If sync still shows “permission” errors with correct rules, try **temporarily** disabling App Check enforcement for Firestore to confirm that was the blocker.

---

## 5. Secrets & API keys (do not ship leaks)

- [ ] **`OpenAISecrets.plist`** is **gitignored** — never commit real keys. For CI/TestFlight, inject secrets via a secure method your team uses, or rely on **remote AI / proxy** only.
- [ ] No API keys pasted into Swift source or committed plist templates.

---

## 6. Subscriptions (in-app behavior)

- [ ] **Local:** Xcode scheme may use `QuestMode/QuestModePro.storekit` for **Run** only — clear StoreKit Configuration before App Store–bound archive if you want a pure sandbox run; shipping binary uses App Store / Sandbox, not the `.storekit` file.
- [ ] **Sandbox** (TestFlight / ASC sandbox): purchase, **restore**, and **expired** subscription (theme + quest limits) behave as expected.
- [ ] Paywall shows **Terms**, **Privacy**, renewal copy, and **Manage subscription** link.

---

## 7. Legal copy

- [ ] **`LegalDocumentView`** Terms & Privacy reviewed or replaced by **your lawyer** for your jurisdictions (templates are not a substitute for legal advice).
- [ ] Contact / governing-law placeholders updated when counsel provides final text.

---

## 8. QA (minimum before “Submit”)

- [ ] Fresh install: sign up / sign in, complete onboarding, complete a quest, see sync if applicable.
- [ ] **Log out / delete account** flows if you offer them (no crashes).
- [ ] **Widget** (if enabled): add from Home Screen after first launch.
- [ ] **Offline / poor network:** app doesn’t corrupt progress; errors are readable.
- [ ] **Crash-free** on main flows (watch Xcode organizer / Crashlytics after TestFlight).

---

## 9. Assets & store listing

- [ ] **App icon** all required sizes in **Assets.xcassets**.
- [ ] **Screenshots** for required device classes (and iPad if you support iPad).
- [ ] **Description** matches what the app does; **subscription** benefits described accurately (6 quests, 3 swaps, recap, worlds).

---

## 10. Final upload

- [ ] **Archive** with **Release** configuration → **Validate App** → **Distribute** to App Store Connect.
- [ ] Paste **`Docs/App-Store-Review-Notes.txt`** (or an updated version) into **App Review Notes**.
- [ ] **Export compliance** question in ASC answered consistently with encryption settings.

---

## Quick reference — paths in this repo

| Topic | Location |
|--------|----------|
| Subscription product IDs | `QuestMode/SubscriptionProductIDs.swift` |
| Step-by-step first submission | `Docs/Step-By-Step-First-Time.md` |
| ASC & compliance detail | `Docs/AppStoreConnect-Setup.md` |
| Review notes template | `Docs/App-Store-Review-Notes.txt` |

After each release, bump **build number** and repeat sections **3–10** as needed.
