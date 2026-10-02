# Fudo Koma backend — Phase 1

## 1. Overview and scope

This Python backend serves the Flutter application. The initial foundation implements configuration, asynchronous MySQL persistence, migrations, Redis connectivity, health/readiness, Docker development, and tests. The current local integration adds cart/user/follow/notification REST endpoints for the Flutter prototype.

**Production API authentication and authorization are pending:** the prototype API endpoints do not verify Firebase tokens. The `/admin` dashboard has a separate environment-configured login for local development only and is disabled in production. Do not expose either surface publicly. Nearby SQL searches, production Compose/Caddy, and Hostinger deployment also remain future work.

Stack: Python 3.12+, FastAPI, SQLAlchemy 2.x, asyncmy, MySQL 8.4, Alembic, Pydantic v2/pydantic-settings, Redis, pytest, Docker. Firebase Admin, Jinja2 and form/session dependencies are included for subsequent phases.

```text
Flutter application --- REST API (local prototype)
        |
        v
FastAPI REST API -------- Jinja admin dashboard (local development)
        |
    +---+---+
    |       |
  MySQL   Redis
```

Flutter now loads carts, registers a fixed local prototype user, and persists follow/status/moderation changes through this API. Endpoints include `GET/POST /api/v1/carts`, `PATCH /api/v1/carts/{id}`, user create/list/update, follows, and notifications. Cart follower counts and follow state are query-derived. The app configures the API using `--dart-define=API_BASE_URL=...`; Android emulators use `http://10.0.2.2:18000`. Flutter models use camelCase while the API/database use snake_case. Location labels and featured state are not stored, and server-generated UUIDs replace the old demo IDs. Firebase UID remains separate from the local UUID.

## 2. Prerequisites

Install Git, Python 3.12 or newer, VS Code with the Python extension, and Docker with Compose v2 (Docker Desktop on Windows). A MySQL client is optional. Firebase project setup is required in Phase 2.

```sh
python --version
docker --version
docker compose version
git --version
```

Python 3.8 is unsupported. Use Mode B if the host Python is too old.

## 3. Clone/open the project

```sh
git clone https://github.com/Mehedee-Hassan/fudo-koma.git
cd fudo-koma
code .
cd backend
```

All following commands run from backend/, unless stated otherwise.

## 4. Python virtual environment — Mode A

Linux/macOS:
```sh
python3 -m venv .venv
source .venv/bin/activate
```

Windows PowerShell:
```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
```

Windows CMD:
```bat
python -m venv .venv
.venv\Scripts\activate.bat
```

In VS Code run **Python: Select Interpreter**, select backend/.venv, then open a new terminal. Check python --version again.

## 5. Install dependencies

