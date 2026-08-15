-- ============================================================================
-- Manazel — Phase 4: People & Contracts
-- Employees + Payroll, Contracts + Contract Documents (nested folders).
--
-- Design reference: docs/database_architecture/supabase_schema_design.md
-- Sections 9-10, cross-checked field-for-field against the real local
-- SQLite schema (lib/core/database/database_service.dart) and its status
-- enums (lib/models/employee.dart, payroll_record.dart, and the literal
-- Arabic status strings used in contracts_page.dart/contract_details_page.dart)
-- rather than re-drafted from memory — see the mapping comments below.
--
-- Backfills financial_reports.filed_by_employee_id, deferred since Phase 2
-- because `employees` didn't exist yet.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. employees
-- Status values match lib/models/employee.dart exactly: 'active' | 'suspended'
-- | 'resigned' | 'terminated'. employee_number keeps the existing app's
-- 'EMP-000001' format, auto-generated and immutable once set (a sequence +
-- default expression, not something the app computes and might get wrong).
-- ----------------------------------------------------------------------------
-- USAGE must be granted explicitly — a sequence created in a migration is
-- NOT automatically usable by `authenticated` just because the table that
-- defaults from it is (found by testing: inserting as a non-owner role
-- failed with "permission denied for sequence" until this grant was added).
create sequence employee_number_seq;
grant usage on sequence employee_number_seq to authenticated;

create table employees (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  employee_number text not null default ('EMP-' || lpad(nextval('employee_number_seq')::text, 6, '0')),
  name text not null,
  position text not null,
  salary numeric(14,2) not null,
  hired_at date not null,
  phone text,
  status text not null default 'active' check (status in ('active','suspended','resigned','terminated')),
  notes text,
  archived_at timestamptz,
  archived_by uuid references profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id),
  unique (employee_number)
);
create trigger trg_employees_updated_at before update on employees
  for each row execute function set_updated_at();
create index idx_employees_hotel on employees(hotel_id) where archived_at is null;

-- Now that employees exists, backfill the column Phase 2 deferred.
alter table financial_reports add column filed_by_employee_id uuid references employees(id);

-- ----------------------------------------------------------------------------
-- 2. payroll_records — status matches lib/models/payroll_record.dart exactly:
-- 'approved' | 'paid'. Salary can be split across cash/bank/personal funding
-- (cash_amount/bank_amount/personal_amount) same as the local app; days_worked/
-- total_days_in_period/prorated_base support partial-month proration.
-- ----------------------------------------------------------------------------
create table payroll_records (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  employee_id uuid not null references employees(id),
  period text not null,  -- 'YYYY-MM'
  base_salary numeric(14,2) not null,
  allowances_total numeric(14,2) not null default 0,
  deductions_total numeric(14,2) not null default 0,
  advances_total numeric(14,2) not null default 0,
  net_salary numeric(14,2) not null,
  status text not null default 'approved' check (status in ('approved','paid')),
  payment_source text,
  cash_amount numeric(14,2) not null default 0,
  bank_amount numeric(14,2) not null default 0,
  personal_amount numeric(14,2) not null default 0,
  approved_at timestamptz not null default now(),
  paid_at timestamptz,
  period_start date,
  period_end date,
  days_worked integer not null default 0,
  total_days_in_period integer not null default 30,
  prorated_base numeric(14,2) not null default 0,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  unique (employee_id, period)
);
create index idx_payroll_hotel_period on payroll_records(hotel_id, period);

create table employee_allowances (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  employee_id uuid not null references employees(id) on delete cascade,
  name text not null,
  amount numeric(14,2) not null,
  created_at timestamptz not null default now()
);

create table employee_deductions (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  employee_id uuid not null references employees(id) on delete cascade,
  name text not null,
  amount numeric(14,2) not null,
  notes text,
  created_at timestamptz not null default now()
);

