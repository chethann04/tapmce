-- 00023_custom_otp_verifications.sql
-- Custom OTP delivery via the send-otp edge function (server-generated, hashed).
-- Replaces Supabase Auth's built-in mailer (noreply@supabase.co), which is
-- blocked by MCE Outlook/Gmail mailboxes, causing OTPs to never arrive.

create table if not exists public.otp_verifications (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  purpose text not null default 'signup',
  code_hash text not null,
  expires_at timestamptz not null,
  attempts integer not null default 0,
  max_attempts integer not null default 5,
  used boolean not null default false,
  created_at timestamptz not null default now()
);

comment on table public.otp_verifications is
  'Hashed OTP codes for email verification. Only accessible by the service role (send-otp edge function).';

-- RLS on but no client policies: the send-otp edge function (service role)
-- is the only reader/writer. Clients can never read hashes or reset attempts.
alter table public.otp_verifications enable row level security;

create index if not exists otp_verifications_email_purpose_idx
  on public.otp_verifications (email, purpose, created_at desc);

-- Tracks whether the user completed email OTP verification.
alter table public.profiles add column if not exists email_verified boolean not null default false;
