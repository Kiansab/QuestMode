/**
 * Quest Mode branded auth emails (dark graphite + soft white — matches app chrome).
 */

export function verificationEmailHTML({ displayName, verifyUrl }) {
  const hello = displayName?.trim()
    ? `Hi ${escapeHtml(displayName.trim().split(/\s+/)[0])},`
    : "Welcome to Quest Mode.";
  return layout({
    eyebrow: "Quest Mode",
    title: "Verify your email",
    lead: `${hello} One tap confirms it’s you — then we build daily quests around your real goals.`,
    ctaLabel: "Verify email",
    ctaUrl: verifyUrl,
    footnote: "If you didn’t create a Quest Mode account, you can ignore this message.",
  });
}

export function passwordResetEmailHTML({ resetUrl }) {
  return layout({
    eyebrow: "Quest Mode",
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
  <meta name="color-scheme" content="dark" />
  <meta name="supported-color-schemes" content="dark" />
  <title>${escapeHtml(title)}</title>
</head>
<body style="margin:0;padding:0;background:#0d0d0f;font-family:-apple-system,BlinkMacSystemFont,'SF Pro Text','Segoe UI',Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#0d0d0f;padding:48px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:440px;">
          <tr>
            <td style="padding:0 8px 20px;text-align:center;">
              <div style="font-size:12px;letter-spacing:0.18em;text-transform:uppercase;color:#8a8a90;font-weight:600;">${escapeHtml(eyebrow)}</div>
            </td>
          </tr>
          <tr>
            <td style="background:#161618;border-radius:22px;border:1px solid rgba(255,255,255,0.08);overflow:hidden;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td style="height:3px;background:linear-gradient(90deg,#c8c8ce 0%,#6e6e74 100%);font-size:0;line-height:0;">&nbsp;</td>
                </tr>
                <tr>
                  <td style="padding:36px 32px 8px;text-align:center;">
                    <h1 style="margin:0;font-size:28px;line-height:1.2;color:#e0e0e4;font-weight:700;letter-spacing:-0.03em;">${escapeHtml(title)}</h1>
                  </td>
                </tr>
                <tr>
                  <td style="padding:12px 32px 28px;text-align:center;color:#8a8a90;font-size:15px;line-height:1.6;">
                    ${escapeHtml(lead)}
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding:0 32px 36px;">
                    <a href="${safeUrl}" style="display:inline-block;background:#e0e0e4;color:#141416;text-decoration:none;font-weight:700;font-size:16px;padding:15px 32px;border-radius:999px;letter-spacing:-0.01em;">
                      ${escapeHtml(ctaLabel)}
                    </a>
                  </td>
                </tr>
                <tr>
                  <td style="padding:0 32px 28px;text-align:center;border-top:1px solid rgba(255,255,255,0.06);">
                    <p style="margin:20px 0 0;color:#5c5c62;font-size:12px;line-height:1.55;">
                      ${escapeHtml(footnote)}
                    </p>
                    <p style="margin:14px 0 0;color:#45454a;font-size:11px;line-height:1.5;">
                      Button not working? Paste this into your browser:<br />
                      <a href="${safeUrl}" style="color:#8a8a90;word-break:break-all;">${escapeHtml(ctaUrl)}</a>
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td style="padding:24px 8px 0;text-align:center;color:#45454a;font-size:11px;line-height:1.5;">
              Daily quests for your real goals.
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
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
