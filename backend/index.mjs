/**
 * Quest Mode — tiny API for one OpenAI key on YOUR server (no Firebase Blaze).
 *
 * Env:
 *   OPENAI_API_KEY          — your secret key from OpenAI
 *   FIREBASE_SERVICE_ACCOUNT_JSON — full JSON string of Firebase service account (Project settings → Service accounts)
 *
 * Or set GOOGLE_APPLICATION_CREDENTIALS to a path (local dev).
 *
 * POST /v1/quest-chat
 *   Authorization: Bearer <Firebase ID token from the app>
 *   Body: { "promptVersion": 1, "kind": "daily"|"replacement"|"ping", "systemPrompt": "...", "userPrompt": "..." }
 *
 * Response: { "assistantContent": "..." } or { "pong": true } for ping
 */

import express from "express";
import admin from "firebase-admin";
import OpenAI from "openai";
import { verificationEmailHTML, passwordResetEmailHTML } from "./emailTemplates.mjs";

const MODEL = "gpt-4o-mini";
const PORT = process.env.PORT || 8787;
const RESEND_API_KEY = process.env.RESEND_API_KEY?.trim() || "";
/** Production FROM — never default to resend.dev (owner-only test mode). */
const RESEND_FROM =
  process.env.RESEND_FROM?.trim() || "Quest Mode <noreply@questmode.app>";
const AUTH_CONTINUE_URL =
  process.env.AUTH_CONTINUE_URL?.trim() || "https://questmode-298cc.firebaseapp.com";

if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)),
  });
} else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  admin.initializeApp();
} else {
  console.error("Set FIREBASE_SERVICE_ACCOUNT_JSON or GOOGLE_APPLICATION_CREDENTIALS");
  process.exit(1);
}

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
if (!process.env.OPENAI_API_KEY?.trim()) {
  console.error("Set OPENAI_API_KEY");
  process.exit(1);
}

const app = express();
app.use(express.json({ limit: "512kb" }));

/** Extract email domain from `Name <user@domain>` or bare `user@domain`. */
function resendFromDomain() {
  const m = RESEND_FROM.match(/@([A-Za-z0-9.-]+\.[A-Za-z]{2,})/);
  return m?.[1]?.toLowerCase() || "";
}

function resendFromIsTestAddress() {
  return resendFromDomain() === "resend.dev";
}

/**
 * Resend only delivers broadly when FROM uses a verified domain (not resend.dev test mode).
 * Cached briefly so /health and send-auth-email stay cheap.
 */
let resendReadyCache = { at: 0, value: null };

async function getBrandedEmailStatus() {
  const now = Date.now();
  if (resendReadyCache.value && now - resendReadyCache.at < 60_000) {
    return resendReadyCache.value;
  }

  const fromDomain = resendFromDomain();
  const base = {
    configured: Boolean(RESEND_API_KEY),
    fromDomain: fromDomain || null,
    fromIsTestAddress: resendFromIsTestAddress(),
  };

  if (!RESEND_API_KEY) {
    const value = {
      ...base,
      ready: false,
      reason: "NOT PRODUCTION-READY: RESEND_API_KEY missing on Render",
    };
    resendReadyCache = { at: now, value };
    return value;
  }

  if (resendFromIsTestAddress()) {
    // resend.dev only delivers to the Resend account owner — not launch-ready.
    const value = {
      ...base,
      ready: false,
      reason:
        "NOT PRODUCTION-READY: RESEND_FROM uses resend.dev (owner-only test mode). Set RESEND_FROM=Quest Mode <noreply@questmode.app> after questmode.app is Verified in Resend, then redeploy",
    };
    resendReadyCache = { at: now, value };
    return value;
  }

  try {
    const r = await fetch("https://api.resend.com/domains", {
      headers: { Authorization: `Bearer ${RESEND_API_KEY}` },
    });
    const body = await r.json().catch(() => ({}));
    if (!r.ok) {
      const value = {
        ...base,
        ready: false,
        reason: body?.message || `Resend domains API failed (${r.status})`,
      };
      resendReadyCache = { at: now, value };
      return value;
    }
    const domains = Array.isArray(body?.data) ? body.data : [];
    const match = domains.find(
      (d) => String(d?.name || "").toLowerCase() === fromDomain
    );
    const status = String(match?.status || "").toLowerCase();
    const verified = status === "verified";
    const value = {
      ...base,
      ready: verified,
      domainStatus: match ? status : "missing",
      reason: verified
        ? "ok"
        : match
          ? `NOT PRODUCTION-READY: Domain ${fromDomain} status is "${status}" (need verified) — add Resend DNS at Vercel, wait for Verified`
          : `NOT PRODUCTION-READY: Domain ${fromDomain} not found in Resend — add questmode.app, complete DNS at Vercel, then set RESEND_FROM=Quest Mode <noreply@questmode.app>`,
    };
    resendReadyCache = { at: now, value };
    return value;
  } catch (e) {
    const value = {
      ...base,
      ready: false,
      reason: e?.message || "Resend domain check failed",
    };
    resendReadyCache = { at: now, value };
    return value;
  }
}

