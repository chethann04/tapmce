-- =============================================================================
-- Migration 00045: Atomic Round Promotion & Duplicate Protection RPC
-- =============================================================================
-- Guarantees concurrency safety, row-level locking, and idempotency
-- when moving candidates across recruitment stages.
-- =============================================================================

-- 1. Ensure Unique constraint on application_round_status (application_id, round_id)
do $$
begin
  if not exists (
    select 1
    from information_schema.table_constraints
    where table_name = 'application_round_status'
      and constraint_type = 'UNIQUE'
      and constraint_name = 'application_round_status_application_id_round_id_key'
  ) then
    alter table application_round_status
      add constraint application_round_status_application_id_round_id_key
      unique (application_id, round_id);
  end if;
exception
  when duplicate_table or duplicate_object then null;
end $$;

-- 2. Create index on applications(current_round) for fast atomic conditional filtering
create index if not exists idx_applications_current_round
  on applications(id, current_round);

-- 3. Atomic Idempotent RPC: promote_application_to_next_round
create or replace function promote_application_to_next_round(
  p_application_id uuid,
  p_from_round int,
  p_performed_by uuid default null
)
returns table (
  promoted boolean,
  new_round int,
  old_round int,
  message text
)
language plpgsql
security definer
as $$
declare
  v_current_round int;
  v_drive_id uuid;
  v_status text;
  v_next_round int;
  v_next_round_id uuid;
  v_current_round_id uuid;
begin
  -- Row-level exclusive lock (FOR UPDATE) prevents race conditions
  select current_round, drive_id, status
  into v_current_round, v_drive_id, v_status
  from applications
  where id = p_application_id
  for update;

  if not found then
    return query select false, 0, 0, 'Application not found';
    return;
  end if;

  -- Idempotency check 1: Candidate is already beyond the source round
  if v_current_round > p_from_round then
    return query select false, v_current_round, v_current_round, 'Candidate already promoted beyond this round';
    return;
  end if;

  -- Idempotency check 2: Candidate in terminal status
  if v_status in ('selected', 'offered', 'rejected') then
    return query select false, v_current_round, v_current_round, 'Candidate already in terminal status';
    return;
  end if;

  v_next_round := p_from_round + 1;

  -- Find current round ID
  select id into v_current_round_id
  from drive_rounds
  where drive_id = v_drive_id and round_number = p_from_round;

  -- Mark current round as cleared
  if v_current_round_id is not null then
    insert into application_round_status (application_id, round_id, attended, result, updated_at)
    values (p_application_id, v_current_round_id, true, 'cleared', now())
    on conflict (application_id, round_id)
    do update set attended = true, result = 'cleared', updated_at = now();
  end if;

  -- Find next round ID
  select id into v_next_round_id
  from drive_rounds
  where drive_id = v_drive_id and round_number = v_next_round;

  if v_next_round_id is not null then
    -- Advance to next round atomically
    update applications
    set current_round = v_next_round, status = 'shortlisted', updated_at = now()
    where id = p_application_id and current_round = p_from_round;

    insert into application_round_status (application_id, round_id, attended, result, updated_at)
    values (p_application_id, v_next_round_id, false, 'pending', now())
    on conflict (application_id, round_id)
    do update set result = 'pending', updated_at = now();

    return query select true, v_next_round, v_current_round, 'Promoted successfully';
  else
    -- End of rounds reached -> Select/Offer
    update applications
    set status = 'selected', updated_at = now()
    where id = p_application_id and current_round = p_from_round;

    return query select true, v_next_round, v_current_round, 'Final stage cleared; selected for offer';
  end if;
end;
$$;
