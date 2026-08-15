-- ============================================================================
-- Manazel — Phase 3 RPCs
--
-- 1. Hardening: every existing `security definer` function from Phases 1-2
--    is pinned to `search_path = public, pg_temp`. A security definer
--    function without a pinned search_path can be tricked by a malicious
--    role that creates objects earlier in its own search_path — not
--    exploitable by an ordinary `authenticated` user in this schema today,
--    but it's a real latent gap worth closing before any more definer
--    functions are added, not after.
-- 2. create_shared_expense_distribution(): the one function in this project
--    that legitimately needs `security definer` — splitting a shared cost
--    across hotels means writing a pending_expenses row onto hotels OTHER
--    than the one the caller has explicit permission on. The funding
--    hotel's authority is what matters for this action (matches the real
--    business process: paying for something shared with other hotels
--    doesn't require having login access to those other hotels). The
--    permission check at the top is the ONLY gate — everything after it
--    runs with elevated privilege deliberately, inside one narrow, audited
--    function, not a blanket bypass.
-- 3. create_invoice(): atomically creates an invoice and, only when
--    funding_source_type = 'deferred_supplier', the matching supplier_debt
--    row — mirrors _ensureDeferredPurchaseDebt in the existing local app.
--    security invoker (no cross-hotel concern — an invoice only ever
--    touches its own hotel_id).
-- 4. save_daily_financial_report() is redefined (CREATE OR REPLACE, same
--    signature) to also handle pending-expense transfer linkage: an expense
--    line's jsonb object may now carry "pending_expense_id" — if present,
--    that pending expense is marked is_transferred; any pending expense
--    that WAS linked to this report but is absent from the new save is
--    automatically un-transferred (mirrors editing a report before posting
--    in the existing local app: removing a transferred item reverts it to
--    the pending list).
-- ============================================================================

alter function is_hotel_accessible(uuid) set search_path = public, pg_temp;
alter function has_permission(uuid, text) set search_path = public, pg_temp;
alter function has_any_permission(text) set search_path = public, pg_temp;
alter function handle_new_auth_user() set search_path = public, pg_temp;
alter function record_financial_category_usage(uuid) set search_path = public, pg_temp;

create or replace function create_shared_expense_distribution(
  p_category_id uuid,
  p_description text,
  p_payment_method text,
  p_funding_hotel_id uuid,
  p_expense_date date,
  p_allocations jsonb  -- [{"hotel_id": uuid, "amount": numeric, "statement": text?}]
) returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_group_id uuid;
  v_total numeric(14,2);
  alloc jsonb;
begin
  if not (is_hotel_accessible(p_funding_hotel_id) and has_permission(p_funding_hotel_id, 'pending_expenses.manage')) then
    raise exception 'permission denied for shared expenses';
  end if;

  select coalesce(sum((a ->> 'amount')::numeric), 0) into v_total from jsonb_array_elements(p_allocations) a;
  if v_total <= 0 then
    raise exception 'Total allocation amount must be greater than zero';
  end if;

  insert into shared_expense_groups (category_id, description, total_amount, payment_method, funding_hotel_id, expense_date, created_by)
  values (p_category_id, p_description, v_total, p_payment_method, p_funding_hotel_id, p_expense_date, auth.uid())
  returning id into v_group_id;

  for alloc in select * from jsonb_array_elements(p_allocations) loop
    insert into shared_expense_allocations (shared_expense_group_id, hotel_id, amount)
    values (v_group_id, (alloc ->> 'hotel_id')::uuid, (alloc ->> 'amount')::numeric);

    insert into pending_expenses (
      hotel_id, category_id, amount, statement, payment_method,
      funding_source_hotel_id, shared_expense_group_id, created_by, updated_by
    ) values (
      (alloc ->> 'hotel_id')::uuid,
      p_category_id,
      (alloc ->> 'amount')::numeric,
      coalesce(alloc ->> 'statement', p_description, 'حصة من مصروف مشترك'),
      'cash',
      p_funding_hotel_id,
      v_group_id,
      auth.uid(), auth.uid()
    );
  end loop;

  return v_group_id;
end;
$$;
revoke all on function create_shared_expense_distribution(uuid, text, text, uuid, date, jsonb) from public;
grant execute on function create_shared_expense_distribution(uuid, text, text, uuid, date, jsonb) to authenticated;

create or replace function create_invoice(
  p_hotel_id uuid,
  p_supplier_id uuid,
  p_invoice_number text,
  p_invoice_date date,
  p_amount_before_tax numeric,
  p_vat numeric,
  p_total_amount numeric,
  p_category_id uuid,
  p_funding_source_type text,
  p_payment_method text default null,
  p_related_hotel_id uuid default null
) returns uuid language plpgsql security invoker as $$
declare
  v_invoice_id uuid;
begin
  if not (is_hotel_accessible(p_hotel_id) and has_permission(p_hotel_id, 'suppliers.manage')) then
    raise exception 'permission denied for invoices';
  end if;

  insert into invoices (
    hotel_id, supplier_id, invoice_number, invoice_date, amount_before_tax, vat, total_amount,
    category_id, funding_source_type, payment_method, related_hotel_id, created_by, updated_by
  ) values (
    p_hotel_id, p_supplier_id, p_invoice_number, p_invoice_date, p_amount_before_tax, p_vat, p_total_amount,
    p_category_id, p_funding_source_type, p_payment_method, p_related_hotel_id, auth.uid(), auth.uid()
  ) returning id into v_invoice_id;

  insert into invoice_audit_log (invoice_id, user_id, operation_type)
  values (v_invoice_id, auth.uid(), 'create');

  if p_funding_source_type = 'deferred_supplier' then
    insert into supplier_debts (hotel_id, supplier_id, invoice_id, amount)
    values (p_hotel_id, p_supplier_id, v_invoice_id, p_total_amount);
  end if;

  return v_invoice_id;