async function verifyBearer(req) {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    const err = new Error("Missing Authorization Bearer token");
    err.status = 401;
    throw err;
  }
  try {
    return await admin.auth().verifyIdToken(authHeader.slice(7));
  } catch {
    const err = new Error("Invalid or expired Firebase ID token");
    err.status = 401;
    throw err;
  }
}

async function sendResendEmail({ to, subject, html }) {
  if (!RESEND_API_KEY) {
    const err = new Error("RESEND_API_KEY is not configured on the server");
    err.status = 503;
    throw err;
  }

  const branded = await getBrandedEmailStatus();
  if (!branded.ready) {
    const err = new Error(
      branded.reason ||
        "Branded email is not production-ready (brandedEmailReady=false). Verify questmode.app in Resend and set RESEND_FROM."
    );
    err.status = 503;
    err.code = "branded_email_not_ready";
    throw err;
  }

  const r = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: RESEND_FROM,
      to: [to],
      subject,
      html,
    }),
  });
  const body = await r.json().catch(() => ({}));
  if (!r.ok) {
    const msg = body?.message || body?.error || `Resend failed (${r.status})`;
    const err = new Error(msg);
    err.status = 502;
    err.code = "resend_send_failed";
    throw err;
  }
  return body;
}

app.get("/", async (_req, res) => {
  const branded = await getBrandedEmailStatus();
  res.json({
    ok: true,
    hint: "Use GET /health, POST /v1/quest-chat, or POST /v1/send-auth-email",
    brandedEmail: Boolean(RESEND_API_KEY),
    brandedEmailReady: branded.ready,
  });
});

/** Post-verify landing (optional AUTH_CONTINUE_URL). Must be on Firebase authorized domains if used. */
app.get("/auth/verified", (_req, res) => {
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.send(`<!DOCTYPE html>
<html lang="en"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Email verified — Quest Mode</title>
<style>
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
font-family:-apple-system,BlinkMacSystemFont,sans-serif;background:#0d0d0f;color:#e0e0e4;text-align:center;padding:24px;}
h1{font-size:1.6rem;margin:0 0 12px;letter-spacing:-0.03em;}
p{color:#8a8a90;line-height:1.5;margin:0;max-width:28rem;}
</style></head><body>
<div>
  <h1>You're verified</h1>
  <p>Return to Quest Mode — it will unlock automatically. You can close this tab.</p>
</div>
</body></html>`);
});

app.get("/health", async (_req, res) => {
  const key = process.env.OPENAI_API_KEY?.trim() || "";
  const openaiKeyPresent = Boolean(key);
  // sk- = OpenAI secret; re_ = Resend (wrong env paste) — never echo the key.
  const openaiKeyLooksValid = key.startsWith("sk-");
  const branded = await getBrandedEmailStatus();
  res.json({
    ok: true,
    brandedEmail: Boolean(RESEND_API_KEY),
    /** true only when FROM domain is Verified in Resend — safe for every inbox */
    brandedEmailReady: branded.ready,
    brandedEmailFrom: RESEND_FROM,
    brandedEmailFromDomain: branded.fromDomain,
    brandedEmailFromIsTestAddress: branded.fromIsTestAddress,
    brandedEmailDomainStatus: branded.domainStatus || null,
    brandedEmailReason: branded.reason,
    /** Explicit launch gate: do not ship auth email until this is true */
    productionEmailReady: branded.ready,
    authContinueUrl: AUTH_CONTINUE_URL,
    openaiKeyPresent,
    openaiKeyLooksValid,
  });
});

/** Tiny authenticated OpenAI smoke test — confirms the server key can chat. */
app.get("/health/openai", async (req, res) => {
  try {
    await verifyBearer(req);
  } catch (e) {
    return res.status(e.status || 401).json({ error: e.message });
  }
  const key = process.env.OPENAI_API_KEY?.trim() || "";
  if (!key) {
    return res.status(503).json({ ok: false, error: "OPENAI_API_KEY missing" });
  }
  if (!key.startsWith("sk-")) {
    return res.status(503).json({
      ok: false,
      error: "OPENAI_API_KEY does not look like an OpenAI secret key (should start with sk-)",
    });
  }
  try {
    const chat = await openai.chat.completions.create({
      model: MODEL,
      temperature: 0,
      max_tokens: 8,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: "Reply with JSON only." },
        { role: "user", content: 'Return {"ok":true}' },
      ],
    });
    const content = chat.choices[0]?.message?.content?.trim() || "";
    return res.json({ ok: true, sample: content.slice(0, 80) });
  } catch (e) {
    console.error(e);
    return res.status(502).json({ ok: false, error: e?.message || "OpenAI request failed" });
  }
});