```sh
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Requirements constrain compatible major versions. The initial development manifest is not an exact reproducible lock; freeze/review resolved versions before production release. Ordinary tests do not need Firebase credentials.

## 6. Environment setup

Linux/macOS:
```sh
cp .env.example .env
```

PowerShell:
```powershell
Copy-Item .env.example .env
```

Edit .env. Example passwords are development-only placeholders; replace them. .env is ignored by Git and excluded from Docker images.

| Variable | Purpose |
|---|---|
| APP_ENV | development, test or production; production enables configuration guards |
| APP_NAME | API documentation title |
| DEBUG | Debug responses/logging; false in production |
| API_V1_PREFIX | API prefix, defaults to /api/v1; starts with / and has no trailing / |
| MYSQL_HOST | 127.0.0.1 for host Python; Compose overrides to mysql |
| MYSQL_PORT | Host MySQL port; Compose API uses internal 3306 |
| MYSQL_DATABASE | Database created on first volume initialization |
| MYSQL_USER | Application database user created on first initialization |
| MYSQL_PASSWORD | Application DB password; required by Compose |
| MYSQL_ROOT_PASSWORD | MySQL initialization/admin password; not used by API |
| DATABASE_URL | Optional mysql+asyncmy URL overriding separate MySQL values; percent-encode credentials in URLs |
| DB_POOL_SIZE | Per-process persistent connection pool size, default 10 |
| DB_MAX_OVERFLOW | Per-process extra connections, default 10 |
| REDIS_URL | Redis connection URL; Compose API overrides to redis://redis:6379/0 |
| API_BIND_ADDRESS | Docker API bind address, defaults to loopback; use 0.0.0.0 only for a trusted physical-device test network |
| API_PORT | Optional Docker API host port, defaults to 18000; internal port stays 8000 |
| REDIS_PORT | Optional host Redis port, defaults to 6379; no effect on internal port |
| FIREBASE_PROJECT_ID | Firebase project, reserved for Phase 2 |
| FIREBASE_CREDENTIALS_PATH | Service-account file path, reserved for Phase 2 |
| ADMIN_SESSION_SECRET | Signs the admin session cookie; use a random value of at least 32 characters |
| ADMIN_USERNAME | Username for the local web admin dashboard; leave unset to disable login |
| ADMIN_PASSWORD | Password for the local web admin dashboard; leave unset to disable login |
| CORS_ORIGINS | JSON array of permitted browser origins including scheme/port; no wildcard in production |
| TRUSTED_HOSTS | JSON array of allowed hostnames; no wildcard/empty list in production |
| DOCS_ENABLED | Enables /docs, /redoc and /openapi.json; consider false in production |

Settings load .env relative to the working directory. Use backend/ as the working directory. Never put passwords in source code. Separate DB fields safely handle special characters without manual URL construction.

To enable the local dashboard login, set `ADMIN_USERNAME` and `ADMIN_PASSWORD`
in `.env`, and generate a unique `ADMIN_SESSION_SECRET` of at least 32
characters (for example, `python -c "import secrets; print(secrets.token_urlsafe(48))"`).
Restart the API after changing these values. Open
`http://localhost:18000/admin`; sign-in sessions expire after eight hours.
The dashboard is disabled in production and must not be exposed publicly.

## 7. Start MySQL and Redis — Mode A

```sh
docker compose up -d mysql redis
docker compose ps
docker compose logs -f mysql
docker compose logs -f redis
```

MySQL and Redis bind to loopback only. MySQL persists in the named mysql_data volume. Redis holds disposable data and currently has no durable volume.

Stop while retaining the database:
```sh
docker compose down
```

**Destructive local reset: this deletes all database data in this stack.**
```sh
docker compose down -v
docker compose up -d mysql redis
```

Changing passwords/database initialization variables does not modify an existing MySQL volume. Alter users intentionally or reset disposable local data.

## 8. MySQL local access

Use a password prompt; do not append the password:
```sh
docker compose exec mysql mysql -u fudo_user -p fudo_koma
```

If MYSQL_USER or MYSQL_DATABASE differs, substitute those values.
```sql
SHOW DATABASES;
USE fudo_koma;
SHOW TABLES;
SELECT @@version, @@session.time_zone;
```

Application connections explicitly use UTC. UUIDs use portable CHAR(32) storage through SQLAlchemy Uuid. Dates use UTC DATETIME; future API serializers must label them as UTC.

## 9. Alembic and schema

Mode A:
```sh
alembic upgrade head
alembic current
alembic history
alembic check
alembic revision --autogenerate -m "add something"
alembic downgrade -1
```

Review generated migrations before applying them. MySQL DDL is not generally transactional; backup first for important data. Application startup does not run migrations or create tables automatically.

Mode B:
```sh
docker compose run --rm api alembic upgrade head
docker compose run --rm api alembic current
docker compose run --rm api alembic history
docker compose run --rm api alembic check
docker compose run --rm api alembic revision --autogenerate -m "add something"
docker compose run --rm api alembic downgrade -1
```

Compose mounts alembic/ so newly generated revisions persist on the host. On Linux ensure the non-root container user (UID 10001) can write that folder, or generate revisions with host Python.

Tables: users, carts, follows, notifications, reports. Foreign keys prevent orphan records. Follow uniqueness is enforced in MySQL. Roles and report target/status values have CHECK constraints. Notifications index user/time; reports index status/time and target; carts index owner, open state, category and coordinates.

**Nearby search remains future work:** use latitude/longitude with an indexed SQL bounding box, followed by database-side ST_Distance_Sphere(POINT(longitude, latitude), POINT(:lng, :lat)). A dedicated POINT column is deferred to avoid duplicated-coordinate synchronization and SRID migration complexity. Never fetch all carts for Python distance calculations. Handle the antimeridian/poles explicitly, validate inputs, cap radius/limit, and inspect EXPLAIN against representative data.

