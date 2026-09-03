# MASTER PROMPT — Placement Connect Web (React + Supabase)

Single, self-contained implementation brief for the web version of Placement Connect. Same product, same backend model, same design system as the Flutter app — different client. Paste this whole document as your first message to the coding agent.

---

## 0. What this is relative to the Flutter app

This is not a new product. It's the same Placement Connect — same roles, same workflow, same business rules, same Supabase schema, same visual identity (brass/paper-grey/true-black, Fraunces/Inter/IBM Plex Mono, the status-thread signature element) — rebuilt as a responsive web app instead of a Flutter mobile app.

If the Supabase project from the Flutter build already exists, this app points at the **same project** — same tables, same RLS, same auth users. Do not create a second schema or a parallel set of tables. If it doesn't exist yet, build the schema fresh using section 3 below (identical to the Flutter master prompt's schema).

One new thing this version adds that the Flutter app didn't: a dedicated **AI Features** area, stubbed as "coming soon" for this pass — see section 8. Don't build the AI functionality itself yet, just the placeholder and the reserved navigation slot.

---

## 1. Role hierarchy (authoritative — unchanged from the mobile app)

| Role | Appointed by | Appoints | Approves | Sees |
|---|---|---|---|---|
| Admin | — | TPO | — | NAAC/NBA institution-wide reports |
| TPO | Admin | Faculty Coordinators (dept-wise) | — | All drives, all departments' stats, attendance |
| Faculty Coordinator | TPO (exactly 1 per department) | — | Students, on first login (dept-scoped) | Own department's placement history + drive attendance |
| Student | — (self-registers) | — | — | Own applications, eligible drives |

- **Admin** appoints TPO only; institution-wide NAAC/NBA reporting is the only other function.
- **TPO** appoints Faculty Coordinators (one per department), owns the full drive lifecycle end to end, sees all departments.
- **Faculty Coordinator** approves/rejects students on first login, department-scoped only, optional interview feedback.
- **Student** self-registers, blocked from applying until approved, opts in/out, applies, tracks status, accepts/declines offers.

## 2. End-to-end workflow (unchanged)

1. Admin sets up the academic cycle and appoints TPO.
2. TPO appoints one Faculty Coordinator per department.
3. Student registers, completes profile — account starts `pending`.
4. Faculty Coordinator approves or rejects, with reason if rejected.
5. Student completes consent/opt-in, or opts out with a reason.
6. TPO onboards a company and creates a drive — role, CTC, eligibility, rounds, deadline.
7. Student views eligible drives (approved + opted-in + eligible only) and applies.
8. TPO schedules rounds and updates each student's status per round.
9. Faculty (optional, if on panel) submits round-level feedback.
10. TPO uploads offers; student accepts or declines.
11. TPO sees everything; Faculty sees own department; Admin pulls institution-wide rollups.

## 3. Non-negotiable business rules (unchanged)

- Students with `approval_status != 'approved'` are blocked from applying — enforced at the RLS layer, not just hidden in the UI. The Apply button must be disabled and show a "pending approval" state, never just absent.
- Exactly one Faculty Coordinator per department — check for an existing coordinator before appointing; offer reassignment, never allow a duplicate.
- Opted-out students never appear in any eligible-list, applicant view, or attendance stat.
- Faculty Coordinator access is department-scoped everywhere. Admin owns cross-department reporting.
- Only TPO transitions application/round status. Faculty feedback informs TPO's decision; it doesn't itself change status.

## 4. Database schema (Supabase / Postgres — identical to the Flutter build)

Reuse verbatim: enums (`user_role`, `approval_status`, `drive_status`, `application_status`, `consent_status`), tables (`profiles`, `faculty_coordinators`, `tpo_appointments`, `academic_cycles`, `companies`, `drives`, `drive_eligibility_exceptions`, `drive_rounds`, `applications`, `application_round_status`, `interview_feedback`, `offers`, `notices`, `student_queries`, `audit_logs`), the two reporting views (`department_placement_stats`, `drive_stats`, both `security_invoker = true`), the RLS policy summary, and both triggers (`set_updated_at`, `guard_student_self_update`).

Do not redesign this schema for the web client. A shared backend across mobile and web is the entire point — if the web app needs a column or table the schema doesn't have, stop and ask before adding it, rather than quietly extending the schema in a way the Flutter app doesn't know about.

## 5. Tech stack

