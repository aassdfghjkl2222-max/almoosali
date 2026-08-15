# Manazel — Enterprise Database Architecture (Supabase / PostgreSQL)

**Status:** Phase 1 (Foundation), Phase 2 (Financial Categories + Daily Financial Reports), Phase 3 (Suppliers, Purchase Invoices, Pending Expenses, Shared Expenses), and Phase 4 (Employees + Payroll, Contracts + Contract Documents) approved and implemented — see `supabase/migrations/` and `lib/data/supabase/`. Remaining phases still design-only.
**Scope:** Database schema + a client-side Dart integration layer (models/repositories/services) for the modules built so far. Not yet wired into `main.dart` or any existing screen — see `lib/data/supabase/supabase_config.dart`.
**Purpose:** A complete, reviewable relational design, implemented incrementally phase by phase as each is explicitly approved.

## Decisions Log

| # | Decision | Status | Date |
|---|---|---|---|
| 1 | Single-company, multi-hotel (not multi-tenant SaaS) | **Approved** | 2026-07-28 |
| 2 | Normalize `financial_reports.details_json` into real line-item tables | **Approved** | 2026-07-28 |
| 3 | Money as `numeric(14,2)`, never float | **Approved** | 2026-07-28 |
| 4 | Status/type fields as `text + check`, not native Postgres enums | **Approved** | 2026-07-28 |
| 5 | Consolidate FinancialEngine/Vault/Settlements into one `treasury_accounts`/`treasury_movements` ledger | **Deferred — NOT approved.** Keep the three systems separate, matching the current app's existing architecture, pending a later dedicated architectural review (per this project's standing rule to never merge those three without a study + explicit decision). Section 6 below is revised accordingly. | 2026-07-28 |
| 6 | Database-level lock enforcement on posted reports (trigger, not just app logic) | **Approved** | 2026-07-28 |

---

## 0. Context & Assumptions (please confirm before Phase 1)

The current production app (this repository) is a fully offline, single-device, Android-only Flutter app backed by local SQLite (`sqflite`), with no authentication, no network layer, and no multi-user concept — see `CLAUDE.md`. This document designs a *different* backend: a cloud, multi-user, multi-hotel Postgres database on Supabase. That is a foundational architecture change, not an incremental one. Two assumptions this design leans on — flag if either is wrong:

1. **Single company, multiple hotels** — one Manazel account (شركة منازل البيت المحدودة) operates many hotels. This is **not** a multi-tenant SaaS where unrelated companies share the database. If multi-company SaaS is actually the goal, every table below needs a `company_id` tenancy column and the RLS strategy changes shape (Section 8).
2. **Supabase Auth is the identity source** — every human user (owner, hotel manager, accountant, employee with app access) gets a real `auth.users` row. The app's current local PIN-based `SecurityService` model does not carry over as-is; it's replaced by Supabase Auth + a `profiles` table (Section 2).

---

## 1. Conventions

| Concern | Convention | Rationale |
|---|---|---|
| Primary keys | `uuid primary key default gen_random_uuid()` | Required by spec; safe for offline-generated records, no collision risk across hotels/devices, no sequential-ID enumeration leak. |
| Table names | `snake_case`, plural (`hotels`, `financial_categories`) | Postgres/Supabase convention. |
| Foreign key columns | `<singular_referenced_table>_id` (`hotel_id`, `category_id`) | Predictable joins. |
| Junction tables | `<table_a>_<table_b>` (`document_type_hotels`) | Matches the pattern already used in the current SQLite schema. |
| Booleans | `is_` / `has_` prefix, `boolean not null default …` | No nullable tri-state booleans anywhere. |
| Timestamps | `_at` suffix, always `timestamptz`, never bare `timestamp` | Correct across hotel time zones if the company ever operates outside one zone. |
| Money | `numeric(14,2)`, never `float`/`double precision` | Floating point is not safe for financial totals — this is a hard rule, not a style preference. |
| Status/type fields | `text` + `check (col in (...))`, not native Postgres `enum` | Adding a new status later is `alter table ... drop constraint / add constraint` (safe, no lock surprises); native enums need `alter type ... add value`, which has transaction restrictions. Favors the "no structural redesign later" requirement over strict enum typing. |
| Soft delete / archive | `archived_at timestamptz null` + `archived_by uuid null references profiles(id)` | Never hard-delete a row a financial record can reference. Matches the existing SQLite app's own `archived_at` pattern on `hotels` — continuity, not a new idea. |
| Audit fields | `created_at`, `updated_at`, `created_by`, `updated_by` on **every** table | Per spec, no exceptions. |
| Row versioning for `updated_at` | One shared trigger function, attached per table | See Section 3. |

---

## 2. Extensions, Global Functions & Auth/Identity Foundation

