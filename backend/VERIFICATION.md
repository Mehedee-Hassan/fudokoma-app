# Phase 1 verification — 2026-10-02 (Asia/Tokyo)

## Deployment readiness update

The current code now includes Firebase email/password and Google sign-in,
Firebase Admin ID-token verification, role/ownership authorization, and a
Firebase-authenticated admin dashboard session. A Hostinger-oriented
production Compose stack and Caddy HTTPS reverse proxy are present. These
changes passed 27 backend tests, 11 Flutter tests, Dart diagnostics, and a
production Compose configuration check. Firebase token verification is
mocked in automated tests; no real Firebase project or production server has
been configured or exercised.

Public deployment is not complete until Firebase options/service-account
credentials, the real domain/DNS, production secrets, first admin bootstrap,
backups, and the Hostinger VPS are configured. See the deployment procedure
in `README.md`.

## Repository and file changes

The supplied workspace was empty. Cloned https://github.com/Mehedee-Hassan/fudo-koma.git into it using Windows certificate validation (Git's default CA backend initially failed). Inspected Flutter models, FirebaseService, FirestoreService, pubspec and ignore rules. No AGENTS.md found in the cloned repository.

All additions are under backend/. No tracked Flutter or other pre-existing file changed; git diff --exit-code passed and git status showed only ?? backend/.

Created:
- app/main.py
- app/core/{__init__.py,config.py,logging.py}
- app/db/{__init__.py,base.py,session.py}
- app/models/{__init__.py,user.py,cart.py,follow.py,notification.py,report.py}
- app/api/{__init__.py,deps.py,routes/__init__.py,routes/health.py}
- app/{__init__.py,schemas/__init__.py,services/__init__.py,admin/__init__.py}
- app/templates/README.md, app/static/css/README.md, scripts/README.md
- alembic/env.py, alembic/script.py.mako
- alembic/versions/e64b21dcf7c7_initial_schema.py
- tests/test_config.py, tests/test_health.py, pytest.ini
- requirements.txt, alembic.ini, Dockerfile, docker-compose.yml
- .env.example, .gitignore, .dockerignore, README.md, VERIFICATION.md
- ignored .env for local execution

Modified existing files: none. Created files were refined during verification.

## Commands executed and results

- git clone: default certificate backend failed; git -c http.sslBackend=schannel clone succeeded, without disabling certificate verification.
- python --version: host Python 3.8.10; unsupported, so native virtual-environment execution was not attempted.
- docker --version / docker info: Docker 29.8.1 daemon available.
- docker compose up -d mysql redis: MySQL started; Redis port 6379 rejected by Windows. Added configurable REDIS_PORT, local .env uses 16379; retry succeeded.
- docker compose build api: Python 3.12.15 image built and dependencies installed successfully.
- docker compose run --rm api alembic revision --autogenerate -m "initial schema": succeeded.
- initial alembic upgrade head: failed on MySQL TEXT literal default. Removed server default from description in model/migration; preserved Python default. Updated coordinates to DOUBLE precision.
- attempted SQL recovery through shell -c failed due Windows argument quoting, without modifying the table.
- recovered with Python/SQLAlchemy only after checking allowed table set and zero users; removed the empty users table created by the failed migration.
- docker compose run --rm api alembic upgrade head: succeeded.
- docker compose run --rm api alembic current: e64b21dcf7c7 (head).
- docker compose run --rm api alembic check: "No new upgrade operations detected."
- reviewed downgrade to drop tables in reverse dependency order, without prematurely dropping MySQL FK-supporting indexes.
- docker compose run --rm api alembic downgrade -1: succeeded on the empty new local schema.
- docker compose run --rm api alembic upgrade head: reapplication succeeded.
- repeated current/check: head, no schema differences.
- docker compose run --rm api pytest -v: 12 passed in 0.95s on final test run. One upstream Starlette TestClient/httpx deprecation warning; no failed tests.
- docker compose up -d --build api: initial attempt failed because 8000 belongs to another service. Added API_PORT, local .env uses 18000; retry succeeded.
- earliest HTTP probes raced startup and failed; repeated after startup and succeeded.
- Invoke-RestMethod http://127.0.0.1:18000/api/v1/health: HTTP 200, {"status":"ok"}.
- Invoke-RestMethod http://127.0.0.1:18000/api/v1/ready: HTTP 200; startup/mysql/redis all true.
- docker compose ps: API/MySQL/Redis all running and healthy.
- docker compose logs --tail=20 api: application startup complete; GET health/ready 200.
- git -C .. diff --exit-code: succeeded; existing files preserved.
- git check-ignore .env credentials/firebase-adminsdk-test.json: both ignored.

## Current local state

The development Docker services may remain from the prior local integration:
API at `http://127.0.0.1:18000`, MySQL on loopback port 3306, and Redis on
loopback port 16379. The production Compose stack has not been started.
Protected API routes require Firebase authentication; `/admin` uses Firebase
admin-role sign-in when configured.

To stop without deleting data, run docker compose down from backend/.

## Remaining work / limitations

Configure real Firebase project settings and keys outside version control.
Hostinger: no VPS has been provisioned or deployment run. Apply the documented
DNS, firewall, secret, migration, first-admin, and independent-backup steps.
Firebase verification tests use mocks; no live Firebase login, load test,
production server run, backup restore, or VPS deployment has been verified.
Nearby SQL search, FCM delivery, rate limiting/caching, monitoring, and
production backup automation remain future work.

Dependency versions use bounded ranges, not a reproducible lock. Review/lock before production. Redis caching/rate limiting is not implemented yet. Readiness checks connectivity, not schema version. DB timestamp updates via ORM use Python UTC; external SQL writers must set updated_at explicitly.
