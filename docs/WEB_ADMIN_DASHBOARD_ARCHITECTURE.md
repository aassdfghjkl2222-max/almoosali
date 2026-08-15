# Manazel — Web Administration Dashboard Architecture

This document designs the future Web Administration Dashboard for the Manazel hotel-group platform. It is an **architecture and information-design document only** — no code, no schema, no implementation. Every module, page, and data source referenced below is derived exclusively from `docs/PROJECT_REFERENCE.md` (the official reference for the mobile application, hereafter "the Reference"). Where the Reference does not document a capability, this document says so explicitly rather than inventing one.

Throughout, every module is tagged:
- **Existing today** — the capability is real and documented in the mobile app (Reference §5–§11).
- **Future extension** — the capability follows logically from existing data/repositories but has no dedicated mobile screen yet, or depends on the cloud layer not yet being wired in (Reference §5.3, §8C, §12, §15).

> **Document status**: this architecture has been reviewed and approved. Sections 1–12 and the Cloud Schema Coverage table below represent the final, unchanged architectural decisions. Everything added below that point (Executive Summary, Architecture Diagram, Module Status Matrix, Development Roadmap, Risks & Constraints, Future Decisions, Appendix) is a documentation-quality finalization pass — it restates and organizes the same decisions for a production audience, and introduces no new module, navigation change, or business rule.

---

## Executive Summary

**What this dashboard is.** A browser-based, company-wide administration panel that manages the same business entities the Manazel mobile app already manages — hotels, employees, financial reports, invoices, contracts, documents, settlements — from a single place, for people who work across hotels rather than inside one of them.

**Why it exists.** The mobile app is intentionally single-device and single-hotel-scoped (one PIN, one phone, local SQLite — Reference §5.1, §14). That is correct for on-property staff, but it cannot answer cross-hotel questions or give head office a consolidated view without physically visiting every device. The dashboard exists to be that consolidated, company-level view and control point.

**What problems it solves.** (1) No cross-hotel visibility today — the dashboard aggregates data the mobile app can only show one hotel at a time. (2) No centralized administration — hotel setup, master data, and (eventually) user/role management get one shared control point instead of being repeated per device. (3) No audit consolidation — hotel, invoice, contract-document, and employee-event logs exist but are siloed per device; the dashboard reads them into one Audit Center (§8).

**Current project state.** The mobile app is mature and fully local (Reference §15). A Supabase/Postgres schema for a future cloud platform is schema-complete for Phases 1–4 (foundation/RBAC, financial core, operational money flow, people+contracts) and design-only for Phases 5–7 (Reference §5.3). **Nothing is connected yet** — the mobile app's Supabase layer is dormant, and this dashboard, as designed here, has no live backend to call. This is a blueprint, not a running system (§1, "Consequence stated plainly").

**Future vision.** Once the cloud layer is activated (a decision explicitly left open — §12, §16 below), the dashboard becomes a second, independent consumer of the same Supabase schema the mobile app was designed to eventually use — without requiring any change to the mobile app's architecture, and without the two clients ever talking to each other directly (§12).

---

## Architecture Diagram

```
┌───────────────────────────┐        ┌────────────────────────────┐
│      Mobile Application    │        │      Web Dashboard          │
│  (Flutter, Android-only)   │        │   (browser, company-wide)   │
│                             │        │                              │
│  Pages → Repositories →    │        │  Pages → (future) API/client │
│  DatabaseService (sqflite) │        │  layer → Supabase client     │
└──────────────┬──────────────┘        └───────────────┬──────────────┘
               │ live today                             │ NOT live today
               ▼                                         ▼
   ┌───────────────────────┐              ┌───────────────────────────────┐
   │   Local SQLite          │              │   Future Supabase / Postgres   │
   │   (manazel.db, per      │              │   Phases 1–4 schema-complete,  │
   │   device, 51 tables,    │              │   Phases 5–7 design-only       │
   │   v50 — Ref §5.1)        │              │   (Ref §5.3)                    │
   └───────────────────────┘              └───────────────────────────────┘
               │                                         ▲
               │        ⛔ no connection today             │
               │        (Ref §5.3, §12)                    │
               └─────────────  future, undecided  ─────────┘
                    "mobile → Supabase" activation
                    (Ref §16 rec. 5 — open decision,
                     out of scope for this dashboard)
```

**Reading this diagram:**
- The mobile app's live data path (left column, solid) is unchanged by anything in this document — Pages → Repositories → `DatabaseService` → local SQLite (Reference §2.1, §14).
- The dashboard's data path (right column) is entirely prospective: it is designed to speak to the same Supabase schema the mobile app's dormant `lib/data/supabase/` layer already targets, but as its own independent client — not by routing through the mobile app or its local database.
- The dotted line at the bottom is the one dependency this document deliberately does **not** resolve: whether/when the mobile app itself gets wired into Supabase is a separate, still-open decision (§12, Future Decisions). The dashboard does not require that decision to be made in order to be designed, phased, or eventually built.
- "Repositories" appear on both sides deliberately: the dashboard's future data-access layer is expected to mirror the mobile app's Repository pattern (Reference §2.1) conceptually — one access layer per entity, no page talking to the database directly — even though the two implementations will be separate codebases in separate languages.

---

## 1. Dashboard Philosophy

### Why this dashboard exists

The mobile app (Reference §1–§2) is a single-device, offline-first operations tool: one PIN unlocks one phone/tablet's local SQLite database (`manazel.db`), scoped to whoever is holding that device. There is no server, no API, and no cross-device view of the business (Reference §5.1, §5.3, §14 — "the app's one and only live data source is local SQLite"). That design is correct for a hotel staff member managing one property day-to-day, but it structurally cannot answer questions like "show me every hotel's pending expenses right now" or "who changed this invoice, from where" without physically holding each device.

The Web Administration Dashboard exists to fill exactly that gap: a browser-based, company-wide control panel that aggregates and manages the same business entities the mobile app already manages — hotels, employees, financial reports, invoices, contracts, documents, settlements — from one place, for people who operate across hotels rather than inside one of them.

### Who will use it

Based on the roles the Reference already documents as *designed* (even if not yet wired anywhere — Reference §8C, the Supabase `roles`/`permissions` schema and its seeded "Owner" role), the dashboard's users are company-level actors, not on-property staff:
- Ownership/company management — cross-hotel financial and operational visibility.
- Head-office finance/accounting — invoices, reports, settlements, suppliers across all hotels.
- HR/payroll administration — employees and payroll across all hotels.
- A future system administrator — users, roles, hotel access grants, backups, AI configuration.

The Reference gives no evidence of on-property staff being intended dashboard users; the mobile app remains their tool. This document does not assume otherwise.

### How it relates to the mobile application

