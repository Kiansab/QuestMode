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

const MODEL = "gpt-4o-mini";
const PORT = process.env.PORT || 8787;

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

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.post("/v1/quest-chat", async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Missing Authorization Bearer token" });
  }
  const idToken = authHeader.slice(7);
  try {
    await admin.auth().verifyIdToken(idToken);
  } catch {
    return res.status(401).json({ error: "Invalid or expired Firebase ID token" });
  }

  const { promptVersion, kind, systemPrompt, userPrompt } = req.body || {};
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

  try {
    const chat = await openai.chat.completions.create({
      model: MODEL,
      temperature: 0.85,
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
  console.log(`Quest Mode backend listening on ${PORT}`);
});
