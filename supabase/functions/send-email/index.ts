import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.39.7/+esm";

// ─────────────────────────────────────────────────────────────────────────────
// Sender migration (students.tap@mcehassan.ac.in)
//
// Every email is sent From the official institutional account
// students.tap@mcehassan.ac.in. The sender is NOT hardcoded anywhere; it is
// the SMTP_EMAIL secret value (falling back to the DEFAULT_SENDER_EMAIL
// constant below if the secret is unset).
//
// Required Supabase Edge Function secrets (`supabase secrets set`):
//   SMTP_HOST      = smtp.gmail.com        (Gmail SMTP, port 465 implicit TLS)
//   SMTP_PORT      = 465
//   SMTP_EMAIL     = students.tap@mcehassan.ac.in
//   SMTP_PASSWORD  = <Gmail App Password for SMTP_EMAIL>
//
// Optional: RESEND_API_KEY + RESEND_FROM_EMAIL (transactional ESP with proper
// SPF/DKIM/DMARC). If set, Resend is preferred and Gmail SMTP is the fallback.
// RESEND_FROM_EMAIL defaults to SMTP_EMAIL if unset.
//
// Email logs are written to public.email_logs with sender, recipient, subject,
// email_type, status (sent|retried|failed), error_message, smtp_response,
// message_id, sent_at, created_at, created_by.
// ─────────────────────────────────────────────────────────────────────────────

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface EmailPayload {
  emailType: string;
  recipient: string;
  subject?: string;
  data: Record<string, any>;
  createdBy?: string;
}

const COLLEGE_NAME = "MCE Placement Connect";
const BRAND_GOLD = "#D4AF37";

// Official institutional sender. All emails must be sent as this address.
// Override via the SMTP_EMAIL secret if the sender ever needs to change —
// never hardcode a different From elsewhere.
const DEFAULT_SENDER_EMAIL = "students.tap@mcehassan.ac.in";

// Timeouts so a slow/hung SMTP server can never freeze the edge function.
const CONNECT_TIMEOUT_MS = 10000;
const SOCKET_TIMEOUT_MS = 15000;

