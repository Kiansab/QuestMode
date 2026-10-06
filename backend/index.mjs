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
const RESEND_FROM = process.env.RESEND_FROM?.trim() || "Quest Mode <onboarding@resend.dev>";
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
    const err = new Error(body?.message || body?.error || `Resend failed (${r.status})`);
    err.status = 502;
    throw err;
  }
  return body;
}

app.get("/", (_req, res) => {
  res.json({
    ok: true,
    hint: "Use GET /health, POST /v1/quest-chat, or POST /v1/send-auth-email",
    brandedEmail: Boolean(RESEND_API_KEY),
  });
});

app.get("/health", (_req, res) => {
  const key = process.env.OPENAI_API_KEY?.trim() || "";
  const openaiKeyPresent = Boolean(key);
  // sk- = OpenAI secret; re_ = Resend (wrong env paste) — never echo the key.
  const openaiKeyLooksValid = key.startsWith("sk-");
  res.json({
    ok: true,
    brandedEmail: Boolean(RESEND_API_KEY),
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
    return res.status(e.status || 502).json({ error: e.message || "Email send failed" });
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

app.listen(PORT, () => {
  console.log(`Quest Mode backend listening on ${PORT} (brandedEmail=${Boolean(RESEND_API_KEY)})`);
});
