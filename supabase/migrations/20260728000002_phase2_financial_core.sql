-- ============================================================================
-- Manazel — Phase 2: Financial Core
-- Financial Categories (single source of truth, company-wide) + Daily
-- Financial Reports (normalized line items, replacing the old details_json
-- blob approach) — decisions 1, 2, 3, 4, 6 applied, decision 5 still deferred.
--
-- Design reference: docs/database_architecture/supabase_schema_design.md
-- Sections 4 and 5. Financial Engine / Vault / Settlements are intentionally
-- absent from this migration — they stay separate systems pending the
-- deferred architectural review (decision 5), per explicit instruction.
--
-- Depends on: 20260728000001_phase1_foundation.sql (hotels, profiles,
-- is_hotel_accessible, has_permission).
--
-- `pending_expense_id` / `supplier_id` on financial_report_expense_lines and
-- `filed_by_employee_id` on financial_reports are deliberately NOT included
-- yet — pending_expenses/suppliers/employees don't exist until later phases.
-- They'll be added via `alter table ... add column ... references ...` in
-- the migration that introduces those tables, not stubbed here without a
-- real FK target (a migration must never reference a table that doesn't
-- exist yet).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. financial_categories — single source of truth for revenue/expense
-- classification across the entire application. Never hotel-scoped: one
-- shared list every hotel selects from.
-- ----------------------------------------------------------------------------
create table financial_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text,
  type text not null check (type in ('expense','revenue')),
  parent_id uuid references financial_categories(id) on delete set null,
  icon_code integer not null,
  color_value integer not null,
  description text,
  sort_order integer not null default 0,
  is_pinned boolean not null default false,
  is_default boolean not null default false,
  usage_count integer not null default 0,
  last_used_at timestamptz,
  archived_at timestamptz,
  archived_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id),
  unique (type, name)
);
create trigger trg_financial_categories_updated_at before update on financial_categories
  for each row execute function set_updated_at();
create index idx_financial_categories_type on financial_categories(type) where archived_at is null;
create index idx_financial_categories_parent on financial_categories(parent_id);

-- Only one category per type may be flagged is_default at a time (mirrors
-- the app's existing setDefaultCategory behavior: setting a new default
-- un-sets the previous one — enforced here as a partial unique index rather
-- than trusting every caller to clear the old flag correctly).
create unique index idx_financial_categories_one_default_per_type
  on financial_categories(type) where is_default = true and archived_at is null;

-- Records a category being picked in a transaction-entry picker. Callable by
-- any authenticated user (not just financial_categories.manage holders) —
-- selecting a category to use it is a routine action every user needs, not
-- an administrative one. security definer so it can update usage_count/
-- last_used_at even though the general UPDATE policy below is admin-only.
create or replace function record_financial_category_usage(target_category_id uuid)
returns void language sql security definer as $$
  update financial_categories
  set usage_count = usage_count + 1, last_used_at = now()
  where id = target_category_id;
$$;
revoke all on function record_financial_category_usage(uuid) from public;
grant execute on function record_financial_category_usage(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- 2. financial_reports — one row per hotel per day (per report_type).
-- ----------------------------------------------------------------------------
create table financial_reports (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  report_date date not null,
  report_type text not null default 'main' check (report_type in ('main','adjustment')),
  income_total numeric(14,2) not null default 0,   -- kept in sync by trigger (2.4), never written directly
  expense_total numeric(14,2) not null default 0,  -- same
  notes text,
  increase_amount numeric(14,2) not null default 0,
  increase_description text,
  increase_funding_source text,
  shortage_amount numeric(14,2) not null default 0,
  shortage_description text,
  shortage_funding_source text,
  is_posted boolean not null default false,
  is_locked boolean not null default false,
  posted_at timestamptz,
  posted_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id),
  unique (hotel_id, report_date, report_type)
);
create trigger trg_financial_reports_updated_at before update on financial_reports
  for each row execute function set_updated_at();
create index idx_financial_reports_hotel_date on financial_reports(hotel_id, report_date desc);

-- 2.1 Revenue line items
create table financial_report_revenue_lines (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references financial_reports(id) on delete cascade,
  category_id uuid not null references financial_categories(id),
  amount numeric(14,2) not null check (amount > 0),
  payment_method text not null check (payment_method in ('cash','pos','bank_transfer')),
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);
create index idx_report_revenue_lines_report on financial_report_revenue_lines(report_id);
create index idx_report_revenue_lines_category on financial_report_revenue_lines(category_id);