```sql
-- 2.1 Extensions
create extension if not exists pgcrypto;      -- gen_random_uuid()
create extension if not exists pg_trgm;       -- fast ILIKE/search on names later (Section 7)

-- 2.2 Shared "touch updated_at" trigger — attached to every table in this document
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Usage per table (repeated, not shown again per-table below for brevity):
-- create trigger trg_<table>_updated_at before update on <table>
--   for each row execute function set_updated_at();

-- 2.3 profiles — 1:1 extension of Supabase auth.users with app-specific fields.
-- auth.users itself is managed entirely by Supabase Auth; never modify it directly.
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  is_active boolean not null default true,
  default_role_id uuid, -- FK added after roles table exists (2.5)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id)
);
create trigger trg_profiles_updated_at before update on profiles
  for each row execute function set_updated_at();

-- 2.4 roles — a small, curated set (Owner, Hotel Manager, Accountant, Front Desk, Auditor…),
-- not a free-for-all — new roles are rare, deliberate, admin-created events.
create table roles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  is_system_role boolean not null default false, -- true = seeded, cannot be deleted
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_roles_updated_at before update on roles
  for each row execute function set_updated_at();

alter table profiles
  add constraint fk_profiles_default_role foreign key (default_role_id) references roles(id);

-- 2.5 permissions — fine-grained capability codes, module-scoped.
create table permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,          -- e.g. 'financial_reports.post', 'invoices.delete'
  module text not null,               -- e.g. 'financial', 'documents', 'employees'
  description text,
  created_at timestamptz not null default now()
);

create table role_permissions (
  role_id uuid not null references roles(id) on delete cascade,
  permission_id uuid not null references permissions(id) on delete cascade,
  primary key (role_id, permission_id)
);

-- 2.6 user_hotel_access — the multi-hotel isolation mechanism. A user has zero or more
-- hotels they can act on, each with a role that MAY differ per hotel (e.g. an accountant
-- who is "Accountant" at Hotel A but only "Auditor" (read-only) at Hotel B).
create table user_hotel_access (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  hotel_id uuid not null references hotels(id) on delete cascade,
  role_id uuid not null references roles(id),
  granted_at timestamptz not null default now(),
  granted_by uuid references profiles(id),
  archived_at timestamptz,
  unique (user_id, hotel_id)
);
```

> **Note on ordering:** `user_hotel_access` references `hotels`, which is defined in Section 4. In the actual migration script, tables must be created in dependency order (identity → hotels → everything else). This document groups tables by *module* for readability, not by creation order — Section 11 gives the real phase/dependency order.

---

## 3. Hotels

```sql
create table hotels (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  name_en text,
  identity_color_value integer,        -- matches existing HotelVisualIdentity concept
  phone text,
  mobile text,
  whatsapp text,
  address text,
  city text,
  status text not null default 'active' check (status in ('active','inactive')),
  archived_at timestamptz,
  archived_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id)
);
create trigger trg_hotels_updated_at before update on hotels
  for each row execute function set_updated_at();
create index idx_hotels_status on hotels(status) where archived_at is null;
```

---

## 4. Financial Categories (single source of truth — expense & revenue)

Directly continues the principle already established in this app: **one unified table for both expense and revenue categories**, referenced everywhere by ID, never by free text.

```sql
create table financial_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text,
  type text not null check (type in ('expense','revenue')),
  parent_id uuid references financial_categories(id) on delete set null, -- hierarchy, ready for future use
  icon_code integer not null,
  color_value integer not null,
  description text,
  sort_order integer not null default 0,
  is_pinned boolean not null default false,   -- "favorite"
  is_default boolean not null default false,  -- pre-selected default (e.g. for invoices)
  usage_count integer not null default 0,
  last_used_at timestamptz,
  archived_at timestamptz,                    -- archive, never delete a used category
  archived_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id),
  unique (type, name)                          -- duplicate-name protection, exact match, per type
);
create trigger trg_financial_categories_updated_at before update on financial_categories
  for each row execute function set_updated_at();
create index idx_financial_categories_type on financial_categories(type) where archived_at is null;
create index idx_financial_categories_parent on financial_categories(parent_id);
```

---

## 5. Daily Financial Reports (normalized — replaces the old JSON-blob line items)

The current SQLite app stores free-form report line items inside a `details_json` text blob. That was a reasonable shortcut for a single-device local app; it does **not** belong in a relational cloud schema meant to support real analytics. This design normalizes it into real line-item tables.

