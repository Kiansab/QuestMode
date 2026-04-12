import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import OpenAI from "openai";

const openaiApiKey = defineSecret("OPENAI_API_KEY");
const MODEL = "gpt-4o-mini";

/**
 * Authenticated users only. Set secret: firebase functions:secrets:set OPENAI_API_KEY
 * iOS calls this when QuestModeUseFirebaseQuestProxy is true (single server-side key).
 */
export const generateQuestsOpenAI = onCall(
  {
    secrets: [openaiApiKey],
    region: "us-central1",
    timeoutSeconds: 120,
    memory: "512MiB",
    maxInstances: 100,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }

    const data = request.data as Record<string, unknown>;
    const kind = String(data.kind ?? "");

    if (kind === "ping") {
      return { pong: true };
    }

    const promptVersion = data.promptVersion;
    if (promptVersion !== 1) {
      throw new HttpsError("invalid-argument", "Unsupported promptVersion.");
    }

    const systemPrompt = String(data.systemPrompt ?? "");
    const userPrompt = String(data.userPrompt ?? "");
    if (systemPrompt.length > 12000 || userPrompt.length > 48000) {
      throw new HttpsError("invalid-argument", "Prompt too large.");
    }
    if (!systemPrompt.trim() || !userPrompt.trim()) {
      throw new HttpsError("invalid-argument", "Missing prompts.");
    }

    const key = openaiApiKey.value();
    if (!key?.trim()) {
      throw new HttpsError("failed-precondition", "Server OPENAI_API_KEY secret is not set.");
    }

    const client = new OpenAI({ apiKey: key });
    const chat = await client.chat.completions.create({
      model: MODEL,
      temperature: 0.85,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
    });

    const content = chat.choices[0]?.message?.content?.trim();
    if (!content) {
      throw new HttpsError("internal", "Empty model response.");
    }
    return { assistantContent: content };
  }
);
