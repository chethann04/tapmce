-- 00024_otp_security_hardening.sql
-- Hardens OTP verification against replay, race conditions, brute force and
-- bypass. All verification now happens inside an atomic, service-role-only
-- Postgres function (verify_otp). The send-otp edge function becomes a thin
-- caller. Clients can never read hashes, reset attempts, or mark codes used.

create extension if not exists pgcrypto;

-- ── Guarantee only ONE active (unused) code per email+purpose ──────────────
-- Any concurrent "send" that would create a second active code violates this
-- unique index, so a second active code can never exist.
create unique index if not exists otp_verifications_one_active_per_email_purpose
  on public.otp_verifications (email, purpose)
  where used = false;

-- ── store_otp: atomically invalidate previous codes and insert a new one ──
-- Runs as a single transaction so a race between two "send" calls can never
-- leave two valid codes for the same email+purpose.
create or replace function public.store_otp(
  p_email text,
  p_purpose text,
  p_code_hash text,
  p_expires_at timestamptz,
  p_max_attempts integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_id uuid;
begin
  update public.otp_verifications
     set used = true
   where email = lower(btrim(p_email))
     and purpose = p_purpose
     and used = false;

  insert into public.otp_verifications (email, purpose, code_hash, expires_at, max_attempts)
  values (lower(btrim(p_email)), p_purpose, p_code_hash, p_expires_at, p_max_attempts)
  returning id into v_new_id;

  return jsonb_build_object('success', true, 'id', v_new_id);
end;
$$;

-- ── verify_otp: single, atomic, replay-proof verification ─────────────────
-- - Row is locked with FOR UPDATE inside one transaction; a concurrent verify
--   blocks, then re-reads the committed row. Once used=true is committed the
--   second request finds nothing to claim and is rejected.
-- - Expired codes are rejected and permanently invalidated.
-- - Wrong codes increment the counter atomically (attempts = attempts + 1) and
--   the row is locked after max_attempts.
-- - Only an EXACT match of the 6-digit code (SHA-256 hash) succeeds.
-- - A successful verify marks used=true in the same transaction, so a code can
--   never be verified twice.
create or replace function public.verify_otp(
  p_email text,
  p_purpose text,
  p_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.otp_verifications%rowtype;
  v_remaining integer;
  v_normalized text;
begin
  -- Normalize identically on every call: lowercase + trim. Digits have no
  -- case, so this is case-safe and exact.
  v_normalized := lower(btrim(p_code));

  -- Enforce an exact 6-digit format before any comparison. Anything else is
  -- never treated as a valid code.
  if v_normalized !~ '^[0-9]{6}$' then
    return jsonb_build_object(
      'success', false,
      'error', 'Invalid code format. Enter the 6-digit code.'
    );
  end if;

  -- Lock the newest unused code for this email+purpose. Any other request
  -- that already claimed it (used=true) no longer matches and is skipped.
  select *
    into v_row
    from public.otp_verifications
   where email = lower(btrim(p_email))
     and purpose = p_purpose
     and used = false
   order by created_at desc
   limit 1
   for update;

  if not found then
    -- Distinguish "never requested" from "already used / consumed".
    if exists (
      select 1 from public.otp_verifications
       where email = lower(btrim(p_email)) and purpose = p_purpose
    ) then
      return jsonb_build_object(
        'success', false,
        'error', 'This code has already been used. Request a new one.'
      );
    end if;
    return jsonb_build_object(
      'success', false,
      'error', 'No active code found for this email. Request a new one.'
    );
  end if;

  -- Expired codes are never accepted and are permanently invalidated.
  if now() > v_row.expires_at then
    update public.otp_verifications set used = true where id = v_row.id;
    return jsonb_build_object(
      'success', false,
      'error', 'This code has expired. Request a new one.'
    );
  end if;

  -- Locked out after max_attempts failed attempts.
  if v_row.attempts >= v_row.max_attempts then
    update public.otp_verifications set used = true where id = v_row.id;
    return jsonb_build_object(
      'success', false,
      'error', 'Too many incorrect attempts. Request a new code.'
    );
  end if;

  -- Exact hash comparison. Never leaks whether a prefix matched.
  if v_row.code_hash <> encode(sha256(convert_to(v_normalized, 'UTF8')), 'hex') then
    update public.otp_verifications
       set attempts = attempts + 1
     where id = v_row.id;
    v_remaining := v_row.max_attempts - v_row.attempts - 1;
    if v_remaining <= 0 then
      -- Final failed attempt permanently locks the code.
      update public.otp_verifications set used = true where id = v_row.id;
      return jsonb_build_object(
        'success', false,
        'error', 'Incorrect code. Request a new code.'
      );
    end if;
    return jsonb_build_object(
      'success', false,
      'error', 'Incorrect code. ' || v_remaining || ' attempt(s) left.'
    );
  end if;

  -- Atomic claim: only one request can ever flip used to true. If somehow a
  -- concurrent request already claimed it, we refuse.
  update public.otp_verifications
     set used = true
   where id = v_row.id and used = false;

  if not found then
    return jsonb_build_object(
      'success', false,
      'error', 'This code has already been used. Request a new one.'
    );
  end if;

  return jsonb_build_object('success', true, 'message', 'Email verified successfully.');
end;
$$;

-- ── Lock the functions down to the service role only ──────────────────────
-- PostgREST exposes public-schema functions as RPC endpoints. Without these
-- revokes a client could call verify_otp directly and bypass the edge function.
revoke execute on function public.verify_otp(text, text, text) from public, anon, authenticated;
revoke execute on function public.store_otp(text, text, text, timestamptz, integer) from public, anon, authenticated;

grant execute on function public.verify_otp(text, text, text) to service_role;
grant execute on function public.store_otp(text, text, text, timestamptz, integer) to service_role;