```sql
create table financial_reports (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  report_date date not null,
  report_type text not null default 'main' check (report_type in ('main','adjustment')),
  income_total numeric(14,2) not null default 0,   -- denormalized cache, kept in sync by trigger (5.4)
  expense_total numeric(14,2) not null default 0,  -- same
  notes text,
  increase_amount numeric(14,2) not null default 0,
  increase_description text,
  increase_funding_source text,
  shortage_amount numeric(14,2) not null default 0,
  shortage_description text,
  shortage_funding_source text,
  filed_by_employee_id uuid references employees(id),
  is_posted boolean not null default false,   -- posted/finalized — locks the report (5.5)
  is_locked boolean not null default false,
  posted_at timestamptz,
  posted_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id),
  unique (hotel_id, report_date, report_type)   -- the real-world rule: one main report per hotel per day
);
create trigger trg_financial_reports_updated_at before update on financial_reports
  for each row execute function set_updated_at();
create index idx_financial_reports_hotel_date on financial_reports(hotel_id, report_date desc);

-- 5.1 Revenue line items
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

-- 5.2 Expense line items
create table financial_report_expense_lines (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references financial_reports(id) on delete cascade,
  category_id uuid not null references financial_categories(id),
  amount numeric(14,2) not null check (amount > 0),
  payment_method text not null,
  funding_source_hotel_id uuid references hotels(id), -- set only when funded by another hotel
  pending_expense_id uuid references pending_expenses(id), -- set only if this line originated from a transferred pending expense
  supplier_id uuid references suppliers(id),
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);
create index idx_report_expense_lines_report on financial_report_expense_lines(report_id);
create index idx_report_expense_lines_category on financial_report_expense_lines(category_id);

-- 5.3 Fixed income breakdown (room/parking cash-pos-transfer split) — kept as explicit
-- columns rather than another line-item table because these five numbers are structurally
-- fixed per report, not an open-ended list.
create table financial_report_income_breakdown (
  report_id uuid primary key references financial_reports(id) on delete cascade,
  room_cash numeric(14,2) not null default 0,
  room_pos numeric(14,2) not null default 0,
  room_bank_transfer numeric(14,2) not null default 0,
  parking_cash numeric(14,2) not null default 0,
  parking_pos numeric(14,2) not null default 0
);

-- 5.4 Trigger: keep financial_reports.income_total / expense_total in sync automatically
-- whenever line items change, so no application code can let the cached totals drift.
create or replace function recalc_report_totals() returns trigger language plpgsql as $$
declare
  target_report_id uuid := coalesce(new.report_id, old.report_id);
begin
  -- coalesce() must wrap the ENTIRE income_breakdown scalar subquery, not just
  -- the column expression inside it — a report with no breakdown row yet makes
  -- that subquery return zero rows (NULL as a scalar), which an inner coalesce
  -- never gets a chance to run against (caught by testing during Phase 2).
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

-- 5.5 Lock enforcement: once a report is posted, its line items become immutable at the
-- database level, not just the application level (defense in depth vs. the current app's
-- UI-only lock).
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
```

---

## 6. Treasury, Vault & Settlements — DEFERRED (decision 5 not approved)

The original draft of this section proposed consolidating three money-tracking concepts into one `treasury_accounts`/`treasury_movements` ledger. **That consolidation was explicitly not approved** and must not be implemented. Per this project's standing rule, those three systems are never merged without a dedicated study and an explicit decision, and that review hasn't happened yet.

Until that review, the cloud schema must preserve the same three-way separation the current SQLite app already has:

- **Financial Engine** (currently `financial_accounts` / `financial_ledger`)
- **Vault** (currently `vault_balances` / `vault_transactions`)
- **Settlements** (currently `settlements` / `settlement_accounts` / `settlement_transactions`)

Each will get its own Postgres design (UUID keys, audit fields, the same conventions as every other table in this document) as its own reviewed section when that architectural review happens — not sketched prematurely here, since inventing that design now would itself be a step toward a merge/shape decision that hasn't been made. Phase 2 of the rollout plan (Section 23) is scoped to `financial_categories` and `financial_reports` only until this section is resolved.

---

## 7. Pending Expenses & Shared Expenses

> **Implemented** in `supabase/migrations/20260730000002_phase3_operational_money_flow.sql` +
> `20260730000003_phase3_rpcs.sql` — treat those files as authoritative over the draft below.
> Two things were refined during implementation and testing that this draft doesn't show:
> `payment_method` became a closed `check` set (`'cash','pos','personal','owner_drawing','deferred'`)
> instead of free text; and creating a shared expense group is never a raw multi-table insert —
> it goes through `create_shared_expense_distribution()`, a `security definer` RPC (the funding
> hotel's permission is the sole gate; it then legitimately writes `pending_expenses` rows onto
> the *other* allocated hotels, matching how a real shared-cost split actually works). That RPC's
> `security invoker` alternative was tried first and rejected — an ordinary user can't insert into
> a hotel's `pending_expenses` they don't have `pending_expenses.manage` on, which is exactly the
> hotel being billed, not the hotel initiating the charge.

```sql
create table pending_expenses (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  category_id uuid not null references financial_categories(id),
  supplier_id uuid references suppliers(id),
  amount numeric(14,2) not null check (amount > 0),
  statement text not null,
  payment_method text not null,
  funding_source_hotel_id uuid references hotels(id),
  due_date date,
  is_transferred boolean not null default false,
  transferred_at timestamptz,
  shared_expense_group_id uuid references shared_expense_groups(id) on delete set null,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id)
);
create trigger trg_pending_expenses_updated_at before update on pending_expenses
  for each row execute function set_updated_at();
create index idx_pending_expenses_hotel on pending_expenses(hotel_id, is_transferred);
create index idx_pending_expenses_category on pending_expenses(category_id);

create table pending_expense_attachments (
  id uuid primary key default gen_random_uuid(),
  pending_expense_id uuid not null references pending_expenses(id) on delete cascade,
  storage_path text not null,   -- Supabase Storage object path
  file_name text not null,
  file_type text not null,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);

create table shared_expense_groups (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references financial_categories(id),
  description text,
  total_amount numeric(14,2) not null check (total_amount > 0),
  payment_method text not null,
  funding_hotel_id uuid not null references hotels(id),
  expense_date date not null,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);

create table shared_expense_allocations (
  id uuid primary key default gen_random_uuid(),
  shared_expense_group_id uuid not null references shared_expense_groups(id) on delete cascade,
  hotel_id uuid not null references hotels(id),
  amount numeric(14,2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  unique (shared_expense_group_id, hotel_id)
);
create index idx_shared_alloc_group on shared_expense_allocations(shared_expense_group_id);
```

