# Manazel — Official Project Reference

This document is a factual, code-verified reference for the Manazel (منازل) Flutter application, as of the current state of the `master` branch. Every claim below was verified directly against source files during a full read-only audit (database service, models, repositories, services, pages, widgets, `main.dart`, `pubspec.yaml`, and the `supabase/` design layer) rather than reconstructed from memory or prior conversations. File paths and line numbers are given where useful for future verification, since the code is the ultimate source of truth and this document will drift over time as the app evolves.

---

## 1. Overview

Manazel is an Android-only Flutter app (no `ios/`, `web/`, `windows/`, etc.) for a Saudi hotel-group company ("شركة منازل البيت المحدودة") to manage a portfolio of hotels: documents, employees/payroll, daily financial reports, a double-entry-style financial ledger ("Financial Center"/vault), tax invoices, suppliers, contracts, inter-hotel and inter-person settlements, and an internal audit trail. The UI is entirely Arabic/RTL.

The app has exactly one live data store: a local SQLite database via `sqflite`, wrapped by a single `DatabaseService` singleton. A separate, more modern Postgres/Supabase schema and Dart data layer exist in the repo as a reviewed design artifact for a future multi-hotel, multi-user cloud platform, but — as of this audit — **it is not initialized, not called from `main.dart`, and not imported by any screen**. Every screen in the running app reads and writes local SQLite only. This distinction matters throughout this document and is called out explicitly wherever it's relevant (schema, auth, roles, data flow).

Access control today is a single shared device PIN (optionally + biometric unlock) — there is no concept of a logged-in *user* with permissions in the live app, even though a complete (but disconnected) users/roles/permission-groups subsystem exists in the SQLite schema and UI code, compile-time disabled.

## 2. Architecture

### 2.1 Layering

```
Pages (UI, StatefulWidget + setState)
      │
      ▼
Repositories (lib/repositories/*)  ──── thin CRUD/query wrappers over one or more tables
      │
      ▼
DatabaseService (lib/core/database/database_service.dart) ── raw SQL via sqflite, one singleton
```

Heavier business logic that spans multiple tables/accounts (posting a daily report, moving money in the ledger, running payroll) lives in `lib/services/*` (`FinancialEngine`, `PayrollService`, `VaultService`, …), which repositories/pages call into. Pages never touch `DatabaseService` directly — they always go through a repository or a service, and this separation is treated as a hard rule (see `CLAUDE.md`).

### 2.2 State management & navigation