The dashboard is a **second client**, not a replacement, and not a redesign of the mobile app (per the task's explicit constraint). It is designed to eventually read and write the *same business data* the mobile app manages, but through a different data path:

```
Mobile app  ──►  local SQLite (per device)         [live today — Reference §5.1, §14]
Dashboard   ──►  Supabase / Postgres (shared cloud) [designed, not connected — Reference §5.3, §12]
```

These two paths do not talk to each other today. The mobile app has no network layer at all; the Supabase Dart integration layer (`lib/data/supabase/`) exists in the mobile codebase but is not initialized from `main.dart` and touches no screen (Reference §5.3). This document does not change that. It designs the dashboard against the same target schema the mobile team already reviewed for that eventual cloud connection, so that when the day comes to wire the mobile app into Supabase, the dashboard is already speaking the same language — not because the dashboard talks to the mobile app directly.

**Consequence stated plainly**: as designed here, the dashboard cannot manage a single real business record until the Supabase layer is actually activated (a decision the Reference explicitly flags as outstanding — §16, recommendation 5). Today this document is a blueprint, not a working system. Every module below is therefore described in terms of *what it will manage once connected*, with its current data-availability status called out per module in §4.

---

## 2. Complete Navigation Structure

Sidebar groups, in the order they will appear. Grouping follows the mobile app's own module boundaries (Reference §11) rather than introducing a new taxonomy — this keeps the two clients conceptually aligned for anyone who uses both.

```
▣ Overview
   └─ Dashboard Home

▣ Hotels
   └─ Hotel Management        (Existing today — mirrors mobile Settings → Hotel Management)
   └─ Recycle Bin              (Existing today)
   └─ Hotel Audit Log          (Existing today)

▣ People
   └─ Employees                (Existing today)
   └─ Payroll                  (Existing today)
   └─ Employee Reports         (Existing today)

▣ Documents
   └─ Permanent Documents      (Existing today)
   └─ Seasonal Documents       (Existing today)
   └─ Employee Documents       (Existing today)
   └─ General / Folderless     (Existing today)
   └─ Document Types & Categories (master data) (Existing today)
   └─ Contract Documents (separate engine)      (Existing today — deliberately parallel, not merged, per Reference §5.1/§11)

▣ Financial Reports
   └─ Daily Reports            (Existing today)
   └─ Previous Reports         (Existing today)
   └─ Monthly Rollup           (Existing today)

▣ Expenses
   └─ Pending Expenses         (Existing today)
   └─ Shared Expenses          (Existing today — current engine, Reference §5.1)
   └─ Shared Expenses (Legacy view) (Existing today — read-only historical, Reference §5.1)
   └─ Inter-Entity Transfers   (Existing today)
   └─ Owner Withdrawals        (Existing today)

▣ Invoices
   └─ Invoice Hub              (Existing today)
   └─ AI/OCR Capture Queue     (Existing today)
   └─ Invoice Reports          (Existing today)
   └─ Invoice Audit Log        (Existing today)

▣ Suppliers
   └─ Supplier Directory       (Future extension — see §4)
   └─ Supplier Statements      (Existing today)
   └─ Supplier Reports         (Existing today)

▣ Contracts
   └─ Contracts                (Existing today)
   └─ Contract Payments        (Existing today)

▣ Financial Center (Vault)
   └─ Vault Dashboard          (Existing today)
   └─ Ledger / Accounts        (Existing today)
   └─ Personal Accounts        (Existing today)
   └─ Entity Loans             (Existing today)
   └─ Deposited / Unposted Funds (Existing today)
   └─ Transactions Log         (Existing today)

▣ Settlements
   └─ Inter-Entity Debts       (Existing today — separate implementation from Vault's, Reference §11/§13)
   └─ Person Debts             (Existing today)
   └─ Supplier Debts           (Existing today)

▣ Analytics Center
   └─ Financial Analysis       (Existing today)
   └─ Cash Movements           (Existing today)
   └─ Employee Analytics       (Existing today)
   └─ Relationships Center     (Existing today)
   └─ Reports Center           (Existing today)
   └─ Documents Analysis       (Existing today)

▣ Notifications Center         (Existing today, reshaped for cross-hotel view — see §6)

▣ Audit Center                 (Existing today, consolidated view — see §8)

▣ Administration
   └─ Master Data              (Existing today)
   └─ Financial Categories     (Existing today)
   └─ Backup & Data Info       (Existing today)
   └─ Sync (Future)            (Future extension — mobile-side stub only, Reference §12/§15)
   └─ AI / OCR Configuration   (Existing today)
   └─ Users & Permissions      (Future extension — Supabase RBAC design, Reference §8C)
   └─ About / Support          (Existing today)

▣ Global Search                (pinned in top bar, not sidebar — see §7)
```

Each group exists because a corresponding module already exists in the mobile app (Reference §11) or is a direct extension of a repository/table that already exists (flagged individually in §4). No group here corresponds to a business capability absent from the Reference.

---

## 3. Dashboard Home

The home page is a landing/orientation surface, not a new module — every widget on it aggregates data from modules described in §4. Nothing here is a new capability.

| Widget | Content | Source (existing capability) |
|---|---|---|
| Company KPI cards | Total active hotels, total employees, total open pending expenses, total unposted funds | `HotelRepository`, `EmployeeRepository`, `ExpenseRepository`, `VaultRepository` (Reference §9.1) |
| Financial snapshot cards | Cash/bank/receivable/payable totals across all hotels | Mirrors `VaultDashboardPage` (Reference §11), aggregated across hotels instead of one |
| Pending operations alert | Count of pending expenses, owner withdrawals, and inter-entity transfers not yet posted | Mirrors `PendingExpensesListPage` ("Pending Financial Operations" hub, Reference §11) |
| Document expiry alerts | Documents expiring in 30/10/5/0 days, across all hotels | `DocumentNotificationService` thresholds (Reference §9.2), reshaped as an in-dashboard feed instead of local device notifications |
| Recent activity feed | Latest rows from the audit-log tables | `hotel_audit_log`, `invoice_audit_log`, `contract_document_audit_log`, `employee_events` (Reference §5.1) |
| Quick actions | Shortcuts into: Add Employee, Add Invoice, Add Contract, Add Pending Expense, Post Daily Report | Same forms as `AddEmployeePage`, `AddInvoicePage`, `AddContractPage`, `AddPendingExpensePage`, `FinancialSummaryPage` (Reference §11) |
| Charts | Revenue/expense trend, category breakdown, cash vs bank split | `fl_chart`-driven pages already in mobile Analytics Center (`financial_analysis_page.dart`, `analysis_charts.dart` — Reference §11) |
| Per-hotel comparison table | Side-by-side snapshot of every hotel's key numbers | New *view*, not a new data source — assembled from the same per-hotel report/ledger data the mobile app already reads one hotel at a time |

No card on this page represents a metric the mobile app cannot already compute for a single hotel — the only genuinely new thing the dashboard adds is the **cross-hotel aggregation view**, which the mobile app structurally cannot offer (it operates one hotel/one device at a time, Reference §2.3).

---

## 4. Every Management Module

Each module below follows the same template: Purpose, Navigation, Pages, Functions, Permissions, Relationships, Existing mobile screens, Future cloud compatibility. Cloud compatibility is assessed against the four **schema-complete** Supabase phases documented in Reference §5.3 — Phase 1 (foundation: roles/permissions/hotels/profiles/user_hotel_access), Phase 2 (financial core: categories/reports), Phase 3 (operational money flow: suppliers/expenses/invoices), Phase 4 (people + contracts). Phases 5–7 are explicitly "design-only" in the Reference, and several mobile modules (noted below) have **no Supabase phase at all yet** — this is stated plainly wherever it applies, not glossed over.

### 4.1 Hotels

| | |
|---|---|
| Purpose | Manage the company's hotel portfolio: create, edit, archive, restore, view identity branding. |
| Navigation | Hotels → Hotel Management / Recycle Bin / Hotel Audit Log |
| Pages | Hotel list & search, hotel wizard (general/location/contact/hotel-info/visual identity), recycle bin (restore or 4-step confirmed permanent delete), audit log |
| Functions | Create/edit hotel, archive/restore, duplicate, permanent delete (cascades per `ON DELETE CASCADE`), identity-color assignment |
| Permissions | Company-level administration only (no on-property use case for hotel creation) |
| Relationships | Root entity — nearly every other table carries `hotel_id` with `ON DELETE CASCADE` (Reference §5.1) |
| Existing mobile screens | `hotel_management_page.dart`, `hotel_wizard_page.dart`, `recycle_bin_page.dart`, `hotel_audit_log_page.dart` (Reference §11) |
| Future cloud compatibility | **Phase 1** — `hotels` table exists in the Supabase schema today (Reference §5.3). Logo/cover-image upload is itself unimplemented even in mobile ("قريباً" placeholder, Reference §12) — the dashboard should not promise it either until mobile ships it, to avoid the two clients diverging on a half-built feature. |

### 4.2 Employees & Payroll

| | |
|---|---|
| Purpose | Manage staff records, lifecycle events, allowances/deductions/advances, and payroll runs across all hotels. |
| Navigation | People → Employees / Payroll / Employee Reports |
| Pages | Employee list w/ payroll summary, add/edit, full detail (advances/deductions/allowances/events/payroll/documents), archive, salary/advances/allowances/deductions/yearly reports |
| Functions | Hire/transfer/suspend/return-to-work/resign/terminate/change-salary/change-position/promote/archive (the full `PayrollService` action set, Reference §9.2), advance recording, payroll approval and payment |
| Permissions | HR/payroll administration |
| Relationships | `employees` → `hotels`; `payroll_records`/`employee_allowances`/`employee_deductions`/`employee_advances`/`employee_events` → `employees` (Reference §5.1). Advances post through `FinancialEngine`. |
| Existing mobile screens | `employees_page.dart`, `add_employee_page.dart`, `employee_details_page.dart`, `employee_archive_page.dart`, `employee_reports_page.dart` (Reference §11) |
| Future cloud compatibility | **Phase 4** — `employees`, `payroll_records`, allowances/deductions/advances, `employee_events` all exist in the Supabase schema (Reference §5.3). No hard delete exists anywhere in the system (mobile or documented cloud design) — the dashboard must not introduce one; archive is the only removal path. |

### 4.3 Documents (Unified Engine)

| | |
|---|---|
| Purpose | Manage reference documents (permanent, seasonal, employee-linked, general) tied to hotels/employees/suppliers via the polymorphic `owner_type`/`owner_id` model. |
| Navigation | Documents → Permanent / Seasonal / Employee Documents / General / Document Types & Categories |
| Pages | Documents hub, permanent/seasonal folder browsers, folderless "general documents" list, folder create/edit, document create/link-existing, cross-folder advanced search, document-type & category master-data management |
| Functions | CRUD on documents and folders, attach files, expiry tracking, link existing documents into a folder by reference (no copy) |
| Permissions | Company-level document administration |
| Relationships | `documents` → `hotels` (polymorphic owner); `document_types` → `document_categories`; `document_type_hotels`, `document_hotels`, `document_folder_links` join tables (Reference §5.1) |
| Existing mobile screens | `documents_hub_page.dart`, `documents_search_page.dart`, `permanent_documents_page.dart`, `seasonal_documents_page.dart`, `employee_documents_hub_page.dart`, `folderless_document_list_page.dart`, `document_types_page.dart`, `manage_document_categories_page.dart` (Reference §11) |
| Future cloud compatibility | **No Supabase phase defined yet.** The Reference's Phase 1–4 table list (§5.3) does not include `documents`, `document_types`, or `document_categories` in any form. This module cannot be wired to the cloud without a new migration phase being designed first — that is a decision outside this document's scope (consistent with Reference §16, recommendation 5). The dashboard's Documents module is therefore UI/IA design only until that phase exists. |

### 4.4 Contract Documents (separate engine)

| | |
|---|---|
| Purpose | Manage an independent, unlimited-nesting folder/document system, kept deliberately separate from §4.3's engine (Reference §5.1: "deliberately parallel... different data shape... rather than reuse of the existing engine"). |
| Navigation | Documents → Contract Documents |
| Pages | Recursive folder browser with breadcrumbs, full-text search across the tree, archive (4-step confirmed hard-delete), audit log, create/edit folder & document sheets |
| Functions | Unlimited nested folders, optional expiry/reminder dates per document, archive/restore, hard delete (archived items only), audit trail |
| Permissions | Company-level document administration |
| Relationships | `contract_folders` (self-referencing `parent_id`, CASCADE) → `contract_documents` → `contract_document_audit_log` (no FK, deliberate — survives deletion, Reference §5.1) |
| Existing mobile screens | `contract_folder_browser_page.dart`, `contract_documents_search_page.dart`, `contract_documents_archive_page.dart`, `contract_document_audit_log_page.dart`, `create_edit_document_page.dart`, `create_edit_folder_sheet.dart` (Reference §11) |
| Future cloud compatibility | **Phase 4** — `contract_document_folders`, `contract_documents`, and their audit log exist in the Supabase schema (Reference §5.3), grouped with the People+Contracts phase. |

### 4.5 Financial Reports

| | |
|---|---|
| Purpose | Manage the daily financial report cycle per hotel — the mobile app's core day-to-day accounting artifact. |
| Navigation | Financial Reports → Daily Reports / Previous Reports / Monthly Rollup |
| Pages | Report entry/edit, preview-before-post, previous-reports list w/ period filters, monthly rollup w/ Excel/PDF, saved/posted read-only view |
| Functions | Add income/expense line items (via the unified `FinancialCategoryPicker`, Reference §10), preview, post (locks the report), export PDF/Excel |
| Permissions | Finance administration; posting is typically a higher-trust action than drafting |
| Relationships | `financial_reports` → `hotels`; a saved report freezes its own copy of line items in `details_json` — no live FK to `financial_report_items` after posting (Reference §5.1) |
| Existing mobile screens | `financial_summary_page.dart`, `monthly_report_page.dart`, `previous_reports_page.dart`, `report_preview_page.dart`, `saved_report_view_page.dart` (Reference §11) |
| Future cloud compatibility | **Phase 2** — `financial_reports` and its line-item child tables exist in the Supabase schema (Reference §5.3). |

### 4.6 Expenses

| | |
|---|---|
| Purpose | Manage not-yet-posted (pending) expenses, shared multi-hotel expenses, inter-entity transfers, and owner withdrawals — everything the mobile app calls "Pending Financial Operations." |
| Navigation | Expenses → Pending Expenses / Shared Expenses / Shared Expenses (Legacy) / Inter-Entity Transfers / Owner Withdrawals |
| Pages | Pending-expense create/list, shared-expense create/edit (auto-distribution + manual override), legacy shared-expense read-only detail, inter-entity transfer create, owner-withdrawal create, pending-operations hub |
| Functions | Category/funding-source/supplier/attachment entry, auto-distribution across hotels, transfer/untransfer to a report |
| Permissions | Finance administration |
| Relationships | `pending_expenses` → `hotels`, `financial_categories`, `shared_expenses`; **two parallel shared-expense systems coexist** — `shared_expenses` (current, v47) and `shared_expense_groups`/`shared_expense_shares` (legacy, kept for historical display only) (Reference §5.1, §13). The dashboard must keep these visually distinct exactly as the mobile app does, per the project's standing rule never to merge FinancialEngine/Vault/Settlements-adjacent systems without a dedicated study. |
| Existing mobile screens | `pending_expenses_list_page.dart`, `add_pending_expense_page.dart`, `add_edit_shared_expense_page.dart`, `shared_expense_details_page.dart`, `add_inter_entity_transfer_page.dart`, `add_owner_withdrawal_page.dart` (Reference §11) |
| Future cloud compatibility | **Phase 3** covers `pending_expenses` and `shared_expense_groups`/`shared_expense_allocations`. Note the naming: the Supabase Phase 3 design uses the *group/allocation* shape, which in the mobile app corresponds to the **legacy** shared-expense system, not the current `shared_expenses` distribution engine (v47) that mobile actually uses today. This mismatch is a real, documented fact worth flagging to whoever eventually wires this up — it is not something to silently reconcile in this document. |

### 4.7 Invoices

| | |
|---|---|
| Purpose | Manage tax invoices — the mobile app's ZATCA-aware invoicing module, including AI/OCR capture. |
| Navigation | Invoices → Invoice Hub / AI-OCR Capture Queue / Invoice Reports / Invoice Audit Log |
| Pages | Invoice hub (search/filter), manual entry (5 funding-source types), detail/edit, QR/AI/OCR capture pipeline (camera/gallery/PDF → multi-invoice picker → quick review), period reporting w/ Excel export, audit log |
| Functions | Manual entry, ZATCA QR parsing, AI vision extraction (Claude/OpenAI/Gemini providers, Reference §9.2), local OCR fallback, duplicate detection, audit logging |
| Permissions | Finance administration |
| Relationships | `invoices` → `hotels`, `financial_categories` (since v49); `invoice_attachments`, `invoice_audit_log` (no FK, deliberate) → `invoices`; `supplier_debts` → `invoices` (Reference §5.1) |
| Existing mobile screens | `invoices_page.dart`, `add_invoice_page.dart`, `invoice_details_page.dart`, `invoice_reports_page.dart`, `invoice_audit_log_page.dart`, `invoice_capture_processing_page.dart`, `multi_invoice_picker_page.dart`, `quick_invoice_review_page.dart` (Reference §11) |
| Future cloud compatibility | **Phase 3** — `invoices`, `invoice_attachments`, `invoice_audit_log`, `supplier_debts`, `supplier_payments` all exist in the Supabase schema (Reference §5.3). The AI/OCR capture pipeline itself is a client-side (mobile) capability calling third-party vision APIs (Reference §9.2) — the dashboard would need its own equivalent integration; this is not something a database connection alone provides, and this document does not assume it exists. |

### 4.8 Suppliers

| | |
|---|---|
| Purpose | Track supplier identity, debts, payments, and account statements. |
| Navigation | Suppliers → Supplier Directory / Statements / Reports |
| Pages | Supplier statement (account statement tab + documents tab), supplier report (invoices for a period) |
| Functions | View statement (totals/paid/remaining + chronological operations), generate period reports |
| Permissions | Finance administration |
| Relationships | `suppliers` → `hotels`; `supplier_debts` → `suppliers`, `invoices`; `supplier_payments` → `suppliers`; `pending_expense_debts` → `suppliers` (Reference §5.1) |
| Existing mobile screens | `supplier_statement_page.dart`, `supplier_report_page.dart`, `supplier_documents_tab.dart`, plus the reusable `supplier_picker_sheet.dart` (quick add/pick) (Reference §11, §10) |
| Future cloud compatibility | **Phase 3** — `suppliers`, `supplier_debts`, `supplier_payments` exist in the Supabase schema (Reference §5.3). |
| **Flagged distinction** | The Reference documents `SupplierRepository` as having full CRUD (Reference §9.1), and a `SuppliersSearchProvider` exists (Reference §9.2) — but there is **no dedicated "manage all suppliers" list/CRUD page in the mobile app today**; suppliers are created via a quick-add picker inline in other flows (invoices, pending expenses), and the standalone "Suppliers" card in `more_modules_page.dart` is an explicit unwired stub (Reference §12). A **Supplier Directory** page is therefore marked **Future extension** here: it is a natural web-first addition built directly on the existing repository (not an invented capability), but it does not correspond to any existing mobile screen, and should be understood as such. |

### 4.9 Contracts

| | |
|---|---|
| Purpose | Manage business contracts and their payment schedules (distinct from the Contract Documents engine, §4.4). |
| Navigation | Contracts → Contracts / Contract Payments |
| Pages | Contract list, add/edit w/ payment schedule, detail w/ PDF report and vault-linked payment collection |
| Functions | Create/edit contract + schedule, generate PDF report, collect a scheduled payment (routes through Vault) |
| Permissions | Finance administration |
| Relationships | `contracts` → `hotels`; `contract_payments` → `contracts` (Reference §5.1) |
| Existing mobile screens | `contracts_page.dart`, `add_contract_page.dart`, `contract_details_page.dart` (Reference §11) |
| Future cloud compatibility | **Phase 4** — `contracts`, `contract_payments` exist in the Supabase schema (Reference §5.3). |

### 4.10 Financial Center (Vault)

| | |
|---|---|
| Purpose | Manage the double-entry-style ledger — cash/bank/personal/entity accounts, receivables/payables, and every transaction that moves money inside the system. |
| Navigation | Financial Center → Vault Dashboard / Ledger / Personal Accounts / Entity Loans / Deposited-Unposted Funds / Transactions Log |
| Pages | Balance summary, category-parameterized generic ledger, collect-receivable, deposited-funds (+archive), entity loans, personal accounts/actions/withdrawals, settle-debt, unposted-funds, full transaction log |
| Functions | `recordTransaction`, `settleDebt`, `recordPersonalAction`, `recordOwnerDrawing`, `recordSharedExpense`, `collectReceivable` — all six routed through `FinancialEngine`, each atomic via `db.transaction` (Reference §9.2) |
| Permissions | Finance administration — highest-trust module, given every write moves real money |
| Relationships | `financial_accounts`/`financial_ledger` → `hotels`; `vault_balances`/`vault_transactions`/`personal_withdrawals`/`entity_loans`/`advance_withdrawals` → `hotels` (Reference §5.1) |
| Existing mobile screens | `vault_dashboard_page.dart`, `ledger_page.dart`, `collect_receivable_page.dart`, `deposited_funds_page.dart`, `entity_loans_page.dart`, `personal_accounts_page.dart`, `personal_action_page.dart`, `personal_withdrawals_page.dart`, `settle_debt_page.dart`, `unposted_funds_page.dart`, `vault_transactions_page.dart` (Reference §11) |
| Future cloud compatibility | **No Supabase phase defined yet.** `financial_accounts`, `financial_ledger`, `vault_balances`, `vault_transactions`, `personal_withdrawals`, `entity_loans`, `deposited_funds`, `advance_withdrawals` do not appear anywhere in Reference §5.3's Phase 1–4 list. This is the single largest cloud-readiness gap among all modules in this document — the entire double-entry ledger engine has no designed cloud counterpart. Building this module's live data connection is not possible until that schema work happens; this document does not assume it will look like any particular shape, since none has been designed. |

### 4.11 Settlements

| | |
|---|---|
| Purpose | Manage debts between hotels, with individuals, and with suppliers — via `SettlementRepository`, a system the Reference explicitly documents as separate from the Vault's own `FinancialEngine`-backed inter-entity-debt implementation (Reference §11, §13). |
| Navigation | Settlements → Inter-Entity Debts / Person Debts / Supplier Debts |
| Pages | List/detail/add for each debt type, receipt attachments, partial-payment transactions |
| Functions | Create settlement account, record settlement, record partial-payment transaction, view summary |
| Permissions | Finance administration |
| Relationships | `settlement_accounts` → `hotels`; `settlements` → `settlement_accounts`, `hotels` (creditor/debtor); `settlement_transactions` → `settlements` (Reference §5.1) |
| Existing mobile screens | `settlements_hub_page.dart`, `inter_entity_debts_page.dart`, `inter_entity_debt_details_page.dart`, `add_inter_entity_debt_page.dart`, `person_debts_page.dart`, `person_account_details_page.dart`, `add_person_operation_page.dart`, `supplier_debts_page.dart` (Reference §11) — under `lib/pages/settlements/`, distinct from the similarly-named page under `lib/pages/vault/` (Reference §13) |
| Future cloud compatibility | **No Supabase phase defined yet** — same gap as §4.10; `settlement_accounts`, `settlements`, `settlement_transactions` are absent from the Phase 1–4 table list (Reference §5.3). The dashboard must keep this module visually and functionally distinct from Financial Center's own inter-entity-debt view (§4.10), exactly as the mobile app does — collapsing them would contradict the project's standing rule against merging these systems without a dedicated study (Reference §13). |

### 4.12 Analytics Center

| | |
|---|---|
| Purpose | Read-only, cross-hotel analysis — the dashboard's direct extension of the mobile Analysis Center, which the Reference explicitly documents as "query-only, no mutation anywhere" (Reference §11). |
| Navigation | Analytics Center → Financial Analysis / Cash Movements / Employee Analytics / Relationships Center / Reports Center / Documents Analysis |
| Pages | KPI landing, cash/bank movements list, employee analytics + drill-down, financial analysis + category/revenue drill-down, relationships center (reads both FinancialEngine and Settlements data without merging them, Reference §11), reports center + per-report/per-line breakdown, documents-by-hotel/date |
| Functions | Filter, drill down, chart (via `fl_chart`) — no create/update/delete anywhere in this module, matching the mobile app exactly |
| Permissions | Read access can reasonably be broader than the transactional modules, since nothing here mutates data |
| Relationships | Reads from nearly every table above; owns no tables itself |
| Existing mobile screens | `analysis_center_page.dart`, `cash_movements_list_page.dart`, `documents_analysis_page.dart`, `employees_analysis_page.dart`, `financial_analysis_page.dart`, `relationships_center_page.dart`, `reports_center_page.dart`, `financial_center_analysis_page.dart` (Reference §11) |
| Future cloud compatibility | Depends entirely on the underlying modules' cloud status (mixed — see §4.5–§4.11 individually). The "Health Index" and "Smart Analysis" cards are explicitly documented as **UI-only stubs with no real algorithm** even in mobile (Reference §12) — the dashboard must not present these as functioning analytics; if included at all, they should be marked "coming soon" exactly as the mobile app implicitly treats them. |

---

## 5. Analytics Center (detail)

Every chart/dashboard in §4.12 uses only data the Reference confirms exists:

| Chart / View | Data source | Status |
|---|---|---|
| Revenue vs. expense trend | `financial_reports` line items | Existing today |
| Expense category breakdown | `financial_categories` + `pending_expenses`/report line items | Existing today |
| Cash vs. bank split | `financial_accounts` (category: cash/bank) | Existing today |
| Employee headcount / cost trend | `employees`, `payroll_records` | Existing today |
| Document expiry distribution | `documents.expiry_date` | Existing today |
| Financial relationships graph | Merged read of `financial_ledger` + `settlements` (via `FinancialRelationshipsRepository`, explicitly documented as read-only and non-merging, Reference §9.1) | Existing today |
| "Health Index" score | — | **Not implemented anywhere, mobile or cloud** (Reference §12) — do not build against a real metric; if surfaced, must be labeled as not yet available |
| "Smart Analysis" | — | Same as above — explicit stub, no algorithm exists |

No chart in this section is invented; each row traces to a named table, repository, or page in the Reference.

---

## 6. Notifications Center

The mobile app's only real, automated notification source is `DocumentNotificationService` — local device notifications at 30/10/5/0 days before a document's `expiry_date`, scheduled in Asia/Riyadh time (Reference §9.2). Everything else the mobile app surfaces as a notification is actually a **badge count on a hub page**, not a push notification — this distinction matters and the dashboard should not claim otherwise.

| Notification Center section | Source | Status |
|---|---|---|
| Expiring documents | `DocumentNotificationService` thresholds, reshaped as an in-dashboard feed (cross-hotel, since the dashboard has no single-device notion) | Existing today (source), Future extension (cross-hotel delivery mechanism — mobile's version is local-device-only) |
| Pending financial operations | Badge count on `PendingExpensesListPage`/Dashboard "Pending Financial Operations" section (Reference §11) | Existing today (as a count, not a push notification) |
| Employees | `employee_events` (lifecycle changes) — no dedicated notification service documented; the dashboard can surface these as a feed, not a "notification" the mobile app itself generates | Existing today (data), Future extension (as a notification) |
| Contracts | `contract_documents.reminder_date` column exists in the schema (Reference §5.1) — but **no service processes it** anywhere documented; unlike document expiry, there is no confirmed reminder mechanism for contracts today | Future extension — the column exists, the automation does not |
| Invoices | `invoice_audit_log` (change history) — a log, not a notification source | Existing today (as an audit feed, see §8) |
| Cloud sync status | `SyncService`/`SettingsSyncService` — explicitly documented as no-op stubs (Reference §9.2, §12) | Future extension — do not build a real sync-status widget against these; there is nothing to report yet |

The Notifications Center is therefore honestly two things: a real feed of document-expiry alerts and pending-operation counts (both existing today), plus a set of clearly-labeled future slots (contract reminders, sync status) whose backing automation does not exist yet.

---

## 7. Search

Global search mirrors the mobile app's `GlobalSearchService` exactly — same 12 registered providers, same debounce-then-parallel-query pattern (Reference §9.2), reimplemented server-side/cross-hotel instead of client-side/single-device:

| Provider (mobile name) | Searches | Cloud status |
|---|---|---|
| Hotels | Name, city, code, address, phone | Phase 1 |
| Employees | Name, position, employee number, phone | Phase 4 |
| Documents | Name, document number, notes, type | No cloud phase (§4.3) |
| Document Types | Type name/description | No cloud phase |
| Contracts | Name, contractor, payment method | Phase 4 |
| Suppliers | Official/short name, tax number | Phase 3 |
| Financial Categories | Name, code, description | Phase 2 |
| Pending Expenses | Statement, notes, category | Phase 3 |
| Daily Reports | Notes, increase/shortage description, employee, date | Phase 2 |
| Invoices | Invoice number, company, tax number, category | Phase 3 |
| Notes | Title/content | No cloud phase |
| Settings | Static index of settings sections | N/A (mobile-only concept, see §9) |

**Design implication, stated directly**: because roughly half of the mobile app's searchable modules (Documents, Document Types, Notes, and everything in the Vault/Settlements group) have no cloud schema yet, the dashboard's global search will, on day one of a real cloud connection, cover fewer modules than the mobile app's search does today. This document does not paper over that gap — it is a direct, correct consequence of what §5.3 of the Reference documents as schema-complete versus not yet designed.

---

## 8. Audit Center

A consolidated, cross-hotel view of every audit mechanism the Reference documents — no new logging concept is introduced, only aggregation:

| Source table/mechanism | What it captures | Reference |
|---|---|---|
| `hotel_audit_log` | Hotel create/edit/archive actions (no FK — survives hotel deletion) | §5.1 |
| `invoice_audit_log` | Invoice field-level changes (no FK — survives invoice deletion; no delete function exists for invoices at all) | §5.1 |
| `contract_document_audit_log` | Folder/document actions in the Contract Documents engine (no FK, deliberate) | §5.1 |
| `employee_events` | Append-only employee lifecycle history (hire/transfer/suspend/etc.) | §5.1, §9.1 |
| Data info | Real DB file size, per-table row counts, documents-folder size (read-only) | §11 (`data_info_page.dart`) |
| System log identity caveat | Every audit row today is attributed to a hard-coded system username, not a real actor, because there is no live per-user login in the mobile app (Reference §7, §13) | §7 |

The last row is an important, honest design constraint: **until real user accounts exist (§11 below), the Audit Center cannot show "who" did something** — mobile-sourced audit rows will all show the same placeholder actor. This is not a dashboard limitation to engineer around; it is a direct consequence of the mobile app's current authentication model, and any future fix has to start there, not in the dashboard.

---

## 9. Administration Center

| Section | Purpose | Existing mobile equivalent | Status |
|---|---|---|---|
| Master Data | Manage cross-hotel shared data (document types, financial categories) | `master_data_hub_page.dart` | Existing today |
| Financial Categories | Unified expense+revenue category management, plus picker display preferences | `financial_categories_page.dart`, `financial_category_display_preferences_page.dart` | Existing today (Phase 2 cloud) |
| Backup & Data Info | View DB size/row counts, manage local backups (list/restore/delete), backup/restore operation log | `backup_page.dart`, `backup_list_page.dart`, `backup_log_page.dart`, `data_info_page.dart` | Existing today, but **mobile-device-scoped** — a web dashboard has no local SQLite file to back up; this section's cloud equivalent (Postgres backup/restore) is a different mechanism entirely and is **not documented anywhere in the Reference** — treat as future extension, not a port of the mobile feature |
| Sync | Cloud sync configuration | `sync_log_page.dart` (explicitly an empty stub, "فارغ صادقاً حالياً"), `SyncService`/`SettingsSyncService` (no-op) | Future extension — nothing to configure yet |
| AI / OCR Configuration | Choose AI invoice-vision provider (Claude/OpenAI/Gemini) and store API keys | `ai_invoice_ocr_settings_page.dart` | Existing today as a concept; the dashboard would manage provider selection/keys for whichever client(s) actually call these providers — the Reference documents this as a mobile-side, client-triggered capability (Reference §9.2), so a dashboard-side equivalent needs its own integration, not assumed to exist |
| System Configuration | General app preferences (dark mode, font size, animation speed, notifications toggle) | `settings_page.dart` | Existing today as a mobile concept; dashboard equivalent is a UI preference set, not a shared/synced value — the Reference gives no evidence these settings are anything but per-device today |
| Users & Permissions | Manage dashboard users, roles, and hotel-access grants | **No live mobile equivalent** — see §11 | Future extension |
| About / Support | App info, FAQ-style help (no contact channel wired per Reference §11) | `about_page.dart`, `support_page.dart` | Existing today |

---

## 10. User Experience

- **Responsive layout**: designed desktop-first (this is an operations tool for office use), with graceful degradation to laptop and tablet breakpoints. Given the mobile app already exists and covers phone-sized screens for on-property use, the dashboard does not need to target phone widths — that use case is already served.
- **Desktop / laptop**: full sidebar + multi-column data tables + side-by-side detail panels, matching the density finance/HR staff expect from back-office tools.
- **Tablet**: collapsible sidebar, single-column detail views, same as most responsive admin panels; not a primary target but not excluded.
- **Dark mode**: the mobile app already ships a reactive dark/light theme keyed off `AppThemeController` and a per-hotel identity color that reseeds correctly in both brightness modes (Reference §2.3, §10). The dashboard should mirror this concept — a light/dark toggle plus the same per-hotel identity-color idea — so a user who works in both clients sees a consistent visual language, without literally sharing rendering code (the dashboard is a separate web codebase).
- **Accessibility**: standard web accessibility practice (keyboard navigation, sufficient contrast, screen-reader labeling) — the Reference does not document any accessibility work in the mobile app to extend or mirror, so this is treated as a dashboard-native baseline rather than a ported capability.
- **Performance**: the mobile app's Global Search already establishes the right pattern to reuse conceptually — debounce input, run provider queries concurrently, discard stale results by request id (Reference §9.2) — the dashboard's search and any live-filtering table should follow the same shape.

---

## 11. Security

**Today, the mobile app has no user-level access control to extend.** Access is a single shared device PIN (Reference §7, §8) — not hashed, no per-user identity, no role or permission check anywhere in the live code path. A complete local users/roles/permission-groups subsystem exists in the mobile codebase but is compile-time disabled (`kAppHasMultipleUsers = false`) and has zero enforcement logic wired to it (Reference §8A). This document does not build the dashboard's security model on that dormant local system — it has no server presence to extend, and the Reference is explicit that nothing reads its role/permission data today.

The only real, reviewed multi-user RBAC design in the entire codebase is the **Supabase Phase 1 schema** (Reference §5.3, §8C):
- `roles`, `permissions`, `role_permissions` — role-to-capability mapping.
- `profiles` — 1:1 extension of Supabase `auth.users`.
- `user_hotel_access` — per-user, per-hotel role grants (the multi-hotel isolation mechanism).
- `is_hotel_accessible()` / `has_permission()` — `security definer` SQL functions used by Postgres Row Level Security policies.
- A seeded "Owner" role with a blanket permission grant (Reference §8C).

**Design decision, stated plainly**: the dashboard's future security model should be built against this Phase 1 schema when the cloud layer is activated — not against the dormant local SQLite `users`/`permission_groups` tables, and not as a newly-invented scheme. This satisfies the task's requirement ("explain future support for users/roles/permissions without changing the current application") precisely: the schema already exists, reviewed and unconnected; the dashboard would be its first real consumer, and doing so requires zero changes to the mobile app or its local database.

Until that connection is made, the dashboard itself — as a design artifact — has no user base to secure. This section describes the target model, not a currently operating one.

---

## 12. Future Cloud Readiness

How the dashboard connects to Supabase later, without changing the mobile app's architecture:

1. **Independent client, shared backend.** The dashboard talks directly to the same Supabase/Postgres project the mobile app's Dart layer was designed against (`lib/data/supabase/`, Reference §5.3) — via whatever standard client the eventual web framework uses (e.g. a JS/TS Supabase client over PostgREST). This is a second, independent consumer of that schema; it does not route through the mobile app in any way, and the mobile app does not need to change for the dashboard to exist or to go live.
2. **The mobile app's activation is a separate, still-undecided step.** Per the Reference (§5.3, §16), wiring the mobile app itself into Supabase is explicitly not yet decided — `SupabaseConfig.initialize()` is defined but never called. This document does not assume that decision is made, and the dashboard's design does not depend on it: the dashboard can go live against Supabase independently, with the mobile app remaining exactly as it is today (local-SQLite-only) for as long as that separate decision remains open.
3. **Coverage is partial and known.** Phases 1–4 (foundation/roles, financial core, operational money flow, people+contracts) are schema-complete; Phases 5–7 are design-only (Reference §5.3, §15). Concretely, per §4 above: Hotels, Employees/Payroll, Financial Reports, Expenses/Invoices/Suppliers, and Contracts/Contract-Documents all have a real target schema today. **Documents (unified engine), the entire Financial Center/Vault ledger, and Settlements do not** — those modules stay UI/IA design only until new migration phases are designed, which is explicitly out of scope for this document.
4. **RLS is the access-control mechanism, not application code.** Because the Phase 1 schema's `is_hotel_accessible()`/`has_permission()` functions back Postgres Row Level Security policies (Reference §5.3, §11 above), the dashboard's per-hotel and per-role data restrictions are enforced at the database layer, not hand-rolled in the dashboard's own code — consistent with how the schema was designed.
5. **No retroactive redesign of the mobile app.** Every mapping in §4 was chosen specifically so that, if and when the mobile app is later wired to the same Supabase project, the dashboard requires no rework — it was already reading/writing the same tables. That sequencing (design once, connect mobile and dashboard independently, on their own timelines) is the core of this document's cloud-readiness position.

---

## Summary Table — Cloud Schema Coverage by Module

| Module | Supabase Phase | Status |
|---|---|---|
| Hotels | Phase 1 | Schema exists |
| Employees & Payroll | Phase 4 | Schema exists |
| Contract Documents | Phase 4 | Schema exists |
| Financial Reports | Phase 2 | Schema exists |
| Financial Categories | Phase 2 | Schema exists |
| Expenses (pending / shared) | Phase 3 | Schema exists (naming mismatch vs. current mobile engine — see §4.6) |
| Invoices | Phase 3 | Schema exists |
| Suppliers | Phase 3 | Schema exists |
| Contracts | Phase 4 | Schema exists |
| Roles/Permissions/User-Hotel-Access | Phase 1 | Schema exists |
| Documents (unified engine) | — | **No phase designed** |
| Financial Center / Vault | — | **No phase designed** |
| Settlements | — | **No phase designed** |
| Notes | — | **No phase designed** |

---

## Module Status Matrix

Tracks **architecture/documentation completeness and cloud readiness** per module — not build progress, since no implementation has started (build sequencing is the Implementation Blueprint's job, `docs/WEB_ADMIN_IMPLEMENTATION_BLUEPRINT.md`). "Cloud Ready" reflects whether a Supabase phase already defines the module's tables (Reference §5.3); "Needs Future DB Phase" is the direct inverse, called out separately for visibility since it's the single biggest build blocker across modules.

| Module | Existing Today (Mobile) | Architecture Complete (this doc) | Cloud Ready | Needs Future DB Phase | Implementation Priority | Key Dependencies | Completion Status |
|---|---|---|---|---|---|---|---|
| Dashboard Home (§3) | Partial (per-hotel view only) | Yes | Mixed — aggregates other modules | No (itself) | High | All Phase 1–4 modules for live data | Architecture: complete |
| Hotels (§4.1) | Yes | Yes | Yes — Phase 1 | No | High (root entity) | None (foundation) | Architecture: complete |
| Employees & Payroll (§4.2) | Yes | Yes | Yes — Phase 4 | No | High | Hotels | Architecture: complete |
| Documents — Unified Engine (§4.3) | Yes | Yes | **No** | **Yes** | Low (blocked) | New migration phase (undecided) | Architecture: complete; build: blocked |
| Contract Documents (§4.4) | Yes | Yes | Yes — Phase 4 | No | Medium | Hotels | Architecture: complete |
| Financial Reports (§4.5) | Yes | Yes | Yes — Phase 2 | No | High | Hotels, Financial Categories | Architecture: complete |
| Expenses (§4.6) | Yes | Yes | Partial — Phase 3 (schema-shape mismatch, see Risks) | No (schema exists, but see Future Decisions) | Medium-High | Hotels, Financial Categories, Suppliers | Architecture: complete; schema mismatch flagged |
| Invoices (§4.7) | Yes | Yes | Yes — Phase 3 | No | High | Hotels, Financial Categories, Suppliers | Architecture: complete |
| Suppliers (§4.8) | Partial (no dedicated mobile list page) | Yes | Yes — Phase 3 | No | Medium | Hotels | Architecture: complete; Supplier Directory page is a documented net-new page |
| Contracts (§4.9) | Yes | Yes | Yes — Phase 4 | No | Medium | Hotels | Architecture: complete |
| Financial Center / Vault (§4.10) | Yes | Yes | **No** | **Yes** | Low (blocked) | New migration phase (undecided) | Architecture: complete; build: blocked |
| Settlements (§4.11) | Yes | Yes | **No** | **Yes** | Low (blocked) | New migration phase (undecided) | Architecture: complete; build: blocked |
| Analytics Center (§4.12, §5) | Yes | Yes | Mixed — inherits underlying modules' status | Partial (blocked where source module is blocked) | Medium | Financial Reports, Employees, Invoices, Vault*, Settlements* | Architecture: complete; two stub cards ("Health Index", "Smart Analysis") explicitly non-functional even in mobile |
| Notifications Center (§6) | Partial (document expiry is real; rest are badge counts, not push notifications) | Yes | Partial | Yes (document expiry depends on blocked Documents module) | Medium | Documents*, Expenses | Architecture: complete; contract reminders have a DB column but no processing service anywhere |
| Search (§7) | Yes | Yes | Partial — only the Phase 1–4-backed providers | Yes (Documents/Notes providers) | Medium | All modules it indexes | Architecture: complete; day-one coverage will be narrower than mobile's 12 providers |
| Audit Center (§8) | Yes (per-log, siloed) | Yes | Partial — `invoice_audit_log` (Phase 3), `employee_events`/`contract_document_audit_log` (Phase 4); **`hotel_audit_log` has no Supabase phase at all** | Yes (hotel audit log) | Medium | Invoices, Employees, Contract Documents, Hotels | Architecture: complete; hotel-level audit trail gap flagged explicitly |
| Administration Center (§9) | Yes (mobile-device-scoped for Backup/Data-Info) | Yes | Mixed — Master Data/Financial Categories (Phase 2), Users & Permissions (Phase 1 RBAC, not yet connected), Backup/Sync/AI-config have no cloud design | Yes (Backup/Sync) | Medium (Master Data), Low (Users & Permissions until Phase 1 RBAC is activated) | Financial Categories, Phase 1 RBAC schema | Architecture: complete; Backup/Data-Info explicitly does not port 1:1 to cloud |

`*` = module itself has no cloud phase yet; dependency is architectural (reads its data model), not a build blocker for the dependent module's other data sources.

---

## Dashboard Development Roadmap

This roadmap sequences the modules above into build phases. It groups modules by shared cloud-schema dependency (Reference §5.3's own Phase 1–4 grouping) plus three dashboard-specific phases for cross-cutting concerns, administration, and the currently-blocked modules. Detailed page-level breakdown of each phase lives in `docs/WEB_ADMIN_IMPLEMENTATION_BLUEPRINT.md` §6 — this section states the architectural sequencing rationale only.

### Phase 1 — Foundation & Hotels
- **Purpose**: stand up the shell every other phase depends on, and deliver the one module every other module is scoped by.
- **Included modules**: Application shell (navigation, header, theme — §2, §10), Hotels (§4.1), Dashboard Home skeleton (§3, without cross-module data yet).
- **Dependencies**: Supabase Phase 1 schema (`hotels`, and the RBAC tables for later use) must be reachable.
- **Completion criteria**: Hotel CRUD/archive/restore functional against Phase 1 schema; shell navigation matches §2 exactly; no module-specific business page yet.
- **Expected outcome**: a working, empty-of-business-data shell that every later phase plugs into without restructuring.

### Phase 2 — Core Financial Operations
- **Purpose**: deliver the mobile app's central daily workflow (Reference §11 — "the mobile app's core day-to-day accounting artifact").
- **Included modules**: Financial Reports (§4.5), Financial Categories / Master Data (§4.5, §9).
- **Dependencies**: Phase 1 (Hotels) complete; Supabase Phase 2 schema.
- **Completion criteria**: full report lifecycle (draft → preview → post → view) works against real Phase 2 tables for at least one hotel.
- **Expected outcome**: the dashboard can do what the mobile app's Financial Reports module does, per hotel, from a browser.

### Phase 3 — Operational Money Flow
- **Purpose**: deliver expense, invoice, and supplier management — the highest transaction-volume modules.
- **Included modules**: Expenses (§4.6), Invoices (§4.7), Suppliers (§4.8).
- **Dependencies**: Phase 1–2 complete; Supabase Phase 3 schema; **the Expenses schema-shape mismatch (Risks, below) must be explicitly resolved or explicitly accepted before this phase's Expenses scope is finalized** — it is not safe to silently build against whichever shape is convenient.
- **Completion criteria**: pending-expense and invoice CRUD functional; supplier statements/reports readable; Supplier Directory (net-new page, §4.8) functional.
- **Expected outcome**: head-office finance can manage day-to-day money-flow operations across all hotels from the dashboard.

### Phase 4 — People & Contracts
- **Purpose**: deliver HR/payroll and contract management.
- **Included modules**: Employees & Payroll (§4.2), Contracts (§4.9), Contract Documents (§4.4).
- **Dependencies**: Phase 1 complete; Supabase Phase 4 schema.
- **Completion criteria**: full employee lifecycle actions available (hire through archive, matching `PayrollService`'s action set — Reference §9.2); contract + payment schedule CRUD; contract-documents folder tree functional.
- **Expected outcome**: HR and contract administration fully available company-wide.

### Phase 5 — Cross-Cutting Intelligence
- **Purpose**: layer read-only aggregation and discovery on top of the data delivered by Phases 1–4.
- **Included modules**: Analytics Center (§4.12, §5), Global Search (§7), Notifications Center (§6, document-expiry portion excluded — blocked, see Risks), Audit Center (§8, `hotel_audit_log` portion excluded — blocked).
- **Dependencies**: Phases 1–4 complete (this phase has no data of its own to manage — it only reads).
- **Completion criteria**: search covers every Phase 1–4-backed provider; analytics charts render from real Phase 1–4 data; audit feed aggregates the three cloud-ready log tables.
- **Expected outcome**: the dashboard's core value proposition (cross-hotel visibility, Executive Summary) is realized for every module that has cloud data.

### Phase 6 — Administration & Security
- **Purpose**: deliver company-level configuration and activate real dashboard user accounts.
- **Included modules**: Administration Center (§9) minus Backup/Sync (blocked, see Risks); Users & Permissions (§11), built against the Supabase Phase 1 RBAC schema.
- **Dependencies**: Phase 1 (RBAC tables already exist at that point); a decision on dashboard user onboarding (Future Decisions, below).
- **Completion criteria**: roles/permissions/hotel-access grants manageable; every prior phase's module respects RLS-enforced access (Reference §5.3, §11) rather than being open to every dashboard user by default.
- **Expected outcome**: the dashboard stops being "one shared login" and becomes genuinely per-user, per-hotel scoped — something the mobile app itself still does not have (Reference §7, §8).

### Phase 7 — Blocked Modules (not scheduled)
- **Purpose**: document intent for the three modules with no cloud schema, without scheduling them, since they depend on a decision this document explicitly does not make.
- **Included modules**: Documents — Unified Engine (§4.3), Financial Center / Vault (§4.10), Settlements (§4.11), Notes (mentioned in §7 and the Cloud Schema Coverage table, no dedicated module section).
- **Dependencies**: a new Supabase migration phase must be designed and approved first (Reference §16 rec. 5) — for Vault/Settlements specifically, this additionally requires the dedicated study the project's standing rule mandates before touching anything FinancialEngine/Vault/Settlements-adjacent (Reference §13).
- **Completion criteria**: not defined here — cannot be, until the schema decision is made.
- **Expected outcome**: none yet. This phase exists so these modules are not forgotten, not so they can be estimated.

---

## Risks & Constraints

Stated directly, without softening, per the requirement to never hide architectural limitations:

1. **No live backend exists today.** Every module above is a design, not a running system. The dashboard cannot manage a single real record until the Supabase layer is activated — a decision this document does not make (Executive Summary; §1, "Consequence stated plainly").
2. **Three modules plus Notes have zero cloud schema**: Documents (Unified Engine), Financial Center/Vault, Settlements, and Notes do not appear in any of Supabase Phases 1–4 (Reference §5.3). They cannot be implemented beyond IA/UI design until a new migration phase is designed — which is explicitly out of scope for this document and requires its own decision process.
3. **`hotel_audit_log` has no Supabase phase**, even though `hotels` itself is Phase 1. The Audit Center (§8) will have an incomplete cross-hotel audit trail even after Phase 1 goes live — hotel-level change history specifically will still be missing.
4. **The Expenses module's Phase 3 cloud schema does not match the mobile app's current engine.** Phase 3 defines `shared_expense_groups`/`shared_expense_allocations` — the shape of the mobile app's **legacy** (pre-v47) shared-expense system — not `shared_expenses`, the engine the mobile app has actually used since v47 (Reference §5.1, §4.6 above). Building Phase 3 against the schema as currently designed risks reproducing the legacy behavior the mobile app itself moved away from. This is a real, unresolved mismatch, not a documentation error to quietly correct here.
5. **No real per-user login exists in the mobile app**, so historical audit rows sourced from mobile data are all attributed to one hard-coded system username (Reference §7, §13). The Audit Center cannot show real "who" for any mobile-originated history — only actions taken from the dashboard itself, once Phase 6 (Users & Permissions) is live, will have genuine per-user attribution.
6. **AI/OCR provider integration is a mobile-side, client-triggered capability** (Reference §9.2) calling third-party vision APIs directly from the device. A dashboard equivalent is not automatically inherited by a database connection — it requires its own integration and its own decision about where API keys live (device-local today; company-scale for a dashboard is a different security posture).
7. **Backup/Data-Info does not port 1:1 to the cloud.** The mobile version backs up a local SQLite file (Reference §11). A Postgres-backed dashboard has no equivalent local file to back up; a cloud backup/restore mechanism is undocumented anywhere in either source document and would need its own design.
8. **"Health Index" and "Smart Analysis" are non-functional stubs even in the mobile app** (Reference §12). The dashboard must not present these as working analytics under any circumstance.
9. **Sync has nothing to build against.** `SyncService`/`SettingsSyncService` are confirmed no-op stubs (Reference §9.2, §12) — there is no partial functionality to extend, only a placeholder to eventually replace.
10. **Search, Audit, and Notifications will all launch with narrower coverage than their mobile counterparts**, strictly because of constraint #2 above (roughly a third of mobile's searchable/auditable/notifiable modules have no cloud data source yet). This is a direct, mechanical consequence of the schema gap, not a scope reduction chosen for the dashboard.
11. **No accessibility work is documented in the mobile app to extend.** Dashboard accessibility (§10) is a from-scratch baseline effort, not a ported capability — budget it as net-new work.
12. **Dashboard locale/RTL posture is undecided.** Neither source document specifies whether the dashboard should be Arabic-first/RTL (matching the mobile app's fixed `ar_SA` locale, per `CLAUDE.md`) or bilingual/English-first for a back-office tool. Building either without a decision risks inconsistency with the company's existing product language. (Also listed under Future Decisions.)

---

## Future Decisions

Decisions intentionally postponed — listed with the reason each is deferred, so a future reader does not mistake silence for an oversight:

1. **Whether/when to wire the mobile app into Supabase.** Postponed because it is a separate, production-risk-bearing decision about the live mobile app, explicitly left open in the Reference (§16 rec. 5). This dashboard's design does not require it to be resolved first (§12), so there is no forcing function to decide it here.
2. **Whether to design a new Supabase migration phase for Documents/Vault/Settlements/Notes.** Postponed because Phases 5–7 are documented as design-only (Reference §5.3), and Vault/Settlements specifically fall under the project's standing rule requiring a dedicated study before any merge-adjacent change (Reference §13) — a rule this document is not positioned to override.
3. **Whether to keep or redesign the Expenses Phase 3 schema shape** (Risk #4 above). Postponed because it requires a data-modeling decision with a clear owner, informed by whether historical legacy-shape data needs to migrate — not something an architecture document can resolve unilaterally.
4. **Dashboard user onboarding and role assignment process** (who gets the seeded "Owner" role, how new dashboard users are provisioned). Postponed to Phase 6 planning (Roadmap, above) — it needs business input on organizational roles, not just the technical RBAC schema, which already exists (Reference §8C).
5. **Cloud backup/restore mechanism design.** Postponed — no design exists in either source document (Risk #7); needs its own scoping exercise separate from this dashboard's page-level architecture.
6. **AI/OCR integration ownership for the dashboard** (server-side proxy vs. dashboard-triggered client calls, and where company-scale API keys are stored). Postponed pending a security/cost review, since it differs materially from the mobile app's per-device key storage model (Reference §7).
7. **Dashboard locale and RTL posture** (Risk #12). Postponed because neither source document states a requirement for this second, browser-based client — unlike the mobile app, whose Arabic/RTL requirement is an explicit, non-negotiable constraint in `CLAUDE.md`. Deciding this before Phase 1's shell is built is advisable, since it affects the shell's layout direction company-wide, but it is not this document's place to assume an answer.

---

## Appendix

### Terminology

| Term | Meaning in this document |
|---|---|
| Reference | `docs/PROJECT_REFERENCE.md`, the official mobile-app architecture reference |
| The Architecture (this document) | `docs/WEB_ADMIN_DASHBOARD_ARCHITECTURE.md` |
| Existing today | Documented as a real, working capability in the mobile app |
| Future extension | Follows from existing data/repositories but has no live mobile screen, or awaits the cloud layer |
| Cloud Ready | The Supabase schema for this module's tables is already designed (Phase 1–4) |
| Blocked | No Supabase phase exists for this module's tables; cannot go beyond IA/UI design |

### Architecture Glossary

| Term | Definition |
|---|---|
| Repository pattern | The mobile app's rule that pages never call the database directly, only through a Repository (Reference §2.1) — the dashboard is expected to mirror this shape conceptually |
| RLS (Row Level Security) | Postgres access-control mechanism the Supabase Phase 1 schema uses to enforce per-hotel, per-role data access at the database layer (Reference §5.3, §11) |
| `is_hotel_accessible()` / `has_permission()` | The two `security definer` SQL functions backing the Supabase schema's RLS policies (Reference §5.3) |
| Phase (Supabase) | One of the Reference's four schema-complete migration groupings (foundation, financial core, operational money flow, people+contracts) plus three design-only phases (Reference §5.3) |
| Phase (this roadmap) | A dashboard build stage (§ Development Roadmap, above) — not the same numbering as Supabase's schema phases, though Phases 1–4 of this roadmap are deliberately aligned to Supabase Phases 1–4 for dependency clarity |

### Module Glossary

See §4.1–§4.12 for full per-module definitions. One-line index:

| Module | One-line definition |
|---|---|
| Hotels | Hotel portfolio CRUD, archive, identity branding |
| Employees & Payroll | Staff records, lifecycle events, payroll runs |
| Documents (Unified) | Polymorphic reference documents across hotels/employees/suppliers |
| Contract Documents | Independent, unlimited-nesting folder/document system |
| Financial Reports | Daily report cycle per hotel |
| Expenses | Pending, shared, inter-entity, and owner-withdrawal expense management |
| Invoices | Tax invoice management incl. AI/OCR capture |
| Suppliers | Supplier identity, debts, payments, statements |
| Contracts | Business contracts and payment schedules |
| Financial Center (Vault) | Double-entry-style ledger — accounts, receivables/payables |
| Settlements | Debts between hotels, persons, and suppliers (separate from Vault) |
| Analytics Center | Read-only, cross-hotel analysis |
| Notifications Center | Document-expiry alerts and pending-operation counts |
| Search | Global, cross-module lookup |
| Audit Center | Consolidated view of all audit-log tables |
| Administration Center | Master data, backup, AI config, system config, users & permissions |

### Abbreviations

| Abbreviation | Meaning |
|---|---|
| RBAC | Role-Based Access Control |
| RLS | Row Level Security |
| CRUD | Create, Read, Update, Delete |
| IA | Information Architecture |
| KPI | Key Performance Indicator |
| OCR | Optical Character Recognition |
| ZATCA | Zakat, Tax and Customs Authority (Saudi Arabia) — source of the QR invoice format the mobile app parses |

### Cross-Reference Table

| This document's section | Primary Reference (`PROJECT_REFERENCE.md`) section(s) |
|---|---|
| §1 Dashboard Philosophy | §1, §2, §5.3, §14 |
| §2 Navigation Structure | §11 |
| §3 Dashboard Home | §9, §11 |
| §4 Every Management Module | §5.1, §5.3, §9, §11 (per-module citations inline) |
| §5 Analytics Center | §11, §12 |
| §6 Notifications Center | §9.2, §11, §12 |
| §7 Search | §9.2 |
| §8 Audit Center | §5.1, §7, §11, §13 |
| §9 Administration Center | §9.2, §11 |
| §10 User Experience | §2.3, §10 |
| §11 Security | §7, §8, §5.3 |
| §12 Future Cloud Readiness | §5.3, §16 |
| Module Status Matrix / Roadmap / Risks / Future Decisions | §13, §15, §16 |

---

*This document is architecture and information design only. No code, schema, or migration was written or modified. `docs/PROJECT_REFERENCE.md` was not changed. Every "Existing today" claim traces to a specific section of the Reference; every "Future extension" claim is stated as such, with the specific gap named rather than assumed away. This finalization pass added documentation structure (Executive Summary, Architecture Diagram, Module Status Matrix, Development Roadmap, Risks & Constraints, Future Decisions, Appendix) without altering any prior architectural decision, module, or navigation choice.*