/**
 * Branded auth emails (Quest Mode UI). Requires RESEND_API_KEY.
 * Body: { "kind": "verify" | "password_reset", "email"?: string }
 * - verify: caller must be signed in; email defaults to token email
 * - password_reset: email required (no auth) — rate-limited lightly by requiring a known user
 */
app.post("/v1/send-auth-email", async (req, res) => {
  try {
    const kind = String(req.body?.kind || "");
    if (kind !== "verify" && kind !== "password_reset") {
      return res.status(400).json({ error: "kind must be verify or password_reset" });
    }

    if (kind === "verify") {
      const decoded = await verifyBearer(req);
      const user = await admin.auth().getUser(decoded.uid);
      const email = user.email;
      if (!email) {
        return res.status(400).json({ error: "Signed-in user has no email" });
      }
      if (user.emailVerified) {
        return res.json({ ok: true, alreadyVerified: true });
      }
      const link = await admin.auth().generateEmailVerificationLink(email, {
        url: AUTH_CONTINUE_URL,
        handleCodeInApp: false,
      });
      await sendResendEmail({
        to: email,
        subject: "Verify your Quest Mode email",
        html: verificationEmailHTML({
          displayName: user.displayName || "",
          verifyUrl: link,
        }),
      });
      return res.json({ ok: true });
    }

    // password_reset — no Bearer required; only send if account exists
    const email = String(req.body?.email || "")
      .trim()
      .toLowerCase();
    if (!email || !email.includes("@")) {
      return res.status(400).json({ error: "Valid email required" });
    }
    let user;
    try {
      user = await admin.auth().getUserByEmail(email);
    } catch {
      // Do not reveal whether the email exists
      return res.json({ ok: true });
    }
    const link = await admin.auth().generatePasswordResetLink(email, {
      url: AUTH_CONTINUE_URL,
      handleCodeInApp: false,
    });
    await sendResendEmail({
      to: email,
      subject: "Reset your Quest Mode password",
      html: passwordResetEmailHTML({ resetUrl: link }),
    });
    return res.json({ ok: true, uidHint: Boolean(user) });
  } catch (e) {
    console.error(e);
    return res.status(e.status || 502).json({
      error: e.message || "Email send failed",
      code: e.code || undefined,
    });
  }
});

app.post("/v1/quest-chat", async (req, res) => {
  try {
    await verifyBearer(req);
  } catch (e) {
    return res.status(e.status || 401).json({ error: e.message });
  }

  const { promptVersion, kind, systemPrompt, userPrompt, maxTokens, temperature } = req.body || {};
  if (kind === "ping") {
    return res.json({ pong: true });
  }
  if (promptVersion !== 1) {
    return res.status(400).json({ error: "Unsupported promptVersion" });
  }
  const sys = String(systemPrompt ?? "");
  const usr = String(userPrompt ?? "");
  if (!sys.trim() || !usr.trim()) {
    return res.status(400).json({ error: "Missing systemPrompt or userPrompt" });
  }
  if (sys.length > 12000 || usr.length > 48000) {
    return res.status(400).json({ error: "Prompt too large" });
  }

  const kindCaps = {
    onboarding_turn: 320,
    replacement: 280,
    daily_extra: 420,
    daily: 520,
  };
  const tokenCap = Math.min(
    900,
    Math.max(120, Number(maxTokens) || kindCaps[kind] || 480)
  );
  const temp = typeof temperature === "number" && temperature >= 0 && temperature <= 1.2
    ? temperature
    : 0.5;

  try {
    const chat = await openai.chat.completions.create({
      model: MODEL,
      temperature: temp,
      max_tokens: tokenCap,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: sys },
        { role: "user", content: usr },
      ],
    });
    const content = chat.choices[0]?.message?.content?.trim();
    if (!content) {
      return res.status(502).json({ error: "Empty model response" });
    }
    return res.json({ assistantContent: content });
  } catch (e) {
    console.error(e);
    return res.status(502).json({ error: e?.message || "OpenAI request failed" });
  }
});

app.listen(PORT, async () => {
  const branded = await getBrandedEmailStatus();
  console.log(
    `Quest Mode backend listening on ${PORT} (brandedEmail=${Boolean(RESEND_API_KEY)} brandedEmailReady=${branded.ready})`
  );
  if (!branded.ready) {
    console.warn(`[email] NOT PRODUCTION-READY: ${branded.reason}`);
  }
});
