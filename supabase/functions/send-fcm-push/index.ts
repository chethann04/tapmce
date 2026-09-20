import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.39.7/+esm";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (payload: unknown, status = 200) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

// ── Built-in fallback Firebase Service Account ──────────────────────────────
const FALLBACK_SERVICE_ACCOUNT = {
  "type": "service_account",
  "project_id": "tapmce-30c3f",
  "private_key_id": "cab33551c7608dd5059e6c2401361e2b2865ef7d",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC4wG3EeVPUOiDi\n+Lfm0hj2rpYQEe8S8WOQJgoXf5nH2dT0/KoBGxvMa5oz4SP32KZBrYJ6E30Kh7Sk\nKxL19+frcvzKD4uS62hQ8bR3tKwl0sNqTkx3x3UGbkrYlK4LazYnbGRxIFS0b//K\n9kk06TLBW+Rag5iuqivWJPbZn6yNaBMG2vdB7AwMSoC7tD445JgwDfp+pET9yoM7\ntfXUZ3C0OKSNpUHs6vFVdhUh9r2lwck3CrsXkFYrilgp5ogyhnWducyhj35gTQja\nSq9DqxSn6unO377ubG+uj5ge6AzsEj3vQOZxf//b2/t7Q0ch8i0OqejWphPkklhC\n07KOAydvAgMBAAECggEAUtLRYrcRgZ7dh2MA7pVZY5044NNpXhChFco30/j8M7/P\n3FQ40m4YtDe41XEk8sNJJUBnsdpyv/m+XaqBwYr1iXPvJ5Z4d9DY3xC8Wr3APuSR\nfmLDnR7ps4xWOWnN7IiPqnTJQn2/+3QKNC7c+r9gZZaQdJNyKztWk5XWpBEVBf7S\n3X9c54jitmYz30Oqn5JVuHyKdECDnYAwnuBkiViG1dMs60+YDjZfl1BjCv2Yc5rP\nmJApaWG8LoAjteSQcEPWB+gFjPoUjydFaMlpmfF/IYYcu2JaVLUMnVExX/3sG1cI\nlLbPQea+YlGCJoKI+zyWcV703jfIG8MI/TGhjYUFgQKBgQDl7tXQI+0bznvkWJ8c\n1EQXL5FJfMFd5plZA6lBx3DcfYjYxNet0SXkGnWDJuA1YnG3scxtl7ic/jja41Uw\nkIFPpJQmNug2EvyWXLKXxDcKYvaKd+MrNp9DA78SPBy+ofFYFmZURP/irP3sPwgX\nwR6XIAU4zGqZtsUfHZ9IV6+OUQKBgQDNslUn5MAlv31P+Z6TpmMvYounIwqITlUL\nsf5iMvqwqyZp9qGQXQeJZjiPO5i3Kl0uLPYRm30x34WuTAmRK0V32MAJ/BnVPUh1\n+bfbhTZFJUvwoa+a8Ny+F0NpeEmdU52+iMzfrqBiz7fJP77U6ucopiKy7C7OHEcZ\nkOEyAC0pvwKBgQCb4jsE3IZwtqFZ4xckRWhQS8h1COZTkfXe2lOSq/MBGP6A75rF\nVakZpzKKEv4oUzCDeD//AMCBdvz2sO7deOqiIxLpgYoWtvKVwgy2RamHGibJI5RY\nhLSei1irtSNLvqDPtofzk7/jXqLb2rPS3vOtQ2Em67dNtRKZEM0fD4uOsQKBgCol\nQ/VslUImvhJI3wj5qpDm7B5Ou7W59wryaWDNeTgBmVlUwz3FEepBG42ddGjzMSxo\n4fIxnbE+TzGrOrqX1x/7NT3WfaSHbfVeOSGtZbU9MxYWythASbpZIeLWVp75pvSH\nKxMZwJr+XHXLrdoKV1qoz6tBYUWx3Y+Lc9i+2IIZAoGAODjWdG+DP/ee4ZufUH88\nAGpTypkorxHzPGuTwV5nxtz8pPSe+x4hyfqkb6X0HsVhR80gG+n1/XqYp8GgxeIx\nYQB1ghjxXa6DsvsohePw3sydnZ+bfJLbPf8xlzu0LUvrLrVaLETTGBthwTa/Sxub\nRHBkIoMkSGrh9FhEpFEd+uo=\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@tapmce-30c3f.iam.gserviceaccount.com",
  "client_id": "113836110563762827913",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40tapmce-30c3f.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
  ;

// ── FCM HTTP v1 (OAuth2 + Service Account) helpers ──────────────────────────

function toBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlToBytes(input: string): Uint8Array {
  const b64 = input.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64.padEnd(b64.length + ((4 - (b64.length % 4)) % 4), "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function parseServiceAccount(raw: string): Record<string, string> {
  const trimmed = raw.trim();

  // 1. Standard JSON
  try {
    const parsed = JSON.parse(trimmed);
    if (typeof parsed === "object" && parsed !== null && parsed.private_key) return parsed;
  } catch (_) { }

  // 2. Base64 encoded JSON
  try {
    const decoded = new TextDecoder().decode(base64UrlToBytes(trimmed));
    if (decoded.trim().startsWith("{")) {
      const parsed = JSON.parse(decoded);
      if (typeof parsed === "object" && parsed !== null && parsed.private_key) return parsed;
    }
  } catch (_) { }

  // 3. Double-escaped quotes (\" -> ")
  try {
    const unesc = trimmed.replace(/\\"/g, '"').replace(/\\\\/g, "\\");
    if (unesc.startsWith('"') && unesc.endsWith('"')) {
      return JSON.parse(unesc.slice(1, -1));
    }
    const parsed = JSON.parse(unesc);
    if (parsed.private_key) return parsed;
  } catch (_) { }

  // 4. Single quotes replaced with double quotes
  try {
    const dbl = trimmed.replace(/'/g, '"');
    const parsed = JSON.parse(dbl);
    if (parsed.private_key) return parsed;
  } catch (_) { }

  // Fallback to built-in service account
  console.warn("[send-fcm-push] Could not parse environment FCM_SERVICE_ACCOUNT. Falling back to built-in service account.");
  return FALLBACK_SERVICE_ACCOUNT;
}

async function createAssertion(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = toBase64Url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const claims = toBase64Url(
    new TextEncoder().encode(
      JSON.stringify({
        iss: serviceAccount.client_email,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      }),
    ),
  );
  const signingInput = `${header}.${claims}`;

  const rawKey = serviceAccount.private_key || "";
  const pem = rawKey
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const keyBytes = base64UrlToBytes(pem);

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(signingInput)),
  );
  return `${signingInput}.${toBase64Url(signature)}`;
}

async function getAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  console.log(`[send-fcm-push] Generating Google OAuth2 token for client: ${serviceAccount.client_email}`);
  const assertion = await createAssertion(serviceAccount);
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const data = await res.json();
  if (!res.ok || !data.access_token) {
    console.error(`[send-fcm-push] OAuth token exchange failed (${res.status}):`, data);
    throw new Error(`OAuth token exchange failed (${res.status}): ${JSON.stringify(data)}`);
  }
  console.log(`[send-fcm-push] Google OAuth2 access token successfully generated.`);
  return data.access_token;
}

async function sendFcmMessage(params: {
  token: string;
  accessToken: string;
  projectId: string;
  title: string;
  body: string;
  driveId: string | null;
  image: string | null;
}): Promise<{ status: number; responseText: string }> {
  const { token, accessToken, projectId, title, body, driveId, image } = params;
  const message = {
    message: {
      token,
      notification: {
        title,
        body,
        ...(image ? { image } : {}),
      },
      data: {
        type: "drive",
        title,
        body,
        ...(driveId ? { drive_id: String(driveId) } : {}),
      },
      android: {
        priority: "HIGH",
        notification: {
          channel_id: "high_importance_channel",
          sound: "default",
        },
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    },
  };

  const maskedToken = token.length > 12 ? `${token.substring(0, 8)}...${token.substring(token.length - 4)}` : token;
  console.log(`[send-fcm-push] FCM HTTP request started for device token: ${maskedToken} on project ${projectId}`);

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    },
  );

  const responseText = await res.text();
  console.log(`[send-fcm-push] FCM HTTP response status: ${res.status}`);
  console.log(`[send-fcm-push] FCM HTTP response body: ${responseText}`);

  if (!res.ok) {
    throw new Error(`FCM send failed (${res.status}): ${responseText}`);
  }

  return { status: res.status, responseText };
}

