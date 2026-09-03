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

  const pem = serviceAccount.private_key
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
    throw new Error(`OAuth token exchange failed (${res.status}): ${JSON.stringify(data)}`);
  }
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
}): Promise<void> {
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
        ...(driveId ? { drive_id: driveId } : {}),
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

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`FCM send failed (${res.status}): ${errText}`);
  }
}

// ── Handler ──────────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const projectId = Deno.env.get("FCM_PROJECT_ID") ?? "";
    const serviceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "";

    if (!projectId || !serviceAccountRaw) {
      console.error("[send-fcm-push] Missing FCM_PROJECT_ID / FCM_SERVICE_ACCOUNT env vars.");
      return json(
        { success: false, error: "FCM_PROJECT_ID and FCM_SERVICE_ACCOUNT env vars are required." },
        500,
      );
    }

    // FCM_SERVICE_ACCOUNT may be raw JSON or base64-encoded JSON
    const serviceAccount = serviceAccountRaw.trimStart().startsWith("{")
      ? JSON.parse(serviceAccountRaw)
      : JSON.parse(new TextDecoder().decode(base64UrlToBytes(serviceAccountRaw.trim())));

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body = await req.json();
    // Supports both Supabase webhook payloads (body.record) and direct invocation
    const record = body.record || body;
    const isDriveWebhook = Boolean(body.record && record.id);

    // ── Resolve target FCM tokens ──────────────────────────────────────────
    const userIds = Array.isArray(body.user_ids) && body.user_ids.length > 0
      ? body.user_ids
      : null;

    let query = supabase.from("fcm_tokens").select("token, user_id");
    if (userIds) query = query.in("user_id", userIds);
    const { data: tokensData, error: tokensErr } = await query;

    if (tokensErr) throw new Error(`Failed to fetch FCM tokens: ${tokensErr.message}`);
    if (!tokensData || tokensData.length === 0) {
      return json({ success: true, message: "No registered FCM device tokens found." });
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
    // Callers that already created an in-app notification row (DB triggers,
    // sendNotification, wizard) pass this to avoid duplicate in-app rows.
    const skipInApp = body.skip_in_app === true;

    const accessToken = await getAccessToken(serviceAccount);

    const sentUserIds: string[] = [];
    const failures: { user: string; error: string }[] = [];

    for (const t of tokensData) {
      try {
        await sendFcmMessage({
          token: t.token,
          accessToken,
          projectId,
          title,
          body: messageBody,
          driveId: driveId ? String(driveId) : null,
          image: imageUrl,
        });
        sentUserIds.push(t.user_id);
      } catch (e) {
        const errMsg = (e as Error).message;
        // Prune stale/unregistered tokens so they stop being retried forever
        if (errMsg.includes("NotRegistered") || errMsg.includes("UNREGISTERED")) {
          try {
            await supabase.from("fcm_tokens").delete().eq("token", t.token);
          } catch {}
        }
        failures.push({ user: t.user_id, error: errMsg });
      }
    }

    // ── Persist in-app notifications for directly-targeted pushes ──────────
    // For drive webhooks the DB trigger (notify_students_on_new_drive) already
    // creates in-app rows, so we only do it here for manual/targeted sends.
    if (sentUserIds.length > 0 && !isDriveWebhook && !skipInApp) {
      const uniqueUserIds = [...new Set(sentUserIds)];
      const rows = uniqueUserIds.map((uid) => ({
        user_id: uid,
        title,
        body: messageBody,
        type: "info",
        ...(driveId ? { drive_id: driveId } : {}),
      }));
      await supabase.from("notifications").insert(rows);
    }

    console.log(
      `[send-fcm-push] Sent to ${sentUserIds.length}/${tokensData.length} devices; failures: ${failures.length}`,
    );

    return json({
      success: true,
      devicesAttempted: tokensData.length,
      devicesSent: sentUserIds.length,
      usersNotified: [...new Set(sentUserIds)].length,
      failures,
      title,
      body: messageBody,
    });
  } catch (err) {
    console.error("[send-fcm-push] Error:", err);
    return json({ success: false, error: (err as Error).message }, 500);
  }
});
