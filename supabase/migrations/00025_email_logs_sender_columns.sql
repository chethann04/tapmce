-- 00025_email_logs_sender_columns.sql
-- Extend email_logs so every audit record captures the sender, the SMTP
-- response code/server reply, and the generated Message-ID. This satisfies
-- the requirement that every email is logged with Sender, Recipient, Subject,
-- Status, SMTP Response, Timestamp and Error.

alter table public.email_logs
  add column if not exists sender text;

alter table public.email_logs
  add column if not exists smtp_response text;

alter table public.email_logs
  add column if not exists message_id text;

comment on column public.email_logs.sender is
  'Envelope/From address the email was sent as (e.g. students.tap@mcehassan.ac.in).';

comment on column public.email_logs.smtp_response is
  'Raw SMTP server reply code and message (or provider response text).';

comment on column public.email_logs.message_id is
  'RFC 5322 Message-ID assigned to the outbound message.';