// SMTP retry policy: transient 4xx/network failures are retried a few times
// with a short backoff before the email is marked "failed".
const SMTP_MAX_ATTEMPTS = 3;
const SMTP_RETRY_BACKOFF_MS = 1000;

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function withTimeout<T>(promise: Promise<T>, ms: number, what: string): Promise<T> {
  let timer: number | undefined;
  return Promise.race([
    promise,
    new Promise<T>((_, reject) => {
      timer = setTimeout(
        () => reject(new Error(`${what} timed out after ${ms}ms`)),
        ms
      );
    }),
  ]).finally(() => clearTimeout(timer));
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const smtpHost = Deno.env.get("SMTP_HOST") || "smtp.gmail.com";
    const smtpPort = parseInt(Deno.env.get("SMTP_PORT") || "465");
    // The sender is the official institutional account by default; override
    // only via the SMTP_EMAIL secret (e.g. temporary fallback account).
    const smtpEmail = Deno.env.get("SMTP_EMAIL") || DEFAULT_SENDER_EMAIL;
    const smtpPassword = Deno.env.get("SMTP_PASSWORD") || "";

    if (!smtpPassword) {
      throw new Error(
        "SMTP password missing. Set SMTP_PASSWORD (a Gmail App Password for SMTP_EMAIL) in Supabase Secrets."
      );
    }

    const payload: EmailPayload = await req.json();
    let { emailType, recipient, data, createdBy } = payload;
    console.log(`[send-email] Request received: type=${emailType}, recipient=${recipient}`);

    if (!recipient) {
      return new Response(
        JSON.stringify({ success: false, error: "Recipient email is required." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 400 }
      );
    }

    data = data || {};

    // Guaranteed Real Data Lookup from Supabase Database if parameters are missing
    try {
      const { data: profile } = await supabase
        .from("profiles")
        .select("id, name, role, department, roll_number, usn, email")
        .eq("email", recipient)
        .maybeSingle();

      if (profile) {
        const resolvedName = profile.name || profile.student_name || "";
        if (resolvedName) {
          if (!data.studentName || data.studentName === "Student") data.studentName = resolvedName;
          if (!data.userName || data.userName === "User") data.userName = resolvedName;
          if (!data.facultyName || data.facultyName === "Faculty Member") data.facultyName = resolvedName;
        }
        if (profile.usn && (!data.usn || data.usn === "N/A")) data.usn = profile.usn;
        if (profile.department && (!data.department || data.department === "N/A")) data.department = profile.department;
        if (profile.role && !data.role) {
          data.role = profile.role === "faculty_coordinator" ? "Faculty Coordinator" : profile.role;
        }
      }

      // If faculty appointment, look up department from faculty_coordinators if missing
      if (emailType === "faculty_appointment" && (!data.department || data.department === "N/A")) {
        if (profile?.id) {
          const { data: coord } = await supabase
            .from("faculty_coordinators")
            .select("department")
            .eq("profile_id", profile.id)
            .maybeSingle();
          if (coord?.department) {
            data.department = coord.department;
          }
        }
      }

      // Extract & sanitize company name from payload data or subject line fallback
      let resolvedCompany = data.companyName || data.company_name || data.company;
      if (!resolvedCompany || resolvedCompany === "undefined" || resolvedCompany === "null" || resolvedCompany === "N/A" || resolvedCompany.trim() === "") {
        if (payload.subject && payload.subject.includes("—")) {
          const parts = payload.subject.split("—");
          const extracted = parts[parts.length - 1].trim();
          if (extracted && extracted !== "undefined" && extracted !== "null" && extracted.trim() !== "") {
            resolvedCompany = extracted;
          }
        } else if (payload.subject && payload.subject.includes(":")) {
          const afterColon = payload.subject.split(":").slice(1).join(":").trim();
          const match = afterColon.match(/^(.+?)\s*\((.+?)\)$/);
          if (match) {
            resolvedCompany = match[1].trim();
            if (!data.roleTitle || data.roleTitle === "N/A") {
              data.roleTitle = match[2].trim();
            }
          } else if (afterColon) {
            resolvedCompany = afterColon;
          }
        }
      }
      if (resolvedCompany && resolvedCompany !== "undefined" && resolvedCompany !== "null" && resolvedCompany.trim() !== "") {
        data.companyName = resolvedCompany;
        data.company_name = resolvedCompany;
      }
    } catch (dbErr) {
      console.warn("[Edge Function] Database fallback lookup warning:", dbErr);
    }

    // Log complete data payload before rendering
    console.log(`[send-email] Full data payload for ${emailType} (${recipient}):`, JSON.stringify(data, null, 2));

    const { subject, html } = generateEmailTemplate(emailType, payload.subject, data);

    let status = "sent";
    let errorMessage: string | null = null;
    let attemptsUsed = 0;

    // All recipients send through the default Gmail SMTP sender.
    const senderHost = smtpHost;
    const senderPort = smtpPort;
    const senderEmail = smtpEmail;
    const senderPassword = smtpPassword;
    console.log(`[send-email] Using SMTP ${senderHost}:${senderPort} (default)`);

    let smtpMeta: { messageId: string | null; responseCode: string; serverResponse: string } | null = null;
    let transport = "gmail-smtp";

    // Resend (transactional ESP) preferred when configured; it carries proper
    // domain-level SPF/DKIM/DMARC, which avoids M365 Junk classification.
    const resendApiKey = Deno.env.get("RESEND_API_KEY") || "";
    const resendFromEmail = Deno.env.get("RESEND_FROM_EMAIL") || DEFAULT_SENDER_EMAIL;

    try {
      if (resendApiKey && resendFromEmail) {
        try {
          const resendId = await sendViaResend({
            from: resendFromEmail,
            to: recipient,
            subject,
            html,
            text: htmlToText(html),
            replyTo: senderEmail,
          });
          transport = "resend";
          smtpMeta = {
            messageId: resendId ? `<${resendId}@resend>` : null,
            responseCode: "200",
            serverResponse: "Resend API accepted (2xx)",
          };
          console.log(`[send-email] Delivered via Resend to ${recipient}`);
        } catch (err: any) {
          console.error(`[send-email] Resend failed (${err?.message}); falling back to Gmail SMTP`);
        }
      }

      if (transport !== "resend") {
        // Transient SMTP/network failures are retried with a short backoff
        // before the send is marked as "failed".
        let lastError: any = null;
        for (attemptsUsed = 1; attemptsUsed <= SMTP_MAX_ATTEMPTS; attemptsUsed++) {
          try {
            smtpMeta = await sendSmtpEmail({
              hostname: senderHost,
              port: senderPort,
              username: senderEmail,
              password: senderPassword,
              from: `${COLLEGE_NAME} <${senderEmail}>`,
              to: recipient,
              subject: subject,
              html: html,
            });
            if (attemptsUsed > 1) {
              status = "retried";
              console.log(`[send-email] SMTP succeeded on attempt ${attemptsUsed}/${SMTP_MAX_ATTEMPTS} for ${recipient}`);
            }
            console.log(
              `[send-email] SMTP accepted. code=${smtpMeta.responseCode} Message-ID=${smtpMeta.messageId} reply="${smtpMeta.serverResponse.trim()}"`
            );
            break;
          } catch (err: any) {
            lastError = err;
            console.error(
              `[send-email] SMTP attempt ${attemptsUsed}/${SMTP_MAX_ATTEMPTS} failed for ${recipient}: ${err?.message}`
            );
            if (attemptsUsed < SMTP_MAX_ATTEMPTS) {
              await sleep(attemptsUsed * SMTP_RETRY_BACKOFF_MS);
            }
          }
        }
        if (!smtpMeta) throw lastError ?? new Error("SMTP send failed after retries");
      }
    } catch (err: any) {
      status = "failed";
      errorMessage = err?.message || String(err);
      console.error(`[Edge Function] Failed to send ${emailType} to ${recipient}:`, err);
    }

    // Audit log in email_logs — every attempt records Sender, Recipient,
    // Subject, Status, SMTP Response, Message-ID, Timestamp and Error.
    try {
      await supabase.from("email_logs").insert({
        sender: senderEmail,
        recipient,
        subject,
        email_type: emailType,
        status,
        error_message: errorMessage,
        smtp_response: smtpMeta?.serverResponse?.trim() || null,
        message_id: smtpMeta?.messageId || null,
        sent_at: status === "sent" || status === "retried" ? new Date().toISOString() : null,
        created_by: createdBy || null,
      });
    } catch (logErr) {
      console.error("[Edge Function] Error writing to email_logs:", logErr);
    }

    if (status === "failed") {
      return new Response(
        JSON.stringify({ success: false, error: errorMessage }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Email ${emailType} sent to ${recipient}`,
        messageId: smtpMeta?.messageId || null,
        smtpCode: smtpMeta?.responseCode || null,
        smtpResponse: smtpMeta?.serverResponse?.trim() || null,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 200 }
    );
  } catch (error: any) {
    console.error("[send-email] Unexpected error:", error, error?.stack || "");
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Robust Deno Native SMTP Client (Supports Port 465 SSL/TLS & Port 587 STARTTLS)
// ─────────────────────────────────────────────────────────────────────────────
interface SmtpOptions {
  hostname: string;
  port: number;
  username: string;
  password: string;
  from: string;
  to: string;
  subject: string;
  html: string;
}

interface SmtpResult {
  messageId: string | null;
  responseCode: string;
  serverResponse: string;
}

function generateMessageId(senderDomain: string): string {
  const rand = crypto.getRandomValues(new Uint8Array(12));
  const hex = Array.from(rand, (b) => b.toString(16).padStart(2, "0")).join("");
  return `<${Date.now().toString(36)}-${hex}@${senderDomain}>`;
}

function rfc2822Date(d = new Date()): string {
  const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const p = (n: number) => String(n).padStart(2, "0");
  return `${days[d.getUTCDay()]}, ${p(d.getUTCDate())} ${months[d.getUTCMonth()]} ${d.getUTCFullYear()} ${p(d.getUTCHours())}:${p(d.getUTCMinutes())}:${p(d.getUTCSeconds())} +0000`;
}

function utf8Base64(s: string): string {
  const bytes = new TextEncoder().encode(s);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
}

// RFC 2047 encoded-word so non-ASCII subjects survive every relay intact.
function encodeSubject(s: string): string {
  if (/^[\x20-\x7e]*$/.test(s)) return s;
  return `=?UTF-8?B?${utf8Base64(s)}?=`;
}

function htmlToText(html: string): string {
  return html
    .replace(/<style[\s\S]*?<\/style>/gi, "")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(p|div|h1|h2|h3|h4|li|tr)>/gi, "\n")
    .replace(/<\/td>/gi, "\t")
    .replace(/<[^>]+>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&copy;/g, "©")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

async function sendSmtpEmail(opts: SmtpOptions): Promise<SmtpResult> {
  const encoder = new TextEncoder();
  const decoder = new TextDecoder();
  const transcript: string[] = [];

  const username = opts.username.trim();
  const password = opts.password.trim();
  const recipient = opts.to.trim().replace(/[\r\n]+/g, "");
  const subject = opts.subject.replace(/[\r\n]+/g, " ");

  const domain = username.split("@")[1] || "localhost";
  const messageId = generateMessageId(domain);

  // Multipart/alternative: plain text + HTML, both UTF-8, CRLF-normalized.
  const boundary = `----=_Part_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 12)}`;
  const plainText = htmlToText(opts.html);
  const body =
    `--${boundary}\r\n` +
    `Content-Type: text/plain; charset=UTF-8\r\n` +
    `Content-Transfer-Encoding: 8bit\r\n\r\n` +
    `${plainText}\r\n` +
    `--${boundary}\r\n` +
    `Content-Type: text/html; charset=UTF-8\r\n` +
    `Content-Transfer-Encoding: 8bit\r\n\r\n` +
    `${opts.html}\r\n` +
    `--${boundary}--\r\n`;

  const headers = [
    `From: ${opts.from.replace(/[\r\n]+/g, "")}`,
    `To: <${recipient}>`,
    `Reply-To: ${username}`,
    `Subject: ${encodeSubject(subject)}`,
    `Date: ${rfc2822Date()}`,
    `Message-ID: ${messageId}`,
    `MIME-Version: 1.0`,
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
    `X-Mailer: MCE Placement Connect`,
  ].join("\r\n");

  // Entire message CRLF-normalized; dot-stuff lines beginning with ".".
  const dataBlock = (headers + "\r\n\r\n" + body)
    .replace(/\r?\n/g, "\r\n")
    .replace(/^\./gm, "..");

  let conn: Deno.Conn;
  console.log(`[SMTP] Connecting to ${opts.hostname}:${opts.port} (${opts.port === 465 ? "implicit TLS" : "STARTTLS"})`);

  if (opts.port === 465) {
    conn = await withTimeout(
      Deno.connectTls({ hostname: opts.hostname, port: opts.port }),
      CONNECT_TIMEOUT_MS,
      `SMTP connect (${opts.hostname}:${opts.port})`
    );
  } else {
    conn = await withTimeout(
      Deno.connect({ hostname: opts.hostname, port: opts.port }),
      CONNECT_TIMEOUT_MS,
      `SMTP connect (${opts.hostname}:${opts.port})`
    );
  }

  // NOTE: reader/writer must be re-acquired AFTER startTls() replaces the
  // connection. Using the pre-TLS streams post-upgrade throws Deno's
  // "BadResource: Bad resource ID" (the 502 the OTP flow was hitting).
  // conn.setTimeout() does not exist on Deno.Conn — socket I/O timeouts are
  // enforced by wrapping readResponse() with withTimeout() below.
  let reader = conn.readable.getReader();
  let writer = conn.writable.getWriter();

  async function readResponse(): Promise<string> {
    let fullResponse = "";
    while (true) {
      const { value, done } = await reader.read();
      if (done || !value) break;
      fullResponse += decoder.decode(value);
      const lines = fullResponse.trim().split("\r\n");
      const lastLine = lines[lines.length - 1];
      if (lastLine && lastLine.length >= 4 && lastLine[3] === " ") {
        break;
      }
    }
    return fullResponse;
  }

  async function sendCmd(cmd: string, expectedCode?: string): Promise<string> {
    await writer.write(encoder.encode(cmd + "\r\n"));
    const res = await withTimeout(
      readResponse(),
      SOCKET_TIMEOUT_MS,
      `SMTP response [${cmd.split(" ")[0]}]`
    );
    if (expectedCode && !res.startsWith(expectedCode)) {
      throw new Error(`SMTP Error [cmd: ${cmd.split(" ")[0]}]: ${res.trim()}`);
    }
    return res;
  }

  try {
    const greeting = await withTimeout(readResponse(), CONNECT_TIMEOUT_MS, "SMTP greeting");
    transcript.push(`S: ${greeting.trim().split("\n")[0]}`);

    const ehlo1 = await sendCmd(`EHLO ${opts.hostname}`, "250");
    transcript.push(`C: EHLO ${opts.hostname}`, `S: ${ehlo1.trim()}`);

    if (opts.port === 587) {
      const starttls = await sendCmd("STARTTLS", "220");
      transcript.push(`C: STARTTLS`, `S: ${starttls.trim()}`);
      conn = await Deno.startTls(conn, { hostname: opts.hostname });
      try { writer.releaseLock(); } catch (_) {}
      try { reader.releaseLock(); } catch (_) {}
      // Re-acquire streams after STARTTLS upgrade (no setTimeout — not a Deno API)
      reader = conn.readable.getReader();
      writer = conn.writable.getWriter();
      const ehlo2 = await sendCmd(`EHLO ${opts.hostname}`, "250");
      transcript.push(`C: EHLO ${opts.hostname} (TLS)`, `S: ${ehlo2.trim()}`);
      console.log("[SMTP] STARTTLS complete, streams re-acquired");
    }

    const authCmd = await sendCmd("AUTH LOGIN", "334");
    transcript.push(`C: AUTH LOGIN`, `S: ${authCmd.trim()}`);
    const userReply = await sendCmd(btoa(username), "334");
    const passReply = await sendCmd(btoa(password), "235");
    transcript.push(`C: AUTH LOGIN (username)`, `S: ${userReply.trim()}`, `S: ${passReply.trim()} [password NOT logged]`);
    console.log(`[SMTP] Authenticated as ${username}`);

    const mailFrom = await sendCmd(`MAIL FROM:<${username}>`, "250");
    const rcptTo = await sendCmd(`RCPT TO:<${recipient}>`, "250");
    const dataGo = await sendCmd("DATA", "354");
    transcript.push(
      `C: MAIL FROM:<${username}>`, `S: ${mailFrom.trim()}`,
      `C: RCPT TO:<${recipient}>`, `S: ${rcptTo.trim()}`,
      `C: DATA`, `S: ${dataGo.trim()}`,
    );
    console.log(`[SMTP] Sending message to ${recipient} (${encoder.encode(dataBlock).length + 1} bytes)`);

    // The DATA terminator is "." on its own line; dataBlock ends with CRLF,
    // so passing dataBlock + "." yields "...\r\n.\r\n".
    const finalReply = await sendCmd(dataBlock + ".", "250");
    transcript.push(`S: ${finalReply.trim()}`);

    const quitReply = await sendCmd("QUIT", "221");
    transcript.push(`C: QUIT`, `S: ${quitReply.trim()}`);

    console.log(`[SMTP] Transaction:\n${transcript.join("\n")}`);
    console.log(`[SMTP] Message accepted by server. Message-ID: ${messageId}`);

    return {
      messageId,
      responseCode: finalReply.trim().split(" ")[0] || "250",
      serverResponse: finalReply,
    };
  } catch (err) {
    console.error(`[SMTP] Transaction failed:\n${transcript.join("\n")}`);
    throw err;
  } finally {
    try { writer.releaseLock(); } catch (_) {}
    try { reader.releaseLock(); } catch (_) {}
    try { conn.close(); } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resend (transactional ESP) transport — used when RESEND_API_KEY is set so
// mail carries domain-level SPF/DKIM/DMARC and lands in M365 inboxes instead
// of Junk. Falls back to the Gmail SMTP path above on any failure.
// ─────────────────────────────────────────────────────────────────────────────
async function sendViaResend(params: {
  from: string;
  to: string;
  subject: string;
  html: string;
  text: string;
  replyTo: string;
}): Promise<string | null> {
  const apiKey = Deno.env.get("RESEND_API_KEY") || "";
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: `${COLLEGE_NAME} <${params.from}>`,
      to: [params.to],
      subject: params.subject,
      html: params.html,
      text: params.text,
      reply_to: params.replyTo,
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Resend API error (${res.status}): ${body}`);
  }
  try {
    const body = await res.json();
    return typeof body?.id === "string" ? body.id : null;
  } catch {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HTML Email Templates (Black & Gold Premium Branding)
// ─────────────────────────────────────────────────────────────────────────────
function wrapTemplate(title: string, bodyContent: string): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
  <style>
    body { margin: 0; padding: 0; background-color: #0F0F0F; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; color: #FFFFFF; }
    .container { max-width: 600px; margin: 20px auto; background: #1A1A1A; border: 1px solid #333333; border-radius: 12px; overflow: hidden; box-shadow: 0 8px 24px rgba(0,0,0,0.5); }
    .header { background: linear-gradient(135deg, #1A1A1A 0%, #2A2A2A 100%); padding: 30px 20px; text-align: center; border-bottom: 2px solid ${BRAND_GOLD}; }
    .header h1 { margin: 0; color: ${BRAND_GOLD}; font-size: 24px; font-weight: 700; letter-spacing: 1px; }
    .header p { margin: 5px 0 0 0; color: #D0D0D0; font-size: 13px; text-transform: uppercase; letter-spacing: 1.5px; }
    .content { padding: 30px 25px; line-height: 1.6; font-size: 15px; color: #EEEEEE; }
    .content p { color: #E0E0E0 !important; margin: 12px 0; }
    .content strong { color: #FFFFFF !important; }
    .content h2 { color: #FFFFFF; font-size: 18px; margin-top: 0; margin-bottom: 15px; border-bottom: 1px solid #333; padding-bottom: 8px; }
    .info-table { width: 100%; border-collapse: collapse; margin: 20px 0; background: #222222; border-radius: 8px; overflow: hidden; }
    .info-table td { padding: 12px 16px; border-bottom: 1px solid #2C2C2C; font-size: 14px; }
    .info-table td.label { color: ${BRAND_GOLD}; font-weight: 600; width: 40%; }
    .info-table td.value { color: #FFFFFF; font-weight: 500; }
    .info-table tr:last-child td { border-bottom: none; }
    .highlight-box { background: rgba(212, 175, 55, 0.15); border-left: 4px solid ${BRAND_GOLD}; padding: 15px; border-radius: 4px; margin: 20px 0; color: #FFFFFF; }
    .badge { display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: bold; text-transform: uppercase; }
    .badge-success { background: #1B4D3E; color: #66BB9A; }
    .badge-warning { background: #4D3B1B; color: ${BRAND_GOLD}; }
    .badge-danger { background: #4D1B1B; color: #FF8A8A; }
    .footer { background: #121212; padding: 20px; text-align: center; font-size: 12px; color: #AAAAAA; border-top: 1px solid #262626; }
    .footer p { margin: 4px 0; color: #999999 !important; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>PLACEMENT CONNECT</h1>
      <p>${COLLEGE_NAME}</p>
    </div>
    <div class="content">
      ${bodyContent}
    </div>
    <div class="footer">
      <p>This is an automated placement notification. Please do not reply directly to this email.</p>
      <p>&copy; ${new Date().getFullYear()} ${COLLEGE_NAME}. All rights reserved.</p>
    </div>
  </div>
</body>
</html>
  `;
}

function formatDate(d?: string | Date): string {
  const dateObj = d ? new Date(d) : new Date();
  if (isNaN(dateObj.getTime())) return String(d);
  const day = String(dateObj.getDate()).padStart(2, "0");
  const month = String(dateObj.getMonth() + 1).padStart(2, "0");
  const year = dateObj.getFullYear();
  return `${day}/${month}/${year}`;
}

function generateEmailTemplate(
  emailType: string,
  customSubject: string | undefined,
  data: Record<string, any>
): { subject: string; html: string } {
  switch (emailType) {
    case "login_alert": {
      const subject = customSubject || `New Login to MCE Placement Connect`;
      const html = wrapTemplate(
        "Login Security Alert",
        `
        <h2>Account Login Security Notice</h2>
        <p>Hello <strong>${data.studentName || data.userName || "User"}</strong>,</p>
        <p>A new login to your MCE Placement Connect account was detected.</p>
        
        <table class="info-table">
          <tr><td class="label">Account Email</td><td class="value">${data.email || "N/A"}</td></tr>
          <tr><td class="label">Login Time</td><td class="value">${formatDate(data.time)}</td></tr>
          <tr><td class="label">Security Status</td><td class="value"><span class="badge badge-success">Successful Login</span></td></tr>
        </table>
        
        <p>If this was you, no action is required. If you did not log in, please reset your password immediately.</p>
        `
      );
      return { subject, html };
    }
    case "otp": {
      const subject = customSubject || `Your MCE Placement Connect Verification Code: ${data.otp || ''}`;
      const html = wrapTemplate(
        "Verification Code",
        `
        <h2>Account Verification Code</h2>
        <p>Use the 6-digit verification code below to confirm your account on <strong>MCE Placement Connect</strong>.</p>
        
        <div class="highlight-box" style="text-align: center; font-size: 28px; font-weight: bold; letter-spacing: 6px; color: ${BRAND_GOLD}; margin: 30px 0;">
          ${data.otp || "000000"}
        </div>
        
        <p>This code will expire shortly. If you did not request this registration, please ignore this email.</p>
        `
      );
      return { subject, html };
    }

    case "welcome": {
      const subject = customSubject || `Welcome to MCE Placement Connect — ${data.studentName || 'Student'}`;
      const html = wrapTemplate(
        "Welcome to Placement Connect",
        `
        <h2>Welcome aboard, ${data.studentName || "Student"}!</h2>
        <p>Your email registration and profile verification for <strong>MCE Placement Connect</strong> has been completed successfully.</p>
        
        <table class="info-table">
          <tr><td class="label">Student Name</td><td class="value">${data.studentName || "N/A"}</td></tr>
          <tr><td class="label">Role</td><td class="value">${data.role || "Student"}</td></tr>
          <tr><td class="label">Department</td><td class="value">${data.department || "N/A"}</td></tr>
          <tr><td class="label">Institution</td><td class="value">${COLLEGE_NAME}</td></tr>
        </table>
        
        <p>You can now log in to access active placement drives, monitor your application status, and track drive attendance seamlessly.</p>
        `
      );
      return { subject, html };
    }

    case "faculty_appointment": {
      const subject = customSubject || `Appointment as Faculty Coordinator — ${data.department || ''}`;
      const html = wrapTemplate(
        "Faculty Coordinator Appointment",
        `
        <h2>Faculty Coordinator Appointment Notice</h2>
        <p>Dear <strong>${data.facultyName || "Faculty Member"}</strong>,</p>
        <p>You have been officially appointed as the <strong>Faculty Coordinator</strong> for the Department of <strong>${data.department || "N/A"}</strong> by the Training & Placement Office (TPO).</p>
        
        <table class="info-table">
          <tr><td class="label">Faculty Name</td><td class="value">${data.facultyName || "N/A"}</td></tr>
          <tr><td class="label">Department</td><td class="value">${data.department || "N/A"}</td></tr>
          <tr><td class="label">Appointment Date</td><td class="value">${formatDate(data.appointmentDate)}</td></tr>
        </table>
        
        <p>You now have access to department placement analytics, student approval queues, and drive attendance reporting.</p>
        `
      );
      return { subject, html };
    }

    case "drive_published": {
      const subject = customSubject || `New Placement Drive Announced: ${data.companyName} (${data.roleTitle})`;
      const html = wrapTemplate(
        "New Placement Drive",
        `
        <h2>New Placement Drive Announced</h2>
        <p>Dear <strong>${data.studentName || "Student"}</strong>,</p>
        <p>A new placement recruitment drive matching your department/branch eligibility has been published.</p>
        
        <table class="info-table">
          <tr><td class="label">Company Name</td><td class="value"><strong>${data.companyName || "N/A"}</strong></td></tr>
          <tr><td class="label">Role Title</td><td class="value">${data.roleTitle || "N/A"}</td></tr>
          <tr><td class="label">Package (CTC)</td><td class="value">${data.package || "As per policy"}</td></tr>
          <tr><td class="label">Registration Deadline</td><td class="value">${data.registrationDeadline || "N/A"}</td></tr>
        </table>
        
        <div class="highlight-box">
          Please log into MCE Placement Connect before the registration deadline to review full job requirements and submit your application.
        </div>
        `
      );
      return { subject, html };
    }

    case "application_submitted": {
      const subject = customSubject || `Application Confirmed: ${data.companyName}`;
      const html = wrapTemplate(
        "Application Confirmation",
        `
        <h2>Application Submitted Successfully</h2>
        <p>Dear <strong>${data.studentName || "Student"}</strong>,</p>
        <p>Your application for the following campus recruitment drive has been successfully registered.</p>
        
        <table class="info-table">
          <tr><td class="label">Company</td><td class="value"><strong>${data.companyName || "N/A"}</strong></td></tr>
          <tr><td class="label">Role</td><td class="value">${data.roleTitle || "N/A"}</td></tr>
          <tr><td class="label">Application Date</td><td class="value">${data.applicationDate || new Date().toLocaleDateString()}</td></tr>
          <tr><td class="label">Status</td><td class="value"><span class="badge badge-success">${data.status || "Applied"}</span></td></tr>
        </table>
        `
      );
      return { subject, html };
    }

    case "attendance_marked": {
      const subject = customSubject || `Attendance Confirmed: ${data.companyName} Drive`;
      const html = wrapTemplate(
        "Attendance Confirmation",
        `
        <h2>QR Attendance Recorded</h2>
        <p>Your attendance for the recruitment drive has been verified via QR scan.</p>
        
        <table class="info-table">
          <tr><td class="label">Company</td><td class="value"><strong>${data.companyName || "N/A"}</strong></td></tr>
          <tr><td class="label">Date</td><td class="value">${data.date || new Date().toLocaleDateString()}</td></tr>
          <tr><td class="label">Time</td><td class="value">${data.time || new Date().toLocaleTimeString()}</td></tr>
          <tr><td class="label">Attendance Status</td><td class="value"><span class="badge badge-success">${data.attendanceStatus || "Present"}</span></td></tr>
        </table>
        `
      );
      return { subject, html };
    }

    case "round_qualified": {
      const upcomingRoundText = data.nextRoundName || data.upcomingRound || "Next Round";
      const displayCompany = (data.companyName && data.companyName !== "undefined" && data.companyName !== "null" && data.companyName !== "N/A")
        ? data.companyName
        : "the campus recruitment drive";
      const subject = customSubject || `Congratulations! Qualified for ${upcomingRoundText} — ${displayCompany}`;
      const html = wrapTemplate(
        "Round Advancement Notice",
        `
        <h2>Congratulations! You Have Shortlisted</h2>
        <p>Dear <strong>${data.studentName || "Student"}</strong>,</p>
        <p>We are pleased to inform you that you have cleared the selection criteria for <strong>${displayCompany}</strong>.</p>
        
        <table class="info-table">
          <tr><td class="label">Company</td><td class="value"><strong>${displayCompany}</strong></td></tr>
          ${data.qualifiedRound ? `<tr><td class="label">Cleared Round</td><td class="value">${data.qualifiedRound}</td></tr>` : ""}
          <tr><td class="label">Upcoming Round</td><td class="value"><strong>${upcomingRoundText}</strong></td></tr>
          ${(data.interviewDate && data.interviewDate !== "TBA" && data.interviewDate !== "N/A" && data.interviewDate !== "undefined") ? `<tr><td class="label">Schedule Date</td><td class="value">${data.interviewDate}</td></tr>` : ""}
          ${(data.venue && data.venue !== "TBA" && data.venue !== "N/A" && data.venue !== "undefined") ? `<tr><td class="label">Venue / Mode</td><td class="value">${data.venue}</td></tr>` : ""}
        </table>
        
        ${data.remarks ? `<div class="highlight-box"><strong>Coordinator Remarks:</strong> ${data.remarks}</div>` : ""}
        `
      );
      return { subject, html };
    }

    case "round_rejected": {
      const displayCompany = (data.companyName && data.companyName !== "undefined" && data.companyName !== "null" && data.companyName !== "N/A")
        ? data.companyName
        : "the campus recruitment drive";
      const subject = customSubject || `Drive Status Update: ${displayCompany}`;
      const html = wrapTemplate(
        "Drive Update",
        `
        <h2>Selection Process Update</h2>
        <p>Dear <strong>${data.studentName || "Student"}</strong>,</p>
        <p>Thank you for participating in the campus recruitment drive for <strong>${displayCompany}</strong>.</p>
        
        <table class="info-table">
          <tr><td class="label">Company</td><td class="value"><strong>${displayCompany}</strong></td></tr>
          <tr><td class="label">Round Evaluated</td><td class="value">${data.rejectedRound || "N/A"}</td></tr>
          <tr><td class="label">Status</td><td class="value"><span class="badge badge-danger">Not Shortlisted</span></td></tr>
        </table>
        
        ${data.remarks ? `<p><strong>Feedback/Remarks:</strong> ${data.remarks}</p>` : ""}
        <p>Keep pursuing opportunities — new recruitment drives are added regularly on MCE Placement Connect.</p>
        `
      );
      return { subject, html };
    }

    case "offer_released": {
      const subject = customSubject || `JOB OFFER: Congratulations on your selection at ${data.companyName}!`;
      const html = wrapTemplate(
        "Job Offer Released",
        `
        <h2>Congratulations on Your Job Offer! 🎉</h2>
        <p>Dear <strong>${data.studentName || "Student"}</strong>,</p>
        <p>The Training & Placement Office is proud to announce that you have been selected for a job offer with <strong>${data.companyName}</strong>!</p>
        
        <table class="info-table">
          <tr><td class="label">Company</td><td class="value"><strong>${data.companyName || "N/A"}</strong></td></tr>
          <tr><td class="label">Role Title</td><td class="value">${data.roleTitle || "N/A"}</td></tr>
          <tr><td class="label">Offered Package</td><td class="value"><strong>${data.package || "N/A"}</strong></td></tr>
          <tr><td class="label">Joining Date</td><td class="value">${data.joiningDate || "As per Offer Letter"}</td></tr>
        </table>
        
        <div class="highlight-box">
          <strong>Next Steps:</strong> Please check MCE Placement Connect under 'My Offers' to review offer letter details and submit your decision.
        </div>
        `
      );
      return { subject, html };
    }

    case "drive_cancelled": {
      const subject = customSubject || `URGENT: Placement Drive Update — ${data.companyName}`;
      const html = wrapTemplate(
        "Placement Drive Update",
        `
        <h2>Placement Drive Schedule Update</h2>
        <p>Please note an important update regarding the recruitment drive for <strong>${data.companyName}</strong>.</p>
        
        <table class="info-table">
          <tr><td class="label">Company</td><td class="value">${data.companyName || "N/A"}</td></tr>
          <tr><td class="label">Reason / Details</td><td class="value">${data.reason || "Schedule adjustment by company"}</td></tr>
          <tr><td class="label">Updated Date</td><td class="value">${data.updatedDate || "To be communicated"}</td></tr>
        </table>
        `
      );
      return { subject, html };
    }

    case "reminder": {
      const subject = customSubject || `Placement Action Required: ${data.reminderTitle || 'Reminder'}`;
      const html = wrapTemplate(
        "Placement Action Reminder",
        `
        <h2>Action Required</h2>
        <p>Dear <strong>${data.studentName || "Student"}</strong>,</p>
        <p>${data.message || "You have a pending requirement on MCE Placement Connect."}</p>
        
        <div class="highlight-box">
          <strong>Requirement:</strong> ${data.reminderTitle || "Pending Action"}<br>
          ${data.deadline ? `<strong>Deadline:</strong> ${data.deadline}` : ""}
        </div>
        `
      );
      return { subject, html };
    }

    default: {
      const subject = customSubject || `Placement Notice — ${COLLEGE_NAME}`;
      const html = wrapTemplate(
        "Placement Notice",
        `
        <h2>${customSubject || "Placement Notice"}</h2>
        <p>${data.message || "Please log in to MCE Placement Connect to view recent updates."}</p>
        `
      );
      return { subject, html };
    }
  }
}
