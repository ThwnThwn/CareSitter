# Phase 11 (parts 1–2): VM deployment and configuration

This is a single-VM Docker Compose deployment for the API, admin web, PostgreSQL,
Redis, and Caddy. Caddy is the only public container (ports 80/443). The admin
web and API share one HTTPS origin; API, database, and Redis have no published
host ports. Caddy obtains and renews certificates for `APP_DOMAIN`.

## Prepare staging or production

1. Point `APP_DOMAIN` DNS to the VM and allow inbound TCP 80/443 and UDP 443.
2. Copy `staging.env.example` or `production.env.example` to `deploy/.env` on
   the VM. Fill all `REPLACE_WITH_*` values. Set permissions to owner only
   (`chmod 600 deploy/.env`). Do not commit or put it in a Docker image.
3. Set `POSTGRES_PASSWORD` equal to the password in
   `ConnectionStrings__CareSitter`, and `REDIS_PASSWORD` equal to the one in
   `Redis__ConnectionString`. Use different random secrets and third-party
   credentials for each environment. A secret manager may render this file
   at deploy time; keep it off CI logs and artifacts.
4. Place the Firebase service-account JSON at
   `deploy/secrets/firebase-service-account.json` with owner-only permissions.
   This directory is gitignored and mounted read-only into the API. It is not
   included in either image.
5. Replace the example domain in `Public__ApiBaseUrl`, CORS, VNPay Return/IPN
   URLs, and the actual customer web redirect URL. The API rejects non-HTTPS
   origins, placeholder secrets, and callbacks that do not match its public
   origin. `PROXY_IP` must remain within `EDGE_SUBNET`; change both if the
   subnet conflicts with the VM.
   List every browser origin that calls the API in `Cors__AllowedOrigins__N`;
   mobile apps without an `Origin` header are unaffected.

For production, use the live VNPay URLs and credentials supplied for that
environment. Staging uses sandbox values. Do not place passwords in the
`frontend/admin-web` build: it calls the API on its own HTTPS origin.

## Apply schema, then start the application

Run these from the repository root on the VM after creating `deploy/.env`:

```sh
sh deploy/preflight.sh
docker compose -f deploy/compose.yml up -d db redis
docker compose -f deploy/compose.yml run --rm migrate
docker compose -f deploy/compose.yml up -d --build api admin proxy
docker compose -f deploy/compose.yml ps
curl --fail https://YOUR_APP_DOMAIN/health/ready
```

The migration service is a one-off command. The API does not apply SQL
migrations on startup. The runner tracks file checksums in
`public.schema_migrations` and stops if an applied SQL file changes. If an
existing legacy table/column would be dropped by migration 19 or 21, review
and back up the data before setting `ALLOW_DESTRUCTIVE_MIGRATIONS=true` for
that migration run; set it back to false afterward. A failed migration may
need manual database repair before retrying. Keep concurrent migration runs
disabled at the deployment level.

The runner **always skips `09-seed.sql`** because it contains demo accounts
with known password hashes. A fresh environment therefore has no admin user,
service catalog, or pricing. Provision these with production-owned credentials
and approved catalog data before allowing users to transact. The remaining
Phase 11 work still includes CI/CD, rollback, monitoring, backup/restore,
load testing, and runbooks; this manifest is not a completed go-live gate.

## Configuration and logs

- `backend/.env` and `backend/docker-compose.yml` remain local-development
  configuration. The deployment reads `deploy/.env` through Compose.
- ASP.NET Core maps double underscores to nested configuration keys. The API
  runs in `Staging` or `Production`, uses PostgreSQL-backed Hangfire, trusts
  only the configured Caddy IP for forwarded headers, and redirects HTTP to
  HTTPS behind Caddy.
- `Logging__LogLevel__Microsoft.AspNetCore=Warning` and the existing HTTP
  client log filter limit framework URL logging. Container logs go to stdout;
  do not add request/response body or authentication-header logging. Caddy
  access logs are not enabled in this manifest.
- PostgreSQL and Redis use named volumes. Backups and restore rehearsal are
  still outstanding Phase 11 work; do not treat these volumes as backups.
