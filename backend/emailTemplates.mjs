/**
 * Vlix branded auth emails (dark graphite + soft white — matches app chrome).
 */

export function verificationEmailHTML({ displayName, verifyUrl }) {
  const hello = displayName?.trim()
    ? `Hi ${escapeHtml(displayName.trim().split(/\s+/)[0])},`
    : "Welcome to Vlix.";
  return layout({
    eyebrow: "Vlix",
    title: "Verify your email",
    lead: `${hello} One tap confirms it’s you — then we build daily habits around your real goals.`,
    ctaLabel: "Verify email",
    ctaUrl: verifyUrl,
    footnote: "If you didn’t create a Vlix account, you can ignore this message.",
  });
}

export function passwordResetEmailHTML({ resetUrl }) {
  return layout({
    eyebrow: "Vlix",
    title: "Reset your password",
    lead: "Tap below to choose a new password. If you didn’t ask for this, you can ignore the email.",
    ctaLabel: "Reset password",
    ctaUrl: resetUrl,
    footnote: "This link expires for your security.",
  });
}

function layout({ eyebrow, title, lead, ctaLabel, ctaUrl, footnote }) {
  const safeUrl = escapeAttr(ctaUrl);
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="color-scheme" content="light dark" />
  <meta name="supported-color-schemes" content="light dark" />
  <title>${escapeHtml(title)}</title>
  <style>
    @media (prefers-color-scheme: light) {
      .vlix-bg { background:#f4f4f5 !important; }
      .vlix-card { background:#ffffff !important; border-color:rgba(0,0,0,.08) !important; }
      .vlix-title { color:#141416 !important; }
      .vlix-muted { color:#5c5c62 !important; }
      .vlix-eyebrow { color:#6e6e74 !important; }
      .vlix-btn { background:#141416 !important; color:#f4f4f5 !important; }
      .vlix-link { color:#3a3a40 !important; }
    }
  </style>
</head>
<body class="vlix-bg" style="margin:0;padding:0;background:#0d0d0f;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text','Segoe UI',Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;">
  <table class="vlix-bg" role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#0d0d0f;padding:48px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:440px;">
          <tr>
            <td style="padding:0 8px 20px;text-align:center;">
              <div class="vlix-eyebrow" style="font-size:12px;letter-spacing:0.18em;text-transform:uppercase;color:#8a8a90;font-weight:600;">${escapeHtml(eyebrow)}</div>
            </td>
          </tr>
          <tr>
            <td class="vlix-card" style="background:#161618;border-radius:22px;border:1px solid rgba(255,255,255,0.08);overflow:hidden;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td style="height:3px;background:linear-gradient(90deg,#c8c8ce 0%,#6e6e74 100%);font-size:0;line-height:0;">&nbsp;</td>
                </tr>
                <tr>
                  <td style="padding:36px 32px 8px;text-align:center;">
                    <h1 class="vlix-title" style="margin:0;font-size:28px;line-height:1.2;color:#e0e0e4;font-weight:700;letter-spacing:-0.03em;">${escapeHtml(title)}</h1>
                  </td>
                </tr>
                <tr>
                  <td class="vlix-muted" style="padding:12px 32px 28px;text-align:center;color:#8a8a90;font-size:15px;line-height:1.6;">
                    ${escapeHtml(lead)}
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding:0 32px 36px;">
                    <a class="vlix-btn" href="${safeUrl}" style="display:inline-block;background:#e0e0e4;color:#141416;text-decoration:none;font-weight:700;font-size:16px;padding:15px 32px;border-radius:999px;letter-spacing:-0.01em;">
                      ${escapeHtml(ctaLabel)}
                    </a>
                  </td>
                </tr>
                <tr>
                  <td style="padding:0 32px 28px;text-align:center;border-top:1px solid rgba(255,255,255,0.06);">
                    <p class="vlix-muted" style="margin:20px 0 0;color:#5c5c62;font-size:12px;line-height:1.55;">
                      ${escapeHtml(footnote)}
                    </p>
                    <p style="margin:14px 0 0;color:#45454a;font-size:11px;line-height:1.5;">
                      Button not working? Paste this into your browser:<br />
                      <a class="vlix-link" href="${safeUrl}" style="color:#8a8a90;word-break:break-all;">${escapeHtml(ctaUrl)}</a>
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:24px 8px 0;text-align:center;color:#45454a;font-size:11px;line-height:1.5;">
              Daily habits for your real goals.
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/** Dark page that matches the app. Confirm button posts so inbox scanners don't verify by opening the link. */
export function verifyConfirmPageHTML({ code, apiKey }) {
  return authPage({
    title: "Verify your email",
    lead: "One tap confirms this address. Then go back to Vlix — it unlocks on its own.",
    body: `<form method="post" action="/auth/verify">
      <input type="hidden" name="code" value="${escapeAttr(code)}"/>
      <input type="hidden" name="apiKey" value="${escapeAttr(apiKey)}"/>
      <button type="submit">Verify email</button>
    </form>`,
  });
}

export function verifySuccessPageHTML() {
  return authPage({
    title: "You're verified",
    lead: "Go back to Vlix. It will let you in on its own. You can close this page.",
  });
}

export function verifyErrorPageHTML(message) {
  return authPage({
    title: "Link didn't work",
    lead: message || "This link expired. Go back to Vlix and tap Resend email.",
  });
}

function authPage({ title, lead, body = "" }) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <meta name="color-scheme" content="light dark"/>
  <title>${escapeHtml(title)} — Vlix</title>
  <style>
    :root { color-scheme: light dark; }
    body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
      background:#f4f4f5;color:#141416;
      font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI",sans-serif;
      padding:24px;text-align:center;}
    .card{width:100%;max-width:420px;background:#ffffff;border:1px solid rgba(0,0,0,.08);
      border-radius:22px;overflow:hidden;}
    .bar{height:3px;background:linear-gradient(90deg,#3a3a40,#8a8a90);}
    .pad{padding:36px 28px 32px;}
    .eyebrow{font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:#6e6e74;font-weight:600;margin-bottom:18px;}
    h1{margin:0 0 12px;font-size:28px;letter-spacing:-.03em;font-weight:700;}
    p{margin:0;color:#5c5c62;line-height:1.55;font-size:15px;}
    button{margin-top:28px;border:0;background:#141416;color:#f4f4f5;font-weight:700;font-size:16px;
      padding:15px 32px;border-radius:999px;cursor:pointer;}
    @media (prefers-color-scheme: dark) {
      body{background:#0d0d0f;color:#e0e0e4;}
      .card{background:#161618;border-color:rgba(255,255,255,.08);}
      .bar{background:linear-gradient(90deg,#c8c8ce,#6e6e74);}
      .eyebrow{color:#8a8a90;}
      p{color:#8a8a90;}
      button{background:#e0e0e4;color:#141416;}
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="bar"></div>
    <div class="pad">
      <div class="eyebrow">Vlix</div>
      <h1>${escapeHtml(title)}</h1>
      <p>${escapeHtml(lead)}</p>
      ${body}
    </div>
  </div>
</body>
</html>`;
}

function escapeHtml(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function escapeAttr(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
    .replace(/</g, "&lt;");
}
