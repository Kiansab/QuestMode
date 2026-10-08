/**
 * Vlix — tiny API for one OpenAI key on YOUR server (no Firebase Blaze).
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

import crypto from "crypto";
import express from "express";
import admin from "firebase-admin";
import OpenAI from "openai";
import {
  verificationEmailHTML,
  passwordResetEmailHTML,
  verifyConfirmPageHTML,
  verifySuccessPageHTML,
  verifyErrorPageHTML,
  resetPasswordPageHTML,
  resetPasswordSuccessPageHTML,
  resetOpenAppPageHTML,
} from "./emailTemplates.mjs";

const MODEL = "gpt-4o-mini";
const PORT = process.env.PORT || 8787;
const RESEND_API_KEY = process.env.RESEND_API_KEY?.trim() || "";
/** Production FROM — never default to resend.dev (owner-only test mode). */
const RESEND_FROM =
  process.env.RESEND_FROM?.trim() || "Vlix <noreply@vlix.app>";
const AUTH_CONTINUE_URL =
  process.env.AUTH_CONTINUE_URL?.trim() || "https://vlix-298cc.firebaseapp.com";
const PUBLIC_BASE = (
  process.env.PUBLIC_BASE_URL || "https://vlix-cjdr.onrender.com"
).replace(/\/$/, "");

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
        "NOT PRODUCTION-READY: RESEND_FROM uses resend.dev (owner-only test mode). Set RESEND_FROM=Vlix <noreply@vlix.app> after vlix.app is Verified in Resend, then redeploy",
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
          : `NOT PRODUCTION-READY: Domain ${fromDomain} not found in Resend — add vlix.app, complete DNS at Vercel, then set RESEND_FROM=Vlix <noreply@vlix.app>`,
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
        "Branded email is not production-ready (brandedEmailReady=false). Verify vlix.app in Resend and set RESEND_FROM."
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

function html(res, body) {
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.send(body);
}

/** Pull the one-time code out of Firebase's link so the email never opens Firebase's page. */
function vlixActionUrl(firebaseLink, path, theme = "dark") {
  const params = new URL(firebaseLink).searchParams;
  const code = params.get("oobCode") || "";
  const apiKey = params.get("apiKey") || "";
  const url = new URL(path, PUBLIC_BASE);
  url.searchParams.set("code", code);
  url.searchParams.set("key", apiKey);
  url.searchParams.set("theme", theme === "light" ? "light" : "dark");
  return url.toString();
}

function vlixVerifyUrl(firebaseLink, theme = "dark") {
  return vlixActionUrl(firebaseLink, "/auth/verify", theme);
}

function vlixResetUrl(firebaseLink, theme = "dark", session = "") {
  const url = new URL(vlixActionUrl(firebaseLink, "/auth/reset", theme));
  if (session) url.searchParams.set("session", session);
  return url.toString();
}

/** session id → { code, apiKey, expires } once the email link is opened. */
const passwordResetSessions = new Map();

function rememberPasswordResetSession(session) {
  const id = String(session || "");
  if (!id) return;
  passwordResetSessions.set(id, { code: "", apiKey: "", expires: Date.now() + 20 * 60 * 1000 });
}

function confirmPasswordResetSession(session, code, apiKey) {
  const row = passwordResetSessions.get(String(session || ""));
  if (!row || Date.now() > row.expires) return;
  row.code = String(code || "");
  row.apiKey = String(apiKey || "");
}

function themeFrom(value) {
  return String(value || "").toLowerCase() === "light" ? "light" : "dark";
}

app.get("/auth/verify", (req, res) => {
  const code = String(req.query.code || "");
  const apiKey = String(req.query.key || "");
  const theme = themeFrom(req.query.theme);
  if (!code || !apiKey) {
    return html(res, verifyErrorPageHTML("This link is incomplete. Go back to Vlix and tap Resend email.", theme));
  }
  html(res, verifyConfirmPageHTML({ code, apiKey, theme }));
});

app.get("/auth/reset", (req, res) => {
  const code = String(req.query.code || "");
  const apiKey = String(req.query.key || "");
  const theme = themeFrom(req.query.theme);
  if (!code || !apiKey) {
    return html(res, verifyErrorPageHTML("This reset link is incomplete. Go back to Vlix and send it again.", theme));
  }
  const session = String(req.query.session || "");
  confirmPasswordResetSession(session, code, apiKey);
  html(res, resetOpenAppPageHTML({ theme }));
});

