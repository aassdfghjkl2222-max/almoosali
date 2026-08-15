-- ============================================================================
-- Manazel — baseline seed data
-- Safe to re-run: every insert is idempotent (on conflict do nothing / update).
-- Extend this file per phase as new modules add their own permission codes —
-- never delete or renumber existing rows here once a real environment exists,
-- since roles/permissions are referenced by id from role_permissions.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Phase 1 — system roles
-- ----------------------------------------------------------------------------
insert into roles (name, description, is_system_role) values
  ('Owner',         'Full access across all hotels and modules', true),
  ('Hotel Manager', 'Full operational access within their assigned hotel(s)', true),
  ('Accountant',    'Financial modules access within their assigned hotel(s)', true),
  ('Front Desk',    'Day-to-day operational access, no financial administration', true),
  ('Auditor',       'Read-only access across their assigned hotel(s)', true)
on conflict (name) do nothing;

-- ----------------------------------------------------------------------------
-- Phase 1 — permission codes actually wired to a policy in this phase's
-- migration. Do not seed permission codes here that no policy checks yet —
-- add them in the migration that introduces the policy, alongside the seed
-- rows for that phase.
-- ----------------------------------------------------------------------------
insert into permissions (code, module, description) values
  ('hotels.manage', 'hotels', 'Edit an existing hotel''s own details'),
  ('users.manage',  'users',  'Grant or update another user''s access to a hotel they themselves already have access to')
on conflict (code) do nothing;

-- ----------------------------------------------------------------------------
-- Phase 1 — role -> permission mapping (non-Owner roles only; Owner's blanket
-- grant is a single statement at the very bottom of this file, run last so it
-- always picks up every permission seeded above it, from every phase).
-- ----------------------------------------------------------------------------
insert into role_permissions (role_id, permission_id)
select r.id, p.id
from roles r
join permissions p on p.code in ('hotels.manage', 'users.manage')
where r.name = 'Hotel Manager'
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- Phase 2 — permission codes for Financial Categories + Daily Financial Reports.
-- financial_categories.manage is deliberately Owner-only by default: a category
-- rename/archive is visible to every hotel at once (single shared source of
-- truth, matches the existing app's own principle), so it isn't handed to
-- Hotel Manager/Accountant automatically — broaden this later as a deliberate
-- per-deployment decision, not a default.
-- ----------------------------------------------------------------------------
insert into permissions (code, module, description) values
  ('financial_categories.manage', 'financial', 'Create, edit, archive, restore or delete financial categories (company-wide)'),
  ('financial_reports.manage',    'financial', 'Create, edit and post a hotel''s daily financial reports and their line items')
on conflict (code) do nothing;

insert into role_permissions (role_id, permission_id)
select r.id, p.id
from roles r
join permissions p on p.code = 'financial_reports.manage'
where r.name in ('Hotel Manager', 'Accountant')
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- Phase 3 — permission codes for Suppliers, Purchase Invoices, Pending
-- Expenses and Shared Expenses. Both granted to Hotel Manager and Accountant
-- (day-to-day operational money flow within their own hotel), same rationale
-- as financial_reports.manage in Phase 2.
-- ----------------------------------------------------------------------------
insert into permissions (code, module, description) values
  ('suppliers.manage', 'financial', 'Create/edit/archive suppliers and their invoices/debts/payments'),
  ('pending_expenses.manage', 'financial', 'Create/edit pending expenses and shared expense distributions')
on conflict (code) do nothing;

insert into role_permissions (role_id, permission_id)
select r.id, p.id
from roles r
join permissions p on p.code in ('suppliers.manage', 'pending_expenses.manage')
where r.name in ('Hotel Manager', 'Accountant')
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- Phase 4 — permission codes for Employees, Payroll, Contracts and Contract
-- Documents. payroll.manage is deliberately separate from employees.manage
-- (running payroll/settling advances is a financial action, hiring/editing
-- HR records is not) — granted to Hotel Manager AND Accountant, matching the
-- same split already used for financial vs. operational permissions.
-- ----------------------------------------------------------------------------
insert into permissions (code, module, description) values
  ('employees.manage', 'employees', 'Hire, edit, suspend, or terminate employees'),
  ('payroll.manage', 'employees', 'Run payroll, manage allowances/deductions/advances'),
  ('contracts.manage', 'contracts', 'Create/edit contracts and their payment schedule'),
  ('contract_documents.manage', 'contracts', 'Create/archive contract document folders and documents')
on conflict (code) do nothing;

insert into role_permissions (role_id, permission_id)
select r.id, p.id
from roles r
join permissions p on p.code in ('employees.manage', 'contracts.manage', 'contract_documents.manage')
where r.name = 'Hotel Manager'
on conflict do nothing;

insert into role_permissions (role_id, permission_id)
select r.id, p.id
from roles r
join permissions p on p.code = 'payroll.manage'
where r.name in ('Hotel Manager', 'Accountant')
on conflict do nothing;

-- ----------------------------------------------------------------------------
-- Owner — blanket grant of every permission seeded above, from every phase.
-- Keep this as the LAST statement in the file; each new phase's permission
-- inserts go above this line, never below it.
-- ----------------------------------------------------------------------------
insert into role_permissions (role_id, permission_id)
select r.id, p.id
from roles r
cross join permissions p
where r.name = 'Owner'
on conflict do nothing;
