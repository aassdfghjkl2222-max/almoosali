# Manazel — Master Development Plan (Final Project Roadmap)

**Document status**: OFFICIAL — governing document for all implementation work from this point until production release.

**Document control**: This is a **fourth**, higher-level document. It does not replace, redesign, or override any of the three documents below — it governs the *order, gating, and tracking* of work that those three documents already fully specify.

| Document | Role | Controls |
|---|---|---|
| `docs/PROJECT_REFERENCE.md` | Ground truth | What exists today in the live mobile app (code-verified facts) |
| `docs/WEB_ADMIN_DASHBOARD_ARCHITECTURE.md` | Design law | What the dashboard is — modules, navigation, data model mapping, security model |
| `docs/WEB_ADMIN_IMPLEMENTATION_BLUEPRINT.md` | Execution law | The exact build order, page-by-page scope, acceptance criteria |
| `docs/MASTER_DEVELOPMENT_PLAN.md` (this document) | Project management | Phase gating, milestones, status tracking, change control, the workflow every future session follows |

Nothing in this document introduces a new business module, changes the navigation structure, changes the data model, or overrides a decision already made in the three source documents. Where this document adds structure not present in the sources (a pre-implementation planning phase, a post-Phase-6 release phase), it is called out explicitly as new *process* scaffolding, not new *product* scope.

---

## 1. Executive Summary

**Current project status.** The Manazel mobile application (Flutter, Android-only) is mature, production-used, and fully wired end-to-end against local SQLite — schema v50, 51 tables, 19 repositories, 41 services, 50 models, 19 top-level page modules (`PROJECT_REFERENCE.md` §1, §5.1, §15). A parallel Supabase/Postgres schema for a future multi-hotel cloud platform is schema-complete and code-reviewed for 4 of 7 planned phases (32 tables across Phases 1–4: foundation/RBAC, financial core, operational money flow, people+contracts) but has **zero runtime effect on the shipping app today** — not initialized, not called, not imported anywhere in `lib/` outside `lib/data/supabase/` itself (`PROJECT_REFERENCE.md` §5.3).

On top of that foundation, a Web Administration Dashboard has been fully designed — not built — across two documents: the Architecture (17 modules, complete navigation, per-module cloud-readiness assessment, security model) and the Implementation Blueprint (7 build phases, 99 total pages — 73 scheduled across Phases 1–6, 26 named but explicitly unscheduled in Phase 7 — shared-component plan, testing strategy, quality gates). Both documents were independently verified against live source code and against each other; two minor defects (a missing page enumeration, a wrong section citation) were found and corrected during that verification pass. **No dashboard code, schema, or migration exists yet.** This is a blueprint, not a running system.

**What has already been completed** (Phase 0 of this plan, retroactively defined below):
- Full code-verified audit of the mobile application (`PROJECT_REFERENCE.md`).
- Complete dashboard architecture — module boundaries, navigation, cloud-schema mapping, security model, risks, and future decisions (`WEB_ADMIN_DASHBOARD_ARCHITECTURE.md`).
- Complete build sequencing — 7 phases, page-by-page order, shared infrastructure plan, testing strategy, quality gates, Definition of Done (`WEB_ADMIN_IMPLEMENTATION_BLUEPRINT.md`).
- Cross-verification of both documents against the live codebase and against each other, with corrections applied.
- Supabase Phases 1–4 schema design, migrated and reviewed (though not connected to any running client — mobile or dashboard).

**What remains:**
- Resolving the open Technical Assumptions and Future Decisions that gate the start of implementation (§3, §10 below) — most importantly: provisioning a real Supabase project, deciding dashboard locale/RTL, and deciding the Expenses schema-shape mismatch before Phase 3.
- Building Blueprint Phases 1 through 6 (73 pages) in strict sequence.
- A production-readiness and go-live pass once Phase 6 completes (not detailed in the Blueprint, added by this document — §2.8).
- Phase 7 (Documents, Financial Center/Vault, Settlements, Notes — 26 pages) remains explicitly **not scheduled**, pending a new Supabase migration phase and, for Vault/Settlements specifically, the project's standing dedicated-study requirement before touching anything FinancialEngine/Vault/Settlements-adjacent.
- The separate, still-open decision of whether/when to wire the *mobile app itself* into Supabase — orthogonal to the dashboard, not required for any of the above.

