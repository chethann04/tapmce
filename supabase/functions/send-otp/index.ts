import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.39.7/+esm";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes
const RESEND_COOLDOWN_MS = 60 * 1000; // 1 minute
const MAX_ATTEMPTS = 5;

async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function generateOtp(): string {
  const buf = new Uint8Array(3);
  crypto.getRandomValues(buf);
  const value = (buf[0] << 16) | (buf[1] << 8) | buf[2];
  return String(value % 1000000).padStart(6, "0");
}

/** Accepts only an exactly 6-digit numeric code (exact-match enforcement). */
function normalizeCode(raw: string): string | null {
  const trimmed = String(raw || "").trim();
  return /^[0-9]{6}$/.test(trimmed) ? trimmed : null;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  let action = "";
  let email = "";
  let purpose = "";

  try {
    const body = await req.json();
    action = String(body.action || "");
    email = String(body.email || "").toLowerCase().trim();
    purpose = String(body.purpose || "signup").trim();
    const rawCode = String(body.code || "");
    console.log(`[send-otp] Request received: action=${action}, email=${email}, purpose=${purpose}`);

    if (!["signup", "password_reset"].includes(purpose)) {
      return json({ success: false, error: "Invalid purpose." }, 400);
    }
    if (!email || !email.includes("@") || !email.includes(".")) {
      return json({ success: false, error: "A valid email is required." }, 400);
    }

    if (action === "send") {
      const otp = generateOtp();
      const codeHash = await sha256Hex(otp);
      const expiresAt = new Date(Date.now() + OTP_TTL_MS).toISOString();

      // store_otp atomically invalidates all prior codes and inserts the new
      // one in a single transaction, so two concurrent "send" calls can never
      // leave two valid codes. A unique partial index backs this up; if two
      // sends race, the second insert fails with 23505 and we ask the user to
      // wait.
      const { data: stored, error: storeErr } = await supabase.rpc("store_otp", {
        p_email: email,
        p_purpose: purpose,
        p_code_hash: codeHash,
        p_expires_at: expiresAt,
        p_max_attempts: MAX_ATTEMPTS,
      });
      if (storeErr) {
        // unique_violation (23505): someone else just stored a newer code.
        if ((storeErr as any)?.code === "23505") {
          return json(
            { success: false, error: "Please wait a moment before requesting a new code." },
            429
          );
        }
        throw storeErr;
      }
      console.log(`[send-otp] OTP stored for ${email} (hash only), expires ${expiresAt}`);

      // Deliver via the existing SMTP send-email function.
      const sendRes = await fetch(`${supabaseUrl}/functions/v1/send-email`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${supabaseServiceKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          emailType: "otp",
          recipient: email,
          subject: `Your MCE Placement Connect Verification Code: ${otp}`,
          data: { otp },
        }),
      });
      const sendData = await sendRes.json().catch(() => ({}));
      console.log(`[send-otp] send-email responded with status ${sendRes.status}`);
      if (!sendRes.ok || sendData.success !== true) {
        // Email failed — invalidate every pending code so no dangling unusable
        // code blocks the email+purpose.
        await supabase
          .from("otp_verifications")
          .update({ used: true })
          .eq("email", email)
          .eq("purpose", purpose)
          .eq("used", false);
        return json(
          { success: false, error: sendData.error || "Failed to deliver the code by email." },
          502
        );
      }

      // Cleanup: drop rows older than 24h.
      await supabase
        .from("otp_verifications")
        .delete()
        .lt("created_at", new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString());

      return json({ success: true, message: "Verification code sent." });
    }

    if (action === "verify") {
      const normalizedCode = normalizeCode(rawCode);
      if (!normalizedCode) {
        return json(
          { success: false, error: "Invalid code format. Enter the 6-digit code." },
          400
        );
      }

      const { data: result, error: rpcErr } = await supabase.rpc("verify_otp", {
        p_email: email,
        p_purpose: purpose,
        p_code: normalizedCode,
      });
      if (rpcErr) throw rpcErr;

      const ok = (result as any)?.success === true;
      if (!ok) {
        return json(
          { success: false, error: (result as any)?.error || "Verification failed." },
          400
        );
      }

      // Mark the student's email as confirmed in Supabase auth and profiles table
      try {
        // 1. Find user in auth.users by email
        const { data: usersData } = await supabase.auth.admin.listUsers();
        const authUser = usersData?.users?.find(
          (u) => u.email?.toLowerCase() === email.toLowerCase()
        );

        if (authUser) {
          await supabase.auth.admin.updateUserById(authUser.id, {
            email_confirm: true,
          });
        }

        // 2. Mark profile as verified
        await supabase
          .from("profiles")
          .update({ email_verified: true, updated_at: new Date().toISOString() })
          .eq("email", email);
      } catch (err) {
        console.error("[send-otp] Error setting email_verified in profiles/auth:", err);
      }

      console.log(`[send-otp] OTP verified for ${email} (purpose=${purpose})`);
      return json({ success: true, message: "Email verified successfully." });
    }

    if (action === "reset_password") {
      const newPassword = String(body.newPassword || "");
      if (newPassword.length < 8) {
        return json({ success: false, error: "Password must be at least 8 characters." }, 400);
      }

      // If a code was provided, verify it (unless already verified/claimed)
      const normalizedCode = normalizeCode(rawCode);
      if (normalizedCode) {
        const { data: result } = await supabase.rpc("verify_otp", {
          p_email: email,
          p_purpose: purpose,
          p_code: normalizedCode,
        });
        // If verify_otp returns false because it was ALREADY claimed (used=true), check if it was used recently
        const ok = (result as any)?.success === true;
        if (!ok) {
          const errMsg = (result as any)?.error || "";
          // If code was already used for this email in the last 10 minutes, allow the password reset
          const { data: recentOtp } = await supabase
            .from("otp_verifications")
            .select("id, updated_at, used")
            .eq("email", email)
            .eq("purpose", purpose)
            .eq("used", true)
            .order("created_at", { ascending: false })
            .limit(1);

          const isRecentlyVerified = recentOtp && recentOtp.length > 0 &&
            (Date.now() - new Date(recentOtp[0].updated_at || recentOtp[0].created_at).getTime() < 10 * 60 * 1000);

          if (!isRecentlyVerified) {
            return json({ success: false, error: errMsg || "Verification failed." }, 400);
          }
        }
      }

      const { data: userList } = await supabase.auth.admin.listUsers({ perPage: 1000 });
      const target = userList?.users?.find((u) => u.email?.toLowerCase() === email);
      if (!target) {
        return json({ success: false, error: "No account found for this email." }, 404);
      }

      const { error: updateErr } = await supabase.auth.admin.updateUserById(target.id, {
        password: newPassword,
      });
      if (updateErr) throw updateErr;

      return json({ success: true, message: "Password updated successfully." });
    }

    return json({ success: false, error: "Unknown action." }, 400);
  } catch (error: any) {
    console.error(`[send-otp] Error (action=${action}):`, error, error?.stack || "");
    return json({ success: false, error: error.message }, 500);
  }
});