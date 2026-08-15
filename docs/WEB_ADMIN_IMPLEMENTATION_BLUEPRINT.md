# Manazel — Web Administration Dashboard: Implementation Blueprint

This document is the official execution guide for building the Web Administration Dashboard. It is **not** architecture and **not** design — those are settled in `docs/PROJECT_REFERENCE.md` (the mobile app's official reference, "the Reference") and `docs/WEB_ADMIN_DASHBOARD_ARCHITECTURE.md` (the approved dashboard architecture, "the Architecture"). This document takes their decisions as fixed and answers one question only: **in what order, by whom, and against what acceptance criteria does this get built.**

Strict rule for this document: every module, page, phase grouping, and dependency below is a direct restatement of something already decided in the Architecture. Nothing here introduces a new module, a new page, a new navigation choice, or a new business rule. Where a sequencing or technical question arises that the two source documents don't answer, it is named as an open risk or assumption — never silently resolved.

---

## 1. Project Overview

The dashboard is a browser-based, company-wide administration panel covering the same business domains as the Manazel mobile app — hotels, employees/payroll, financial reports, expenses, invoices, suppliers, contracts, the financial ledger, settlements, documents, and analytics — built against a Supabase/Postgres backend that is currently schema-complete for four of seven planned phases (Reference §5.3; Architecture, Executive Summary). No implementation exists today. This blueprint sequences the Architecture's 17 modules into seven build phases (Architecture, Development Roadmap) and specifies, page by page, what "done" means for each.

## 2. Implementation Philosophy

1. **The two source documents are law.** If a question arises during implementation that isn't answered by the Reference or the Architecture, it is escalated as a new decision request — it is never inferred or improvised into the codebase.
2. **Cloud-schema readiness drives sequencing, not business importance alone.** A module that matters a great deal (e.g., the Financial Center/Vault ledger) but has no Supabase schema (Architecture, Module Status Matrix) cannot be built ahead of a module that does — sequencing follows what can actually be connected to a real backend.
3. **Parity before novelty.** Every page this blueprint schedules maps to an existing mobile screen or an explicitly-flagged net-new page (Architecture §4.8, Supplier Directory). No phase introduces a page that doesn't trace to the Architecture.
4. **Blocked means blocked.** The three modules with no cloud schema (Documents, Vault, Settlements) plus Notes are not built ahead of schedule "just to have something to show" — doing so would produce UI with nothing real behind it and create rework once (or if) a schema is eventually designed.
5. **Shared infrastructure ships once, not per-module.** Navigation, theming, the confirm-dialog pattern, the thousands-separator formatter, and the entity-picker pattern are built in Phase 1 as reusable components (§7), not re-implemented per module.

## 3. Implementation Principles

- **One data-access layer per entity**, mirroring the mobile app's Repository rule that pages never touch the database directly (Reference §2.1; Architecture Diagram, "Repositories appear on both sides deliberately"). Web pages call a client-side data-access module per entity, not a shared generic query function scattered across pages.
- **RLS is the access-control mechanism, not application code** (Architecture §12, item 4; §11). Pages request data; Postgres Row Level Security decides what comes back. The dashboard does not duplicate hotel/role filtering logic client-side as its source of truth.
- **Confirm-before-mutate, everywhere.** Every action that creates, edits, deletes, posts, or archives a record must show a confirmation step before executing, mirroring the mobile app's `AppDialog.confirmAction` pattern documented as the app-wide mandatory standard (Reference §10). This is a page-level acceptance criterion in every phase below, not a nice-to-have.
- **Every money value is thousands-separated**, mirroring `AppTextField`'s formatting behavior (Reference §10). Same status as the point above — a per-page acceptance criterion, not a stylistic suggestion.
- **No page ships without its module's documented functions.** If the Architecture lists a function for a module (e.g., duplicate detection for invoices, Architecture §4.7), the corresponding page's acceptance criteria include it explicitly — partial ports are not "done."
- **Blocked modules are documented, not built.** Phase 7 (§6) exists to keep the blocked modules visible on the roadmap without scheduling engineering time against them.

## 4. Technical Assumptions

These are assumptions this blueprint must make to sequence work, stated explicitly because neither source document resolves them (they are also listed as open items in the Architecture's Future Decisions and Risks sections):

1. **A Supabase project matching Phases 1–4 of the reviewed schema is provisioned and reachable** before Phase 1 of this blueprint starts. Provisioning itself is outside this document's scope.
2. **Real Supabase Auth (sign-in) must exist from Phase 1**, even though the *administration UI* for managing roles/permissions/hotel-access grants is not delivered until Phase 6. This is because the Phase 1 schema's RLS policies are keyed off `auth.uid()` (Reference §5.3) — without an authenticated session, no Phase 1–5 page can read or write anything. **Consequence, stated directly**: between Phase 1 and Phase 6, initial user accounts and their role/hotel-access grants must be provisioned directly in Supabase (outside the dashboard's own UI), since the UI to do that doesn't exist yet. This is a real interim-operations gap, not a detail to gloss over — it should be resourced (someone with direct Supabase access) before Phase 1 begins.
3. **The Expenses schema-shape mismatch (Architecture, Risk #4) is resolved or explicitly accepted before Phase 3 starts.** This blueprint cannot schedule Expenses pages against an undecided data shape; Phase 3's start is gated on that decision, not merely aware of it.
4. **Dashboard locale/RTL direction is decided before Phase 1's shell is built** (Architecture, Risk #12 / Future Decision #7), since it determines the shell's base layout direction and is expensive to reverse after multiple phases of pages exist.
5. **No mobile-app changes are required or assumed.** Every technical assumption above is scoped to the dashboard and its Supabase connection; none of them require or wait on the separate, still-open "wire the mobile app into Supabase" decision (Architecture §12, Future Decision #1).

## 5. Implementation Order

Phase order follows the Architecture's Development Roadmap exactly, for the reasons given there (cloud-schema grouping, dependency direction):

```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6
                                                        │
Phase 7 (Documents / Vault / Settlements / Notes) ──────┘ not scheduled — see §6.7
```

Phases 1–4 are strictly sequential (each depends on the previous). Phase 5 (cross-cutting intelligence) depends on Phases 1–4 jointly, since it only reads their data. Phase 6 (administration/security) can technically start its non-auth pages (Master Data finalization, AI config, system settings) in parallel with Phase 5, but Users & Permissions specifically should not be considered complete until Phases 1–4's modules exist to scope permissions against. Phase 7 has no position in the sequence — it is explicitly unscheduled pending the DB-phase decision named in the Architecture's Future Decisions.

## 6. Development Phases

Each phase below expands the Architecture's Roadmap entry with full execution detail. Page counts reference §8's full page-by-page table; shared components reference §7.

### 6.1 Phase 1 — Foundation, Authentication & Hotels

| | |
|---|---|
| Objectives | Stand up the application shell and authentication, and deliver the one module every later phase is scoped by (Hotels). |
| Scope | Navigation shell, header, theming, real Supabase Auth sign-in, Hotels module, Dashboard Home skeleton. |
| Modules | Hotels (Architecture §4.1); Dashboard Home (§3, skeleton only — most widgets stay empty until later phases supply data). |
| Required pages | 7 — see §8, Phase 1 table. |
| Shared components | App shell (sidebar + header), theme provider (light/dark), confirm-dialog component, data-table component, form-field components incl. thousands-separator input, auth session provider. All built here first; reused, not rebuilt, in every later phase (§7). |
| Dependencies | Supabase Phase 1 schema reachable (`hotels`, `roles`, `permissions`, `role_permissions`, `profiles`, `user_hotel_access`); locale/RTL decision made (Technical Assumption #4); at least one interim Supabase-side user/hotel-access grant provisioned manually (Technical Assumption #2). |
| Acceptance criteria | Shell navigation matches Architecture §2 exactly, including group names and ordering. Sign-in works against real Supabase Auth. Hotel CRUD, archive/restore, and audit log function against live Phase 1 tables. Every mutating hotel action shows a confirm dialog. No module-specific business page beyond Hotels exists yet. |
| Estimated complexity | High — this phase carries all shared-infrastructure cost that every later phase amortizes. |
| Expected deliverables | Working shell + auth + Hotels module, deployed to a real (non-production) Supabase environment. |
| Risks | Auth/RLS sequencing gap (Technical Assumption #2) if not resourced; locale/RTL decision arriving late and forcing shell rework. |

### 6.2 Phase 2 — Core Financial Operations

| | |
|---|---|
| Objectives | Deliver the mobile app's central daily accounting workflow, company-wide. |
| Scope | Financial Reports full lifecycle; Financial Categories management; Master Data hub (financial-categories entry only — its document-types entry stays routed to a "not yet available" state until Phase 7, mirroring the mobile app's own `ComingSoonPage` pattern for unbuilt entries, Reference §12). |
| Modules | Financial Reports (Architecture §4.5); Financial Categories / Master Data (Architecture §4.5, §9). |
| Required pages | 8 — see §8, Phase 2 table. |
| Shared components | Category-picker component (mirrors the mobile app's unified `FinancialCategoryPicker` — search-only, no free-text entry, Reference §10); PDF/Excel export trigger component (a UI affordance; actual export generation is a backend/service concern outside this document's scope). |
| Dependencies | Phase 1 complete; Supabase Phase 2 schema reachable. |
| Acceptance criteria | Full report lifecycle (draft → preview → post → locked view) works for at least one hotel against real Phase 2 tables. Category picker enforces no-free-text-entry, matching mobile behavior. Posting a report is irreversible in the UI (matches `is_locked`, Reference §5.1) and requires confirm-dialog. |
| Estimated complexity | Medium-High — the report lifecycle's preview/post/lock states are the most stateful flow in this phase. |
| Expected deliverables | Financial Reports and Financial Categories fully functional for one pilot hotel, then rolled out to all Phase-1-provisioned hotels. |
| Risks | `financial_report_items` catalog vs. frozen `details_json` snapshot behavior (Reference §5.1) must be replicated correctly — a naive implementation could accidentally make posted reports mutable when the category catalog changes later. |

### 6.3 Phase 3 — Operational Money Flow

| | |
|---|---|
| Objectives | Deliver expense, invoice, and supplier management — the highest transaction-volume modules. |
| Scope | Pending/shared expenses, inter-entity transfers, owner withdrawals, full invoice lifecycle incl. AI/OCR capture, supplier directory/statements/reports. |
| Modules | Expenses (Architecture §4.6); Invoices (Architecture §4.7); Suppliers (Architecture §4.8). |
| Required pages | 18 — see §8, Phase 3 table. |
| Shared components | Supplier-picker component (mirrors mobile's `supplier_picker_sheet`, Reference §10); funding-source selector component; attachment upload/viewer component; ZATCA QR/AI capture intake component (client-side capture UI; the actual OCR/AI vision call is a separate integration, Technical Assumption/Risk noted below). |
| Dependencies | Phases 1–2 complete; Supabase Phase 3 schema reachable; **the Expenses schema-shape decision (Technical Assumption #3) resolved before this phase starts** — this is a hard gate, not a soft dependency. |
| Acceptance criteria | Pending-expense and invoice CRUD functional with duplicate detection (Architecture §4.7, mirroring `InvoiceRepository`'s documented duplicate-by-number-or-content check, Reference §9.1). Supplier Directory (net-new page) functional against `SupplierRepository`-equivalent operations. Every money entry point uses the thousands-separator formatter and a funding-source selector consistent with the mobile app's 5 funding-source types. |
| Estimated complexity | High — largest page count of any phase, and the only phase gated on an external decision before it can start. |
| Expected deliverables | Full money-flow operations available company-wide for pilot hotels. |
| Risks | AI/OCR integration ownership (Architecture, Future Decision #6) — if unresolved, the AI/OCR Capture Queue page ships with manual entry only and the capture pipeline is deferred within this phase, not blocking the rest of Invoices. |

### 6.4 Phase 4 — People & Contracts

| | |
|---|---|
| Objectives | Deliver HR/payroll and contract administration company-wide. |
| Scope | Full employee lifecycle actions, payroll, contracts with payment schedules, the independent Contract Documents folder engine. |
| Modules | Employees & Payroll (Architecture §4.2); Contracts (Architecture §4.9); Contract Documents (Architecture §4.4). |
| Required pages | 14 — see §8, Phase 4 table. |
| Shared components | Employee lifecycle-action component (hire/transfer/suspend/return/resign/terminate/change-salary/change-position/promote/archive — one shared action-menu pattern, not 10 separate bespoke forms, mirroring `PayrollService`'s unified action set, Reference §9.2); recursive folder-tree browser component (for Contract Documents, mirroring mobile's breadcrumb-based recursive browser, Reference §11). |
| Dependencies | Phase 1 complete (Hotels); Supabase Phase 4 schema reachable. |
| Acceptance criteria | All ten `PayrollService` lifecycle actions available and functioning; no hard delete anywhere (archive only, matching Reference §5.1/§9.1/§11's explicit "no hard delete anywhere in the system" for employees). Contract Documents folder tree supports unlimited nesting and matches mobile's 4-step confirm on hard-delete for archived items (Architecture §4.4). |
| Estimated complexity | Medium-High — the employee lifecycle action set is the most business-rule-dense flow in this phase. |
| Expected deliverables | Employees, Payroll, Contracts, and Contract Documents fully functional company-wide. |
| Risks | None specific to this phase beyond the general risks in §13; it is the most schema-complete, best-understood phase of the four data-delivery phases. |

### 6.5 Phase 5 — Cross-Cutting Intelligence

| | |
|---|---|
| Objectives | Layer read-only aggregation and discovery on top of Phases 1–4's data, realizing the dashboard's core cross-hotel value proposition (Architecture, Executive Summary). |
| Scope | Analytics Center, Global Search, Notifications Center (partial — document-expiry portion excluded, blocked by Phase 7), Audit Center (partial — `hotel_audit_log` portion excluded, no cloud phase exists for it at all, Architecture Risk #3). |
| Modules | Analytics Center (Architecture §4.12, §5); Search (Architecture §7); Notifications Center (Architecture §6); Audit Center (Architecture §8). |
| Required pages | 18 — see §8, Phase 5 table. |
| Shared components | Chart component wrapper (mirrors mobile's `fl_chart`-based `analysis_charts.dart` pattern, Reference §9.2/§11 — same visual language, different rendering library since this is a web codebase); debounced search-with-concurrent-provider-query pattern (mirrors mobile's `GlobalSearchService` — 200ms debounce, `Future.wait`-equivalent parallel queries, stale-result discard by request id, Reference §9.2); audit-log feed component (reused across the three cloud-ready log sources). |
| Dependencies | Phases 1–4 complete — this phase has no data of its own, only reads. |
| Acceptance criteria | Search covers every Phase 1–4-backed provider (a strict subset of mobile's 12 — Architecture §7 table lists which); "Health Index" and "Smart Analysis" are either omitted entirely or explicitly labeled not-yet-available — under no circumstance presented as functioning (Architecture Risk #8, non-negotiable); Notifications Center ships pending-operations counts live, with document-expiry alerts visibly labeled as pending Phase 7. |
| Estimated complexity | Medium — mostly read/aggregation logic, no new write paths. |
| Expected deliverables | Cross-hotel analytics, search, notifications, and audit visibility for every Phase 1–4 module. |
| Risks | Scope creep risk — because this phase touches every prior module, it is the easiest place to accidentally start "improving" business logic that Phases 1–4 already fixed. Analytics/Search/Notifications/Audit are read-only by design (Architecture §4.12) and must stay that way. |

### 6.6 Phase 6 — Administration & Security

| | |
|---|---|
| Objectives | Deliver company-level configuration and activate real, per-user, per-hotel dashboard access — replacing the interim manual-provisioning arrangement from Phase 1 (Technical Assumption #2). |
| Scope | Master Data finalization (document-types entry still blocked, Phase 7), Financial Categories administration, AI/OCR configuration, general system settings, About/Support, and the full Users & Permissions module built against the Supabase Phase 1 RBAC schema. |
| Modules | Administration Center (Architecture §9) minus Backup/Sync (both blocked — no cloud design exists for either, Architecture Risk #7 and #9); Security / Users & Permissions (Architecture §11). |
| Required pages | 8 — see §8, Phase 6 table. |
| Shared components | Role/permission-assignment component; hotel-access-grant component (both new to this phase — there is no mobile equivalent to port, since the mobile app's own Users/Permissions subsystem is dormant and unconnected, Architecture §11 / Reference §8). |
| Dependencies | Phase 1's RBAC tables (already provisioned then); a decision on dashboard user onboarding process (Architecture, Future Decision #4). |
| Acceptance criteria | Every prior phase's module respects RLS-enforced, per-user, per-hotel access once this phase ships — i.e., after Phase 6, the interim manual-provisioning arrangement from Phase 1 is fully retired. Roles, permissions, and hotel-access grants are manageable end-to-end from the UI. |
| Estimated complexity | Medium — schema already exists and is reviewed (Reference §5.3); the work is UI plus wiring, not schema design. |
| Expected deliverables | Dashboard becomes genuinely multi-user and per-hotel scoped, closing the gap noted in the Architecture ("something the mobile app itself still does not have," §Roadmap Phase 6). |
| Risks | If the user-onboarding-process decision (Future Decision #4) is still unresolved when this phase starts, only the technical RBAC UI can be built — actual user provisioning process/rollout must wait for that decision separately. |

### 6.7 Phase 7 — Blocked Modules (documented, not scheduled)

| | |
|---|---|
| Objectives | None scheduled. This entry exists so Documents, Financial Center/Vault, Settlements, and Notes remain visible on the roadmap without implying they can be estimated today. |
| Scope | Not defined — cannot be, until a new Supabase migration phase is designed and, for Vault/Settlements specifically, the dedicated study the project's standing rule requires is completed (Reference §13; Architecture §Future Decisions #2). |
| Modules | Documents — Unified Engine (Architecture §4.3); Financial Center / Vault (Architecture §4.10); Settlements (Architecture §4.11); Notes (mentioned in Architecture §7 and the Cloud Schema Coverage table, no dedicated section). |
| Required pages | 26 — enumerated in §8, Phase 7 table, for completeness/no-omission only, **not as a commitment to build them**. |
| Shared components | Not designed. |
| Dependencies | A new Supabase migration phase (undecided, out of scope for both source documents and this blueprint). |
| Acceptance criteria | Not defined. |
| Estimated complexity | Not estimable without a schema. |
| Expected deliverables | None at this time. |
| Risks | The single largest risk to this blueprint's integrity is building any Phase 7 page ahead of schedule "informally" — doing so would produce UI with no real backend, contradicting the Architecture's explicit "Blocked" status for these modules (Module Status Matrix) and this blueprint's Implementation Philosophy item 4. |

---

## 7. Shared Infrastructure

Built once in Phase 1 (unless noted), reused by every later phase:

| Component | Purpose | Mobile precedent (if any) |
|---|---|---|
| Navigation shell (sidebar + header) | Matches Architecture §2's group structure exactly | No direct mobile equivalent — mobile uses `AppDrawer` (Reference §10), conceptually similar (grouped nav to every module) but a different UI shape for a different form factor |
| Theme provider (light/dark) | Company visual identity, dark-mode support | Mobile's `AppTheme`/`HotelVisualIdentity` reactive light/dark theming (Reference §10) — mirrored conceptually, not shared code, since this is a separate web codebase |
| Search | Debounced, concurrent, per-module-provider pattern | Mobile's `GlobalSearchService` (Reference §9.2) |
| Authentication | Supabase Auth session provider | No mobile equivalent — mobile has no real login system (Reference §7, §8) |
| Permissions | RLS-driven; a thin client-side "can I see this nav item" check reflecting (not replacing) server-side RLS | Supabase Phase 1 RBAC schema (Reference §5.3) — no mobile equivalent, since mobile's own RBAC schema is dormant |
| Confirm-dialog pattern | Mandatory before every mutating action | Mobile's `AppDialog.confirmAction` (Reference §10) |
| Thousands-separator input | Mandatory on every money field | Mobile's `AppTextField` formatter (Reference §10) |
| Category picker | Search-only, no free-text entry | Mobile's unified `FinancialCategoryPicker` (Reference §10) |
| Entity pickers (supplier, employee, document-type) | Shared bottom-sheet/modal pattern for "pick or quick-add a reference row" | Mobile's `supplier_picker_sheet`, `employee_picker_sheet`, `pick_document_type_dialog` (Reference §10) |
| Data table | Sortable/filterable list view, reused by every module's list page | No direct mobile equivalent (mobile lists are simple scrolling lists — a data table is a web-appropriate reinterpretation of the same list/search functionality, not a new business capability) |
| Attachment upload/viewer | Reused by Documents-adjacent modules (Contract Documents, Invoices, Expenses, Suppliers) | Mobile's `AttachmentService` (Reference §9.2) |
| Logging & error handling | Centralized client-side error boundary + structured logging to a backend log sink | No mobile equivalent documented (mobile has no `print()` debugging per project convention, and no centralized error-reporting service documented in the Reference) — this is net-new infrastructure, not a port |
| State management boundaries | Server state (Supabase data) lives in a data-fetching/cache layer per entity; UI-only state (form drafts, modal open/closed) stays local to the component. No global business-state store — mirrors the mobile app's own absence of a state-management library (Reference §2.2) by keeping state close to where it's used, translated to web idioms |

---

## 8. Page-by-Page Implementation Order

Every page from the Architecture, in build order. "Depends on" references shared components (§7) plus earlier pages/modules where a real functional dependency exists (e.g., Invoice Detail depends on the Supplier picker).

### Phase 1 (7 pages)
| # | Page | Module | Depends on |
|---|---|---|---|
| 1 | Authentication (sign-in) | Shell | Supabase Auth |
| 2 | App Shell (sidebar + header) | Shell | Theme provider |
| 3 | Dashboard Home (skeleton) | Shell/§3 | App Shell |
| 4 | Hotel List & Search | Hotels | App Shell, Data table |
| 5 | Hotel Wizard (create/edit) | Hotels | Confirm-dialog |
| 6 | Hotel Recycle Bin | Hotels | Confirm-dialog |
| 7 | Hotel Audit Log | Hotels | Audit-log feed component (built here, first use) |

### Phase 2 (8 pages)
| # | Page | Module | Depends on |
|---|---|---|---|
| 8 | Master Data Hub | Master Data | App Shell |
| 9 | Financial Categories Management | Financial Categories | Category picker (built here, first use) |
| 10 | Financial Category Display Preferences | Financial Categories | #9 |
| 11 | Daily Report Entry/Edit | Financial Reports | Category picker, thousands-separator input |
| 12 | Report Preview | Financial Reports | #11 |
| 13 | Previous Reports List | Financial Reports | Data table |
| 14 | Saved/Posted Report View | Financial Reports | #11–13 |
| 15 | Monthly Rollup | Financial Reports | #13, export trigger |

### Phase 3 (18 pages)
| # | Page | Module | Depends on |
|---|---|---|---|
| 16 | Pending Expenses Hub | Expenses | Data table, Hotels (#4) |
| 17 | Add Pending Expense | Expenses | Category picker, funding-source selector |
| 18 | Add/Edit Shared Expense | Expenses | #17 |
| 19 | Shared Expense Detail | Expenses | #18 |
| 20 | Shared Expense (Legacy view, read-only) | Expenses | Data table |
| 21 | Add Inter-Entity Transfer | Expenses | Hotels (#4) |
| 22 | Add Owner Withdrawal | Expenses | Confirm-dialog |
| 23 | Invoice Hub | Invoices | Data table, Supplier picker |
| 24 | Add Invoice | Invoices | Funding-source selector, attachment upload |
| 25 | Invoice Detail/Edit | Invoices | #24, Audit-log feed |
| 26 | Invoice Reports | Invoices | Data table, export trigger |
| 27 | Invoice Audit Log | Invoices | Audit-log feed component |
| 28 | AI/OCR Capture Queue | Invoices | ZATCA/AI capture intake component |
| 29 | Multi-Invoice Picker | Invoices | #28 |
| 30 | Quick Invoice Review | Invoices | #28–29 |
| 31 | Supplier Directory (net-new) | Suppliers | Data table |
| 32 | Supplier Statement | Suppliers | #31 |
| 33 | Supplier Report | Suppliers | #31, export trigger |

### Phase 4 (14 pages)
| # | Page | Module | Depends on |
|---|---|---|---|
| 34 | Employee List | Employees | Data table, Hotels (#4) |
| 35 | Add/Edit Employee | Employees | Confirm-dialog |
| 36 | Employee Detail | Employees | Employee lifecycle-action component |
| 37 | Employee Archive | Employees | #34 |
| 38 | Employee Reports | Employees | Export trigger |
| 39 | Contract List | Contracts | Data table |
| 40 | Add/Edit Contract | Contracts | Confirm-dialog |
| 41 | Contract Detail | Contracts | #40, Vault-linked payment collection (interface only until Phase 7) |
| 42 | Contract Folder Browser | Contract Documents | Recursive folder-tree component (built here, first use) |
| 43 | Contract Documents Search | Contract Documents | #42 |
| 44 | Contract Documents Archive | Contract Documents | #42, Confirm-dialog (4-step) |
| 45 | Contract Document Audit Log | Contract Documents | Audit-log feed component |
| 46 | Create/Edit Contract Document | Contract Documents | Attachment upload |
| 47 | Create/Edit Contract Folder | Contract Documents | #42 |

### Phase 5 (18 pages)
| # | Page | Module | Depends on |
|---|---|---|---|
| 48 | Analytics Center Landing | Analytics | Chart component |
| 49 | Financial Analysis | Analytics | #48 |
| 50 | Expense Category Detail (drill-down) | Analytics | #49 |
| 51 | Revenue Drilldown | Analytics | #49 |
| 52 | Cash Movements List | Analytics | Data table |
| 53 | Employee Analytics | Analytics | #48 |
| 54 | Employee Detail Analytics | Analytics | #53 |
| 55 | Employee Operations List | Analytics | #53 |
| 56 | Relationships Center | Analytics | Reads Invoices/Expenses/Financial Reports data |
| 57 | Relationship Transaction List | Analytics | #56 |
| 58 | Relationship Transaction Detail | Analytics | #57 |
| 59 | Reports Center | Analytics | Data table |
| 60 | Report Details | Analytics | #59 |
| 61 | Report Amount Breakdown | Analytics | #60 |
| 62 | Documents Analysis | Analytics | **Blocked — depends on Phase 7 Documents module; page stub only, labeled not-yet-available** |
| 63 | Global Search | Search | Debounced search component (built here, first use) |
| 64 | Notifications Center | Notifications | Pending-ops portion live; document-expiry portion labeled pending Phase 7 |
| 65 | Audit Center (consolidated) | Audit | Audit-log feed component; `hotel_audit_log` portion labeled not-cloud-ready (Architecture Risk #3) |

### Phase 6 (8 pages)
| # | Page | Module | Depends on |
|---|---|---|---|
| 66 | AI/OCR Configuration | Administration | App Shell |
| 67 | System/General Settings | Administration | App Shell |
| 68 | About | Administration | — |
| 69 | Support | Administration | — |
| 70 | Users List | Security | Role/permission-assignment component (built here, first use) |
| 71 | Add/Edit User | Security | #70 |
| 72 | Roles Management | Security | #70 |
| 73 | Hotel-Access Grants | Security | Hotel-access-grant component (built here, first use), Hotels (#4) |

### Phase 7 — enumerated for completeness, not scheduled (26 pages)
| # | Page | Module |
|---|---|---|
| 74 | Documents Hub | Documents |
| 75 | Documents Search | Documents |
| 76 | Permanent Documents | Documents |
| 77 | Seasonal Documents | Documents |
| 78 | Employee Documents Hub | Documents |
| 79 | Folderless / General Documents | Documents |
| 80 | Document Types | Documents |
| 81 | Document Categories | Documents |
| 82 | Vault Dashboard | Financial Center |
| 83 | Ledger | Financial Center |
| 84 | Personal Accounts | Financial Center |
| 85 | Entity Loans | Financial Center |
| 86 | Deposited Funds | Financial Center |
| 87 | Unposted Funds | Financial Center |
| 88 | Collect Receivable | Financial Center |
| 89 | Settle Debt | Financial Center |
| 90 | Vault Transactions Log | Financial Center |
| 91 | Settlements Hub | Settlements |
| 92 | Inter-Entity Debts List | Settlements |
| 93 | Inter-Entity Debt Detail | Settlements |
| 94 | Add Inter-Entity Debt | Settlements |
| 95 | Person Debts List | Settlements |
| 96 | Person Account Detail | Settlements |
| 97 | Add Person Operation | Settlements |
| 98 | Supplier Debts List | Settlements |
| 99 | Notes List | Notes |

**Total: 99 pages** — 73 scheduled across Phases 1–6, 26 named but unscheduled in Phase 7.

---

## 9. Component Dependency Map

```
Layer 0 — Platform
  Supabase Auth · Supabase client · Postgres (RLS-enforced)

Layer 1 — Shell (Phase 1)
  Theme provider · Navigation shell · Auth session provider
       │
       ▼
Layer 2 — Shared interaction components (Phase 1, extended in later phases at first use)
  Confirm-dialog · Thousands-separator input · Data table · Attachment upload/viewer
  Category picker (Phase 2) · Entity pickers (Phase 3) · Chart wrapper (Phase 5)
  Debounced search (Phase 5) · Audit-log feed (Phase 1, reused) · Role/permission & hotel-access
  components (Phase 6)
       │
       ▼
Layer 3 — Per-entity data-access modules
  One per table-owning module (Hotels, Employees, Financial Reports, Expenses, Invoices,
  Suppliers, Contracts, Contract Documents, ...) — mirrors the Reference's Repository
  pattern (§2.1), each module's data-access code isolated from every other module's
       │
       ▼
Layer 4 — Pages (§8)
  Each page composes Layer 2 components + its own Layer 3 data-access module.
  No page skips Layer 3 to query Supabase directly — same discipline as the mobile
  app's "pages never touch the database directly" rule (Reference §2.1).
```

Cross-module page dependencies (beyond the layered stack above) are called out per-page in §8's "Depends on" column — e.g., Contract Detail (#41) referencing Vault-linked payment collection, which stays interface-only until Phase 7 actually exists.

---

## 10. Testing Strategy

| Level | Scope | When |
|---|---|---|
| Unit testing | Data-access modules (Layer 3) and business-rule logic (e.g., report posting/locking, duplicate invoice detection, payroll proration) — tested against real or realistic Supabase fixtures, not mocks, mirroring the mobile app's own preference for real-data testing over mocking where practical | Every phase, per module, before that module's pages are considered feature-complete |
| Component (widget-equivalent) testing | Shared components (§7) in isolation — confirm-dialog fires before mutation, thousands-separator formats correctly, category/entity pickers reject free text | Phase 1 for shell-level components; at each component's first real use thereafter |
| Integration testing | Page + data-access module + live (non-production) Supabase — full CRUD round-trip per page | End of each phase, across all of that phase's pages |
| Manual testing | Structured test scripts per page, executed by a person, covering the acceptance criteria in §6 | End of each phase, before the phase's quality gate (§11) |
| Regression testing | A growing suite covering every previously-shipped phase's acceptance criteria, re-run before each new phase ships | Continuously from Phase 2 onward (Phase 1 has nothing to regress against yet) |
| Acceptance testing | Sign-off against this blueprint's phase-level acceptance criteria (§6) and the Architecture's Module Status Matrix status for that module | End of each phase, gating the move to the next |

## 11. Quality Gates

Before moving from one phase to the next, all of the following must hold:

1. Every page listed for the completed phase in §8 exists and meets that phase's acceptance criteria (§6).
2. Every mutating action across the phase's pages shows a confirm dialog; every money field uses thousands-separator formatting (Implementation Principles, §3).
3. No page reads/writes Supabase directly, bypassing its module's data-access layer (§9, Layer 3/4 discipline).
4. Regression suite (§10) passes for every prior phase, not just the one completing.
5. No Phase 7 (blocked) page has been built ahead of schedule (Implementation Philosophy #4).
6. Any phase-specific hard dependency named in §6 (e.g., Phase 3's Expenses schema-shape decision) is confirmed resolved, not merely "in progress."
7. The phase's module status in the Architecture's Module Status Matrix is updated to reflect build (not just architecture) completion, keeping the two documents' status claims from drifting apart.

## 12. Definition of Done

**A page is done** when: it matches its documented function set (Architecture §4, per module), passes its acceptance criteria (§6), has unit + component + integration test coverage (§10), includes confirm-dialog and thousands-separator parity where applicable, and has passed manual testing against its test script.

**A phase is done** when: every page in that phase (§8) is done, the phase's quality gate (§11) passes in full, and the regression suite covering all prior phases still passes.

**The project is done** (for the scheduled scope, Phases 1–6) when: all 73 scheduled pages are done, Phase 6's security model has fully retired the Phase 1 interim manual-provisioning arrangement (Technical Assumption #2), and every module's Architecture Module Status Matrix entry reads "build: complete" for everything except the four Phase 7 modules, which remain "blocked" by design — not a defect, a documented, intentional stopping point.

## 13. Project Risks

Consolidates and extends the Architecture's Risks & Constraints with execution-specific items:

1. **All twelve risks listed in the Architecture** (Risks & Constraints section) apply directly to this execution plan and are not repeated in full here — see that section for: no live backend today, missing cloud schema for four modules, the `hotel_audit_log` gap, the Expenses schema mismatch, no real per-user mobile history, AI/OCR integration ownership, Backup/Data-Info not porting to cloud, non-functional analytics stubs, the Sync no-op, narrower day-one Search/Audit/Notifications coverage, missing accessibility precedent, and undecided locale/RTL posture.
2. **Auth/RLS sequencing gap (Technical Assumption #2).** If Phase 1 ships without a resourced plan for interim manual user/hotel-access provisioning, Phases 2–5 stall waiting for access grants that have no UI to create them yet.
3. **Phase 3 start gated on an external decision** (Expenses schema-shape, Technical Assumption #3). If that decision is not made in time, Phase 3 either slips or starts with Invoices/Suppliers only, deferring Expenses specifically — a valid partial-start, but one that must be an explicit call, not a default.
4. **Scope creep in Phase 5.** Because Analytics/Search/Notifications/Audit touch every prior module, it is the phase most likely to accidentally accrue "while we're in here" changes to Phases 1–4's already-shipped business logic.
5. **Temptation to pre-build Phase 7.** Stakeholder pressure to show Documents/Vault/Settlements progress is likely, given how central Vault/Settlements are to daily operations — this blueprint's position (Implementation Philosophy #4) is that building against no schema produces throwaway work, not progress.
6. **Third-party AI/OCR cost and security posture at company scale** (vs. mobile's per-device key model) is unresolved (Architecture, Future Decision #6) and could affect Phase 3's Invoices scope if not addressed before that phase's AI/OCR Capture Queue page is built.
7. **Locale/RTL decision arriving after Phase 1 begins** would force shell-level rework across every already-built page — the highest-leverage decision to get in front of, given how early it must be made (Technical Assumption #4).

## 14. Future Expansion Plan

Strictly bounded by what the Architecture already named as deferred — this section does not introduce anything new:

1. **Phase 7 activation**, once a new Supabase migration phase is designed and (for Vault/Settlements) the required dedicated study is completed (Reference §13; Architecture Future Decision #2). At that point, Documents, Financial Center/Vault, Settlements, and Notes would each become a new numbered phase (8, 9, 10, 11) following this same blueprint template — objectives/scope/modules/pages/dependencies/acceptance criteria/complexity/deliverables/risks.
2. **Mobile app activation into Supabase**, if and when that separate, still-open decision (Architecture Future Decision #1) is made. This blueprint takes no position on whether that ever happens; if it does, it does not change anything about how the dashboard itself was built, per the Architecture's explicit "independent client, shared backend" design (Architecture §12, item 1).
3. **Resolution of the remaining Future Decisions** listed in the Architecture (Expenses schema shape, cloud backup/restore design, AI/OCR integration ownership, dashboard user-onboarding process) — each, once resolved, unblocks or refines exactly the phase named against it above; none require re-opening this blueprint's overall structure.

No further expansion is proposed beyond what the Architecture already scoped as deferred.

---

## Cross-Reference Summary

| This document's section | Architecture section | Reference section |
|---|---|---|
| §1–§4 (Overview/Philosophy/Principles/Assumptions) | Executive Summary, §12 | §1, §2, §5.3 |
| §5–§6 (Order/Phases) | Development Roadmap, Module Status Matrix | §5.3, §9, §11 |
| §7 (Shared Infrastructure) | §2, §10 | §9.2, §10 |
| §8 (Page-by-page order) | §3, §4 (all subsections) | §11 |
| §9 (Component dependency map) | §12, item 1 | §2.1 |
| §10–§12 (Testing/Gates/DoD) | — (execution-only, no architectural claim) | §10 (confirm-dialog/thousands-separator source) |
| §13 (Project Risks) | Risks & Constraints | §13, §15 |
| §14 (Future Expansion) | Future Decisions | §16 |

---

*This document is an execution plan only. No code, schema, migration, or UI mockup was produced. Neither `docs/PROJECT_REFERENCE.md` nor `docs/WEB_ADMIN_DASHBOARD_ARCHITECTURE.md` was modified. Every phase, page, and dependency traces to a specific section of one or both source documents; every open question is named as a risk, assumption, or future decision rather than resolved unilaterally.*