end;
$$;
revoke all on function create_invoice(uuid, uuid, text, date, numeric, numeric, numeric, uuid, text, text, uuid) from public;
grant execute on function create_invoice(uuid, uuid, text, date, numeric, numeric, numeric, uuid, text, text, uuid) to authenticated;

create or replace function save_daily_financial_report(
  p_hotel_id uuid,
  p_report_date date,
  p_report_type text default 'main',
  p_notes text default null,
  p_increase_amount numeric default 0,
  p_increase_description text default null,
  p_increase_funding_source text default null,
  p_shortage_amount numeric default 0,
  p_shortage_description text default null,
  p_shortage_funding_source text default null,
  p_room_cash numeric default 0,
  p_room_pos numeric default 0,
  p_room_bank_transfer numeric default 0,
  p_parking_cash numeric default 0,
  p_parking_pos numeric default 0,
  p_revenue_lines jsonb default '[]'::jsonb,
  p_expense_lines jsonb default '[]'::jsonb  -- may include "pending_expense_id" per line now
) returns uuid language plpgsql security invoker as $$
declare
  v_report_id uuid;
  v_already_posted boolean;
  v_old_pending_ids uuid[];
  v_new_pending_ids uuid[] := '{}';
  line jsonb;
  v_pending_id uuid;
begin
  if not (is_hotel_accessible(p_hotel_id) and has_permission(p_hotel_id, 'financial_reports.manage')) then
    raise exception 'permission denied for financial_reports';
  end if;

  insert into financial_reports (
    hotel_id, report_date, report_type, notes,
    increase_amount, increase_description, increase_funding_source,
    shortage_amount, shortage_description, shortage_funding_source,
    created_by, updated_by
  ) values (
    p_hotel_id, p_report_date, p_report_type, p_notes,
    p_increase_amount, p_increase_description, p_increase_funding_source,
    p_shortage_amount, p_shortage_description, p_shortage_funding_source,
    auth.uid(), auth.uid()
  )
  on conflict (hotel_id, report_date, report_type) do update set
    notes = excluded.notes,
    increase_amount = excluded.increase_amount,
    increase_description = excluded.increase_description,
    increase_funding_source = excluded.increase_funding_source,
    shortage_amount = excluded.shortage_amount,
    shortage_description = excluded.shortage_description,
    shortage_funding_source = excluded.shortage_funding_source,
    updated_by = auth.uid()
  returning id, is_posted into v_report_id, v_already_posted;

  if v_already_posted then
    raise exception 'Cannot modify a posted financial report — create an adjustment report instead';
  end if;

  insert into financial_report_income_breakdown (report_id, room_cash, room_pos, room_bank_transfer, parking_cash, parking_pos)
  values (v_report_id, p_room_cash, p_room_pos, p_room_bank_transfer, p_parking_cash, p_parking_pos)
  on conflict (report_id) do update set
    room_cash = excluded.room_cash,
    room_pos = excluded.room_pos,
    room_bank_transfer = excluded.room_bank_transfer,
    parking_cash = excluded.parking_cash,
    parking_pos = excluded.parking_pos;

  -- Pending expenses currently linked to THIS report, before we touch anything —
  -- needed afterwards to work out which ones just got removed (un-transfer them).
  select array_agg(pending_expense_id) into v_old_pending_ids
  from financial_report_expense_lines
  where report_id = v_report_id and pending_expense_id is not null;

  delete from financial_report_revenue_lines where report_id = v_report_id;
  for line in select * from jsonb_array_elements(p_revenue_lines) loop
    insert into financial_report_revenue_lines (report_id, category_id, amount, payment_method, notes, created_by)
    values (
      v_report_id, (line ->> 'category_id')::uuid, (line ->> 'amount')::numeric,
      line ->> 'payment_method', line ->> 'notes', auth.uid()
    );
  end loop;

  delete from financial_report_expense_lines where report_id = v_report_id;
  for line in select * from jsonb_array_elements(p_expense_lines) loop
    v_pending_id := nullif(line ->> 'pending_expense_id', '')::uuid;

    insert into financial_report_expense_lines (
      report_id, category_id, amount, payment_method, funding_source_hotel_id,
      pending_expense_id, supplier_id, notes, created_by
    ) values (
      v_report_id, (line ->> 'category_id')::uuid, (line ->> 'amount')::numeric,
      line ->> 'payment_method', nullif(line ->> 'funding_source_hotel_id', '')::uuid,
      v_pending_id, nullif(line ->> 'supplier_id', '')::uuid, line ->> 'notes', auth.uid()
    );

    if v_pending_id is not null then
      update pending_expenses set is_transferred = true, transferred_at = now() where id = v_pending_id;
      v_new_pending_ids := array_append(v_new_pending_ids, v_pending_id);
    end if;
  end loop;

  -- Un-transfer any pending expense that was linked before this save but isn't anymore.
  if v_old_pending_ids is not null then
    update pending_expenses
    set is_transferred = false, transferred_at = null
    where id = any(v_old_pending_ids) and not (id = any(v_new_pending_ids));
  end if;

  return v_report_id;
end;
$$;
