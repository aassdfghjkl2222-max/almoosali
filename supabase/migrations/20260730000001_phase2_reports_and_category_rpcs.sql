-- ============================================================================
-- Manazel — Phase 2 completion: RPCs for atomic multi-row operations
--
-- The base tables/RLS from 20260728000002_phase2_financial_core.sql are
-- sufficient for single-row reads/writes directly through the Supabase
-- client. Two real gaps remain for a genuinely production-ready client:
--
-- 1. Saving a whole daily report (report shell + income breakdown + N
--    revenue/expense lines) as separate client calls is not atomic — a
--    dropped connection mid-save could leave a report with some but not all
--    of its line items. save_daily_financial_report() does the whole thing
--    in one statement.
-- 2. Reordering financial categories (Section: "Manual Ordering") from the
--    client would otherwise mean one UPDATE per category — slow and
--    non-atomic for a list of any real size. reorder_financial_categories()
--    and reset_financial_category_order() do it server-side in one call.
--
-- All four functions are `security invoker`: they run with the CALLING
-- user's own RLS still enforced on every table operation inside them (the
-- explicit permission checks at the top just give an earlier, clearer error
-- than waiting for a policy violation deep inside a loop).
-- ============================================================================

create or replace function post_financial_report(target_report_id uuid)
returns void language plpgsql security invoker as $$
declare
  v_hotel_id uuid;
begin
  select hotel_id into v_hotel_id from financial_reports where id = target_report_id;
  if v_hotel_id is null then
    raise exception 'Report not found';
  end if;
  if not (is_hotel_accessible(v_hotel_id) and has_permission(v_hotel_id, 'financial_reports.manage')) then
    raise exception 'permission denied for financial_reports';
  end if;
  update financial_reports set is_posted = true, posted_at = now(), posted_by = auth.uid()
  where id = target_report_id;
end;
$$;
revoke all on function post_financial_report(uuid) from public;
grant execute on function post_financial_report(uuid) to authenticated;

-- p_revenue_lines / p_expense_lines: jsonb arrays of
-- {"category_id": uuid, "amount": numeric, "payment_method": text, "notes": text?}
-- (expense lines also accept "funding_source_hotel_id": uuid?).
-- Replaces ALL of a report's line items with exactly this set (matches how
-- the existing Flutter daily-report screen already works: it rebuilds its
-- item lists wholesale on every save, not an incremental diff).
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
  p_expense_lines jsonb default '[]'::jsonb
) returns uuid language plpgsql security invoker as $$
declare
  v_report_id uuid;
  v_already_posted boolean;
  line jsonb;
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

  delete from financial_report_revenue_lines where report_id = v_report_id;
  for line in select * from jsonb_array_elements(p_revenue_lines) loop
    insert into financial_report_revenue_lines (report_id, category_id, amount, payment_method, notes, created_by)
    values (
      v_report_id,
      (line ->> 'category_id')::uuid,
      (line ->> 'amount')::numeric,
      line ->> 'payment_method',
      line ->> 'notes',
      auth.uid()
    );
  end loop;

  delete from financial_report_expense_lines where report_id = v_report_id;
  for line in select * from jsonb_array_elements(p_expense_lines) loop
    insert into financial_report_expense_lines (report_id, category_id, amount, payment_method, funding_source_hotel_id, notes, created_by)
    values (
      v_report_id,
      (line ->> 'category_id')::uuid,
      (line ->> 'amount')::numeric,
      line ->> 'payment_method',
      nullif(line ->> 'funding_source_hotel_id', '')::uuid,
      line ->> 'notes',
      auth.uid()
    );
  end loop;

  return v_report_id;
end;
$$;
revoke all on function save_daily_financial_report(uuid, date, text, text, numeric, text, text, numeric, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, jsonb) from public;
grant execute on function save_daily_financial_report(uuid, date, text, text, numeric, text, text, numeric, text, text, numeric, numeric, numeric, numeric, numeric, jsonb, jsonb) to authenticated;

create or replace function reorder_financial_categories(ordered_ids uuid[])
returns void language plpgsql security invoker as $$
declare
  i integer;
begin
  if not has_any_permission('financial_categories.manage') then
    raise exception 'permission denied for financial_categories';
  end if;
  for i in 1 .. coalesce(array_length(ordered_ids, 1), 0) loop
    update financial_categories set sort_order = i - 1 where id = ordered_ids[i];
  end loop;
end;
$$;
revoke all on function reorder_financial_categories(uuid[]) from public;
grant execute on function reorder_financial_categories(uuid[]) to authenticated;

create or replace function reset_financial_category_order(target_type text)
returns void language plpgsql security invoker as $$
declare
  rec record;
  i integer := 0;
begin
  if not has_any_permission('financial_categories.manage') then
    raise exception 'permission denied for financial_categories';
  end if;
  for rec in select id from financial_categories where type = target_type order by created_at asc loop
    update financial_categories set sort_order = i where id = rec.id;
    i := i + 1;
  end loop;
end;
$$;
revoke all on function reset_financial_category_order(text) from public;
grant execute on function reset_financial_category_order(text) to authenticated;