## 10. Run FastAPI locally — Mode A

After migrations:
```sh
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Reload is development-only. The Docker API is reachable at port 18000 by default; the local `.env` may override API_PORT.

| URL | Behavior |
|---|---|
| http://127.0.0.1:18000 | No root page; 404 is expected |
| http://127.0.0.1:18000/docs | Swagger |
| http://127.0.0.1:18000/redoc | ReDoc |
| http://127.0.0.1:18000/api/v1/health | Liveness: {"status":"ok"} |
| http://127.0.0.1:18000/api/v1/ready | Startup + SELECT 1; 503 if MySQL unavailable |
| http://127.0.0.1:18000/admin | Local admin dashboard; requires configured login and is disabled in production |
| http://127.0.0.1:18000/api/v1/carts | Local prototype carts |
| http://127.0.0.1:18000/api/v1/users | Local prototype users |

Readiness reports Redis separately and remains 200 when only Redis fails. Dependency probes run concurrently with bounded timeouts. Error responses do not reveal credentials. Readiness checks connectivity, not migration version; verify alembic current/check during deployment.

All cart/user prototype endpoints return 403 when `APP_ENV=production`. They have no authentication in development: do not publish or port-forward a development instance. Flutter integration steps and emulator configuration are also documented in the repository [README](../README.md#connect-flutter-to-the-local-backend).

## 11. Run everything in Docker — Mode B

```sh
docker compose up --build
```

In a second terminal:
```sh
docker compose exec api alembic upgrade head
docker compose ps
docker compose logs -f api
docker compose restart api
docker compose down
```

For detached mode: docker compose up -d --build. The API waits for healthy DB/Redis. No Firebase setup is needed for Phase 1. The Dockerfile uses Python 3.12-slim and UID 10001. It caches dependency installation before copying source.

The Dockerfile default runs Uvicorn with two workers and no reload. Development Compose overrides it with reload. Direct Uvicorn supports worker supervision; this follows [FastAPI deployment guidance](https://fastapi.tiangolo.com/deployment/server-workers/) and avoids obsolete uvicorn.workers/Gunicorn recipes. Each worker owns a DB pool: budget (pool size + overflow) × workers × replicas, leaving MySQL capacity for migrations and administration. Production Compose/HTTPS is still Phase 5; the Dockerfile alone is not a production deployment.

## 12. Firebase setup — preparation for Phase 2

Create a Firebase project and use Firebase Console project settings/service accounts to generate a service-account JSON. Store it outside the repository (or in ignored backend/credentials/ locally). Set FIREBASE_PROJECT_ID and FIREBASE_CREDENTIALS_PATH to the correct path. For Docker, Phase 2 must add a read-only secret mount and use its container path.

**NEVER commit Firebase service-account credentials.** Client firebase_options.dart is not an Admin SDK credential. Flutter will send Authorization: Bearer <firebase_id_token>; the server must verify it with Firebase Admin and load role/block state from MySQL. No verification, auth bypass, role promotion or authenticated endpoint exists in Phase 1.

## 13. Tests

Mode A:
```sh
pytest
pytest -v
```

Mode B:
```sh
docker compose run --rm api pytest -v
```

Tests cover liveness, readiness success/failure, optional Redis, startup requirement, trusted hosts, URL handling and production configuration guards. Dependency probes are mocked; no real Firebase/MySQL/Redis credentials are required for unit tests. Integration verification uses real Docker MySQL and Redis separately. Owner/pagination/cart-schema authorization tests arrive with their implementations.

## 14. Common local problems

**8000 in use:** set API_PORT=18000 in .env for Docker, or change uvicorn --port for host Python; inspect Windows:
```powershell
Get-NetTCPConnection -LocalPort 8000
```
Linux:
```sh
ss -ltnp
```

**3306 in use:** set MYSQL_PORT=13306 in .env; host Python follows that setting, API container still uses 3306. Do not stop another project's DB.

**Redis 6379 unavailable/reserved:** set REDIS_PORT=16379 and REDIS_URL=redis://127.0.0.1:16379/0, then recreate Redis. The container API still uses redis:6379.

**MySQL unhealthy:**
```sh
docker compose ps
docker compose logs --tail=100 mysql
```
Wait for initialization, verify password matches the existing volume and available disk. Do not reset valuable data.

**Redis unavailable:**
```sh
docker compose exec redis redis-cli ping
docker compose logs --tail=100 redis
```

**Wrong DATABASE_URL / Alembic cannot connect:** use mysql+asyncmy, correct hostname for the execution mode, start DB, inspect .env without sharing secrets, run alembic current. Compose intentionally clears DATABASE_URL so local host overrides do not break container networking. Managed DB support is a Phase 5 production concern.

**Missing package:** activate the correct interpreter and python -m pip install -r requirements.txt. Diagnose with python -m pip show fastapi sqlalchemy asyncmy.

**Firebase credentials missing:** expected in Phase 1; future auth must fail explicitly rather than fake verification.

**Docker daemon not running:**
```sh
docker info
docker compose version
```
Start Docker Desktop or the Docker service.

**.env not loading:** confirm current directory is backend and filename is .env, not .env.txt. List variables use valid JSON arrays, not comma-separated strings.

**Windows activation restrictions:** use CMD activation or, where organizational policy permits, Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned. Process scope ends with the terminal. You can also invoke .venv\Scripts\python.exe directly.

## 15. Production architecture — planned

```text
Internet -> HTTPS reverse proxy -> stateless FastAPI containers
                                  |                 |
                                MySQL             Redis
                                  |
                          persistent volume/backups
