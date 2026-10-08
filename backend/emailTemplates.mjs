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
    :root { color-scheme: light dark; supported-color-schemes: light dark; }
    @media (prefers-color-scheme: dark) {
      .vlix-bg { background-color:#0d0d0f !important; background-image:linear-gradient(#0d0d0f,#0d0d0f) !important; }
      .vlix-card { background-color:#1a1a1c !important; background-image:linear-gradient(#1a1a1c,#1a1a1c) !important; }
      .vlix-title { color:#f5f5f7 !important; }
      .vlix-muted, .vlix-eyebrow, .vlix-link { color:#8c8c94 !important; }
      .vlix-btn { background-color:#e0e0e6 !important; color:#141416 !important; }
    }
  </style>
</head>
<body class="vlix-bg" bgcolor="#0d0d0f" style="margin:0;padding:0;background-color:#0d0d0f;background-image:linear-gradient(#0d0d0f,#0d0d0f);color:#f5f5f7;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text','Segoe UI',Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;">
  <table class="vlix-bg" role="presentation" width="100%" cellspacing="0" cellpadding="0" bgcolor="#0d0d0f" style="background-color:#0d0d0f;background-image:linear-gradient(#0d0d0f,#0d0d0f);padding:48px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:440px;">
          <tr>
            <td style="padding:0 8px 20px;text-align:center;">
              <div class="vlix-eyebrow" style="font-size:12px;letter-spacing:0.18em;text-transform:uppercase;color:#8a8a90;font-weight:600;">${escapeHtml(eyebrow)}</div>
            </td>
          </tr>
          <tr>
            <td class="vlix-card" bgcolor="#1a1a1c" style="background-color:#1a1a1c;background-image:linear-gradient(#1a1a1c,#1a1a1c);border-radius:22px;border:1px solid rgba(255,255,255,0.08);overflow:hidden;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td style="height:3px;background:linear-gradient(90deg,#c8c8ce 0%,#6e6e74 100%);font-size:0;line-height:0;">&nbsp;</td>
                </tr>
                <tr>
                  <td style="padding:36px 32px 8px;text-align:center;">
                    <h1 class="vlix-title" style="margin:0;font-size:28px;line-height:1.2;color:#f5f5f7;font-weight:700;letter-spacing:-0.03em;">${escapeHtml(title)}</h1>
                  </td>
                </tr>
                <tr>
                  <td class="vlix-muted" style="padding:12px 32px 28px;text-align:center;color:#8a8a90;font-size:15px;line-height:1.6;">
                    ${escapeHtml(lead)}
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding:0 32px 36px;">
                    <a class="vlix-btn" href="${safeUrl}" style="display:inline-block;background:#e0e0e6;color:#141416;text-decoration:none;font-weight:700;font-size:16px;padding:15px 32px;border-radius:999px;letter-spacing:-0.01em;">
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
export function verifyConfirmPageHTML({ code, apiKey, theme = "dark" }) {
  return authPage({
    theme,
    title: "Verify your email",
    lead: "One tap confirms this address. Then go back to Vlix — it unlocks on its own.",
    body: `<form method="post" action="/auth/verify">
      <input type="hidden" name="code" value="${escapeAttr(code)}"/>
      <input type="hidden" name="apiKey" value="${escapeAttr(apiKey)}"/>
      <input type="hidden" name="theme" value="${escapeAttr(theme)}"/>
      <button type="submit">Verify email</button>
    </form>`,
  });
}

export function verifySuccessPageHTML(theme = "dark") {
  return authPage({
    theme,
    title: "You're verified",
    lead: "Go back to Vlix. It will let you in on its own. You can close this page.",
  });
}

export function resetOpenAppPageHTML({ appUrl, theme = "dark" }) {
  const safe = escapeAttr(appUrl);
  return authPage({
    theme,
    title: "Continue in Vlix",
    lead: "Choose your new password in the app. If Vlix doesn’t open, tap the button.",
    body: `<a class="open-app" href="${safe}">Open Vlix</a>
      <script>window.location.href=${JSON.stringify(appUrl)};</script>`,
  });
}

export function resetPasswordPageHTML({ code, apiKey, theme = "dark", error = "" }) {
  const err = error
    ? `<p style="color:#ff8a80;margin-top:14px;">${escapeHtml(error)}</p>`
    : "";
  return authPage({
    theme,
    title: "Choose a new password",
    lead: "At least 6 characters. Then go back to Vlix and sign in.",
    body: `<form method="post" action="/auth/reset">
      <input type="hidden" name="code" value="${escapeAttr(code)}"/>
      <input type="hidden" name="apiKey" value="${escapeAttr(apiKey)}"/>
      <input type="hidden" name="theme" value="${escapeAttr(theme)}"/>
      <input type="password" name="password" placeholder="New password" minlength="6" autocomplete="new-password" required/>
      <input type="password" name="confirm" placeholder="Confirm password" minlength="6" autocomplete="new-password" required/>
      ${err}
      <button type="submit">Save password</button>
    </form>`,
  });
}

export function resetPasswordSuccessPageHTML(theme = "dark") {
  return authPage({
    theme,
    title: "Password updated",
    lead: "Go back to Vlix and sign in with your new password. You can close this page.",
  });
}

export function verifyErrorPageHTML(message, theme = "dark") {
  return authPage({
    theme,
    title: "Link didn't work",
    lead: message || "This link expired. Go back to Vlix and tap Resend email.",
  });
}

function authPage({ title, lead, body = "", theme = "dark" }) {
  const mode = theme === "light" ? "light" : "dark";
  return `<!DOCTYPE html>
<html lang="en" class="${mode}">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <meta name="color-scheme" content="${mode}"/>
  <title>${escapeHtml(title)} — Vlix</title>
  <style>
    body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;
      background:#0d0d0f;color:#f5f5f7;
      font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","Segoe UI",sans-serif;
      padding:24px;text-align:center;}
    .card{width:100%;max-width:420px;background:#1a1a1c;border:1px solid rgba(255,255,255,.08);
      border-radius:22px;overflow:hidden;}
    .bar{height:3px;background:linear-gradient(90deg,#e0e0e6,#8c8c94);}
    .pad{padding:36px 28px 32px;}
    .eyebrow{font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:#8c8c94;font-weight:600;margin-bottom:18px;}
    h1{margin:0 0 12px;font-size:28px;letter-spacing:-.03em;font-weight:700;color:#f5f5f7;}
    p{margin:0;color:#8c8c94;line-height:1.55;font-size:15px;}
    button, a.open-app{display:block;box-sizing:border-box;margin-top:28px;border:0;background:#e0e0e6;color:#141416;font-weight:700;font-size:16px;
      padding:15px 32px;border-radius:999px;cursor:pointer;width:100%;text-decoration:none;text-align:center;}
    input[type="password"]{display:block;width:100%;box-sizing:border-box;margin-top:12px;background:#141416;color:#f5f5f7;
      border:1px solid rgba(255,255,255,.12);border-radius:12px;padding:14px 16px;font-size:16px;}
    html.light input[type="password"]{background:#f4f4f5;color:#141416;border-color:rgba(0,0,0,.12);}
    html.light body{background:#f4f4f5;color:#141416;}
    html.light .card{background:#ffffff;border-color:rgba(0,0,0,.08);}
    html.light .bar{background:linear-gradient(90deg,#141416,#6e6e74);}
    html.light .eyebrow, html.light p{color:#5c5c62;}
    html.light h1{color:#141416;}
    html.light button{background:#141416;color:#f4f4f5;}
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