---

## 8. Suppliers & Purchase Invoices

> **Implemented** in `supabase/migrations/20260730000002_phase3_operational_money_flow.sql` +
> `20260730000003_phase3_rpcs.sql` — treat those files as authoritative over the draft below.
> `funding_source` became `funding_source_type` with a closed `check` set of 5 English codes
> mirroring the existing local app's `kInvoiceFundingSources` exactly (`hotel_safe`, `owner`,
> `other_hotel`, `personal_expense`, `deferred_supplier`) rather than free text, consistent with
> decision 4 (codes, not localized strings, in the data layer). Invoice creation goes through
> `create_invoice()` (`security invoker` — no cross-hotel concern here), which atomically writes
> the `invoice_audit_log` row and, only when `funding_source_type = 'deferred_supplier'`, the
> matching `supplier_debts` row — mirrors `_ensureDeferredPurchaseDebt` in the existing local app.

```sql
create table suppliers (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  official_name text not null,
  short_name text not null,
  tax_number text not null,
  default_category_id uuid references financial_categories(id), -- FK now, not free text
  notes text,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id),
  unique (hotel_id, tax_number)
);
create trigger trg_suppliers_updated_at before update on suppliers
  for each row execute function set_updated_at();
create index idx_suppliers_hotel on suppliers(hotel_id) where archived_at is null;
create index idx_suppliers_name_trgm on suppliers using gin (official_name gin_trgm_ops);

create table invoices (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  supplier_id uuid not null references suppliers(id),
  invoice_number text not null,
  invoice_date date not null,
  amount_before_tax numeric(14,2) not null,
  vat numeric(14,2) not null,
  total_amount numeric(14,2) not null,
  category_id uuid not null references financial_categories(id),
  funding_source text not null,
  payment_method text,
  related_hotel_id uuid references hotels(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id),
  unique (hotel_id, supplier_id, invoice_number)
);
create trigger trg_invoices_updated_at before update on invoices
  for each row execute function set_updated_at();
create index idx_invoices_hotel_date on invoices(hotel_id, invoice_date desc);
create index idx_invoices_category on invoices(category_id);
create index idx_invoices_supplier on invoices(supplier_id);

create table invoice_attachments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references invoices(id) on delete cascade,
  storage_path text not null,
  file_name text not null,
  file_type text not null,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);

create table invoice_audit_log (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references invoices(id) on delete cascade,
  user_id uuid references profiles(id),
  operation_type text not null check (operation_type in ('create','update','delete')),
  changed_fields jsonb,
  occurred_at timestamptz not null default now()
);

create table supplier_debts (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  supplier_id uuid not null references suppliers(id),
  invoice_id uuid not null references invoices(id) unique,
  amount numeric(14,2) not null,
  status text not null default 'unpaid' check (status in ('unpaid','partially_paid','paid')),
  created_at timestamptz not null default now()
);

create table supplier_payments (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  supplier_id uuid not null references suppliers(id),
  amount numeric(14,2) not null check (amount > 0),
  method text,
  payment_date date not null,
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);
```

---

## 9. Employees

> **Implemented** in `supabase/migrations/20260730000004_phase4_people_and_contracts.sql` +
> `20260730000005_phase4_rpcs.sql` — treat those files as authoritative over the draft below.
> Cross-checked field-for-field against the real local SQLite schema and Dart models rather than
> re-drafted from memory: `employees.status` uses the real four values (`active`/`suspended`/
> `resigned`/`terminated`, from `lib/models/employee.dart`, not the draft's `active`/`on_leave`/
> `terminated`); `employee_number` is database-generated (`EMP-000001` format via a sequence,
> immutable) rather than app-assigned; `payroll_records`/`employee_advances` carry the fuller
> real field set (cash/bank/personal/entity split amounts, proration fields) the draft omitted.
> Payroll creation goes through `create_payroll_record()`, which recomputes `advances_total`
> from the real unsettled `employee_advances` rows rather than trusting a client-supplied number,
> and settles exactly those advances atomically with the payroll row.