- No state-management library (no Provider/Riverpod/Bloc/GetX). Every screen is a `StatefulWidget` managing its own state via `setState`, loading data from a repository in `initState`.
- No router package (`go_router`/`auto_route`/etc. are absent from `pubspec.yaml`) and no named-route table in `main.dart`. Navigation is `Navigator.push(context, MaterialPageRoute(builder: (_) => TargetPage(hotel: hotel)))`, with data passed via constructor parameters (a `Hotel` object is threaded explicitly through nearly every hotel-scoped screen). Results flow back via `Navigator.pop(context, result)`, read from the `await Navigator.push(...)` call.
- One custom transition helper exists, `premiumRoute<T>()` in `lib/core/app_page_route.dart` — a `PageRouteBuilder` (fade + slight upward slide, 300ms) used for top-level section navigation (e.g. from `AppDrawer`, `dashboard_page.dart`'s `_openSection`). It is a nicer transition wrapper, not a routing system — sub-forms/dialogs still use plain `MaterialPageRoute`.

### 2.3 Per-hotel visual identity

Each hotel carries an `identityColorValue` (`lib/models/hotel.dart`). `lib/core/hotel_visual_identity.dart` (`HotelVisualIdentity.identityForHotel(hotel)`) derives a full `HotelIdentity` (scaffold/card/appBar/button/icon/divider/table colors + a 2-color chart palette) from that single primary color, always paired with a fixed gold secondary (`0xffB8913F`). Hotel-scoped screens wrap their `Scaffold` in `Theme(data: AppTheme.createTheme(identity), child: ...)` so only that screen's subtree adopts the hotel's color — `dashboard_page.dart:168-173` is the canonical example, and most hotel-scoped pages (vault, employees, contracts, settlements, invoices, analysis) follow the same pattern. At the app root, `main.dart` also derives a theme from whatever hotel is currently "in session" (`HotelSession.current`) and feeds it to `MaterialApp(theme:, darkTheme:)` as the app-wide default outside any specific hotel screen.

## 3. Tech Stack & Dependencies

Dart SDK: `^3.12.2` (`pubspec.yaml`); no separate Flutter SDK pin beyond `flutter: sdk: flutter`. App identity in `pubspec.yaml`: `name: manazel_new`, version `1.0.0+1` — note the `description` field is still the generic Flutter template text ("A new Flutter project."), not a real project description.

| Category | Packages |
|---|---|
| Local DB / storage | `sqflite ^2.4.2`, `path ^1.9.1`, `shared_preferences ^2.3.3` (non-sensitive UI prefs only), `path_provider ^2.1.2` |
| PDF / Excel / export / files | `pdf ^3.10.8`, `printing ^5.11.0`, `excel ^4.0.6`, `share_plus ^10.1.0`, `file_picker ^11.0.2`, `open_filex ^4.7.0`, `image_picker ^1.2.3`, `image ^4.3.0` |
| Auth / security / biometric | `local_auth ^2.3.0`, `flutter_secure_storage ^9.2.2` |
| Cloud (not yet wired) | `supabase_flutter ^2.8.0` — pubspec.yaml carries an explicit comment marking this as an independent, not-yet-initialized data layer |
| AI / OCR / connectivity | `http ^1.2.0`, `google_mlkit_text_recognition ^0.15.0`, `connectivity_plus ^6.1.0`, `mobile_scanner ^7.0.0` (ZATCA QR scanning) |
| Notifications / locale | `flutter_local_notifications ^18.0.1`, `timezone ^0.9.4`, `intl ^0.20.2`, `flutter_localizations` (SDK) |
| UI / misc | `cupertino_icons ^1.0.8`, `fl_chart ^0.69.0` |
| Dev | `flutter_test` (SDK), `flutter_lints ^6.0.0` |

No `freezed`/`json_serializable`/code-gen tooling — all 50 models in `lib/models/` are hand-written with manual `fromMap`/`toMap`/`copyWith`.

## 4. Project Structure

```
lib/
  core/            21 files — database_service.dart, theming (app_colors/app_sizes/app_radius/app_text_styles/app_theme),
                    hotel_visual_identity.dart, hotel_identity.dart, app_page_route.dart, text_similarity.dart, ...
  data/
    supabase/      Dart integration layer for the (currently unwired) Supabase backend:
                    supabase_config.dart, models/, repositories/, services/
  models/          50 plain Dart model classes (fromMap/toMap/copyWith, no code-gen)
  repositories/    19 files — one repository per table/feature area, the only layer allowed to call DatabaseService
  services/        41 files total:
                    root — financial_engine.dart, payroll_service.dart, vault_service.dart, security_service.dart,
                           auth_service.dart, session_service.dart, backup_service.dart, pdf_service.dart,
                           excel_service.dart, contract_report_service.dart, document_notification_service.dart,
                           attachment_service.dart, image_enhancement_service.dart, invoice_local_ocr_service.dart,
                           zatca_qr_parser.dart, training_mode_service.dart, sync_service.dart, settings_sync_service.dart,
                           daily_report_builder.dart, daily_report_text_renderer.dart, document_merge_service.dart
                    search/            GlobalSearchService, GlobalSearchProvider (interface), GlobalSearchResult
                    search/providers/  12 concrete per-module search providers
                    invoice_ai/        InvoiceAiService + provider interface + 3 concrete AI vision providers (Claude/OpenAI/Gemini)
  pages/           19 top-level feature directories (see §11 Feature Inventory)
  widgets/         17 shared/reusable widgets: widgets/common/, widgets/documents/, widgets/financial/,
                    widgets/suppliers/, widgets/vault/, plus widgets/app_button.dart at the root
  utils/           small helpers
  main.dart        app bootstrap and root MaterialApp
supabase/
  migrations/      7 SQL migration files (Phase 1–4, dated 2026-07-28 → 2026-07-30) — Postgres schema, RLS, seed.sql
  README.md
docs/
  database_architecture/supabase_schema_design.md — design doc + decisions log for the Supabase schema
  PROJECT_REFERENCE.md — this document
test/               unit tests (search matching, Supabase model/similarity tests) — no widget/integration test suite
```

## 5. Database

### 5.1 Local SQLite (the only live data store)

`lib/core/database/database_service.dart` (2197 lines), current schema version **50**. `PRAGMA foreign_keys = ON` is set in `onConfigure`. The DB filename switches to `manazel_training.db` when Training Mode is active, otherwise `manazel.db` (`TrainingModeService` swaps the whole file).

**51 tables** are created on a fresh install (`_createTables`, lines 559–660). Full list, grouped by domain:

**Hotels & audit**
- `hotels` — ~35 columns: identity/location/contact/branding/regional settings (currency/language/timezone columns exist but a docstring notes they are "storage-only, not read by any report yet"). `active`/`archived_at`/`archived_by`/`status`/`archive_reason` implement soft-archive.
- `hotel_audit_log` — no FK (deliberately survives hotel deletion).

**Unified documents engine**
- `documents` (polymorphic `owner_type`/`owner_id`, `hotel_scope`) → `hotels` CASCADE. Index `idx_documents_owner(owner_type, owner_id)`.
- `document_categories`, `document_types` (→ `document_categories`), `document_type_hotels` (→ `document_types`, `hotels`), `document_attachments` (→ `documents`, `hotels`), `document_hotels` (→ `documents`, `hotels`), `document_folder_links` (→ `documents`, `document_types`).
- `employee_documents` — **legacy/dead table**, superseded by `documents(owner_type='employee')` since v33; code comment states it's no longer used by any Dart code.

**Contract-documents engine (deliberately parallel, not reusing the documents engine above)**
- `contract_folders` (self-referencing `parent_id` → unlimited nesting, CASCADE), `contract_documents` (→ `contract_folders`), `contract_document_audit_log` (no FK, deliberate).

**Employees / HR**
- `employees` → `hotels`. `payroll_records`, `employee_allowances`, `employee_deductions`, `employee_advances` (funding split across cash/bank/personal/entity) → `employees`/`hotels`. `employee_events` (append-only lifecycle log) → `employees`/`hotels`.

**Financial core (ledger)**
- `financial_reports` (daily reports; `is_posted`, `report_type` main/additional, `is_locked`) → `hotels`.
- `financial_accounts` (asset/liability, cash/bank/personal/entity) → `hotels`.
- `financial_ledger` (double-entry-style rows) → `financial_accounts`, `hotels`.
- `financial_categories` — the unified expense+revenue category engine introduced in v48 (renamed from the old `expense_categories`), always `hotel_id = NULL` (app-wide), self-referencing `parent_id`. Index `idx_financial_categories_type(type)`.
- `financial_report_items` — a catalog table only (name/type/default funding source); saved reports keep their own frozen copy inside `financial_reports.details_json`, no FK relationship.

**Expenses (pending / shared / owner drawings / transfers)**
- `pending_expenses` (→ `hotels`, `financial_categories`, `shared_expenses`), `pending_expense_debts`, `pending_expense_attachments`.
- `shared_expenses` — the newer (v47) per-property distribution engine → `financial_categories`.
- `shared_expense_groups`/`shared_expense_shares` — **legacy v1** shared-expense system, explicitly retained only to display historical data, superseded by `shared_expenses`.
- `advance_withdrawals` ("owner drawing" tracking, posted via `FinancialEngine.recordOwnerDrawing`), `inter_entity_transfers`.

**Invoices & suppliers**
- `invoices` (→ `hotels`, `financial_categories` since v49), `invoice_attachments`, `invoice_audit_log` (no FK, deliberate — survives invoice deletion, no delete function exists for it either).
- `suppliers`, `supplier_debts` (→ `suppliers`, `invoices`), `supplier_payments`.

**Contracts (business, distinct from the contract-documents engine)**
- `contracts` → `hotels`, `contract_payments` → `contracts`.

**Vault / settlements**
- `vault_balances` (UNIQUE `hotel_id, type`), `vault_transactions`, `personal_withdrawals`, `entity_loans`, `deposited_funds` (→ `financial_reports` `ON DELETE SET NULL`).
- `settlement_accounts`, `settlements` (types: inter_entity/person/supplier), `settlement_transactions`.

**Users / permissions (schema exists, not wired — see §8)**
- `users` (plaintext `password` column, `role_id`), `permission_groups` (JSON permissions list). No FK relationships.

**Misc**
- `notes` → `hotels`.

Every FK to `hotel_id` uses `ON DELETE CASCADE` except the deliberately-orphan-surviving audit tables (`hotel_audit_log`, `invoice_audit_log`, `contract_document_audit_log`).

### 5.2 Schema upgrade mechanism

A single `onUpgrade` callback runs sequential `if (oldVersion < N) {...}` blocks (v21 → v50), each individual `db.execute(...)` wrapped in its own `try { } catch (_) { }` so a partially-applied upgrade never blocks the app on inconsistent real-world installs. Beyond that, `_ensureSchemaHealth(db)` runs on **every** `onOpen` (not only on a version bump) and idempotently re-checks/re-adds every column and re-creates (`IF NOT EXISTS`) every table introduced since v21, all wrapped in one outer try/catch — a safety net documented in-code as recovery from a previously undetected failed `ALTER TABLE`.

Notable migrations: v25 seeds 3 demo users (admin/manager/employee, password `123456`, plaintext); v31/v48 progressively unify expense categories into the current `financial_categories` engine; v32–v35 build the unified polymorphic documents engine; v43 unifies payment-method vocabulary across 6 tables; v44–v45 add hotel archiving + ~25 new `hotels` columns; v46 adds the independent contract-documents engine; v47 adds the new shared-expenses distribution engine; v49–v50 wire `financial_categories` as a real FK into invoices and add `last_used_at`.

### 5.3 The Supabase layer (design-complete, not connected)

A parallel Postgres schema exists at `supabase/migrations/` (7 files) with `supabase/seed.sql`, `supabase/README.md`, and a design doc at `docs/database_architecture/supabase_schema_design.md`. It defines 32 tables across 4 completed phases:

- **Phase 1 (foundation)**: `roles`, `permissions`, `role_permissions`, `hotels`, `profiles`, `user_hotel_access` — a real multi-hotel, multi-user RBAC model with Row Level Security, built on two `security definer` SQL functions (`is_hotel_accessible`, `has_permission`).
- **Phase 2 (financial core)**: `financial_categories`, `financial_reports` + line-item child tables.
- **Phase 3 (operational money flow)**: `suppliers`, `shared_expense_groups`/`allocations`, `pending_expenses` (+ attachments), `invoices` (+ attachments, audit log), `supplier_debts`, `supplier_payments`.
- **Phase 4 (people + contracts)**: `employees`, `payroll_records`, allowances/deductions/advances, `employee_events`, `contracts`, `contract_payments`, `contract_document_folders`, `contract_documents`, audit log.

Design choices deliberately differ from the SQLite schema: UUID primary keys, `numeric(14,2)` money columns, `text + check` instead of implicit enums, RLS everywhere, and consistent `_at`/`_by` audit columns. The design doc's decisions log explicitly records that consolidating `FinancialEngine`/`Vault`/`Settlements` into one system was proposed and **deferred, not approved** — consistent with the project's standing rule never to merge those three systems without a dedicated study and an explicit decision.

**This layer has zero effect on the running app.** Confirmed three independent ways: (1) `main.dart` has no Supabase import or `SupabaseConfig.initialize()` call anywhere; (2) `pubspec.yaml`'s own comment next to the `supabase_flutter` dependency states it is "a new, independent data layer... not yet initialized from main.dart and not connected to any current screen"; (3) a full-codebase grep for Supabase identifiers/imports outside `lib/data/supabase/` itself returned zero hits in `lib/pages/`, `lib/repositories/`, `lib/services/`, `lib/core/`. `SupabaseConfig`'s own class docstring says the same thing directly. Test coverage for this layer (`test/data/supabase/`) is unit-level only, not integration-wired to the app.

## 6. Data Models

50 model classes in `lib/models/`, all hand-written (`fromMap`/`toMap`/`copyWith`, no code generation), grouped by domain:

- **Hotel & audit**: `Hotel` (largest model, ~35 fields), `HotelAuditLog`.
- **Auth/permissions (schema-only, see §8)**: `User`, `Role`, `Permission`, `PermissionGroup`.
- **Unified documents engine**: `Document`, `DocumentCategory`, `DocumentType`, `DocumentAttachment`.
- **Contract-documents engine (parallel)**: `ContractFolder`, `ContractDocument`, `ContractDocumentAuditLog`.
- **Employees/HR**: `Employee`, `EmployeeEvent`, `EmployeeAllowance`, `EmployeeDeduction`, `EmployeeAdvance`, `PayrollRecord`.
- **Financial core**: `FinancialAccount`, `FinancialTransaction`, `FinancialReport`, `FinancialCategory`, `DailyReportTemplate` (+ `ReportTemplateLine`, `UnwithdrawnTemplateLine`, `SharedExpenseTemplateLine` — pure display DTOs shared identically by preview/text-share/PDF export).
- **Expenses**: `PendingExpense`, `PendingExpenseDebt`, `PendingExpenseAttachment`, `SharedExpense` (new engine), `SharedExpenseGroup`/`SharedExpenseShare` (legacy engine), `Invoice`, `InvoiceAttachment`, `InvoiceAuditLogEntry`, `ExtractedInvoiceData` (+ `InvoiceExtractionSource` enum: zatcaQr/aiVision/localOcr).
- **Suppliers**: `Supplier`, `SupplierDebt`, `SupplierPayment` (docstring notes: no screen creates rows here yet).
- **Contracts**: `Contract`, `ContractPayment`.
- **Vault/withdrawals/loans/transfers**: `VaultTransaction`, `PersonalWithdrawal`, `AdvanceWithdrawal`, `EntityLoan`, `InterEntityTransfer`, `DepositedFund`.
- **Settlements**: `Settlement`, `SettlementAccount`, `SettlementTransaction`.
- **Misc**: `Note`, `RelationshipTxn` (read-only DTO unifying ledger + settlement transactions for the "Financial Relationships" analysis screen — explicitly does not merge or mutate either underlying system).

## 7. Authentication & Security

- **Login mechanism**: a single shared device PIN, stored via `SecurityService` (singleton, `lib/services/security_service.dart`) wrapping `flutter_secure_storage`. **The PIN is stored unhashed** (`_storage.write(key: 'user_pin', value: pin)`) and verified by plain string equality — no salting/hashing, no lockout/attempt-limiting/cooldown logic anywhere in the class.
- Optional biometric unlock via `local_auth` (`canCheckBiometrics`, `authenticateWithBiometrics`, `biometricOnly: true`), stored as a simple enabled/disabled flag, not tied to any user identity.
- `SecurityService` also stores AI-provider API keys (Claude/OpenAI/Gemini) for the invoice-OCR feature — unrelated to login, same secure-storage mechanism.
- **Boot sequence** (`main.dart`, `main()`): `WidgetsFlutterBinding.ensureInitialized()` → `SecurityService.instance.hasPin()` → `AppThemeController.bootstrap()` → `TrainingModeController.bootstrap()` → `runApp()`. Routing: `home: hasPin ? PinLoginPage() : SecuritySetupPage()` — that is the entire decision; no user-accounts check, no role check. A fire-and-forget (non-awaited) call reschedules document-expiry notifications on startup. No explicit database-init call — `DatabaseService` opens lazily on first query. No Supabase init.
- **Two near-duplicate session-holder classes exist**: `AuthService` (`lib/services/auth_service.dart`, not a singleton, holds `currentUser`/`isLoggedIn`) and `SessionService` (`lib/services/session_service.dart`, singleton `.instance`, same shape). Verified via grep: `AuthService` has **zero real call sites anywhere in `lib/`** (dead code, only mentioned in a doc comment); `SessionService` has exactly one call site, `lib/pages/login/login_page.dart:53`. Both classes hold a `User` (the SQLite `users`-table model), not a Supabase auth identity.
- `LoginPage` (`lib/pages/login/login_page.dart`) — a username/password form against `UserRepository.login()` (plaintext comparison, `user_repository.dart:40`) — exists in the codebase but **is not reachable from `main.dart`, the drawer, or any other screen**; it is orphaned. The app never actually uses username/password login in practice; only the PIN path is live.
- `lib/models/invoice_audit_log_entry.dart` contains a code comment confirming this directly: since there's no real live multi-user login, audit-log rows use a hard-coded constant username ("مستخدم النظام") rather than a real per-user identity.

## 8. User Roles & Permissions

There are, in effect, **two separate roles/permissions systems in this codebase, and neither is active in the running app in the way its name suggests**:

**A. Local SQLite users/roles/permission-groups (dormant, compile-time disabled)**
A complete admin subsystem exists: `users` table (`role_id` column, plaintext `password`), `permission_groups` table (JSON permission list), models `User`/`Role`/`Permission`/`PermissionGroup`, repository `UserRepository` (full CRUD + login + permission-group CRUD), and UI pages `UsersPage`, `AddEditUserPage`, `PermissionGroupsPage`. However:
- The only navigation entry point to this subsystem — the drawer item "إدارة المستخدمين والصلاحيات" — is gated by `const bool kAppHasMultipleUsers = false;` in `lib/widgets/common/app_drawer.dart:34`, so the menu item is never built (`if (kAppHasMultipleUsers) ...`) and `UsersPage` is unreachable from the live app.
- `LoginPage`, the only screen that would call `UserRepository.login()`, is itself orphaned (see §7).
- **No page, repository, or service anywhere checks `roleId`, permission-group membership, or calls any "has permission" gate to restrict an action.** The `Role`/`Permission` models are declared but have no enforcement logic referencing them at all.
- Net effect: this whole subsystem is dead weight from the running app's perspective — real, working code, just never invoked.

**B. What actually gates access today**: whether the device knows the correct PIN (or passes biometric unlock tied to that PIN). There is no per-user identity, and once past the PIN screen, every feature and every action in the app is available — there is no role or permission check anywhere in the live code path.

**C. The Supabase layer's RBAC design (not connected — see §5.3)**: a materially more complete design exists there — `roles`, `permissions`, `role_permissions`, `profiles`, `user_hotel_access` (per-user, per-hotel role grants), Postgres Row Level Security policies gated by `is_hotel_accessible()`/`has_permission()` SQL functions, and a seeded "Owner" role with a blanket grant. `supabase/seed.sql` includes a `users.manage` permission code. This is a genuine, reviewed multi-tenant RBAC design — but again, it has zero runtime effect on the shipping app today; it's backend schema/migrations plus an unwired Dart layer.

**Practical takeaway for anyone extending this app**: don't assume `roleId`/permission-group data reflects real restrictions — nothing reads it. If a feature needs access control today, it would need new code; there is no existing hook to plug into.

## 9. Services, Repositories & Providers

### 9.1 Repositories (`lib/repositories/`, 19 files)

Every repository is a thin CRUD/query layer over one or more tables and is the only thing besides `services/` allowed to call `DatabaseService`. All 19 are actively imported/used somewhere in the app (no dead repository files):

`ContractDocumentRepository`, `ContractRepository`, `DocumentRepository`, `DocumentTypeRepository`, `EmployeeRepository`, `ExpenseRepository`, `FinancialCategoryRepository`, `FinancialRelationshipsRepository` (read-only aggregator merging FinancialEngine + Settlements data without merging the underlying systems), `FinancialRepository` (daily reports), `HotelRepository`, `InterEntityTransferRepository`, `InvoiceRepository`, `NoteRepository`, `SettlementRepository`, `SharedExpenseDistributionRepository` (new v47 engine), `SharedExpenseRepository` (legacy v1 engine), `SupplierRepository`, `UserRepository`, `VaultRepository`.

Each of these has a parallel `Supa*Repository` counterpart under `lib/data/supabase/repositories/`, part of the unwired Supabase layer.

### 9.2 Services (`lib/services/`, 41 files total)

**Financial engine (heavy, transactional)** — `FinancialEngine` (singleton, `lib/services/financial_engine.dart`): the core double-entry-style ledger over `financial_accounts`/`financial_ledger`. Exposes `recordTransaction`, `settleDebt`, `recordPersonalAction`, `recordOwnerDrawing`, `recordSharedExpense`, `collectReceivable`, plus balance/ledger getters. All six mutating operations open `await db.transaction((txn) async {...})` before touching account balances — confirmed atomic per operation (lines 132, 152, 173, 201, 226, 249).

**Vault** — `VaultService` (UI-facing wrapper: balance-sufficiency check, confirm dialog, records a transaction via `VaultRepository`, undo snackbar). Most of the actual vault logic lives in `VaultRepository`, not a service.

**Payroll** — `PayrollService`: builds the employment timeline from `employee_events`, computes prorated salary breakdowns, and exposes the full HR action set (`hireEmployee`, `transferEmployee`, `suspendEmployee`, `returnToWork`, `resignEmployee`, `terminateEmployee`, `changeSalary`, `changePosition`, `promoteEmployee`, `archiveEmployee`, `addAdvance`, `approveSalary`, `paySalary`) — financial postings routed through `FinancialEngine`.

**Settlements** — no dedicated service file; logic lives entirely in `SettlementRepository`, read/aggregated by `FinancialRelationshipsRepository`.

**Global Search** (`lib/services/search/`) — `GlobalSearchService` holds a static list of exactly 12 registered `GlobalSearchProvider` implementations and runs them concurrently via `Future.wait`: `HotelsSearchProvider`, `EmployeesSearchProvider`, `DocumentsSearchProvider`, `DocumentTypesSearchProvider`, `ContractsSearchProvider`, `SuppliersSearchProvider`, `FinancialCategoriesSearchProvider`, `PendingExpensesSearchProvider`, `DailyReportsSearchProvider`, `InvoicesSearchProvider`, `NotesSearchProvider`, `SettingsSearchProvider` (a static index of settings sections, not a DB query). Adding a new module means implementing `GlobalSearchProvider` and adding it to that one list — no other file needs to change. The search screen (`lib/pages/search/global_search_page.dart`) debounces input 200ms before querying and ignores stale results from superseded requests via a monotonically-increasing request id.

**Export/reporting (lighter, no DB transactions)** — `PdfService`, `ExcelService`, `ContractReportService`, `daily_report_builder.dart` (rebuilds the canonical report template from `details_json`), `daily_report_text_renderer.dart` (WhatsApp-style plain-text rendering shared by share/copy), `DocumentMergeService` (merges multiple documents' attachments into one PDF by rasterizing to images — visual merge only, not vector-preserving).

**Auth/security** — `SecurityService`, `AuthService` (dead code — zero call sites), `SessionService` (one call site) — see §7.

**Misc/infrastructure** — `AttachmentService` (file picking/permanent storage/deletion), `BackupService` (local DB file backup/restore/listing, scheduled auto-backup check), `DocumentNotificationService` (local notifications at 30/10/5/0 days before document expiry, Asia/Riyadh timezone), `ImageEnhancementService` (pre-processes invoice photos before OCR — fails safe, returns original bytes on error), `InvoiceLocalOcrService` (offline ML Kit fallback OCR, Latin script only), `SettingsSyncService` and `SyncService` (**both are no-op stubs** for a documented future cloud-sync feature — `pushToCloud`/`pullFromCloud` do nothing), `TrainingModeService` (swaps the entire DB file for a training copy), `zatca_qr_parser.dart` (Base64→TLV parser for ZATCA simplified-invoice QR codes).

**Invoice AI** (`lib/services/invoice_ai/`) — `InvoiceAiProvider` (abstract interface + shared prompt/JSON parsing), `InvoiceAiService` (orchestrator: reads active provider/key from settings, checks connectivity, delegates), and three concrete vision providers: `ClaudeInvoiceAiProvider` (Anthropic Messages API), `GeminiInvoiceAiProvider` (Google Generative Language API), `OpenAiInvoiceAiProvider` (OpenAI Chat Completions with vision input).

Every service and repository listed above was confirmed to have at least one real caller in the live app, with the single exception of `AuthService`, which is unused dead code (kept in the codebase but never imported).

## 10. UI System

- **Colors** (`lib/core/app_colors.dart`): default identity primary `0xff7A1E2C` (maroon), default secondary/gold `0xffB8913F`, plus fixed state colors (success/warning/danger/info). Screen backgrounds/cards/text/borders were deliberately migrated to read from `Theme.of(context)` instead of fixed constants, to support dark mode.
- **Spacing** (`lib/core/app_sizes.dart`): `xs=4, sm=8, md=16, lg=24, xl=32, xxl=48`, plus icon sizes and `buttonHeight=55`/`hotelCardHeight=125`. It also carries its own radius constants (`radiusSmall=10, radiusMedium=18, radiusLarge=28`).
- **Radius** (`lib/core/app_radius.dart`): a *separate* scale, `xs=8, sm=12, md=18, lg=24, xl=32` — note this overlaps but does not match `AppSizes`'s radius constants; two radius scales coexist in the codebase and both are in active use, so don't assume they're interchangeable when touching either file.
- **Typography** (`lib/core/app_text_styles.dart`): `display/headline/title/subtitle/body/bodyBold/caption`, all deliberately omitting `color` (except `button`, hardcoded white) so they inherit from the active theme for dark-mode support.
- **Theme engine** (`lib/core/app_theme.dart`, `AppTheme.createTheme(HotelIdentity, {Brightness})`): single source for both light and dark `ThemeData`. Light mode pins `ColorScheme.fromSeed` to the hotel identity's exact colors; dark mode reseeds from the same primary color at dark brightness, so each hotel keeps its hue in dark mode. Also configures `appBarTheme`, `cardTheme`, `elevatedButtonTheme`, `tabBarTheme`, `dataTableTheme`, `iconTheme`, `dividerTheme`, `bottomNavigationBarTheme`, `dialogTheme`, `bottomSheetTheme`.
- **Shared widgets** (17 files): `lib/widgets/common/` — `AppCard` (base container, tap-scale animation, optional identity-colored accent stripe), `AppDialog` (`show()` info dialog + `confirmAction()`, the app-wide mandatory confirm/cancel pattern with a dangerous/red variant), `AppDrawer` (main nav — hotels, documents hub, contracts, contract-documents, suppliers, notes, master data, users [gated off], backup, settings, support, about, logout), `AppLoading`, `AppTextField` (incl. optional thousands-separator formatter), `ComingSoonPage` (generic placeholder for unbuilt sections), `HotelIdentityTitle` (AppBar title + hotel color/name pill). Root: `AppButton`. Domain-specific: `widgets/documents/*` (2 dialogs), `widgets/financial/*` (4 — report-item sheet, `DailyReportView`, the unified `FinancialCategoryPicker`, `FinancialCategoryTile`), `widgets/suppliers/supplier_picker_sheet.dart`, `widgets/vault/amount_source_selector.dart`.
- **Navigation**: see §2.2 — confirmed via grep: `MaterialPageRoute` appears 157 times across 76 files, `Navigator.push` 196 times across 84 files; no router package, no named routes.

## 11. Implemented Features

Feature inventory by module (`lib/pages/`, 19 top-level directories):

- **Dashboard** — per-hotel control panel with 8 sections (Pending Financial Operations w/ badge, Financial Report, Financial Center/Vault, Hotel Documents, Analysis Center, Tax Invoices, Employees, More).
- **Hotels** — list/search/select (`hotels_page.dart`); add/edit/archive lives under Settings → Hotel Management, not here.
- **Employees** — list w/ payroll summary, add/edit, full detail (advances/deductions/allowances/events/payroll/documents), archive (no hard delete anywhere in the system), salary/advances/allowances/deductions/yearly reports w/ Excel export.
- **Documents (unified engine)** — hub (permanent/seasonal/employee-doc sections + search), permanent/seasonal folder browsers, folderless "general documents" list, folder create/edit, document create/link-existing, cross-folder advanced search.
- **Contract Documents (separate module)** — unlimited nested folders, recursive browser with breadcrumbs, full-text search across the tree, archive w/ 4-step confirm hard-delete, audit log.
- **Document Types (master data)** — reference type list, add/edit (category, mandatory/renewal flags, hotel scope), category management.
- **Financial Reports** — daily report entry/edit, preview-before-post, monthly rollup w/ Excel/PDF, previous-reports list w/ period filters, saved/posted read-only view w/ share/PDF/print.
- **Expenses** — pending expense create (category/funding-source/supplier/attachments), shared-expense create/edit (auto-distribution across hotels + manual override), inter-entity transfer, owner withdrawal, period-filtered reporting, pending-operations hub.
- **Invoices** — hub w/ search/filter, manual entry (5 funding-source types), detail/edit + audit log, QR/AI/OCR capture pipeline (camera/gallery/PDF → multi-invoice picker → quick review), period reporting w/ Excel export, supplier report/statement.
- **Settlements** — hub for inter-entity debts, person debts, supplier debts; list/detail/add for each, receipt attachments.
- **Vault / Financial Center** — dashboard (cash/bank/receivable/payable summary), generic category ledger, collect-receivable, deposited-funds (+ archive), entity loans, financial-relationships browser, personal accounts/actions/withdrawals, settle-debt, unposted-funds, full transaction log. Note: a second, independent inter-entity-debts implementation exists here (`vault/inter_entity_debts_page.dart`, backed by `FinancialEngine`) alongside the Settlements module's own (`settlements/pages/inter_entity_debts_page.dart`, backed by `SettlementRepository`) — two parallel systems by design, per the standing rule never to merge FinancialEngine/Vault/Settlements without a dedicated study.
- **Contracts** — list, add/edit w/ payment schedule, detail w/ PDF report and vault-linked payment collection.
- **Analysis Center** — read-only, no-mutation query layer: cash/bank movements, documents-by-hotel/date, employee analytics, financial analysis w/ drill-down (`fl_chart`), financial-relationships analytics, full report browser w/ per-line breakdown.
- **Global Search** — instant, debounced (200ms), app-wide search across 12 modules (see §9.2).
- **Login/Security** — PIN entry (+ optional biometric), first-run PIN setup.
- **Master Data** — hub for cross-hotel shared data (document types, financial categories).
- **Notes** — simple per-hotel CRUD list.
- **Settings** — general prefs (dark mode, font size, animation speed, notification toggle), AI invoice-OCR provider config, backup (real local file backup/restore + listing + log), DB data-info (file size, per-table row counts, documents-folder size — read-only), unified financial-categories management (+ display-preferences page for the picker's layout), hotel management (search/add/edit wizard/duplicate/archive/recycle-bin/audit-log), about, support (FAQ-style, no contact channel wired).
- **Users** — full CRUD UI for users/permission-groups exists but is unreachable in the running app (§8).
- **Alerts** — document-expiry alerts per hotel.

## 12. Missing / Not-Yet-Implemented Features

Confirmed stub, placeholder, or explicitly-not-yet-wired features found during the audit:

- **Cloud sync** — `SyncService`/`SettingsSyncService` are no-op stubs; `settings/sync_log_page.dart` is a genuinely empty log (comment: "فارغ صادقاً حالياً"); `settings/backup_page.dart`'s cloud-sync section is UI shell only, no network call.
- **Multi-user accounts / roles / permissions** — full UI and schema exist but are compile-time disabled (`kAppHasMultipleUsers = false`) and have zero enforcement code anywhere (§8).
- **Hotel logo/cover image upload** — UI present in `hotel_wizard_page.dart` but inert, marked "قريباً" pending an image-cropping dependency.
- **"Suppliers"/"Maintenance"/"Rooms" cards** in `more_modules_page.dart` — empty `onTap: () {}`, no navigation at all (not even a `ComingSoonPage`).
- **`ComingSoonPage`-routed entries** in `documents_hub_page.dart` and `master_data_hub_page.dart` for any section without a real `builder`.
- **`SupplierPayment`** — model and repository support exist, but no screen actually creates rows in this table yet (docstring-confirmed).
- **Supplier statement payment recording** — `supplier_statement_page.dart` is explicitly view-only; no payment-entry screen yet.
- **Invoice reporting ↔ Analysis Center linkage** — `invoice_reports_page.dart` comment confirms it isn't linked to the Analysis/Financial Center yet.
- **User activity tracking** — `users/user_activity_page.dart` shows fields (last login, devices, operation count) populated with "not available yet" text rather than real data, since there's no live per-user login system.
- **Analysis Center "Health Index" / "Smart Analysis" cards** — explicitly documented as UI-only stubs, no real algorithm behind them.
- **The entire Supabase/multi-hotel-platform layer** (§5.3, §8C) — schema and Dart repositories exist and are code-reviewed, but nothing is initialized or connected; this is the largest "implemented but not live" item in the codebase.
- **`LoginPage`** (username/password) — fully coded but orphaned/unreachable from the app's actual navigation graph.

## 13. Limitations

- **PIN security**: stored unhashed, verified by plain string equality, no lockout/attempt-limiting/cooldown. A single shared secret gates the entire app; there is no way to restrict any user or action once past the PIN.
- **No real multi-user attribution**: every audit-log row (invoices, hotels, contract documents) is written under a hard-coded system username, not a real actor, because there is no live login identity to attribute to.
- **Two duplicate radius scales** (`AppSizes.radiusSmall/Medium/Large` vs `AppRadius.xs/sm/md/lg/xl`) coexist with different values — a source of visual inconsistency risk when picking one at random for new UI.
- **Two near-identical session-holder services** (`AuthService` dead, `SessionService` barely used) exist side by side — a future contributor could easily wire new code to the wrong one.
- **Two parallel shared-expense systems** (`shared_expense_groups`/`shared_expense_shares` legacy vs. `shared_expenses` current) and **two parallel inter-entity-debt implementations** (Vault's `FinancialEngine`-backed page vs. Settlements' `SettlementRepository`-backed page) coexist by design — not a bug, but anyone touching "debts between hotels" must know which system a given screen actually uses before changing shared logic.
- **`employee_documents` and `document_categories`/legacy `expense_categories`-era tables**: dead/legacy tables remain in the schema for backward data compatibility; don't assume every table still visible in the DB is actively written to.
- **Regional settings on `Hotel`** (currency/language/timezone/date-format/time-format columns) are stored but not read by any report or calculation yet — populated data with no behavioral effect.
- **No automated test suite** for the live app: `test/widget_test.dart` is the unmodified Flutter template (tests a counter that doesn't exist in `ManazelApp` — it will fail if run) and there is no real widget/integration coverage. The only real tests are narrow unit tests (search-matching logic, Supabase model/similarity helpers under `test/data/supabase/`) — none exercise a live screen or the SQLite repository layer.
- **The Supabase design is unvalidated against the running app** — it was built as a forward-looking multi-tenant redesign, but has never been exercised against the same data/flows the SQLite app actually handles daily; treat it as a design draft, not a proven replacement.

## 14. Data Flow

The running app's actual data flow, verified from source (not the generic "Providers → Supabase" template sometimes assumed for Flutter apps — this app has neither a state-management Providers layer nor a live Supabase connection):

```
User interaction (StatefulWidget)
        │
        ▼
Page calls a Repository method (lib/repositories/*)
   — for compound operations, the Page may instead call a Service
     (FinancialEngine / PayrollService / VaultService / GlobalSearchService / ...)
     which itself calls into one or more Repositories
        │
        ▼
Repository builds SQL and calls DatabaseService (lib/core/database/database_service.dart)
   — a single sqflite-backed singleton; multi-step mutations are wrapped in
     db.transaction(...) inside the Service layer (e.g. FinancialEngine's six
     mutating methods) to keep balance + ledger writes atomic
        │
        ▼
sqflite (local SQLite file: manazel.db, or manazel_training.db in Training Mode)
        │
        ▼
Result (row(s) / bool / generated id) returned back up the same call chain
        │
        ▼
Page calls setState(...) to rebuild with the new data
```

There is no Providers/state-management layer to route through, and no network hop — everything above happens on-device, synchronously from the UI's perspective (all repository/service calls are `Future`-based and awaited). The one exception noted for completeness: `GlobalSearchService` fans a single query out to 12 providers concurrently via `Future.wait` before merging results back for display.

The Supabase-backed flow described in the design docs (`UI → Repository → Supa*Repository → Supabase Postgres (RLS-gated) → UI`) exists only as code under `lib/data/supabase/`, exercised solely by its own unit tests — it is not a path any real screen currently takes.

## 15. Development Status

- **Core hotel-operations app**: mature and actively used — hotels, employees/payroll, documents (both engines), financial reports, the vault/ledger engine, invoices (incl. AI/OCR capture), suppliers, contracts, settlements, and global search are all fully wired end-to-end against local SQLite, with PDF/Excel export throughout.
- **Multi-hotel cloud platform (Supabase)**: Phases 1–4 of a 7-phase design are schema-complete and code-reviewed (migrations + Dart repository layer + unit tests), but Phase 5–7 are design-only and the entire layer remains disconnected from the running app pending an explicit decision to wire it in.
- **Multi-user/RBAC**: fully coded at the SQLite layer but compile-time disabled; a more complete RBAC design exists at the Supabase layer, also disconnected.
- **Cloud sync**: not started beyond stub service classes and placeholder UI.
- **Automated testing**: minimal — a handful of unit tests for search-matching and Supabase-layer models/similarity helpers; no widget or integration tests; the default Flutter template test is unmodified and would fail if run.
- **Schema versioning discipline**: strong — 50 sequential, individually try/caught upgrade steps plus an idempotent `_ensureSchemaHealth` safety net on every open, suggesting this app has already been through many real-world upgrade cycles across existing installs.

## 16. Recommendations

These are observations from this audit, not decisions — several intersect with the project's own standing rules (never merge FinancialEngine/Vault/Settlements without a dedicated study; number formatting and confirm-dialogs are already standardized) and should be treated as candidates to discuss, not a queue to execute unprompted:

1. **Resolve the `AuthService`/`SessionService` duplication** — `AuthService` is dead code; either delete it or document why it's being kept, so future contributors don't accidentally build against the unused one.
2. **Decide the fate of the disabled Users/Permissions subsystem** — it's fully built and unreachable; either flip `kAppHasMultipleUsers` on with a real plan for PIN-vs-account coexistence, or explicitly mark it as reference/future code so it isn't mistaken for dead weight and deleted, or vice versa.
3. **Unify the two radius scales** (`AppSizes` vs `AppRadius`) the next time either is touched for unrelated work, to remove a standing source of visual drift — low-risk, mechanical, but worth flagging rather than doing silently given it touches UI broadly.
4. **PIN hashing** — if this is a real security concern for the business (vs. accepted risk for a single-device internal tool), storing a hash instead of the raw PIN would be a small, contained change; flagging it here rather than treating it as implicitly out of scope.
5. **Clarify the Supabase layer's status to the team** — it represents a large amount of completed design work sitting idle; worth an explicit decision (schedule to wire it in, keep as reference architecture, or archive) rather than letting it silently accumulate more phases with no activation plan.
6. **Add minimal regression coverage** before further risky changes to the financial/vault/settlements code paths, given the near-total absence of automated tests today — even a handful of repository-level tests against a real in-memory/temp sqlite DB would catch the kind of schema/logic regressions that are currently only caught by manual device testing.
7. **Remove or explicitly document dead legacy tables** (`employee_documents`, the pre-v48 `expense_categories` remnants, `shared_expense_groups`/`shared_expense_shares` once their historical data is no longer needed) so new contributors don't mistake them for active tables.

---

*This document reflects a point-in-time, code-verified snapshot. As the app evolves, re-verify against source before relying on specifics (exact schema version, table/column lists, file line numbers) — the architecture and layering conventions described in §2 are the most durable part of this reference; specific counts and version numbers are the most likely to drift.*
