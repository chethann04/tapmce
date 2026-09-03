-- Notifications table for student round status updates
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null default 'info', -- info, success, warning
  drive_id uuid references drives(id) on delete cascade,
  application_id uuid references applications(id) on delete cascade,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table notifications enable row level security;

-- Students see their own notifications
create policy notifications_student_select on notifications
  for select using (auth.uid() = user_id);

-- System/TPO can insert notifications
create policy notifications_tpo_insert on notifications
  for insert with check (auth_role() = 'tpo');

-- Students can mark their own as read
create policy notifications_student_update on notifications
  for update using (auth.uid() = user_id);

-- Index for fast lookups
create index idx_notifications_user_id on notifications(user_id);
create index idx_notifications_read on notifications(user_id, read);
create index idx_notifications_drive on notifications(drive_id);

-- Remarks column on application_round_status for TPO feedback
alter table application_round_status add column if not exists remarks text;

-- Update result check constraint to allow all round outcome values
alter table application_round_status drop constraint if exists application_round_status_result_check;
alter table application_round_status add constraint application_round_status_result_check
  check (result in ('pending','cleared','rejected','selected','not_selected','passed','failed'));

-- Instructions column on drive_rounds for round-specific info
alter table drive_rounds add column if not exists instructions text;
alter table drive_rounds add column if not exists scheduled_date timestamptz;
