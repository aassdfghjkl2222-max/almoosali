-- ============================================================================
-- Manazel — Phase 4 RPCs
--
-- create_payroll_record(): creates a payroll row and, when advance ids are
-- passed, settles exactly those advances atomically with it. Two integrity
-- choices worth stating explicitly:
--
-- 1. advances_total is NOT trusted from the client — it's recomputed here
--    from the real, currently-unsettled employee_advances rows matching the
--    ids passed in. A caller cannot claim to settle a different amount than
--    what those rows actually total.
-- 2. net_salary is computed here from p_prorated_base (required, no
--    default) + allowances - deductions - advances, rather than trusted
--    as a whole from the client — but the PRORATION policy itself (how
--    prorated_base is derived from days_worked/base_salary for a partial
--    month) intentionally stays in the Dart layer, replicating whatever
--    rule the existing local app already uses, not re-invented here without
--    evidence of what that rule actually is.
-- ============================================================================

create or replace function create_payroll_record(
  p_hotel_id uuid,
  p_employee_id uuid,
  p_period text,
  p_base_salary numeric,
  p_prorated_base numeric,
  p_allowances_total numeric default 0,
  p_deductions_total numeric default 0,
  p_payment_source text default null,
  p_cash_amount numeric default 0,
  p_bank_amount numeric default 0,
  p_personal_amount numeric default 0,
  p_period_start date default null,
  p_period_end date default null,
  p_days_worked integer default 0,
  p_total_days_in_period integer default 30,
  p_settle_advance_ids uuid[] default '{}'
) returns uuid language plpgsql security invoker as $$
declare
  v_payroll_id uuid;
  v_advances_total numeric(14,2);
begin
  if not (is_hotel_accessible(p_hotel_id) and has_permission(p_hotel_id, 'payroll.manage')) then
    raise exception 'permission denied for payroll';
  end if;

  select coalesce(sum(amount), 0) into v_advances_total
  from employee_advances
  where id = any(p_settle_advance_ids) and employee_id = p_employee_id and is_settled = false;

  insert into payroll_records (
    hotel_id, employee_id, period, base_salary, allowances_total, deductions_total, advances_total,
    net_salary, payment_source, cash_amount, bank_amount, personal_amount,
    period_start, period_end, days_worked, total_days_in_period, prorated_base, created_by
  ) values (
    p_hotel_id, p_employee_id, p_period, p_base_salary, p_allowances_total, p_deductions_total, v_advances_total,
    p_prorated_base + p_allowances_total - p_deductions_total - v_advances_total,
    p_payment_source, p_cash_amount, p_bank_amount, p_personal_amount,
    p_period_start, p_period_end, p_days_worked, p_total_days_in_period, p_prorated_base, auth.uid()
  ) returning id into v_payroll_id;

  if array_length(p_settle_advance_ids, 1) > 0 then
    update employee_advances
    set is_settled = true, payroll_id = v_payroll_id
    where id = any(p_settle_advance_ids) and employee_id = p_employee_id and is_settled = false;
  end if;

  return v_payroll_id;
end;
$$;
revoke all on function create_payroll_record(uuid, uuid, text, numeric, numeric, numeric, numeric, text, numeric, numeric, numeric, date, date, integer, integer, uuid[]) from public;
grant execute on function create_payroll_record(uuid, uuid, text, numeric, numeric, numeric, numeric, text, numeric, numeric, numeric, date, date, integer, integer, uuid[]) to authenticated;

-- Marking a payroll record as actually paid (separate, deliberate step from
-- creating/approving it — matches paid_at being nullable and distinct from
-- approved_at in the schema).
create or replace function mark_payroll_paid(target_payroll_id uuid)
returns void language plpgsql security invoker as $$
declare
  v_hotel_id uuid;
begin
  select hotel_id into v_hotel_id from payroll_records where id = target_payroll_id;
  if v_hotel_id is null then
    raise exception 'Payroll record not found';
  end if;
  if not (is_hotel_accessible(v_hotel_id) and has_permission(v_hotel_id, 'payroll.manage')) then
    raise exception 'permission denied for payroll';
  end if;
  update payroll_records set status = 'paid', paid_at = now() where id = target_payroll_id;
end;
$$;
revoke all on function mark_payroll_paid(uuid) from public;
grant execute on function mark_payroll_paid(uuid) to authenticated;