```sql
create table employees (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  employee_number text,
  full_name text not null,
  position text not null,
  base_salary numeric(14,2) not null,
  hired_at date not null,
  phone text,
  status text not null default 'active' check (status in ('active','on_leave','terminated')),
  notes text,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id)
);
create trigger trg_employees_updated_at before update on employees
  for each row execute function set_updated_at();
create index idx_employees_hotel on employees(hotel_id) where archived_at is null;

create table payroll_records (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  employee_id uuid not null references employees(id),
  period text not null,              -- 'YYYY-MM'
  base_salary numeric(14,2) not null,
  allowances_total numeric(14,2) not null default 0,
  deductions_total numeric(14,2) not null default 0,
  advances_total numeric(14,2) not null default 0,
  net_salary numeric(14,2) not null,
  status text not null default 'approved',
  approved_at timestamptz not null default now(),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  unique (employee_id, period)
);
create index idx_payroll_hotel_period on payroll_records(hotel_id, period);

create table employee_allowances (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  name text not null,
  amount numeric(14,2) not null,
  created_at timestamptz not null default now()
);

create table employee_deductions (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  name text not null,
  amount numeric(14,2) not null,
  notes text,
  created_at timestamptz not null default now()
);

create table employee_advances (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  amount numeric(14,2) not null,
  advance_date date not null,
  is_settled boolean not null default false,
  payroll_id uuid references payroll_records(id) on delete set null,
  created_at timestamptz not null default now()
);

create table employee_events (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  hotel_id uuid not null references hotels(id) on delete cascade,
  event_type text not null,          -- 'hired','promoted','salary_change','terminated', ...
  event_date date not null,
  reason text,
  performed_by uuid references profiles(id),
  old_value text,
  new_value text,
  created_at timestamptz not null default now()
);
create index idx_employee_events_employee on employee_events(employee_id, event_date desc);
```

---

## 10. Contracts (+ Contract Documents, nested folders)

> **Implemented** in `supabase/migrations/20260730000004_phase4_people_and_contracts.sql` —
> treat that file as authoritative over the draft below. `contracts.status`/`contract_payments.status`
> use codes translated from the real Arabic strings actually computed/stored in
> `contracts_page.dart`/`contract_details_page.dart` (`'ساري'`→`active`, `'منتهي'`→`expired`,
> `'مستحقة'`→`pending`, `'تم السداد'`→`paid`) rather than the draft's invented `active`/`completed`/
> `cancelled` set — no evidence of a distinct "cancelled" contract status exists in the local app,
> so it wasn't carried over. `duration` stays free text (e.g. `"سنة واحدة"`), matching the local
> app, not the draft's `duration_months integer`.

```sql
create table contracts (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  name text not null,
  contractor_name text not null,
  start_date date not null,
  duration_months integer not null,
  end_date date not null,
  total_value numeric(14,2) not null,
  payment_method text not null,
  status text not null default 'active' check (status in ('active','completed','cancelled')),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id)
);
create trigger trg_contracts_updated_at before update on contracts
  for each row execute function set_updated_at();

create table contract_payments (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references contracts(id) on delete cascade,
  amount numeric(14,2) not null,
  due_date date not null,
  status text not null default 'pending' check (status in ('pending','paid','overdue')),
  funding_source text,
  created_at timestamptz not null default now()
);

-- Contract documents: unlimited nested folders (self-referencing), matches the existing
-- Contract Documents module already built in the current app.
create table contract_document_folders (
  id uuid primary key default gen_random_uuid(),
  parent_folder_id uuid references contract_document_folders(id) on delete cascade,
  hotel_id uuid references hotels(id),  -- null = company-wide folder
  name text not null,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);
create index idx_contract_folders_parent on contract_document_folders(parent_folder_id);

create table contract_documents (
  id uuid primary key default gen_random_uuid(),
  folder_id uuid not null references contract_document_folders(id) on delete cascade,
  name text not null,
  storage_path text not null,
  file_type text not null,
  version integer not null default 1,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id)
);
create trigger trg_contract_documents_updated_at before update on contract_documents
  for each row execute function set_updated_at();

create table contract_document_audit_log (
  id uuid primary key default gen_random_uuid(),
  document_id uuid references contract_documents(id) on delete cascade,
  folder_id uuid references contract_document_folders(id) on delete cascade,
  performed_by uuid references profiles(id),
  action text not null,   -- 'created','archived','restored','deleted','replaced'
  reason text,
  occurred_at timestamptz not null default now()
);
```

---

## 11. Shared / Hotel Documents (general document management)

```sql
create table document_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  color_value integer not null,
  created_at timestamptz not null default now()
);

create table document_types (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references document_categories(id),
  name text not null,
  description text,
  is_mandatory boolean not null default false,
  requires_renewal boolean not null default false,
  lifecycle text not null default 'permanent' check (lifecycle in ('permanent','renewable')),
  scope text not null default 'all' check (scope in ('all','single')),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (name)
);

create table document_type_hotels (
  document_type_id uuid not null references document_types(id) on delete cascade,
  hotel_id uuid not null references hotels(id) on delete cascade,
  primary key (document_type_id, hotel_id)
);

create table documents (
  id uuid primary key default gen_random_uuid(),
  document_type_id uuid references document_types(id),
  owner_type text not null default 'hotel' check (owner_type in ('hotel','employee','company')),
  owner_id uuid not null,  -- soft reference: hotel.id / employee.id / a fixed company sentinel
  name text not null,
  document_number text,
  issue_date date,
  expiry_date date,
  issuing_authority text,
  notes text,
  hotel_scope text not null default 'single' check (hotel_scope in ('single','shared')),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id)
);
create trigger trg_documents_updated_at before update on documents
  for each row execute function set_updated_at();
create index idx_documents_owner on documents(owner_type, owner_id);
create index idx_documents_expiry on documents(expiry_date) where archived_at is null;

create table document_hotels (   -- for hotel_scope = 'shared'
  document_id uuid not null references documents(id) on delete cascade,
  hotel_id uuid not null references hotels(id) on delete cascade,
  primary key (document_id, hotel_id)
);

create table document_attachments (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references documents(id) on delete cascade,
  storage_path text not null,
  file_name text not null,
  file_type text not null,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);
```

