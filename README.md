# EpiWatch

EpiWatch is a healthcare data capture and antimicrobial-resistance (AMR) surveillance platform for India. It combines a cross-platform Flutter client with a FastAPI and PostgreSQL backend for clinical reporting, patient identity workflows, laboratory culture and AST entry, facility onboarding, and health-authority surveillance.

This repository is the Flutter rewrite of the original WPF client. The Flutter app is intentionally a thin client: authentication, authorization, patient matching, ABHA verification, facility scoping, clinical validation, and persistence are owned by the backend.

> Built for Smart India Hackathon by team SIH26_40 (Big Hero 6, HealthTech).

## Contents

- [Features](#features)
- [Architecture](#architecture)
- [Repository Layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running the Project](#running-the-project)
- [Demo Accounts](#demo-accounts)
- [Role-Based Workspaces](#role-based-workspaces)
- [Clinical and Surveillance Workflows](#clinical-and-surveillance-workflows)
- [API Surface](#api-surface)
- [Security and Privacy](#security-and-privacy)
- [Testing](#testing)
- [Supported Platforms](#supported-platforms)
- [Known Limitations](#known-limitations)
- [Development Notes](#development-notes)

## Features

### Clinical workflows

- Doctor dashboard with facility-level reporting metrics.
- Patient record search and history.
- Patient matching before creating a new identity.
- ABHA number checksum validation and optional ABDM verification.
- Patient report submission with fixed clinical vocabularies.
- Duplicate-patient conflict handling with candidate matches.

### Laboratory workflows

- Laboratory dashboard with culture and isolate counts.
- Culture worklist for pending and preliminary isolates.
- Culture and antimicrobial susceptibility testing (AST) entry.
- Isolate amendment and finalization workflow.
- Gram-negative antibiotic panels and resistance classification.
- Facility-scoped laboratory data access.

### Public-health surveillance

- Live statewide surveillance summary.
- District-level facility and case rollups.
- Daily disease trends.
- Facility and statewide surveillance metrics.
- Facility geospatial data for outbreak mapping.
- National statistics, geographic clusters, alerts, and disease trend screens in the Health Authority workspace.
- Read-through Redis caching with PostgreSQL fallback.

### Administration

- Facility access applications.
- Admin review and approval of applications.
- Provisioning of role-based accounts with one-time passwords.
- Mandatory password change for provisioned accounts.

## Architecture

```mermaid
flowchart LR
    Flutter[Flutter client\nWindows / Android / Web / iOS] -->|HTTP JSON + Bearer JWT| API[FastAPI API]
    API --> Auth[JWT auth\nArgon2 passwords\nrole checks]
    API --> DB[(PostgreSQL)]
    API -. optional cache .-> Redis[(Redis)]
    API -. optional graph sync .-> Neo4j[(Neo4j)]
    API -. optional verification .-> ABDM[ABDM v3\nmock or NHA sandbox]
    Raw[raw clinical tables] --> ETL[Surveillance ETL\nabout every 5 hours]
    ETL --> Analytics[analytics tables]
    Analytics --> API
```

### Client

The Flutter client uses:

- **Riverpod** `NotifierProvider` for authentication and screen state.
- **Dio** for HTTP requests and bearer-token injection.
- **Drift** and `drift_flutter` for local persistence support.
- **fl_chart** for clinical and surveillance charts.
- **flutter_map** with OpenStreetMap tiles for facility mapping.
- A role-to-workspace mapping in `app/lib/workspaces.dart`.
- An `IndexedStack` shell so switching tabs does not destroy loaded screens or in-progress forms.

The client distinguishes server refusals from transport failures:

- `ApiException`: an HTTP refusal that requires user action.
- `DuplicatePatientException`: a structured HTTP 409 patient conflict.
- `NetworkException`: offline, timeout, DNS, or other transport failure that may be retried.

### Backend

The FastAPI backend provides:

- SQLAlchemy models and PostgreSQL persistence.
- JWT access tokens using the authenticated database role for authorization.
- Argon2 password hashing.
- Facility-scoped clinical and laboratory routes.
- Read-only, all-facility surveillance routes for the `health_authority` role.
- Idempotent SQL/Python surveillance aggregation into `analytics.*` tables.
- Optional Redis caching and Neo4j graph synchronization.
- Optional ABDM integration with a local mock gateway for development.

## Repository Layout

```text
.
├── app/                         # Flutter application
│   ├── lib/
│   │   ├── models/              # API and UI data models
│   │   ├── screens/             # Doctor, lab, admin, and authority screens
│   │   ├── services/            # API client, catalogues, local services
│   │   ├── state/               # Riverpod state notifiers
│   │   ├── theme/               # Shared product theme tokens
│   │   └── workspaces.dart      # Role-to-navigation mapping
│   ├── test/                    # Flutter unit and widget tests
│   ├── android/                 # Android platform project
│   ├── ios/                     # iOS platform project
│   ├── web/                     # Web platform project
│   └── windows/                 # Windows platform project
├── backend/
│   ├── app/
│   │   ├── routers/             # FastAPI route modules
│   │   ├── services/             # ABHA, cache, crypto, graph, and domain services
│   │   ├── auth.py               # JWT and password operations
│   │   ├── db.py                 # SQLAlchemy engine and sessions
│   │   └── models.py             # Database models
│   ├── migrations/               # Ordered PostgreSQL migrations
│   ├── mock_abdm/                # Local ABDM-compatible development gateway
│   ├── scripts/                  # Seed, ETL, graph sync, and maintenance scripts
│   ├── tests/                    # Backend tests
│   └── requirements.txt
├── CLAUDE.md                     # Maintainer and architecture notes
└── README.md
```

## Prerequisites

Install the following before starting:

- Git
- Flutter SDK compatible with Dart SDK `3.12.2` or newer
- Python 3.11+ recommended
- PostgreSQL
- Android Studio and an emulator/device for Android development
- Visual Studio with the Desktop development with C++ workload for Windows builds
- Xcode and CocoaPods for iOS builds (macOS required)
- Redis is optional and used only to accelerate surveillance reads
- Neo4j is optional and used by graph synchronization

Check the main toolchain:

```powershell
flutter doctor
python --version
psql --version
```

## Installation

### 1. Clone the repository

```powershell
git clone <your-repository-url>
cd EpiWatchFlutter
```

### 2. Configure PostgreSQL

Create a database and user, then set a PostgreSQL connection string. For local development, a typical URL is:

```text
postgresql://epiwatch:your-password@localhost:5432/epiwatch
```

The migrations create the required schemas and tables. Run them from `backend/` after configuring the environment variables below.

### 3. Set up the backend

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Create `backend/.env`:

```dotenv
DATABASE_URL=postgresql://epiwatch:your-password@localhost:5432/epiwatch
JWT_SECRET=replace-with-a-long-random-secret
PGCRYPTO_KEY=replace-with-a-secret-key

# Optional: defaults to localhost Redis and degrades to PostgreSQL if unavailable.
REDIS_URL=redis://localhost:6379/0

# Optional Neo4j graph synchronization.
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=replace-with-your-neo4j-password

# Optional ABDM integration. Leave unset when using offline ABHA validation.
ABDM_BASE_URL=
ABDM_GATEWAY_URL=
ABDM_CLIENT_ID=
ABDM_CLIENT_SECRET=
ABDM_CM_ID=sbx
```

Do not commit `.env` files or real credentials.

Run migrations and seed demo data:

```powershell
python migrations\run_migrations.py
python -m scripts.seed
```

The migration runner is safe to re-run because applied migration filenames are recorded in `public.schema_migrations`.

### 4. Set up the Flutter client

Open a second terminal at the repository root:

```powershell
cd app
flutter pub get
```

The client defaults to:

- `http://127.0.0.1:8000` on Windows, Web, and iOS.
- `http://10.0.2.2:8000` on the Android emulator, which maps to the host machine.

For a physical Android device or a different backend host, pass a build-time configuration in the client or update `ApiClient.defaultBaseUrl` in `app/lib/services/api_client.dart`.

## Configuration

### Backend environment variables

| Variable | Required | Purpose |
|---|---:|---|
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `JWT_SECRET` | Yes | Signs and verifies access tokens |
| `PGCRYPTO_KEY` | Yes | Encrypts protected PII columns |
| `REDIS_URL` | No | Surveillance read cache; PostgreSQL remains the source of truth |
| `NEO4J_URI` | No | Neo4j connection for graph synchronization |
| `NEO4J_USER` | No | Neo4j username |
| `NEO4J_PASSWORD` | No | Neo4j password |
| `ABDM_BASE_URL` | No | ABDM profile API base URL |
| `ABDM_GATEWAY_URL` | No | ABDM gateway/session URL |
| `ABDM_CLIENT_ID` | No | ABDM client ID |
| `ABDM_CLIENT_SECRET` | No | ABDM client secret |
| `ABDM_CM_ID` | No | ABDM communication module ID, defaults to `sbx` |

### Local ABDM mock

The mock gateway reproduces the ABDM v3 session and ABHA verification shapes without requiring NHA sandbox credentials:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
uvicorn mock_abdm.server:app --port 8010
```

Configure the backend to use the mock URLs when needed. The mock includes two valid demonstration ABHA accounts and rejects missing tracing headers, invalid credentials, and unknown accounts.

## Running the Project

Start the backend:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --port 8000
```

Verify it:

```powershell
Invoke-WebRequest http://127.0.0.1:8000/health
```

Run the Flutter client in another terminal:

```powershell
cd app
flutter run -d windows
```

Other common targets:

```powershell
flutter devices
flutter run -d chrome
flutter run -d android
```

FastAPI's interactive API documentation is available at `http://127.0.0.1:8000/docs` while the backend is running.

Refresh surveillance aggregates manually:

```powershell
cd backend
python -m scripts.generate_surveillance_tables
```

Run the five-hour development loop:

```powershell
python -m scripts.generate_surveillance_tables --daemon
```

The daemon is a minimal in-process loop. Production deployments should use an operating-system scheduler or task queue when more scheduled jobs are introduced.

## Demo Accounts

All seeded demo accounts use the password `EpiWatch123!`:

| Email | Role | Workspace |
|---|---|---|
| `doctor@epiwatch.test` | `doctor` | Clinical reporting |
| `lab@epiwatch.test` | `lab` | Culture and AST |
| `health-authority@epiwatch.test` | `health_authority` | All-facility surveillance |
| `admin@epiwatch.test` | `admin` | Facility onboarding |

Change these credentials before using a non-development environment.

## Role-Based Workspaces

Authorization is enforced twice: the Flutter client chooses the available workspace, and the backend verifies the role from the database on every protected request. The JWT role claim is not trusted as the sole authorization source.

| Role | Access |
|---|---|
| Doctor | Dashboard, patient records, patient reports, ABHA and patient matching |
| Lab | Laboratory dashboard, culture worklist, isolates, AST results |
| Health Authority | Live statewide surveillance, disease trends, geographic clusters, national statistics, alerts |
| Admin | Facility applications and account provisioning |

Health Authority routes intentionally read across facilities. Doctor and lab clinical routes remain facility-scoped. Admin is not a backdoor into clinical or laboratory data.

## Clinical and Surveillance Workflows

### Patient report flow

1. The doctor searches existing patient records or submits identity fields for matching.
2. The backend evaluates candidate matches and facility scope.
3. ABHA is validated offline using its checksum; ABDM verification is attempted only when configured and reachable.
4. The report is persisted in PostgreSQL.
5. A duplicate match returns a structured `409` response so the clinician can resolve it rather than retrying indefinitely.

### Laboratory flow

1. A lab user opens the facility worklist.
2. The user records a culture and AST result using the fixed clinical catalogue.
3. New isolates default to `preliminary` status.
4. The lab can amend or finalize an isolate through the isolate endpoint.
5. Resistance metrics are derived from the normalized antibiotic and AST data.

### Surveillance flow

1. Clinical and laboratory data is stored in `raw.*` tables.
2. `scripts.generate_surveillance_tables` aggregates recent data into `analytics.*` tables.
3. Health Authority endpoints query those analytics tables, with Redis used as a best-effort cache.
4. The live surveillance summary reads selected raw report counts directly so its headline values do not wait for the ETL refresh.

Clinical vocabulary is deliberately fixed-list and aligned with WHO GLASS, ICMR-AMRSN, and ACORN concepts. This keeps data comparable across facilities.

## API Surface

The backend exposes OpenAPI documentation at `/docs`. The main route groups are:

| Prefix | Purpose |
|---|---|
| `/auth` | Login, logout, password change |
| `/reports` | Clinical report creation and listing |
| `/patients` | Search, matching, history, ABHA verification |
| `/dashboard` | Doctor and lab dashboard summaries |
| `/lab` | Isolate creation, amendment, worklist, AST data |
| `/applications` | Facility onboarding and admin approval |
| `/surveillance` | Health Authority statewide analytics and map data |
| `/health` | Service health check |

All protected API calls use an HTTP bearer access token:

```http
Authorization: Bearer <access-token>
```

## Security and Privacy

- Passwords are hashed with Argon2; plaintext passwords are not stored.
- Access tokens are signed JWTs with a server-side secret.
- Role checks use the current database user row, preventing a stale JWT role from retaining access after a role change.
- Clinical routes use the authenticated user's facility rather than accepting arbitrary facility scope from the client.
- Protected PII columns use the configured `PGCRYPTO_KEY` encryption key.
- ABHA checksum validation can run offline, allowing the clinical workflow to degrade gracefully when ABDM is unavailable.
- Redis is an optimization only. A cache outage falls back to PostgreSQL.
- Development credentials and mock ABDM values must never be used in production.

This project handles health information. A production deployment requires a formal security review, secrets management, TLS, database access controls, audit logging, backups, retention policies, and compliance review appropriate to the deployment environment.

## Testing

### Flutter

```powershell
cd app
flutter analyze
flutter test
```

The Flutter tests cover authentication, API error classification, role-based routing, patient matching and duplicate handling, ABHA verification, AST validation, dashboards, and reporting flows.

### Backend

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
pytest
```

Backend integration tests that exercise PostgreSQL require a configured `DATABASE_URL` and an available database with the required schema. Keep test databases separate from development data.

### Health check

```powershell
Invoke-WebRequest http://127.0.0.1:8000/health
```

Expected response:

```json
{"status":"ok"}
```

## Supported Platforms

| Platform | Status |
|---|---|
| Windows | Verified to build, launch, and remain responsive |
| Web | Flutter web target is included; verify against the running backend |
| Android | Builds, but device/emulator runtime verification is still required |
| iOS | Platform scaffolding exists; building requires macOS and Xcode and has not been verified on Windows |

## Known Limitations

- The machine-learning surveillance layer is not implemented yet. Planned work includes EWMA/CUSUM detection, Isolation Forest, resistance classification, spatial scan statistics, antibiograms, and forecasting.
- There is no email or password-reset-link infrastructure. Admin-provisioned accounts receive a one-time password and must change it after first login.
- ABDM production access requires National Health Authority registration and credentials. The included mock gateway is for development and testing.
- The surveillance ETL currently runs manually or through its minimal five-hour daemon; no production scheduler is included.
- Backdating reports and laboratory tests is not supported by the current API contract; submit-time dates default to today.
- Android and iOS require platform-specific verification before production claims can be made.

## Development Notes

- Keep business rules in the backend; do not duplicate clinical or authorization logic in Flutter.
- Preserve the distinction between `ApiException` and `NetworkException`.
- Extend fixed clinical catalogues deliberately so aggregation remains reliable.
- If changing backend behavior, remember that the backend was copied from the WPF repository while both clients remain in use. See `CLAUDE.md` for repository history and maintainer conventions.
- Run the app after changes affecting startup, theme, or navigation; a successful build alone is not sufficient validation.

## License

No license has been declared in this repository yet. Add a license before distributing or accepting external contributions.
