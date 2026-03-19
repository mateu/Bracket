# 2026 DB Migration Runbook (Bracket)

## Scope
Migrate Bracket from `bracket_2025` to `bracket_2026` in a reproducible, rollback-safe way.

## Objectives
- Keep users/roles
- Reset tournament state for new season
- Make process repeatable in production
- Preserve backups for rollback

## Environment
- MySQL endpoint: `127.0.0.1:3307`
- Service: `bracket3030.service`
- Source DB: `bracket_2025`
- Target DB: `bracket_2026`

## 0) Preconditions
- App service healthy on current DB
- MySQL reachable
- Disk space available for backup dump

## 1) Backup source DB
```bash
set -euo pipefail
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/home/hunter/dev/Bracket/data/backup"
mkdir -p "$BACKUP_DIR"

# Use env vars instead of inline credentials
: "${BRACKET_DB_USER:?set BRACKET_DB_USER}"
: "${BRACKET_DB_PASSWORD:?set BRACKET_DB_PASSWORD}"

mysqldump -h 127.0.0.1 -P 3307 -u "$BRACKET_DB_USER" -p"$BRACKET_DB_PASSWORD" \
  --single-transaction --routines --triggers bracket_2025 \
  > "$BACKUP_DIR/bracket_2025-pre-2026-migration-${TS}.sql"
```

## 2) Create target DB and clone data
```sql
DROP DATABASE IF EXISTS bracket_2026;
CREATE DATABASE bracket_2026 CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
```

```bash
mysqldump -h 127.0.0.1 -P 3307 -u "$BRACKET_DB_USER" -p"$BRACKET_DB_PASSWORD" bracket_2025 \
| mysql -h 127.0.0.1 -P 3307 -u "$BRACKET_DB_USER" -p"$BRACKET_DB_PASSWORD" bracket_2026
```

## 3) Prune/reset season-specific state in target
Run against `bracket_2026` only:

```sql
DELETE FROM pick;
DELETE FROM region_score;
DELETE FROM session;
DELETE FROM token;

UPDATE game SET winner = NULL, lower_seed = 0;
UPDATE team SET round_out = 7;
UPDATE player SET points = 0;
```

## 4) Validation checks
See also: note/YEARLY_DB_GETTER_FUNCTIONS_CHECKLIST.md for required MySQL routine checks (get_winner/get_loser) during yearly rollover.

```sql
SELECT COUNT(*) AS players FROM player;
SELECT COUNT(*) AS picks FROM pick;                 -- expect 0
SELECT COUNT(*) AS region_scores FROM region_score; -- expect 0
SELECT COUNT(*) AS sessions FROM session;           -- expect 0
SELECT COUNT(*) AS tokens FROM token;               -- expect 0
SELECT COUNT(*) AS teams FROM team;                 -- expect 64
SELECT COUNT(*) AS games FROM game;                 -- expect 63
SELECT COUNT(*) AS winners_set FROM game WHERE winner IS NOT NULL; -- expect 0
SELECT round_out, COUNT(*) FROM team GROUP BY round_out ORDER BY round_out; -- expect only 7=>64
```

## 5) Cutover app config
Update `/home/hunter/dev/Bracket/bracket_local.conf`:
- `year 2026`
- DSN `database=bracket_2026`
- `edit_cutoff_time.year 2026` (and tournament lock values)

Restart service:
```bash
systemctl --user restart bracket3030.service
systemctl --user status bracket3030.service
```

## 6) Smoke test
```bash
curl -I http://127.0.0.1:3030
```
Expect redirect to `/login` and non-5xx status.

## 7) Rollback
- Revert `bracket_local.conf` back to `bracket_2025`
- Restart service
- Keep `bracket_2026` for diagnostics

## Notes
- Do **not** run `deploy_bracket.pl` for this migration path.
- 2026 team/seed/region data load happens as a separate import step.
 `deploy_bracket.pl` for this migration path.
- 2026 team/seed/region data load happens as a separate import step.