**Overall implementation strategy.** Strictly sequential, schema-readiness-driven, phase-gated execution of the Blueprint's existing 7-phase plan — no reordering, no parallel-phase shortcuts across data dependencies, no building ahead of an available backend schema. Every phase ends in a Quality Gate (§6) that must pass before the next phase starts. Documentation is treated as part of the deliverable, not an afterthought: every phase completion updates this document's status tracker (§2, §5). Phase 7 stays visible on the roadmap but unscheduled until its blocking decisions are made — building it early "to show progress" is explicitly forbidden by the Blueprint (Implementation Philosophy #4) and that prohibition is inherited unchanged here.

---

## 2. Project Phases

Phase numbering follows the Blueprint exactly (Phases 1–7) so the two documents never drift apart. This document adds one phase before (**Phase 0**) and one phase after (**Go-Live**) the Blueprint's numbered range, using names rather than numbers to avoid colliding with the Blueprint's own reserved future numbering (Blueprint §14: Phase 7's four modules become numbered Phases 8–11 *if and when* they are unblocked).

### 2.0 Phase 0 — Planning & Architecture *(COMPLETE)*
| | |
|---|---|
| Objective | Establish ground truth, design, and execution sequencing before any implementation begins. |
| Scope | Mobile-app audit (Reference), dashboard architecture (Architecture), build blueprint (Blueprint), this master plan. |
| Deliverables | `PROJECT_REFERENCE.md`, `WEB_ADMIN_DASHBOARD_ARCHITECTURE.md`, `WEB_ADMIN_IMPLEMENTATION_BLUEPRINT.md`, `MASTER_DEVELOPMENT_PLAN.md` — all cross-verified. |
| Dependencies | None — this is the starting point. |
| Completion criteria | All four documents exist, are internally consistent, and are verified against live source code. **Met.** |
| Risks | Documents drifting from code or from each other over time (see §9). |
| Estimated complexity | N/A — retrospective. |
| Status | **COMPLETE** |

### 2.1 Phase 1 — Foundation, Authentication & Hotels
Objective, scope, pages, dependencies, and acceptance criteria are fully specified in Blueprint §6.1 — restated here at tracking level only.
- **Objective**: stand up the app shell, real Supabase Auth, and the Hotels module — the one module every later phase is scoped by.
- **Scope**: navigation shell, header, theming, sign-in, Hotel CRUD/archive/restore/audit-log, Dashboard Home skeleton.
- **Deliverables**: 7 pages (Blueprint §8, Phase 1 table); all Phase-1 shared components (§7 below) built once here.
- **Dependencies**: Supabase Phase 1 schema reachable; locale/RTL decision made (Technical Assumption #4); at least one interim Supabase-side user/hotel-access grant provisioned manually (Technical Assumption #2).
- **Completion criteria**: Blueprint §6.1 acceptance criteria in full.
- **Risks**: Auth/RLS sequencing gap if not resourced; late locale/RTL decision forcing shell rework.
- **Estimated complexity**: High (carries all shared-infrastructure cost).
- **Status**: NOT STARTED

### 2.2 Phase 2 — Core Financial Operations
- **Objective**: deliver the mobile app's central daily accounting workflow, company-wide.
- **Scope**: Financial Reports full lifecycle, Financial Categories management, Master Data hub (financial-categories entry only).
- **Deliverables**: 8 pages (Blueprint §8, Phase 2 table).
- **Dependencies**: Phase 1 complete; Supabase Phase 2 schema reachable.
- **Completion criteria**: Blueprint §6.2 acceptance criteria in full.
- **Risks**: `financial_report_items` catalog vs. frozen `details_json` snapshot behavior must be replicated correctly.
- **Estimated complexity**: Medium-High.
- **Status**: NOT STARTED

### 2.3 Phase 3 — Operational Money Flow
- **Objective**: deliver expense, invoice, and supplier management — the highest transaction-volume modules.
- **Scope**: Pending/shared expenses, inter-entity transfers, owner withdrawals, full invoice lifecycle incl. AI/OCR capture, supplier directory/statements/reports.
- **Deliverables**: 18 pages (Blueprint §8, Phase 3 table).
- **Dependencies**: Phases 1–2 complete; Supabase Phase 3 schema reachable; **the Expenses schema-shape mismatch (Architecture Risk #4) explicitly resolved or explicitly accepted — hard gate, not soft.**
- **Completion criteria**: Blueprint §6.3 acceptance criteria in full.
- **Risks**: AI/OCR integration ownership unresolved defers the capture pipeline within this phase.
- **Estimated complexity**: High (largest page count, only externally-gated phase).
- **Status**: NOT STARTED

### 2.4 Phase 4 — People & Contracts
- **Objective**: deliver HR/payroll and contract administration company-wide.
- **Scope**: full employee lifecycle actions, payroll, contracts with payment schedules, the independent Contract Documents folder engine.
- **Deliverables**: 14 pages (Blueprint §8, Phase 4 table).
- **Dependencies**: Phase 1 complete (Hotels); Supabase Phase 4 schema reachable.
- **Completion criteria**: Blueprint §6.4 acceptance criteria in full — including "no hard delete anywhere" for employees.
- **Risks**: None phase-specific beyond general risks (§10) — best-understood of the four data phases.
- **Estimated complexity**: Medium-High.
- **Status**: NOT STARTED

### 2.5 Phase 5 — Cross-Cutting Intelligence
- **Objective**: layer read-only aggregation and discovery on top of Phases 1–4's data — the dashboard's core cross-hotel value proposition.
- **Scope**: Analytics Center, Global Search, Notifications Center (partial), Audit Center (partial).
- **Deliverables**: 18 pages (Blueprint §8, Phase 5 table).
- **Dependencies**: Phases 1–4 complete — this phase has no data of its own.
- **Completion criteria**: Blueprint §6.5 acceptance criteria in full — "Health Index"/"Smart Analysis" never presented as functioning, under any circumstance.
- **Risks**: Scope creep — easiest phase to accidentally "improve" already-shipped Phase 1–4 business logic.
- **Estimated complexity**: Medium.
- **Status**: NOT STARTED

### 2.6 Phase 6 — Administration & Security
- **Objective**: deliver company-level configuration and activate real, per-user, per-hotel dashboard access, retiring Phase 1's interim manual-provisioning arrangement.
- **Scope**: Administration Center minus Backup/Sync (blocked), full Users & Permissions module against Supabase Phase 1 RBAC schema.
- **Deliverables**: 8 pages (Blueprint §8, Phase 6 table).
- **Dependencies**: Phase 1's RBAC tables (already provisioned then); a decision on dashboard user onboarding (Future Decision #4).
- **Completion criteria**: Blueprint §6.6 acceptance criteria in full — every prior phase's module respects RLS-enforced, per-user, per-hotel access.
- **Risks**: If onboarding-process decision is unresolved, only the technical RBAC UI ships; provisioning process waits separately.
- **Estimated complexity**: Medium (schema exists; work is UI + wiring).
- **Status**: NOT STARTED — this is the phase that closes out the **scheduled scope**.

### 2.7 Phase 7 — Blocked Modules *(documented, not scheduled)*
- **Objective**: none scheduled — keeps Documents, Financial Center/Vault, Settlements, and Notes visible without implying they can be estimated today.
- **Scope**: not defined until a new Supabase migration phase is designed and, for Vault/Settlements, the project's standing dedicated study is completed.
- **Deliverables**: 26 pages named for completeness (Blueprint §8, Phase 7 table) — **not a build commitment**.
- **Dependencies**: a new Supabase migration phase (undecided, out of scope for the Architecture, Blueprint, and this document alike).
- **Completion criteria**: not definable until the schema decision is made.
- **Risks**: the single largest integrity risk to this whole plan is building any Phase 7 page ahead of schedule "informally" (Blueprint Implementation Philosophy #4) — explicitly forbidden.
- **Estimated complexity**: not estimable without a schema.
- **Status**: BLOCKED — contingent, not on the critical path to production release of the scheduled scope.

### 2.8 Go-Live — Production Readiness & Release *(new — added by this document)*
Not present in the Blueprint because the Blueprint's scope ends at "Definition of Done" for Phases 1–6 (Blueprint §12). This document adds the release step needed to actually reach production, without adding any new business module.
- **Objective**: move the dashboard from "Phases 1–6 done in a non-production Supabase environment" to a live, company-usable production system.
- **Scope**: provision the real production Supabase project; run the full regression suite (Blueprint §10) against it; execute final per-phase Quality Gates (§6 below) cumulatively; retire any remaining interim access-provisioning arrangements; company-wide rollout communication and initial admin onboarding.
- **Deliverables**: production Supabase project live; all 73 scheduled pages deployed and verified against it; rollout/runbook notes.
- **Dependencies**: Phases 1–6 all individually complete (Blueprint DoD, §12) and all cumulative regression suites passing.
- **Completion criteria**: see §7 ("The entire project is complete") below.
- **Risks**: production RLS policy misconfiguration exposing cross-hotel data; production data-migration or seeding errors; premature go-live before Phase 6 security has fully replaced interim manual provisioning.
- **Estimated complexity**: Medium — mostly operational/verification work, not new feature development.
- **Status**: NOT STARTED — cannot start before Phase 6 completes.

**Phase 7 explicitly does not block Go-Live.** Production release of the scheduled scope (Phases 1–6) is complete and shippable on its own; Phase 7's modules were never part of the scheduled scope and remain a documented future extension (Blueprint §14 item 1: activation would create new Phases 8–11 after Go-Live, not before it).

---

## 3. Development Order

Exact, unambiguous sequence. Nothing below may be reordered without a documented Architecture/Blueprint amendment (§8).

```
Phase 0 (COMPLETE)
   │
   ▼
[Gate: Technical Assumptions §4 resolved — Supabase project provisioned, locale/RTL decided,
 interim Supabase-side user/hotel-access grant provisioned (Technical Assumption #2)]
   │
   ▼
Phase 1 — Foundation, Auth, Hotels
   │
   ▼ [Quality Gate §6]
Phase 2 — Core Financial Operations
   │
   ▼ [Quality Gate §6]
[Gate: Expenses schema-shape decision resolved — hard gate per Blueprint Technical Assumption #3]
   │
   ▼
Phase 3 — Operational Money Flow
   │
   ▼ [Quality Gate §6]
Phase 4 — People & Contracts
   │
   ▼ [Quality Gate §6]
Phase 5 — Cross-Cutting Intelligence  (reads Phases 1–4 only; cannot start earlier)
   │
   ▼ [Quality Gate §6]
Phase 6 — Administration & Security  (RBAC UI may start in parallel with late Phase 5 per Blueprint §5, but Users & Permissions is not "complete" until Phases 1–4 exist to scope permissions against)
   │
   ▼ [Quality Gate §6 + cumulative regression]
Go-Live — Production Readiness & Release
   │
   ▼
PRODUCTION (scheduled scope live)

Phase 7 (Documents / Vault / Settlements / Notes) — parked outside this sequence.
Reactivates only after: (a) a new Supabase migration phase is designed and approved,
and (b) for Vault/Settlements, the standing dedicated study is completed.
Not a prerequisite for, and not blocked by, Go-Live above.
```

**What MUST be built before anything else**: the Phase 1 shell + Supabase Auth + Hotels module. No other page in Phases 2–6 has a valid dependency path that skips Phase 1 (Blueprint §9's Component Dependency Map: Layer 1 shell components and Layer 3's Hotels data-access module are both Phase 1 deliverables that every later Layer 3/4 module and page builds on).

**Sequential vs. parallel**: Phases 1→2→3→4 are strictly sequential (Blueprint §5). Within Phase 5, Analytics/Search/Notifications/Audit have no dependency on each other and may be built in any order or in parallel, provided Phases 1–4 are already complete. Phase 6's non-auth administration pages (Master Data finalization, AI config, system settings) may start in parallel with Phase 5; Users & Permissions specifically waits for Phases 1–4's data to exist to scope permissions against.

---

## 4. Module Dependency Map

**Note on terminology**: this map uses **"Tier"**, not "Layer," specifically to avoid colliding with Blueprint §9's own "Component Dependency Map," which independently defines Layers 0–4 with different boundaries (e.g. Blueprint's Layer 3 is "per-entity data-access modules" as a generic architectural concept, cutting across all phases). The two schemes describe different things at different altitudes — this one groups *modules by phase-gated tier*, Blueprint's groups *code by architectural role*. Do not treat "Tier N" here and "Layer N" in Blueprint §9 as the same numbering.

```
Tier 0 — Platform (Phase 1, built once)
  Supabase Auth · Supabase client · Postgres (RLS-enforced)
       │
       ▼
Tier 1 — Shell & Foundational Module (Phase 1)
  App shell (nav/header/theme) · Auth session provider · HOTELS
  ── Hotels is the one module nearly every other table carries a foreign key to
     (Reference §5.1) — it is foundational, not optional, for every later phase.
       │
       ▼
Tier 2 — Shared interaction components (Phase 1, extended at first use in later phases)
  Confirm-dialog · Thousands-separator input · Data table · Attachment upload/viewer
  Category picker (Phase 2) · Entity pickers (Phase 3) · Chart wrapper (Phase 5)
  Debounced search (Phase 5) · Audit-log feed (Phase 1) · Role/permission components (Phase 6)
       │
       ▼
Tier 3 — Data-delivery modules (Phases 2–4, sequential, each phase-gated)
  Phase 2: Financial Reports, Financial Categories
  Phase 3: Expenses, Invoices, Suppliers            (gated on Expenses schema-shape decision)
  Phase 4: Employees & Payroll, Contracts, Contract Documents
       │
       ▼
Tier 4 — Cross-cutting, read-only (Phase 5 — depends on ALL of Tier 3, not just one module)
  Analytics Center · Search · Notifications (partial) · Audit Center (partial)
       │
       ▼
Tier 5 — Administration & Security (Phase 6 — depends on Tier 1's RBAC tables + Tier 3's data to scope against)
  Master Data finalization · AI/OCR config · System settings · Users & Permissions
       │
       ▼
Tier 6 — Production (Go-Live — depends on ALL of Tiers 1–5 complete)

Tier X — Blocked, parked outside the dependency chain (Phase 7)
  Documents (Unified) · Financial Center/Vault · Settlements · Notes
  ── Architecturally designed, but has NO cloud schema (Architecture §12 item 3) —
     cannot be placed in any tier above until a new migration phase exists.
     Does not block, and is not blocked by, Tiers 0–6.
```

**Foundational modules**: Hotels (Tier 1) and the RBAC schema (Tier 0/5 split — tables exist from Phase 1, UI/enforcement complete only in Phase 6). Nearly every other module's data model has a `hotel_id` foreign key (Reference §5.1); nothing in Tiers 3–5 is meaningfully usable without Hotels existing first.

**Modules that can be implemented independently of each other** (but not of earlier tiers): within Phase 3, Expenses/Invoices/Suppliers share only the Hotels/Categories dependency, not each other. Within Phase 4, Employees/Payroll and Contracts/Contract Documents are independent of each other, both depending only on Hotels. Within Phase 5, Analytics/Search/Notifications/Audit are mutually independent, read-only consumers of Tier 3's data.

**Modules that strictly require previous phases**: everything in Tier 4 (Phase 5) requires all of Tier 3 (Phases 2–4), not a subset — Analytics/Audit read across every prior module. Tier 5's Users & Permissions requires Tier 3's modules to exist so there is real data to scope role-based access against, even though its underlying RBAC tables are provisioned as early as Phase 1.

---

## 5. Milestones

| # | Milestone | Goal | Expected Output | Validation Requirements |
|---|---|---|---|---|
| M0 | Planning Complete | Ground truth, architecture, and execution order established and verified | Four governing documents, cross-verified | This document's existence and internal consistency (met) |
| M1 | Foundation Live | Dashboard shell + real auth + Hotels functional against a real (non-production) Supabase environment | 7 pages deployed to a non-prod environment | Blueprint §6.1 acceptance criteria; Quality Gate §6 |
| M2 | Daily Accounting Online | Financial Reports lifecycle fully operable company-wide | 8 pages; full draft→preview→post→lock cycle proven for ≥1 hotel, then rolled out | Blueprint §6.2 acceptance criteria; Quality Gate §6 |
| M3 | Money Flow Online | Expenses/Invoices/Suppliers fully operable | 18 pages; Expenses schema-shape decision resolved and reflected in the build | Blueprint §6.3 acceptance criteria; Quality Gate §6 |
| M4 | People & Contracts Online | HR/payroll and contract administration fully operable | 14 pages; all 10 `PayrollService` lifecycle actions functional | Blueprint §6.4 acceptance criteria; Quality Gate §6 |
| M5 | Cross-Hotel Intelligence Online | Analytics/Search/Notifications/Audit realize the dashboard's core value proposition | 18 pages; search covers every Phase 1–4-backed provider | Blueprint §6.5 acceptance criteria; Quality Gate §6 |
| M6 | Multi-User Security Live | Dashboard becomes genuinely per-user, per-hotel scoped; interim provisioning retired | 8 pages; RLS-enforced access verified across every prior phase's module | Blueprint §6.6 acceptance criteria; Quality Gate §6 |
| M7 | Production Release | Scheduled scope (Phases 1–6, 73 pages) live in production | Production Supabase project serving real dashboard users | §7 "entire project complete" criteria below |
| MF | Phase 7 Activation *(contingent, not dated)* | Documents/Vault/Settlements/Notes unblocked and scheduled as new numbered phases | New Supabase migration phase + Vault/Settlements dedicated study, both approved | A new Architecture/Blueprint amendment (§8) — out of this plan's current scope |

---

## 6. Quality Gates

Adopted directly from Blueprint §11, with two project-management additions (marked **NEW**). **No phase may proceed to the next until every item below holds for the completing phase:**

1. Every page listed for the completing phase (Blueprint §8) exists and meets that phase's acceptance criteria (§2 tables above / Blueprint §6.x).
2. Every mutating action across the phase's pages shows a confirm dialog; every money field uses thousands-separator formatting (Blueprint Implementation Principles §3; project standing rule — see `CLAUDE.md`, memory `feedback_number_format_and_confirmation_standards`).
3. No page reads/writes Supabase directly, bypassing its module's data-access layer (Blueprint §9, Layer 3/4 discipline).
4. Regression suite (Blueprint §10) passes for every prior phase, not just the one completing.
5. No Phase 7 (blocked) page has been built ahead of schedule.
6. Any phase-specific hard dependency (e.g., Phase 3's Expenses schema-shape decision, Phase 1's locale/RTL decision) is confirmed **resolved**, not merely "in progress."
7. The phase's status in the Architecture's Module Status Matrix is updated from "Architecture: complete" to "build: complete," keeping the Architecture and the running build from silently drifting apart.
8. **NEW — Documentation sync check**: this document's phase-status table (§2, §5) and the relevant module rows in `WEB_ADMIN_DASHBOARD_ARCHITECTURE.md`'s Module Status Matrix are updated in the same change set as the phase's completion — not as a follow-up task.
9. **NEW — No unresolved contradiction**: a search for the completing phase's module names across all three source documents turns up no unresolved contradiction between what was built and what was documented (i.e., a lightweight repeat of the Phase 0 verification pass, scoped to just the modules that shipped).

---

## 7. Definition of Done

- **A screen (page) is done** when: it matches its documented function set (Architecture §4, per module), passes its phase's acceptance criteria (Blueprint §6.x), has unit + component + integration test coverage (Blueprint §10), includes confirm-dialog and thousands-separator parity where applicable, and has passed manual testing against its test script (Blueprint §12).
- **A module is done** when: every page belonging to that module (Blueprint §8) is done, and the module's row in the Architecture's Module Status Matrix reads "build: complete."
- **A phase is done** when: every page in that phase is done, the phase's Quality Gate (§6 above) passes in full, and the regression suite covering all prior phases still passes.
- **The entire project is complete** (for the scheduled scope) when: all 73 scheduled pages (Phases 1–6) are done, Phase 6's security model has fully retired the Phase 1 interim manual-provisioning arrangement, every module's Architecture Module Status Matrix entry reads "build: complete" for everything except the four Phase 7 modules — which remain "blocked" **by design**, not as a defect — and the Go-Live phase's completion criteria (§2.8) are met in a real production Supabase environment. Phase 7's eventual activation, if and when it happens, is a separate future project stage (Blueprint §14 item 1), not a condition of "the entire project is complete" as scoped by this plan.

---

## 8. Change Management

All future feature requests are classified into exactly one of three tiers before any work starts:

| Tier | Definition | Examples | Process |
|---|---|---|---|
| **Minor enhancement** | Changes behavior *within* an already-documented page/module without adding a new page, table, or navigation entry | Adding a filter to an existing list page; adjusting a report's column set | Implement directly within the current phase's scope; update the relevant page's acceptance-criteria note in the Blueprint if the change alters "done" for that page; no Architecture change needed |
| **Major feature** | Adds a new page, a new navigation entry, or a new capability to an existing module, without touching the data model or module boundaries | A new "Supplier Debts" report view; a new dashboard widget | Requires an Architecture amendment first (new row in the relevant §4.x module table, new nav entry in §2) — **never implemented before the Architecture document is updated and reviewed** — then a corresponding Blueprint page entry is added in the correct phase |
| **Architecture change** | Adds a new module, changes the data model, merges/splits an existing system (especially FinancialEngine/Vault/Settlements), or changes phase sequencing | A new "Rooms/Maintenance" module; consolidating Vault and Settlements; changing which Supabase phase a module maps to | Requires the full Phase-0-style process: a dedicated study, explicit user decision, then updates to **all three** governing documents plus this plan — never inferred or improvised into the codebase (Blueprint Implementation Philosophy #1). Anything FinancialEngine/Vault/Settlements-adjacent additionally follows the project's standing rule: research history, present a study, wait for an explicit decision, never merge on initiative |

**Documentation must remain synchronized at every tier**: even a Minor enhancement that changes a page's acceptance criteria updates the Blueprint's page entry; a Major feature updates the Architecture *before* the Blueprint; an Architecture change updates the Reference (if it touches the mobile app), the Architecture, the Blueprint, and this plan's phase tables — in that order, since each document is the source of truth for a different layer (see Document Control table at the top of this document).

---

## 9. Documentation Maintenance

| When this changes... | ...update this document |
|---|---|
| Mobile app code (new table, new screen, new service) | `PROJECT_REFERENCE.md` first — it is the only document allowed to describe live mobile-app behavior |
| Dashboard module scope, navigation, or security model | `WEB_ADMIN_DASHBOARD_ARCHITECTURE.md` |
| Build order, page list, phase composition, shared components | `WEB_ADMIN_IMPLEMENTATION_BLUEPRINT.md` |
| Phase status, milestone completion, gate results, risk status | `MASTER_DEVELOPMENT_PLAN.md` (this document) — §2 status fields, §5 milestone table |
| A new Future Decision is made (Architecture "Future Decisions" list) | The Architecture document's Future Decisions entry is marked resolved; if it changes sequencing, this document's §3/§4 is updated too |
| A new risk materializes during implementation | This document's §10, and — if it was not already named in the Architecture or Blueprint's risk sections — added there too |

**Rule**: no document is edited in isolation when a change spans layers. A Major feature or Architecture change (§8) is not "started" until every document in the affected chain has been updated — this prevents exactly the kind of silent drift the Phase 0 verification pass had to catch and correct manually.

---

## 10. Risk Management

Consolidates Architecture's 12 documented risks and Blueprint's 6 execution-specific risks (Blueprint §13 item 1 confirms all 12 Architecture risks apply directly to execution), plus 3 project-management-level risks added by this document.

**Inherited from Architecture (Risks & Constraints §, full list of 12)**: no live backend today; four modules with zero cloud schema (Documents, Vault, Settlements, Notes); `hotel_audit_log` has no Supabase phase; Expenses Phase 3 schema mismatch vs. mobile's current engine; no real per-user login means historical audit rows can't show "who"; AI/OCR integration ownership undecided; Backup/Data-Info doesn't port 1:1 to cloud; "Health Index"/"Smart Analysis" are non-functional stubs; Sync has nothing to build against; Search/Audit/Notifications launch narrower than mobile; no accessibility precedent to extend; locale/RTL posture undecided.

**Inherited from Blueprint (execution-specific, §13 items 2–7)**: Auth/RLS sequencing gap if Phase 1 ships without a resourced interim-provisioning plan; Phase 3 start gated on the Expenses schema-shape decision; scope creep in Phase 5; stakeholder pressure to pre-build Phase 7; AI/OCR cost/security posture at company scale unresolved; late locale/RTL decision forcing shell rework.

**Added by this document (project-management level):**
1. **Decision latency risk.** Seven Future Decisions (Architecture) plus five Technical Assumptions (Blueprint §4) currently sit open. If any is left unresolved past the phase that depends on it, that phase stalls rather than proceeding on an assumption — per Blueprint Implementation Philosophy #1, nothing is inferred. *Mitigation*: track open decisions explicitly against the phase that needs them (§3's gate markers) and resolve them with enough lead time, not at the last responsible moment.
2. **Documentation drift risk.** Four governing documents must stay mutually consistent across a multi-phase, multi-session project. *Mitigation*: Quality Gate items 8–9 (§6) make documentation sync a hard phase-completion condition, not an optional follow-up; every future AI session re-verifies (§11) rather than trusting stale memory of prior state.
3. **Single-session context loss risk.** Because this project spans many separate AI sessions, a session could start work without reading the current phase status. *Mitigation*: §11's mandatory read-order makes this document the first read of every session specifically to prevent that.

---

## 11. AI Development Workflow

Every future AI session working on this project follows this exact sequence, with no exceptions:

1. **Read `MASTER_DEVELOPMENT_PLAN.md` first** (this document). It answers: what phase are we in, what already passed its Quality Gate, what is explicitly blocked, what decisions are still open. This is the entry point — it is read before any code is written or any other document is opened.
2. **Read `docs/PROJECT_REFERENCE.md`** for ground truth about anything the current task touches in the live mobile app. This document controls *facts* — if a claim elsewhere conflicts with what this document (or a fresh check of the actual source code) says, the code and this document win.
3. **Read `docs/WEB_ADMIN_DASHBOARD_ARCHITECTURE.md`** for the module's design: navigation placement, functions, permissions, relationships, cloud-schema mapping. This document controls *architecture* — no session invents a module boundary, page, or business rule not already stated here (Blueprint Implementation Philosophy #1).
4. **Read `docs/WEB_ADMIN_IMPLEMENTATION_BLUEPRINT.md`** for the exact page(s) in scope for the current phase, their dependencies, and their acceptance criteria. This document controls *execution* — the order and the "done" bar for whatever is being built right now.
5. **Confirm the current phase's gate conditions are met** (§3, §6 of this document) before writing anything. If a hard gate (e.g., Phase 3's Expenses schema-shape decision) is still open, that is escalated as a blocker, not worked around.
6. **Implement strictly within the current phase's scope.** No pulling forward a Phase 7 page, no "while we're in here" changes to a different phase's already-shipped logic (Blueprint §13 risk #4).
7. **On completion of a page/module/phase, update documentation per §9** in the same change set — never as a deferred follow-up.
8. **Update this document's status tracker (§2, §5)** so the next session's step 1 reflects reality.

This sequence is identical for every session, regardless of which specific page or module is being worked on — it is the project manager referred to in this document's objective.

---

## 12. Future Scalability

Scoped strictly to what the Architecture already named as designed-for or explicitly deferred — nothing new is proposed here.

- **New modules**: never added directly. Classified as an Architecture change (§8) — requires a new `§4.x` entry in the Architecture document (purpose, navigation, pages, functions, permissions, relationships, mobile-screen mapping, cloud-phase mapping) before any Blueprint phase references it.
- **New reports**: if built on an existing module's existing data (e.g., a new report inside Financial Reports or Invoices), this is a Major feature (§8) — a new page entry in that module's Architecture section and the corresponding Blueprint phase. If it requires new tables, it is an Architecture change.
- **New hotels**: already fully supported by the existing design — `hotels` is the foundational, unlimited-cardinality table both the mobile schema and the Supabase Phase 1 schema are built around (Reference §5.1; Architecture §4.1). No plan change needed; this is normal operational usage, not a development task.
- **New companies** (multi-tenant beyond the current single-company, multi-hotel model): **not designed anywhere in the current documents.** The Supabase RBAC model (`user_hotel_access`) scopes users to hotels within one company, not to multiple companies. This would be an Architecture change requiring a dedicated study before any implementation — flag explicitly to the user rather than assuming it fits the current schema.
- **New users**: fully designed already — Supabase Phase 1's `roles`/`permissions`/`role_permissions`/`profiles`/`user_hotel_access` (Architecture §11), built and delivered in Phase 6 of this plan. Adding a user post-launch is normal operation through the Phase 6 UI, not a development task.
- **Future cloud expansion**: Phase 7's four blocked modules (Documents, Vault, Settlements, Notes) are the next planned expansion, gated on a new Supabase migration phase plus (for Vault/Settlements) the standing dedicated study. Separately, wiring the *mobile app itself* into Supabase remains an independent, still-open decision (Architecture §12 item 2) that this plan does not require to be resolved for anything above — the dashboard was deliberately designed as an independent Supabase client precisely so that decision can stay open indefinitely without blocking dashboard delivery.

---

## Final Section — Readiness Assessment

| Score | Value | Basis |
|---|---|---|
| **Architecture Readiness Score** | **97 / 100** | 17 modules fully specified, every claim traced to the Reference, cloud-schema mapping complete and verified against live migrations, security model sound. Deduction: 12 risks and 7 future decisions remain genuinely open by design (correctly documented as open, not resolved — this is honest scoping, not a defect, but it does mean the architecture is not 100% decision-complete). |
| **Documentation Readiness Score** | **98 / 100** | All four governing documents exist, cross-verified against each other and against live source code (schema version, table counts, file counts, call-site counts all confirmed exact); two defects found during verification were corrected. Deduction: documentation maintenance (§9) is a process commitment, not yet proven across a real multi-phase execution cycle. |
| **Development Readiness Score** | **80 / 100** | The plan, sequencing, and acceptance criteria are unambiguous and ready to execute against. Deduction reflects genuinely open pre-Phase-1 prerequisites that are not yet resolved: Supabase project provisioning (Technical Assumption #1), dashboard locale/RTL decision (Technical Assumption #4), interim auth/RBAC provisioning resourcing (Technical Assumption #2) — Phase 1 cannot start until these are closed, and Phase 3 additionally requires the Expenses schema-shape decision (Technical Assumption #3) before it starts. |
| **Overall Project Readiness Score** | **90 / 100** | Weighted toward planning/documentation quality (which is very high) with an honest discount for the open prerequisites that gate the very first implementation step. |

**Is the project officially ready to begin implementation?**

**Yes, conditionally.** The architecture and execution plan are complete, internally consistent, and verified — there is no ambiguity about *what* to build or *in what order*. Phase 1 implementation should not start, however, until the Phase 1 gate conditions in §3 are explicitly closed: a real Supabase project provisioned, the dashboard locale/RTL decision made, and an interim access-provisioning plan resourced. None of these require redesigning anything already decided — they are operational/decision prerequisites, not open architecture questions. Once closed, Phase 1 may begin immediately under the workflow defined in §11.

---

*This document is a project-management artifact only. No code, schema, or migration was written. No business module was invented. Every phase, dependency, and criterion above traces to `PROJECT_REFERENCE.md`, `WEB_ADMIN_DASHBOARD_ARCHITECTURE.md`, or `WEB_ADMIN_IMPLEMENTATION_BLUEPRINT.md`; where this document adds structure not present in those three (Phase 0, the Go-Live phase, the consolidated risk/readiness sections), it is stated as new process scaffolding, not new product scope.*