// ── Handler ──────────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  console.log(`[send-fcm-push] FUNCTION START: ${new Date().toISOString()} [${req.method}]`);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const serviceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "";

    // Parse service account or fall back safely to built-in tapacc-e12f4
    let serviceAccount: Record<string, string>;
    if (serviceAccountRaw && serviceAccountRaw.length > 10) {
      serviceAccount = parseServiceAccount(serviceAccountRaw);
    } else {
      serviceAccount = FALLBACK_SERVICE_ACCOUNT;
    }

    const projectId = serviceAccount.project_id || "tapacc-e12f4";

    console.log(`[send-fcm-push] Firebase Project ID: ${projectId}`);
    console.log(`[send-fcm-push] Client Email: ${serviceAccount.client_email}`);

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    let body: Record<string, any> = {};
    try {
      body = await req.json();
    } catch (_) {
      body = {};
    }

    const record = body.record || body;
    const isDriveWebhook = Boolean(body.record && record.id);

    // ── Resolve target FCM tokens ──────────────────────────────────────────
    const directToken = body.token || body.fcm_token;
    let tokensData: { token: string; user_id: string }[] = [];

    if (directToken) {
      console.log(`[send-fcm-push] Direct single token provided: ${String(directToken).substring(0, 8)}...`);
      tokensData = [{ token: String(directToken), user_id: body.user_id || "direct-test-device" }];
    } else {
      const userIds = Array.isArray(body.user_ids) && body.user_ids.length > 0
        ? body.user_ids
        : null;

      let query = supabase.from("fcm_tokens").select("id, user_id, fcm_token");
      if (userIds) query = query.in("user_id", userIds);
      let { data, error: tokensErr } = await query;

      if (tokensErr && tokensErr.message.includes("fcm_token")) {
        let fallbackQuery = supabase.from("fcm_tokens").select("id, user_id, token");
        if (userIds) fallbackQuery = fallbackQuery.in("user_id", userIds);
        const res = await fallbackQuery;
        data = res.data;
        tokensErr = res.error;
      }

      if (tokensErr) {
        console.error("[send-fcm-push] Database query error:", tokensErr);
        throw new Error(`Failed to fetch FCM tokens: ${tokensErr.message}`);
      }

      tokensData = (data || [])
        .map((row: Record<string, any>) => ({
          token: (row.fcm_token || row.token) as string,
          user_id: row.user_id as string,
        }))
        .filter((t) => Boolean(t.token));
    }

    console.log(`[send-fcm-push] Target tokens resolved: ${tokensData.length}`);

    if (tokensData.length === 0) {
      return json({
        success: true,
        message: "No registered FCM device tokens found.",
        devicesAttempted: 0,
        devicesSent: 0,
      });
    }

    // ── Resolve notification content ───────────────────────────────────────
    const companyId = record.company_id ?? body.company_id;
    let companyName = "Placement Drive";
    if (companyId) {
      const { data: comp } = await supabase
        .from("companies")
        .select("name")
        .eq("id", companyId)
        .maybeSingle();
      if (comp?.name) companyName = comp.name;
    }

    const roleTitle = body.role_title || record.role_title || record.role || "Job Role";
    const packageLpa = body.package_lpa || record.package_lpa || record.ctc_or_stipend || "";
    const driveId = body.drive_id || record.id || null;
    const title = body.title || `🚀 New Placement Drive: ${companyName}`;
    const messageBody = body.body ||
      `Role: ${roleTitle}${packageLpa ? ` | CTC: ${packageLpa}` : ""}. Apply before deadline!`;
    const imageUrl = body.image || record.image_url || null;
    const skipInApp = body.skip_in_app === true;

    const accessToken = await getAccessToken(serviceAccount);

    const sentUserIds: string[] = [];
    const failures: { user: string; error: string }[] = [];
    const rawResponses: { status: number; response: string }[] = [];

    for (const t of tokensData) {
      try {
        const sendResult = await sendFcmMessage({
          token: t.token,
          accessToken,
          projectId,
          title,
          body: messageBody,
          driveId: driveId ? String(driveId) : null,
          image: imageUrl,
        });
        sentUserIds.push(t.user_id);
        rawResponses.push({ status: sendResult.status, response: sendResult.responseText });
      } catch (e) {
        const errMsg = (e as Error).message;
        console.error(`[send-fcm-push] Delivery failed for token:`, errMsg);
        if (errMsg.includes("NotRegistered") || errMsg.includes("UNREGISTERED")) {
          try {
            await supabase.from("fcm_tokens").delete().eq("fcm_token", t.token);
            await supabase.from("fcm_tokens").delete().eq("token", t.token);
          } catch (_) { }
        }
        failures.push({ user: t.user_id, error: errMsg });
      }
    }

    // ── Persist in-app notifications for directly-targeted pushes ──────────
    if (sentUserIds.length > 0 && !isDriveWebhook && !skipInApp && !directToken) {
      const uniqueUserIds = [...new Set(sentUserIds)];
      const rows = uniqueUserIds.map((uid) => ({
        user_id: uid,
        title,
        body: messageBody,
        type: "info",
        ...(driveId ? { drive_id: driveId } : {}),
      }));
      try {
        await supabase.from("notifications").insert(rows);
      } catch (notifErr) {
        console.warn("[send-fcm-push] In-app notification insert warning:", notifErr);
      }
    }

    console.log(
      `[send-fcm-push] Summary: Sent to ${sentUserIds.length}/${tokensData.length} devices; Failures: ${failures.length}`,
    );

    return json({
      success: failures.length === 0,
      devicesAttempted: tokensData.length,
      devicesSent: sentUserIds.length,
      usersNotified: [...new Set(sentUserIds)].length,
      failures,
      rawResponses,
      title,
      body: messageBody,
      projectId,
    });
  } catch (err) {
    console.error("[send-fcm-push] Fatal Error:", err);
    return json({ success: false, error: (err as Error).message }, 500);
  }
});
