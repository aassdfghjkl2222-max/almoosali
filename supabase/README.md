# Manazel — Supabase Database

This folder holds the SQL migrations for the cloud database design in
`../docs/database_architecture/supabase_schema_design.md`. The matching Dart
integration layer (models/repositories/services) lives at
`../lib/data/supabase/`. **Neither is connected to the running Flutter app
yet** — `main.dart` and every existing screen are unchanged; the app still
runs entirely on local SQLite. See the design doc's Decisions Log for what's
approved so far.

## Status

- **Phase 1 (Foundation) — implemented:** `migrations/20260728000001_phase1_foundation.sql`
  + `seed.sql`. Covers `roles`, `permissions`, `role_permissions`, `hotels`,
  `profiles`, `user_hotel_access`, and the `is_hotel_accessible`/`has_permission`
  RLS helper functions, with RLS enabled and policies on every Phase 1 table.
- **Phase 2 (Financial Categories + Daily Financial Reports) — implemented:**
  `migrations/20260728000002_phase2_financial_core.sql` (tables, triggers,
  RLS) + `migrations/20260730000001_phase2_reports_and_category_rpcs.sql`
  (atomic `save_daily_financial_report`, `post_financial_report`,
  `reorder_financial_categories`, `reset_financial_category_order` RPCs) +
  matching `seed.sql` permission rows. Dart layer: `lib/data/supabase/models/`,
  `repositories/` (`SupaFinancialCategoryRepository`, `SupaFinancialReportRepository`),
  `services/SupaDailyFinancialReportService`.
- **Phase 3 (Suppliers, Purchase Invoices, Pending Expenses, Shared Expenses) — implemented:**
  `migrations/20260730000002_phase3_operational_money_flow.sql` (tables, RLS,
  backfills Phase 2's deferred `financial_report_expense_lines.pending_expense_id`/
  `supplier_id` columns) + `migrations/20260730000003_phase3_rpcs.sql`
  (`create_shared_expense_distribution`, `create_invoice`, plus
  `save_daily_financial_report` extended to transfer/un-transfer linked
  pending expenses) + matching `seed.sql` permission rows. Dart layer:
  `SupaSupplierRepository`, `SupaInvoiceRepository`, `SupaPendingExpenseRepository`,
  `SupaSharedExpenseRepository`.
- **Phase 4 (Employees + Payroll, Contracts + Contract Documents) — implemented:**
  `migrations/20260730000004_phase4_people_and_contracts.sql` (tables, RLS,
  backfills `financial_reports.filed_by_employee_id`) +
  `migrations/20260730000005_phase4_rpcs.sql` (`create_payroll_record` with
  server-verified advance settlement, `mark_payroll_paid`) + matching
  `seed.sql` permission rows. Dart layer: `SupaEmployeeRepository`,
  `SupaPayrollRepository`, `SupaContractRepository`, `SupaContractDocumentRepository`.
- **Phases 5-7 — design only,** not yet migrated. See Section 23 of the design
  doc. Financial Engine / Vault / Settlements remain excluded from every phase
  until the deferred consolidation review (decision 5) happens.

## Applying the migrations locally / to a real project

This repo does not include a `config.toml` or any project credentials — those
are environment-specific and shouldn't be committed. To apply these migrations
against your own Supabase project:

```bash
# One-time setup in this folder (creates config.toml, links to your project):
supabase init          # if not already a Supabase-CLI project
supabase link --project-ref <your-project-ref>

# Apply all migrations in order:
supabase db push

# Load baseline roles/permissions:
supabase db execute -f seed.sql
```

Or, without the CLI: run every file in `migrations/` in filename order, then
`seed.sql`, in the Supabase Studio SQL editor.

Every migration in this folder has been applied and functionally verified
against a real (throwaway, local) PostgreSQL 15 instance with RLS actually
enforced through a non-superuser role — not just checked for syntax. See the
git history / task notes for what was exercised (permission-gated
insert/update/delete, the posted-report lock at the trigger level, the
totals-recalculation trigger, and the RPC-based atomic save/post/reorder
paths).

## Using the Dart integration layer

Nothing auto-connects. To actually use it from the app:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=xxxxxxxx
```

then, once and only where you explicitly decide to start using it (not from
`main.dart` automatically):

```dart
await SupabaseConfig.initialize();
```

`SupaFinancialCategoryRepository` / `SupaFinancialReportRepository` /
`SupaDailyFinancialReportService` are otherwise ordinary Dart classes — no
different to use than the existing local `FinancialCategoryRepository`,
except every id is a `String` (uuid) instead of an `int`, and report saving
goes through one atomic `saveWholeReport`/`saveDraft` call instead of several
separate inserts.

## Notes for whoever picks up Phase 5+

- Every table follows the conventions in Section 1 of the design doc (UUID PK,
  `numeric(14,2)` for money, `text + check` instead of native enums, soft
  delete via `archived_at`, `created_at`/`updated_at`/`created_by`/`updated_by`
  on every table, one shared `set_updated_at()` trigger).
- New permission codes belong in the migration that introduces the policy
  checking them, with matching seed rows added in the same change — don't add
  unused permission codes speculatively (Phases 1-4 deliberately don't).
- Before inventing a status/enum value set or column shape for a new table,
  check the real local SQLite schema (`database_service.dart`) and the
  matching Dart model first — Phase 4's draft in the design doc originally
  guessed `employees.status` and `contracts.status` values that turned out
  to not match the real app at all (fixed before implementing, not after).
  "Never guess" applies to schema design just as much as to code.
- A sequence used as a column default (see `employee_number_seq`) needs an
  explicit `grant usage on sequence ... to authenticated` — found by testing:
  a non-owner role's insert failed with "permission denied for sequence"
  even though it could insert into the table itself. Don't assume a fresh
  Supabase project's ambient defaults cover this; grant it in the migration.
- Multi-row client operations that need atomicity belong in a `security
  invoker` RPC (see `save_daily_financial_report`/`create_invoice`/
  `create_payroll_record` for the pattern) — a dropped connection
  mid-sequence must never leave inconsistent data. The one exception is when
  the operation legitimately needs to write across hotels the caller doesn't
  have direct permission on (see `create_shared_expense_distribution`):
  that's `security definer`, gated by a single explicit permission check at
  the top of the function, nothing more — never make a function `security
  definer` by default "to be safe."
- Don't trust a client-supplied aggregate when the real rows backing it are
  already in the database — `create_payroll_record` recomputes
  `advances_total` server-side from the actual unsettled `employee_advances`
  rows rather than trusting a number the client sends, same principle as
  `financial_reports.income_total`/`expense_total` being trigger-computed.
- Two RLS policies on different tables must never both do a plain `exists
  (select 1 from <the other table> where ...)` on each other — Postgres will
  report "infinite recursion detected in policy" (hit this for real between
  `shared_expense_groups`/`shared_expense_allocations`, fixed by routing the
  cross-table check through a `security definer` helper function instead,
  see `is_shared_expense_group_visible` for the pattern to copy). The
  company-wide-folder pattern in `contract_document_folders`
  (`hotel_id is null or is_hotel_accessible(hotel_id)`) is safe because it
  never queries back into a table whose own policy queries it — check for
  that specific shape before adding a new cross-table policy.
- Hotel/role/user-access **creation** (as opposed to updates within a hotel you
  already have access to) is intentionally service-role-only through Phase 4
  to avoid an RLS bootstrapping hole — see the comment block in the Phase 1
  migration before building a self-service "add hotel" or "invite user" flow.