---

## 12. Notes

```sql
create table notes (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid references hotels(id) on delete cascade,  -- null = company-wide note
  title text not null,
  content text not null,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id)
);
create trigger trg_notes_updated_at before update on notes
  for each row execute function set_updated_at();
```

---

## 13. Notifications

```sql
create table notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id) on delete cascade, -- null = broadcast to all with hotel access
  hotel_id uuid references hotels(id) on delete cascade,
  type text not null,               -- 'document_expiry','invoice_due','report_reminder', ...
  title text not null,
  body text,
  related_type text,
  related_id uuid,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index idx_notifications_user_unread on notifications(user_id) where is_read = false;

create table notification_preferences (
  user_id uuid primary key references profiles(id) on delete cascade,
  notifications_enabled boolean not null default true,
  sound_enabled boolean not null default true,
  vibration_enabled boolean not null default true,
  critical_enabled boolean not null default true,
  silent_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);
```

---

## 14. Parking Management

The current app only has "Parking Revenue" as a financial-category *label* — there is no operational parking data model yet. This is a proposed baseline, not a migration of existing data (there is none):

```sql
create table parking_spaces (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  space_number text not null,
  space_type text not null default 'car' check (space_type in ('car','motorcycle','vip')),
  status text not null default 'available' check (status in ('available','occupied','maintenance')),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (hotel_id, space_number)
);
create trigger trg_parking_spaces_updated_at before update on parking_spaces
  for each row execute function set_updated_at();

create table parking_sessions (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references parking_spaces(id),
  hotel_id uuid not null references hotels(id) on delete cascade,
  vehicle_plate_number text,
  check_in_at timestamptz not null default now(),
  check_out_at timestamptz,
  amount_charged numeric(14,2),
  payment_method text,
  category_id uuid references financial_categories(id), -- links to the "Parking Revenue" category
  created_by uuid references profiles(id),
  created_at timestamptz not null default now()
);
create index idx_parking_sessions_hotel_open on parking_sessions(hotel_id) where check_out_at is null;
```

---

## 15. Inventory

Also a new module (not present in the current app):

```sql
create table inventory_items (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  name text not null,
  sku text,
  unit text not null,               -- 'piece','box','liter', ...
  unit_cost numeric(14,2),
  reorder_level numeric(14,2) not null default 0,
  current_quantity numeric(14,2) not null default 0, -- cached; kept in sync by trigger below
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id)
);
create trigger trg_inventory_items_updated_at before update on inventory_items
  for each row execute function set_updated_at();
create index idx_inventory_items_hotel on inventory_items(hotel_id) where archived_at is null;

create table inventory_stock_movements (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references inventory_items(id) on delete cascade,
  movement_type text not null check (movement_type in ('in','out','adjustment')),
  quantity numeric(14,2) not null,
  reference_type text,
  reference_id uuid,
  notes text,
  created_by uuid references profiles(id),
  created_at timestamptz not null default now()
);
create index idx_inventory_movements_item on inventory_stock_movements(item_id, created_at desc);

create or replace function apply_inventory_movement() returns trigger language plpgsql as $$
begin
  update inventory_items set current_quantity = current_quantity +
    (case new.movement_type when 'in' then new.quantity when 'out' then -new.quantity else new.quantity end)
  where id = new.item_id;
  return new;
end;
$$;
create trigger trg_apply_inventory_movement after insert on inventory_stock_movements
  for each row execute function apply_inventory_movement();
```

---

## 16. Activity Logs (system-wide audit trail)

```sql
create table activity_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references profiles(id),
  hotel_id uuid references hotels(id),
  module text not null,             -- 'financial','documents','employees', ...
  action text not null,             -- 'create','update','archive','delete','post', ...
  entity_type text not null,
  entity_id uuid not null,
  old_values jsonb,
  new_values jsonb,
  ip_address text,
  created_at timestamptz not null default now()
);
create index idx_activity_logs_entity on activity_logs(entity_type, entity_id);
create index idx_activity_logs_user on activity_logs(user_id, created_at desc);
create index idx_activity_logs_created on activity_logs(created_at desc);
```

---

## 17. Settings (system + hotel-level, extensible without redesign)

Deliberately key/value (EAV-lite), not one column per setting — new settings must never require a migration.