-- 2.2 Expense line items (pending_expense_id/supplier_id added in a later phase)
create table financial_report_expense_lines (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references financial_reports(id) on delete cascade,
  category_id uuid not null references financial_categories(id),
  amount numeric(14,2) not null check (amount > 0),
  payment_method text not null,
  funding_source_hotel_id uuid references hotels(id),
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);
create index idx_report_expense_lines_report on financial_report_expense_lines(report_id);
create index idx_report_expense_lines_category on financial_report_expense_lines(category_id);

-- 2.3 Fixed income breakdown (room/parking × cash/pos/transfer) — structurally
-- fixed columns, not an open-ended list, so a 1:1 table rather than more rows.
create table financial_report_income_breakdown (
  report_id uuid primary key references financial_reports(id) on delete cascade,
  room_cash numeric(14,2) not null default 0,
  room_pos numeric(14,2) not null default 0,
  room_bank_transfer numeric(14,2) not null default 0,
  parking_cash numeric(14,2) not null default 0,
  parking_pos numeric(14,2) not null default 0
);

-- 2.4 Keep financial_reports.income_total / expense_total in sync automatically
-- whenever line items or the income breakdown change — no application code
-- can let the cached totals drift from the real line items.
create or replace function recalc_report_totals() returns trigger language plpgsql as $$
declare
  target_report_id uuid := coalesce(new.report_id, old.report_id);
begin
  -- Note: coalesce() must wrap the ENTIRE income_breakdown scalar subquery, not
  -- just the column expression inside it — if no breakdown row exists yet for
  -- this report, the subquery itself returns zero rows (NULL as a scalar), and
  -- an inner coalesce never runs because there's no row for it to apply to.
  update financial_reports r set
    income_total = (select coalesce(sum(amount),0) from financial_report_revenue_lines where report_id = target_report_id)
                    + coalesce((select room_cash+room_pos+room_bank_transfer+parking_cash+parking_pos
                                from financial_report_income_breakdown where report_id = target_report_id), 0),
    expense_total = (select coalesce(sum(amount),0) from financial_report_expense_lines where report_id = target_report_id)
  where r.id = target_report_id;
  return null;
end;
$$;
create trigger trg_recalc_totals_revenue
  after insert or update or delete on financial_report_revenue_lines
  for each row execute function recalc_report_totals();
create trigger trg_recalc_totals_expense
  after insert or update or delete on financial_report_expense_lines
  for each row execute function recalc_report_totals();
create trigger trg_recalc_totals_breakdown
  after insert or update or delete on financial_report_income_breakdown
  for each row execute function recalc_report_totals();

-- 2.5 Lock enforcement: once a report is posted, both its line items AND the
-- report row itself become fully immutable at the database level — defense
-- in depth beyond the current app's UI-only lock. Corrections after posting
-- require a new adjustment report (report_type = 'adjustment'), never an
-- edit of posted history.
create or replace function forbid_edit_if_posted() returns trigger language plpgsql as $$
declare
  posted boolean;
begin
  select is_posted into posted from financial_reports where id = coalesce(new.report_id, old.report_id);
  if posted then
    raise exception 'Cannot modify line items of a posted financial report';
  end if;
  return coalesce(new, old);
end;
$$;
create trigger trg_lock_revenue_lines before insert or update or delete on financial_report_revenue_lines
  for each row execute function forbid_edit_if_posted();
create trigger trg_lock_expense_lines before insert or update or delete on financial_report_expense_lines
  for each row execute function forbid_edit_if_posted();
create trigger trg_lock_income_breakdown before insert or update or delete on financial_report_income_breakdown
  for each row execute function forbid_edit_if_posted();

create or replace function forbid_edit_if_report_itself_posted() returns trigger language plpgsql as $$
begin
  if old.is_posted then
    raise exception 'Cannot modify a posted financial report — create an adjustment report instead';
  end if;
  return new;
end;
$$;
create trigger trg_lock_financial_report before update on financial_reports
  for each row execute function forbid_edit_if_report_itself_posted();