-- Advance funding can itself be split cash/bank/personal, or funded by
-- ANOTHER hotel entirely (entity_amount/entity_hotel_id) — matches the local
-- app's employee_advances exactly.
create table employee_advances (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  employee_id uuid not null references employees(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  advance_date date not null,
  notes text,
  is_settled boolean not null default false,
  payroll_id uuid references payroll_records(id) on delete set null,
  cash_amount numeric(14,2) not null default 0,
  bank_amount numeric(14,2) not null default 0,
  personal_amount numeric(14,2) not null default 0,
  entity_amount numeric(14,2) not null default 0,
  entity_hotel_id uuid references hotels(id),
  created_at timestamptz not null default now()
);
create index idx_employee_advances_employee on employee_advances(employee_id, is_settled);

create table employee_events (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references employees(id) on delete cascade,
  hotel_id uuid not null references hotels(id) on delete cascade,
  event_type text not null,  -- 'hired' | 'promoted' | 'salary_change' | 'suspended' | 'resigned' | 'terminated'
  event_date date not null,
  reason text,
  performed_by uuid references profiles(id),
  old_value text,
  new_value text,
  created_at timestamptz not null default now()
);
create index idx_employee_events_employee on employee_events(employee_id, event_date desc);

-- ----------------------------------------------------------------------------
-- 3. contracts (+ payments). Status values match the literal Arabic strings
-- computed in contracts_page.dart/contract_details_page.dart, translated to
-- codes per decision 4: 'ساري' -> 'active', 'منتهي' -> 'expired' (contracts,
-- computed from end_date); 'مستحقة' -> 'pending', 'تم السداد' -> 'paid'
-- (contract_payments). No evidence of a distinct "cancelled" contract status
-- in the local app, so it's not invented here.
-- ----------------------------------------------------------------------------
create table contracts (
  id uuid primary key default gen_random_uuid(),
  hotel_id uuid not null references hotels(id) on delete cascade,
  name text not null,
  contractor_name text not null,
  start_date date not null,
  duration text not null,  -- free text in the local app too (e.g. "سنة واحدة"), not a fixed unit
  end_date date not null,
  total_value numeric(14,2) not null,
  payment_method text not null,
  status text not null default 'active' check (status in ('active','expired')),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references profiles(id),
  updated_by uuid references profiles(id)
);
create trigger trg_contracts_updated_at before update on contracts
  for each row execute function set_updated_at();
create index idx_contracts_hotel on contracts(hotel_id) where archived_at is null;

create table contract_payments (
  id uuid primary key default gen_random_uuid(),
  contract_id uuid not null references contracts(id) on delete cascade,
  amount numeric(14,2) not null check (amount > 0),
  payment_date date not null,
  status text not null default 'pending' check (status in ('pending','paid')),
  funding_source text,
  created_at timestamptz not null default now()
);
create index idx_contract_payments_contract on contract_payments(contract_id);

-- ----------------------------------------------------------------------------
-- 4. Contract Documents — unlimited nested folders (self-referencing),
-- matches the existing Contract Documents module already built in the local
-- app. hotel_id null = company-wide folder (visible/manageable across every
-- hotel the user has ANY access to, via has_any_permission).
-- ----------------------------------------------------------------------------
create table contract_document_folders (
  id uuid primary key default gen_random_uuid(),
  parent_folder_id uuid references contract_document_folders(id) on delete cascade,
  hotel_id uuid references hotels(id),
  name text not null,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid references profiles(id)
);
create index idx_contract_folders_parent on contract_document_folders(parent_folder_id);
create index idx_contract_folders_hotel on contract_document_folders(hotel_id);

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
create index idx_contract_documents_folder on contract_documents(folder_id);

create table contract_document_audit_log (
  id uuid primary key default gen_random_uuid(),
  document_id uuid references contract_documents(id) on delete cascade,
  folder_id uuid references contract_document_folders(id) on delete cascade,
  performed_by uuid references profiles(id),
  action text not null check (action in ('created','archived','restored','deleted','replaced')),
  reason text,
  occurred_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 5. Row Level Security
--
-- Permission codes referenced below ('employees.manage', 'payroll.manage',
-- 'contracts.manage', 'contract_documents.manage') are cataloged in
-- seed.sql, matching every earlier phase's pattern.
-- ----------------------------------------------------------------------------
alter table employees enable row level security;
create policy employees_select on employees for select using (is_hotel_accessible(hotel_id));
create policy employees_write on employees for all
  using (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'employees.manage'))
  with check (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'employees.manage'));

alter table employee_events enable row level security;
create policy employee_events_select on employee_events for select using (is_hotel_accessible(hotel_id));
create policy employee_events_write on employee_events for all
  using (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'employees.manage'))
  with check (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'employees.manage'));