```sql
create table system_settings (
  key text primary key,
  value jsonb not null,
  description text,
  updated_at timestamptz not null default now(),
  updated_by uuid references profiles(id)
);

create table hotel_settings (
  hotel_id uuid not null references hotels(id) on delete cascade,
  key text not null,
  value jsonb not null,
  updated_at timestamptz not null default now(),
  updated_by uuid references profiles(id),
  primary key (hotel_id, key)
);
```

---

## 18. Backup Metadata

```sql
create table backup_logs (
  id uuid primary key default gen_random_uuid(),
  backup_type text not null check (backup_type in ('manual','auto')),
  status text not null check (status in ('running','succeeded','failed')),
  file_size_bytes bigint,
  storage_path text,
  triggered_by uuid references profiles(id),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  error_message text
);
```

---

## 19. Relationships Summary (high-level)

- `hotels` is the hub every operational table hangs off via `hotel_id`.
- `financial_categories` is referenced by ID from every money-classifying table: report lines, pending expenses, shared expenses, invoices, suppliers (default), parking sessions. **Never** a free-text category name anywhere in this schema.
- `financial_reports` → `financial_report_revenue_lines` / `financial_report_expense_lines` / `financial_report_income_breakdown` (1-to-many / 1-to-1).
- Financial Engine / Vault / Settlements: intentionally not designed yet (Section 6) — remain three separate systems pending review.
- `contracts` → `contract_payments` (1-to-many); `contract_document_folders` self-referencing tree → `contract_documents`.
- `documents` many-to-many `hotels` via `document_hotels` when shared across hotels; many-to-many `document_types`↔`hotels` via `document_type_hotels` for scoping which types apply where.
- `profiles` many-to-many `hotels` via `user_hotel_access`, carrying a `role_id` per pairing — this is the whole multi-hotel isolation mechanism.
- `roles` many-to-many `permissions` via `role_permissions`.

No table stores the same fact twice — e.g., a category's name lives only in `financial_categories.name`; every other table stores `category_id` and joins when it needs the name, so a rename is instant and universal (this is the exact property the app's `financial_categories` module already values today).

---

## 20. Indexing Strategy (Section: Performance)

Already inlined per table above; summarized by pattern:

- **Every foreign key** has a supporting index (Postgres does not auto-index FK columns, unlike the PK side).
- **Every hotel-scoped, time-series table** (`financial_reports`, `invoices`, `activity_logs`, and whatever the Financial Engine/Vault/Settlements tables turn out to be once designed) gets a composite `(hotel_id, date/time desc)` index — this is the exact access pattern reports and dashboards use ("this hotel, this date range, newest first").
- **Partial indexes** (`where archived_at is null`) on lookup tables (`hotels`, `suppliers`, `employees`, `inventory_items`) so the far more common "active only" queries scan a much smaller index than "all rows ever."
- **Trigram indexes** (`pg_trgm`) on free-text search columns (`suppliers.official_name`) for fast partial-match search without a full external search service.
- **JSONB columns** (`activity_logs.old_values/new_values`, `system_settings.value`) are not indexed by default — add a `gin` index only if a specific query pattern against them becomes real (avoid speculative indexes on write-heavy audit tables).

---

## 21. Row Level Security Strategy

RLS is enabled on every table that carries a `hotel_id` (directly or via a parent). Two helper functions carry all the logic so policies stay one-line and consistent:

```sql
-- Does the current authenticated user have any (non-archived) access grant to this hotel?
create or replace function is_hotel_accessible(target_hotel_id uuid)
returns boolean language sql stable security definer as $$
  select exists (
    select 1 from user_hotel_access uha
    where uha.user_id = auth.uid()
      and uha.hotel_id = target_hotel_id
      and uha.archived_at is null
  );
$$;

-- Does the current user's role (for the given hotel) carry a specific permission code?
create or replace function has_permission(target_hotel_id uuid, perm_code text)
returns boolean language sql stable security definer as $$
  select exists (
    select 1
    from user_hotel_access uha
    join role_permissions rp on rp.role_id = uha.role_id
    join permissions p on p.id = rp.permission_id
    where uha.user_id = auth.uid()
      and uha.hotel_id = target_hotel_id
      and uha.archived_at is null
      and p.code = perm_code
  );
$$;
```

**Representative policy pattern** (repeated per hotel-scoped table, shown once for `invoices` and once for a child table `invoice_attachments` to show the parent-lookup pattern):

```sql
alter table invoices enable row level security;

create policy invoices_select on invoices
  for select using (is_hotel_accessible(hotel_id));

create policy invoices_insert on invoices
  for insert with check (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'invoices.create'));

create policy invoices_update on invoices
  for update using (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'invoices.edit'));

-- No delete policy at all — invoices are never hard-deleted by any role; this is enforced
-- by RLS itself (no policy = no delete access), not just application code.

alter table invoice_attachments enable row level security;
create policy invoice_attachments_select on invoice_attachments
  for select using (
    exists (select 1 from invoices i where i.id = invoice_id and is_hotel_accessible(i.hotel_id))
  );
```

