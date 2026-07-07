# TopNotchRentalz — Deployment Guide (staging + production)

## Host requirements (all must be true before choosing)

| Requirement | How to confirm |
|---|---|
| Node.js 22+ | host runtime picker shows 22.x |
| **Persistent disk that survives deploys/restarts/scaling** | the host offers a mountable volume/disk and its docs say data survives redeploys — **SQLite + uploads + backups all live on this disk** |
| HTTPS + custom domain | free TLS + domain attach |
| Environment variables | secret env editor |
| Auto-restart on crash | supervised process / health checks |
| Server logs | log viewer or shell access |

**Recommended options** (all satisfy the above):
- **Render** (Web Service + Persistent Disk) — `deploy/render.yaml` included
- **Railway** (service + Volume)
- **Fly.io** (app + Volume)
- **Any Ubuntu VPS** (Hetzner/DigitalOcean) — `deploy/topnotch.service` + `deploy/Caddyfile` included

⚠️ Do **not** use serverless-only platforms without a disk (Vercel/Netlify functions,
Heroku free dynos): their filesystems are wiped on every deploy and SQLite data
would be lost. The persistence check is: *deploy twice, confirm a row created
between deploys still exists.* This is step 1 of the launch checklist.

## Staging + production (two separate services, two separate disks)

Create the service twice from the same repo/branch:

| | Staging | Production |
|---|---|---|
| `TN_ENV` | `staging` (demo partners/fleet stay) | `production` (no demo data; LUXX Miami seeded as onboarding lead) |
| Domain | `staging.topnotchrentalz.com` | `topnotchrentalz.com` |
| Disk mount | `/var/data` → `TN_DATA_DIR=/var/data/tn` | separate disk, same mount pattern |
| `EXCEL_WEBHOOK_URL` | test workbook flow | real TopNotchRentalz workbook flow |
| Stripe | `sk_test_…` | `sk_live_…` (after pilot passes) |
| All passwords/keys | different values | different values — never share between envs |

Each service: build command `none`, start command `node topnotch-server/server.js`,
health check path `/api/health`, env vars from `.env.example` (set
`TN_SECURE_COOKIES=1`, `TN_BASE_URL=https://<domain>`, `BACKUP_ENCRYPTION_KEY`).

### VPS variant
```
sudo cp deploy/topnotch.service /etc/systemd/system/   # auto-restart on failure
sudo systemctl enable --now topnotch
sudo cp deploy/Caddyfile /etc/caddy/Caddyfile && sudo systemctl reload caddy   # HTTPS
```

## Deploy procedure
1. Push to the branch the service tracks (use a `staging` branch for staging).
2. Host builds + restarts; `/api/health` returns `{ok:true}` when live.
3. First boot prints one-time temp passwords in the service logs → sign in → forced change.
4. Verify in **Admin → System Health**: DB OK, backup fresh, Excel/Stripe/email flags.

## Rollback procedure (emergency)
1. **Code rollback:** redeploy the previous commit (host "Rollback" button, or
   `git revert` + push). The database schema is additive-only, so older code
   runs against newer databases.
2. **Data rollback:** stop the service →
   `BACKUP_ENCRYPTION_KEY=... node scripts/restore.mjs <backup-file>` → start.
   The pre-restore db is kept at `topnotch.db.pre-restore` so the rollback
   itself is reversible.
3. If Excel got bad rows during the incident, the workbook is a report —
   fix/ignore there; the database remains the source of truth.
4. Announce in team chat; check Admin → Audit Log for the incident window.

## Backups
- Daily encrypted (AES-256-GCM) snapshots + before every fleet import; 30 kept.
- Manual button: Admin → Settings → "Back up now".
- Copy `backups/` off-host nightly (cron + rclone to Drive/S3). Customer
  documents (`data/uploads/`) are **excluded** from these archives by design —
  sync them separately to a private bucket only.
- Restore is tested automatically in `tests/phase4.mjs` (test 7).

## Monitoring
- Point UptimeRobot (or similar) at `https://<domain>/api/health` (1-min checks).
- Admin → System Health shows: DB, backup age/failures, Excel sync queue,
  email delivery mode, Stripe config + rejected webhooks, failed logins,
  denied permissions, sessions, storage, rejected uploads.