- **React** (latest stable), Vite for tooling — not Create React App.
- **TypeScript**, strict mode. No `any` escape hatches without a comment explaining why.
- **Supabase JS client** (`@supabase/supabase-js`) — same project URL/anon key as the Flutter app, provided via environment variables, never hardcoded.
- **Routing**: React Router, with auth guards and role guards mirroring go_router's setup in the Flutter app — same route-protection logic, different router library.
- **State/data**: TanStack Query (React Query) for server state (Supabase reads/writes, caching, refetching), plain React state/context for local UI state. No Redux — this app's state shape doesn't need it.
- **Styling**: Tailwind CSS, with the design tokens from `design.md` wired in as CSS variables / a Tailwind theme extension — not Tailwind's default palette left untouched.
- **Forms**: React Hook Form + Zod for validation — schemas shared conceptually with the business rules in section 3 (e.g. a drive's CGPA cutoff, a student's backlog count).
- **Component primitives**: shadcn/ui (Radix-based, unstyled-by-default) as the base, then themed to match `design.md` — don't ship shadcn's default look unstyled.
- **Realtime**: Supabase Realtime subscriptions for live application-status updates, matching the mobile app's Realtime usage.
- **File uploads**: Supabase Storage, same buckets and access policies as the Flutter app (resumes, offer letters, photos, ID proofs).
- **Auth**: Supabase Auth, same provider setup as the mobile app —
  - Students: Microsoft OAuth (college email domain).
  - Faculty: Google OAuth.
  - TPO and Admin: email/password + email OTP verification, same policy as the Flutter build.
  - Session handled via Supabase's browser client session persistence; no custom token storage.
- **Exports**: CSV via a small client-side library (e.g. `papaparse` for parsing, plain string building for export), XLSX via `SheetJS`, PDF via a library capable of running in-browser (e.g. `pdf-lib` or a server-side Edge Function if generation gets complex) — flag which approach before building if it's ambiguous.
- **Testing**: Vitest + React Testing Library for unit/component tests, Playwright for e2e flows (login → apply → status update → offer accept, per role).

## 6. Architecture

Feature-first folders, same philosophy as the Flutter app: `features/<domain>/{components,hooks,api,types}`. A `lib/supabase` client singleton, a `lib/queries` or per-feature `api.ts` layer that wraps every Supabase call — **components never call `supabase.from(...)` directly**, they call a hook that calls the API layer. This mirrors the Flutter app's repository pattern and keeps the same separation of concerns.

No business logic in components. Validation and business rules live in shared schema/service files, not scattered across form components.

## 7. Implementation scope for this pass

Same module breakdown as the Flutter master prompt, adapted to web — plus one module the mobile app never needed: a public landing page, since a website (unlike an installed app) needs something to show a visitor who isn't logged in yet.

### A. Public landing page (new — web only)

This is the one screen with no equivalent in the Flutter app. It's the first thing anyone hits at the root domain before auth, and it needs to read as a real product's marketing site, not a placeholder in front of the dashboard.