app.post("/auth/reset", express.urlencoded({ extended: false }), async (req, res) => {
  const code = String(req.body?.code || "");
  const apiKey = String(req.body?.apiKey || "");
  const theme = themeFrom(req.body?.theme);
  const password = String(req.body?.password || "");
  const confirm = String(req.body?.confirm || "");
  if (!code || !apiKey) {
    return html(res, verifyErrorPageHTML("This reset link is incomplete. Go back to Vlix and send it again.", theme));
  }
  if (password.length < 6) {
    return html(res, resetPasswordPageHTML({ code, apiKey, theme, error: "Use at least 6 characters." }));
  }
  if (password !== confirm) {
    return html(res, resetPasswordPageHTML({ code, apiKey, theme, error: "Those passwords don’t match." }));
  }
  try {
    const r = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:resetPassword?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ oobCode: code, newPassword: password }),
      }
    );
    const body = await r.json().catch(() => ({}));
    if (!r.ok) {
      const message = String(body?.error?.message || "");
      if (message === "INVALID_OOB_CODE" || message === "EXPIRED_OOB_CODE") {
        return html(res, verifyErrorPageHTML("This link expired. Go back to Vlix and send a new one.", theme));
      }
      if (message.startsWith("WEAK_PASSWORD")) {
        return html(res, resetPasswordPageHTML({ code, apiKey, theme, error: "That password is too easy. Try a longer one." }));
      }
      console.error("reset action failed", message || r.status);
      return html(res, resetPasswordPageHTML({ code, apiKey, theme, error: "Couldn’t save that password. Send a new link from Vlix." }));
    }
    return html(res, resetPasswordSuccessPageHTML(theme));
  } catch (e) {
    console.error(e);
    return html(res, resetPasswordPageHTML({ code, apiKey, theme, error: "Couldn’t reach the password service. Try again." }));
  }
});

app.post("/auth/verify", express.urlencoded({ extended: false }), async (req, res) => {
  const code = String(req.body?.code || "");
  const apiKey = String(req.body?.apiKey || "");
  const theme = themeFrom(req.body?.theme);
  if (!code || !apiKey) {
    return html(res, verifyErrorPageHTML("This link is incomplete. Go back to Vlix and tap Resend email.", theme));
  }
  try {
    const r = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:update?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ oobCode: code }),
      }
    );
    const body = await r.json().catch(() => ({}));
    if (!r.ok) {
      const message = String(body?.error?.message || "");
      if (message === "INVALID_OOB_CODE" || message === "EXPIRED_OOB_CODE") {
        return html(res, verifyErrorPageHTML("This link expired. Go back to Vlix and tap Resend email.", theme));
      }
      console.error("verify action failed", message || r.status);
      return html(res, verifyErrorPageHTML("Couldn't verify that link. Go back to Vlix and tap Resend email.", theme));
    }
    return html(res, verifySuccessPageHTML(theme));
  } catch (e) {
    console.error(e);
    return html(res, verifyErrorPageHTML("Couldn't verify that link. Go back to Vlix and tap Resend email.", theme));
  }
});

app.get("/auth/verified", (_req, res) => {
  html(res, verifySuccessPageHTML());
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
 * Branded auth emails (Vlix UI). Requires RESEND_API_KEY.
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
      const theme = themeFrom(req.body?.theme);
      await sendResendEmail({
        to: email,
        subject: "Verify your Vlix email",
        html: verificationEmailHTML({
          displayName: user.displayName || "",
          verifyUrl: vlixVerifyUrl(link, theme),
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
    const theme = themeFrom(req.body?.theme);
    const session = crypto.randomBytes(24).toString("hex");
    rememberPasswordResetSession(session);
    await sendResendEmail({
      to: email,
      subject: "Reset your Vlix password",
      html: passwordResetEmailHTML({ resetUrl: vlixResetUrl(link, theme, session) }),
    });
    return res.json({ ok: true, session });
  } catch (e) {
    console.error(e);
    return res.status(e.status || 502).json({
      error: e.message || "Email send failed",
      code: e.code || undefined,
    });
  }
});

app.get("/v1/password-reset-ready", (req, res) => {
  const session = String(req.query.session || "");
  const row = passwordResetSessions.get(session);
  if (!row || Date.now() > row.expires || !row.code || !row.apiKey) {
    return res.json({ ready: false });
  }
  return res.json({ ready: true, code: row.code, key: row.apiKey });
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
    onboarding_turn: 880,
    replacement: 420,
    daily_extra: 780,
    daily: 860,
  };
  const tokenCap = Math.min(
    1200,
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
    `Vlix backend listening on ${PORT} (brandedEmail=${Boolean(RESEND_API_KEY)} brandedEmailReady=${branded.ready})`
  );
  if (!branded.ready) {
    console.warn(`[email] NOT PRODUCTION-READY: ${branded.reason}`);
  }
});