-- Payroll and its supporting tables are a separate permission from general
-- HR management — running payroll/settling advances is a financial action.
alter table payroll_records enable row level security;
create policy payroll_records_select on payroll_records for select using (is_hotel_accessible(hotel_id));
create policy payroll_records_write on payroll_records for all
  using (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'payroll.manage'))
  with check (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'payroll.manage'));

alter table employee_allowances enable row level security;
create policy employee_allowances_select on employee_allowances for select using (is_hotel_accessible(hotel_id));
create policy employee_allowances_write on employee_allowances for all
  using (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'payroll.manage'))
  with check (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'payroll.manage'));

alter table employee_deductions enable row level security;
create policy employee_deductions_select on employee_deductions for select using (is_hotel_accessible(hotel_id));
create policy employee_deductions_write on employee_deductions for all
  using (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'payroll.manage'))
  with check (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'payroll.manage'));

alter table employee_advances enable row level security;
create policy employee_advances_select on employee_advances for select using (is_hotel_accessible(hotel_id));
create policy employee_advances_write on employee_advances for all
  using (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'payroll.manage'))
  with check (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'payroll.manage'));

alter table contracts enable row level security;
create policy contracts_select on contracts for select using (is_hotel_accessible(hotel_id));
create policy contracts_write on contracts for all
  using (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'contracts.manage'))
  with check (is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'contracts.manage'));

alter table contract_payments enable row level security;
create policy contract_payments_select on contract_payments for select using (
  exists (select 1 from contracts c where c.id = contract_id and is_hotel_accessible(c.hotel_id))
);
create policy contract_payments_write on contract_payments for all using (
  exists (select 1 from contracts c where c.id = contract_id and is_hotel_accessible(c.hotel_id) and has_permission(c.hotel_id, 'contracts.manage'))
) with check (
  exists (select 1 from contracts c where c.id = contract_id and is_hotel_accessible(c.hotel_id) and has_permission(c.hotel_id, 'contracts.manage'))
);

-- hotel_id null = company-wide: visible to any authenticated user with a
-- foothold anywhere, matching financial_categories' company-wide pattern.
alter table contract_document_folders enable row level security;
create policy contract_document_folders_select on contract_document_folders for select using (
  hotel_id is null or is_hotel_accessible(hotel_id)
);
create policy contract_document_folders_write on contract_document_folders for all using (
  (hotel_id is null and has_any_permission('contract_documents.manage'))
  or (hotel_id is not null and is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'contract_documents.manage'))
) with check (
  (hotel_id is null and has_any_permission('contract_documents.manage'))
  or (hotel_id is not null and is_hotel_accessible(hotel_id) and has_permission(hotel_id, 'contract_documents.manage'))
);

alter table contract_documents enable row level security;
create policy contract_documents_select on contract_documents for select using (
  exists (select 1 from contract_document_folders f where f.id = folder_id and (f.hotel_id is null or is_hotel_accessible(f.hotel_id)))
);
create policy contract_documents_write on contract_documents for all using (
  exists (select 1 from contract_document_folders f where f.id = folder_id and (
    (f.hotel_id is null and has_any_permission('contract_documents.manage'))
    or (f.hotel_id is not null and is_hotel_accessible(f.hotel_id) and has_permission(f.hotel_id, 'contract_documents.manage'))
  ))
) with check (
  exists (select 1 from contract_document_folders f where f.id = folder_id and (
    (f.hotel_id is null and has_any_permission('contract_documents.manage'))
    or (f.hotel_id is not null and is_hotel_accessible(f.hotel_id) and has_permission(f.hotel_id, 'contract_documents.manage'))
  ))
);

alter table contract_document_audit_log enable row level security;
create policy contract_document_audit_log_select on contract_document_audit_log for select using (
  exists (select 1 from contract_document_folders f where f.id = folder_id and (f.hotel_id is null or is_hotel_accessible(f.hotel_id)))
);
create policy contract_document_audit_log_insert on contract_document_audit_log for insert with check (
  exists (select 1 from contract_document_folders f where f.id = folder_id and (
    (f.hotel_id is null and has_any_permission('contract_documents.manage'))
    or (f.hotel_id is not null and is_hotel_accessible(f.hotel_id) and has_permission(f.hotel_id, 'contract_documents.manage'))
  ))
);