-- ----------------------------------------------------------------------------
-- 3. RLS helper — company-wide permission check (financial_categories has no
-- hotel_id to scope has_permission() against). Extends the Phase 1 helpers.
-- ----------------------------------------------------------------------------
create or replace function has_any_permission(perm_code text)
returns boolean language sql stable security definer as $$
  select exists (
    select 1
    from user_hotel_access uha
    join role_permissions rp on rp.role_id = uha.role_id
    join permissions p on p.id = rp.permission_id
    where uha.user_id = auth.uid()
      and uha.archived_at is null
      and p.code = perm_code
  );
$$;

-- ----------------------------------------------------------------------------
-- 4. Row Level Security — financial_categories
-- ----------------------------------------------------------------------------
alter table financial_categories enable row level security;

create policy financial_categories_select on financial_categories
  for select using (auth.role() = 'authenticated');

create policy financial_categories_insert on financial_categories
  for insert with check (has_any_permission('financial_categories.manage'));

create policy financial_categories_update on financial_categories
  for update using (has_any_permission('financial_categories.manage'));

-- Hard delete only allowed when genuinely unused — mirrors the app's own
-- "archive if used, delete only if never used" rule, enforced here too so
-- no future client can bypass it by talking to the database directly.
create policy financial_categories_delete on financial_categories
  for delete using (
    has_any_permission('financial_categories.manage')
    and not exists (select 1 from financial_report_revenue_lines where category_id = financial_categories.id)
    and not exists (select 1 from financial_report_expense_lines where category_id = financial_categories.id)
  );

-- ----------------------------------------------------------------------------
-- 5. Row Level Security — financial_reports & children
-- ----------------------------------------------------------------------------
alter table financial_reports enable row level security;

create policy financial_reports_select on financial_reports
  for select using (is_hotel_accessible(hotel_id));

create policy financial_reports_insert on financial_reports
  for insert with check (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'financial_reports.manage'));

create policy financial_reports_update on financial_reports
  for update using (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'financial_reports.manage'));

-- Draft (unposted) reports can be discarded; posted ones cannot (also
-- enforced by trg_lock_financial_report, which fires before this policy
-- would even be reached on an UPDATE — this is the DELETE-specific case).
create policy financial_reports_delete on financial_reports
  for delete using (
    is_hotel_accessible(hotel_id)
    and has_permission(hotel_id, 'financial_reports.manage')
    and not is_posted
  );

alter table financial_report_revenue_lines enable row level security;
create policy report_revenue_lines_select on financial_report_revenue_lines
  for select using (exists (
    select 1 from financial_reports r where r.id = report_id and is_hotel_accessible(r.hotel_id)
  ));
create policy report_revenue_lines_write on financial_report_revenue_lines
  for all using (exists (
    select 1 from financial_reports r
    where r.id = report_id and is_hotel_accessible(r.hotel_id) and has_permission(r.hotel_id, 'financial_reports.manage')
  )) with check (exists (
    select 1 from financial_reports r
    where r.id = report_id and is_hotel_accessible(r.hotel_id) and has_permission(r.hotel_id, 'financial_reports.manage')
  ));

alter table financial_report_expense_lines enable row level security;
create policy report_expense_lines_select on financial_report_expense_lines
  for select using (exists (
    select 1 from financial_reports r where r.id = report_id and is_hotel_accessible(r.hotel_id)
  ));
create policy report_expense_lines_write on financial_report_expense_lines
  for all using (exists (
    select 1 from financial_reports r
    where r.id = report_id and is_hotel_accessible(r.hotel_id) and has_permission(r.hotel_id, 'financial_reports.manage')
  )) with check (exists (
    select 1 from financial_reports r
    where r.id = report_id and is_hotel_accessible(r.hotel_id) and has_permission(r.hotel_id, 'financial_reports.manage')
  ));

alter table financial_report_income_breakdown enable row level security;
create policy report_income_breakdown_select on financial_report_income_breakdown
  for select using (exists (
    select 1 from financial_reports r where r.id = report_id and is_hotel_accessible(r.hotel_id)
  ));
create policy report_income_breakdown_write on financial_report_income_breakdown
  for all using (exists (
    select 1 from financial_reports r
    where r.id = report_id and is_hotel_accessible(r.hotel_id) and has_permission(r.hotel_id, 'financial_reports.manage')
  )) with check (exists (
    select 1 from financial_reports r
    where r.id = report_id and is_hotel_accessible(r.hotel_id) and has_permission(r.hotel_id, 'financial_reports.manage')
  ));