Company-wide tables with no `hotel_id` (`roles`, `permissions`, `financial_categories`, `document_categories`, `document_types`) get simpler policies: readable by any authenticated user, writable only by roles holding a matching `*.manage` permission — financial categories specifically should require `financial_categories.manage`, kept separate from ordinary `financial_reports.*` permissions, since category management is explicitly meant to be an admin-only action (mirrors the existing app's "only one place to manage categories" principle).

`profiles` gets a policy so a user can always read/update their own row (`id = auth.uid()`), plus a broader read policy for anyone who shares at least one hotel with them (needed for "created_by"/"assigned to" display names to resolve without exposing the entire user directory).

---

## 22. Migration Notes — mapping from the current SQLite schema

For whoever executes Phase 1+, a quick correspondence table (not exhaustive, but covers every structural change worth calling out):

| Current SQLite (`database_service.dart`) | This design | What changed and why |
|---|---|---|
| `expense_categories` / `financial_report_items` (already unified into `financial_categories` in-app) | `financial_categories` | Same shape, `hotel_id` dropped (was always null), integer id → uuid, `is_visible` → `archived_at`. |
| `financial_reports.details_json` | `financial_report_revenue_lines` + `financial_report_expense_lines` + `financial_report_income_breakdown` | JSON blob → real normalized rows, queryable/indexable/aggregable directly instead of via `LIKE` matching (the current app's `isFinancialCategoryInUse` does a `details_json LIKE '%"category_id":$id%'` check — this design makes that a plain indexed join). |
| `invoices.expense_category` (text) + `invoices.category_id` (added later) | `invoices.category_id` (not-null FK) | The current app carries both a legacy text snapshot and a real FK for backward compatibility with pre-migration rows; a fresh cloud schema doesn't need the text column at all. |
| `vault_balances` / `vault_transactions`, `financial_accounts` / `financial_ledger`, `settlements` / `settlement_accounts` / `settlement_transactions` | Not yet designed (Section 6) | Kept as three separate systems per decision 5 (deferred) — will each get their own UUID/Postgres design once reviewed, not merged. |
| PIN-based local `SecurityService` | Supabase Auth + `profiles` + `user_hotel_access` | Local single-device PIN has no meaning in a multi-user cloud system; replaced entirely. |
| No `roles`/`permissions` tables (single implicit "owner" user) | `roles` / `permissions` / `role_permissions` / `user_hotel_access` | New — required for real multi-user, multi-hotel access control. |

---

## 23. Suggested Phased Implementation Order

Given as a starting proposal, not a commitment — re-sequence freely:

1. **Foundation:** `profiles`, `roles`, `permissions`, `role_permissions`, `hotels`, `user_hotel_access`, RLS helper functions. **— Implemented, see `supabase/migrations/20260728000001_phase1_foundation.sql`.**
2. **Financial core:** `financial_categories`, `financial_reports` + line-item tables + triggers. (Financial Engine / Vault / Settlements excluded until Section 6 is reviewed and designed.) **— Implemented: `supabase/migrations/20260728000002_phase2_financial_core.sql` + `20260730000001_phase2_reports_and_category_rpcs.sql` (atomic save/post/reorder RPCs), plus the Dart integration layer under `lib/data/supabase/` (models, `SupaFinancialCategoryRepository`, `SupaFinancialReportRepository`, `SupaDailyFinancialReportService`). Not yet wired into any screen.**
3. **Operational money flow:** `pending_expenses`, `shared_expense_groups`/`allocations`, `suppliers`, `invoices` + attachments/audit log, `supplier_debts`/`supplier_payments`. **— Implemented: `supabase/migrations/20260730000002_phase3_operational_money_flow.sql` + `20260730000003_phase3_rpcs.sql` (atomic `create_shared_expense_distribution`, `create_invoice`; `save_daily_financial_report` extended to transfer/un-transfer linked pending expenses), plus `lib/data/supabase/` models/repositories for all four modules. Also backfilled Phase 2's two deferred columns (`financial_report_expense_lines.pending_expense_id`/`supplier_id`) now that their targets exist.**
4. **People & contracts:** `employees` + payroll tables, `contracts` + payments + document folders/documents. **— Implemented: `supabase/migrations/20260730000004_phase4_people_and_contracts.sql` + `20260730000005_phase4_rpcs.sql` (atomic `create_payroll_record` with server-verified advance settlement, `mark_payroll_paid`), plus `lib/data/supabase/` models/repositories for all four modules. Also backfilled `financial_reports.filed_by_employee_id`, deferred since Phase 2.**
5. **Documents, notes, notifications:** `document_categories`/`document_types`/`documents` + attachments, `notes`, `notifications`.
6. **New modules with no existing data to migrate:** `parking_spaces`/`parking_sessions`, `inventory_items`/`inventory_stock_movements`.
7. **Cross-cutting:** `activity_logs`, `system_settings`/`hotel_settings`, `backup_logs` — these can be added at any point without disturbing anything already built, by design.

Each phase is a closed, working slice — nothing in a later phase is required for an earlier phase to function, so this can genuinely ship incrementally rather than as one big-bang cutover.