- **Route**: `/` when signed out; signed-in users hitting `/` redirect straight to their role's dashboard — the landing page is never shown to an authenticated session.
- **Sections**: hero (product name, one-line value proposition, primary CTA into sign-in, secondary CTA to scroll to "How it works"), a short "How it works" walkthrough pinned to the real four-role workflow from section 2 (not generic SaaS filler — student applies, faculty approves, TPO runs the drive, admin reports), a feature-highlight section built around the actual signature elements (the status thread, role-scoped dashboards, real-time status updates), a role-based sign-in entry point (Student / Faculty / TPO / Admin, matching the role-segmented login the Flutter app already uses), and a footer (contact/support, not a fabricated list of links to pages that don't exist).
- **Content honesty**: no invented testimonials, no fake logos of companies "using" the platform, no placeholder stats ("500+ students placed!") unless real numbers are supplied — use descriptive copy about what the product does instead of unverifiable social proof.
- **Design**: same token system as the rest of the app (`design.md` — brass/paper-grey/true-black, Fraunces for the hero headline, Inter for body, the status thread rendered as a live-looking illustrative example in the feature section) — a visitor should recognize the same product the moment they log in, not land somewhere that looks like a different brand's marketing site bolted onto the app.
- **Performance/SEO**: this is the one route where SEO plausibly matters (a logged-out page meant to be found and shared) — semantic HTML, a real `<title>`/meta description, and reasonably fast initial load. If section 11's SSR question resolves toward Next.js, this page is the primary reason why; if it resolves toward a plain SPA, keep this route's bundle lean regardless (no heavy chart libraries or admin-only dependencies loaded before login).
- **No auth-gated content leaks here**: nothing on this route should query Supabase for anything role-specific — it's static/public content plus the sign-in entry point, nothing else.

### B. Auth & profile bootstrap
- Login/signup pages per the auth flow in section 5, reached from the landing page's sign-in CTA.
- Post-login routing by `profiles.role` to the correct module shell.
- Pending-approval gate for students (browse-only, no Apply actions) — same rule as mobile, enforced by RLS not just route guards.

### C. Admin module
- Appoint TPO, academic cycle CRUD, NAAC/NBA report screen (query the two views, export PDF/XLSX).

### D. TPO module
- Appoint Faculty Coordinator (block duplicates), companies CRUD, drive creation + eligibility + exceptions, round scheduling, applicant list with bulk/CSV shortlist upload, offer upload, all-department dashboard.

### E. Faculty Coordinator module
- Pending-approval queue (approve/reject with reason), department placement history, drive attendance view, optional interview feedback form.

### F. Student module
- Multi-step profile setup, consent/opt-in form, eligible drives list, apply form (blocked if not approved), My Applications tracker, offer accept/decline, grievance/query form, settings.

### G. Shared/cross-cutting
- Notices/announcements (read for all, write for TPO/Admin).
- Global search across companies, students, drives — debounced, paginated.
- Notification center — in-app, backed by Supabase Realtime (web push/FCM is a mobile-only concern, skip it here unless later specified).

## 8. AI Features — stub only, this pass

Add a top-level "AI Features" entry to the navigation (visible to all roles, or scoped to which roles — confirm before assuming all four), pointing at a dedicated route (`/ai` or similar). This screen is a **placeholder only**:

- On-brand "Coming soon" state: use the same empty/error-state visual language as the rest of the app (icon, one-sentence description, no functional controls), not a bare "Coming Soon" text dump.
- Copy should describe what's coming in outline, without overpromising specifics that aren't decided yet — something like "AI-assisted resume feedback, drive matching, and interview prep are on the way" is fine as placeholder copy if it matches the eventual plan; otherwise keep it generic ("AI-powered tools for your placement season are on the way").
- No backend work for this pass: no AI API keys, no edge functions, no schema changes for AI features. When the real AI feature set is scoped later, it gets its own master prompt — don't pre-build infrastructure for a spec that doesn't exist yet.
- The nav slot and route should be built so that swapping the placeholder for the real feature later is a content change, not a navigation restructure.

## 9. Design system — reuse `design.md` and the HTML reference files directly

- Color, type, spacing, radius, elevation, motion values: identical to `design.md` and `placement_connect_premium_final.html`, translated into Tailwind config / CSS variables instead of Flutter `ThemeExtension`s. Same hex values, same three themes (System / Light / True-black), same brass-as-semantic-signal rule (brass = verified/offer, not just "the accent").
- The status thread is the signature component here too — build it once as a shared React component (`<StatusThread stages={[...]} currentIndex={n} />`), used identically across the student application card, the full timeline view, and the TPO round tracker, same as the Flutter widget.
- Desktop and tablet breakpoints matter more here than on mobile — the true-black theme needs a specific check at wide desktop widths, since large flat black areas expose layout issues a phone screen hides. A left-rail nav (per `design.md`'s layout plan) is the desktop-appropriate pattern; collapse to the floating bottom-pill nav from the mobile reference only below a tablet breakpoint if you want visual continuity with the app — otherwise a standard responsive top-nav/sidebar collapse is fine. Confirm which before building if it's ambiguous.
- Corner language, shadow/elevation steps, and motion durations from `master_prompt_3_polish_final.md` apply here too — same numbers, CSS instead of Dart.

## 10. What's explicitly out of scope for this pass

- The real AI feature set (see section 8) — placeholder only.
- Native mobile concerns that don't translate to web: predictive back gesture, edge-to-edge system bars, FCM push notifications. Skip these; use browser-appropriate equivalents where an equivalent genuinely exists (e.g. browser notifications) and skip where it doesn't.
- Anything not already covered by the Flutter app's schema and business rules — if the web app needs new functionality the mobile app doesn't have (beyond the AI stub), stop and ask before building it.

## 11. Open items to confirm before coding starts

- Is this pointing at the same Supabase project as the existing Flutter app, or a fresh one?
- Next.js vs. plain Vite SPA — the stack above assumes a client-rendered SPA; say so if server-side rendering / SEO matters for any part of this (e.g. a public-facing marketing/landing page before login).
- Which roles see the AI Features nav entry — all four, or a subset?
- PDF export approach for Admin/TPO reports (client-side vs. Edge Function) — flagged in section 5, needs a decision before that piece is built.
- Whether web push notifications are wanted at all for this pass, given FCM was mobile-specific in the original scope.
- Landing page content: any real numbers/stats to feature (placements made, companies visited, etc.), or should copy stay descriptive with no claimed metrics until real data exists? Also confirm the institution's name/branding details if the page should identify which college this is for.

---

## Before you call any module done

Same bar as the Flutter app: compiles/builds clean, no TODOs, no placeholder services (the AI stub is the one deliberate exception, and only because it was explicitly scoped as a stub), talks to real Supabase, RLS-respecting queries only, errors handled with the same "what happened / what to do" voice as the design system specifies, covered by tests.

## The one rule that overrides speed

Missing a credential, a config value, or a clear answer to something ambiguous — ask. Don't guess, don't invent a placeholder that looks like it works, and don't quietly diverge from the Flutter app's schema or business rules to make a screen easier to build.
