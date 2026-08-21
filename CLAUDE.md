# EpiWatch (Flutter)

Windows/Android/web/iOS EHR + antimicrobial-resistance (AMR) surveillance app
for India, built for Smart India Hackathon (team SIH26_40, "Big Hero 6",
HealthTech). This is the Flutter rewrite of a WPF client; see
[FORK_PROVENANCE.md](FORK_PROVENANCE.md) for where it forked from and why the
backend is duplicated here.

## Layout

```
app/         Flutter client (windows + android + web + ios from one codebase)
backend/     FastAPI + PostgreSQL, copied verbatim from the WPF repo
```

The client is a thin client. All clinical logic, patient matching, ABHA
verification, and role enforcement live server-side in `backend/`. Nothing
in `app/` should duplicate business logic the backend already owns.

## Repo history the user cares about

- Commit as **Vroom101 <ishi.forever2@gmail.com>** — no Claude co-author
  trailer, no AI-authorship mentions in commit messages. The user does not
  want AI attribution on their GitHub.
- The old WPF client lives at `C:/Users/avane/Desktop/EpiWatch` (sibling
  folder). It is **not retired** — it stays as the demo fallback until this
  Flutter app is trusted. Do not delete or modify it from here.
- `backend/` in this repo was copied from WPF-repo commit `fcdf283` (git-
  tracked files only — no `.env`, no `.venv`, no logs). Until the WPF client
  stops receiving backend changes, a backend fix made in one repo should be
  mirrored to the other, or ask the user which one is now canonical.
- Postgres runs locally; the DB password lives in `backend/.env`
  (gitignored, not committed, copy from the WPF repo's `backend/.env` if
  missing — same DB).
- Seed accounts: `doctor@epiwatch.test` / `EpiWatch123!` (role `doctor`),
  `lab@epiwatch.test` / `EpiWatch123!` (role `lab`). Run
  `python -m scripts.seed` from `backend/` (inside its venv) if missing.

## What's built (verified, not just compiled)

All 6 screens are live against the real backend, not placeholders:

| Doctor | Lab |
|---|---|
| Dashboard | Lab Dashboard (pathogen + S/I/R charts) |
| Patient Records | Culture Worklist |
| Submit Report | Culture & AST entry |

- `flutter analyze` clean, `flutter test` passing (49 tests as of the last
  session — patient matching/duplicate flow, ABHA verify, AST panel
  validation, role-based workspace routing, API error classification).
- Windows build launches and stays responsive. Android compiles but is
  **unverified** — no device/emulator was ever attached in this session.
  Don't claim Android works without actually running it on a device.
- iOS platform scaffolding (`app/ios/`) exists but is **entirely
  unverified** — added via `flutter create --platforms=ios .` from a
  Windows machine, which cannot run `pod install`, build, or launch an iOS
  target (needs a Mac with Xcode). Don't claim iOS works, or even
  compiles, until someone actually builds it on macOS.

## Architecture decisions (don't relitigate without a reason)

- **State management: Riverpod** (`NotifierProvider`/`Notifier`), not Bloc
  or plain `setState`. Maps onto the WPF ViewModels' `ObservableProperty`/
  `RelayCommand` pattern. Every screen with async loading follows
  `lib/state/dashboard.dart`'s shape: a state class with `isBusy`/`error`,
  a `Notifier` that does one `load()`.
- **Error handling: `ApiException` vs `NetworkException` are deliberately
  distinct types** (`lib/services/api_exceptions.dart`). This exists
  because the WPF client had a real bug: a 409 duplicate-patient response
  got caught as a network error and queued for infinite retry. Only
  `NetworkException` (transport failure — offline, timeout, DNS) is safe to
  retry/queue. `ApiException` (including `DuplicatePatientException`) is a
  refusal the user must act on. **Never collapse these back into one type.**
- **Shell doesn't know its own destinations**
  (`lib/screens/shell_screen.dart` + `lib/workspaces.dart`). It renders
  whatever `NavDestination` list it's handed; role → destination-list
  mapping lives in `workspaces.dart` only. This exists because the WPF
  client's shell hardcoded 3 doctor destinations, so a lab user with a
  correctly-issued `role=lab` token still saw the doctor UI. There's a
  regression test for this (`test/widget_test.dart`): a lab session must
  never render "Patient Records" or "Submit Report".
- **`IndexedStack` for tab content**, not rebuild-on-navigate — so a
  loaded dashboard or an in-progress form isn't destroyed by switching
  tabs and back.
- **Theme tokens copied verbatim** from the WPF `Colors.xaml`
  (`lib/theme/app_colors.dart`) so the two clients read as one product
  while WPF is still around. Don't invent new colors; extend this file
  from the same design system if you need one.
- **Clinical vocabulary is fixed-list, not free text**
  (`lib/services/clinical_catalog.dart`): WHO GLASS specimen types/AST
  categories/age strata, ICMR-AMRSN priority pathogens, ACORN
  syndrome/origin/outcome. This is what makes cross-facility aggregation
  possible. Don't add free-text alternatives to these fields without
  discussing it — "E. coli" vs "E.coli" vs "Escherichia coli" typed
  freehand cannot be counted together.
- **`ClinicalCatalog.antibioticToClass` must cover every drug in
  `gramNegativePanel`.** The WPF client shipped with Cefepime missing from
  this map (silently under-counted MDR isolates). Verified absent here,
  and there's a regression test for it — keep it passing if you touch
  either list.

## Known deviations from the WPF client (intentional, not oversights)

- District field: Flutter `Autocomplete` instead of an editable ComboBox
  (free text still allowed).
- Date of birth: `showDatePicker` instead of a WPF DatePicker.
- Submit Report's `reportDate` and lab `testDate` are fixed to "today" at
  submit time, not user-editable — matches the current `ReportCreateRequest`
  contract. If backdating a report turns out to matter, that's a small
  follow-up, not a redo.
- New isolate submissions default to `status: "preliminary"` (the
  backend's documented default), not `"final"` like the old WPF client.

## Not built yet

The ML/analytics surveillance engine (EWMA/CUSUM detection, Isolation
Forest, resistance classifier, spatial scan, antibiogram, forecasting) is
**entirely unstarted** in both this repo and the WPF one. It's backend-only
work and does not depend on which client exists. The user is building the
calibrated synthetic training dataset separately and will resume this once
that's ready — don't start it unprompted.

## Working style for this project

- The user explicitly asked for full client parity before touching ML —
  that's done. Next request will likely be either ML/analytics work or
  Android verification (needs an emulator/device attached).
- A green build has lied before in this project (a WPF resource-key
  collision passed `dotnet build` with 0 errors but crashed on launch).
  **Always launch the app and confirm the window opens and stays
  responsive** after a change that touches startup, theme, or navigation —
  don't stop at `flutter analyze`/`flutter test` passing.
- When work splits across independent screens/files, parallel background
  agents with fully-specified, non-overlapping-file briefs worked well
  here (doctor screens vs lab screens, zero merge conflicts). Re-verify
  their combined output yourself before committing — don't just concatenate
  two "all green" reports.