```

Keep API containers replaceable. MySQL data needs backups independent of container images. A future Caddy service will reverse_proxy api:8000 on the internal Compose network; publicly expose only 80/443. Never publicly expose MySQL, Redis or API 8000.

## 16. Deploy to Hostinger VPS — Phase 5 pending

This project requires a VPS, not shared hosting. The complete executable deployment guide, production Compose, Caddyfile, migration workflow, backups/restore and rollback procedures will be added in Phase 5. This section records requirements without pretending missing files are usable.

Method A: use a Hostinger Ubuntu Docker VPS template where available; verify Docker/Compose and optionally use Docker Manager. Method B: SSH into an Ubuntu VPS, install Docker using its official Ubuntu instructions, create a non-root deployment user and deploy Compose from /opt/fudo-koma/backend. UI availability must be verified against current Hostinger documentation during Phase 5.

Production preparation: domain A record to VPS IP, SSH keys, strong DB/session secrets, Firebase service-account secret outside Git, explicit CORS/trusted hosts, off-server backups, HTTPS reverse proxy and firewall. No live Hostinger server has been configured by this implementation.

## 17. Performance notes

Approximately 1,000 requests/second requires measured capacity, indexed queries, bounded pagination, no N+1, caching where useful, connection budgeting, horizontal replicas, load testing, metrics and monitoring. One server is not guaranteed to reach this target. Redis is connectivity-ready only; rate limiting/caching/background workers are not implemented. Avoid caching authorization or block status without an invalidation plan.

## 18. Scaling later

```text
       Load balancer
        /   |   \
      API  API  API
        \   |   /
       MySQL + Redis
```

Move MySQL to a separate database server when operational needs justify it. Shared secure sessions, consistent secrets, migrations run once per deployment, metrics and distributed rate limits are prerequisites before replicas. No microservices/Kubernetes are needed.

## 19. Optional GitHub Actions deployment — planned

Tests must pass before deployment. A future workflow may deploy a protected release branch over SSH or a verified Hostinger-supported integration. Store SSH/Hostinger credentials or API keys (only if that integration requires them), repository authentication and production environment secrets in GitHub Actions Secrets; never workflow YAML. Private repos should use scoped deploy keys. Automatic production deployment is not enabled.

Security requirements before production: no .env/credential JSON in Git; strong DB/session passwords; no public 3306/6379/8000; HTTPS/firewall; restricted CORS/trusted hosts; SSH keys and reduced root use; OS/Docker updates; verified backup/restore; rate limiting; server-side admin authorization and CSRF.

## 20. Command cheat sheet

```sh
# Local dependencies
docker compose up -d mysql redis
# Mode A migrations/API/tests
alembic upgrade head
uvicorn app.main:app --reload
pytest
# Mode B
docker compose up -d --build
docker compose exec api alembic upgrade head
docker compose run --rm api pytest
docker compose logs -f api
docker compose down
```

Production build/up commands will be documented when docker-compose.prod.yml is implemented in Phase 5.
