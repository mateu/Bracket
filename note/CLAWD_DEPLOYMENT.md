# Bracket on clawd (Port 3030)

## Goal
Run Bracket from `/home/hunter/dev/Bracket` on clawd, with local Perl deps (project-local), and MySQL backend.

## What was done

1. Installed OS packages needed for build/runtime (cpanm, DB libs, MariaDB server/client, etc.).
2. Installed Perl dependencies **locally** into:
   - `/home/hunter/dev/Bracket/local`
3. Created local app config:
   - `/home/hunter/dev/Bracket/bracket_local.conf`
   - DB: `bracket_2025`
   - DB credentials sourced from local environment/secrets (not committed)
4. Installed and enabled MariaDB, created DB:
   - `bracket_2025`
5. Imported working DB data from Surf:
   - `mysqldump` from `surf:bracket_2025`
   - imported into local `bracket_2025`
6. Loaded required SQL functions on clawd:
   - `sql/getter-functions.sql`
   - This fixes errors like: `FUNCTION bracket_2025.get_loser does not exist`.
7. Added persistent user service:
   - `~/.config/systemd/user/bracket3030.service`
   - Runs Bracket on `0.0.0.0:3030`
   - Auto-restarts on failure

## Service management

```bash
systemctl --user status bracket3030.service
systemctl --user restart bracket3030.service
systemctl --user stop bracket3030.service
systemctl --user start bracket3030.service
```

## Logs

- Error log: `/tmp/bracket3030-error.log`
- Access log: `/tmp/bracket3030-web.log`
- Service logs:

```bash
journalctl --user -u bracket3030.service -f
```

## URL

- `http://<clawd-ip>:3030`
- Login page redirects from `/` to `/login`.

## MySQL parity mode (matches Surf family)

To avoid MariaDB/MySQL SQL syntax drift, clawd now uses **MySQL 8.0** via Docker for Bracket DB.

- Container: `bracket-mysql8`
- Host mapping: `127.0.0.1:3307 -> container 3306`
- App DSN (`bracket_local.conf`):

```text
dbi:mysql:database=bracket_2025;host=127.0.0.1;port=3307
```

### MySQL container ops

```bash
docker ps | grep bracket-mysql8
docker logs -f bracket-mysql8
docker restart bracket-mysql8
```

### Data source

Imported from MariaDB backup after normalization for MySQL 8 compatibility.
Backups are in:

- `data/backup/bracket_2025-pre-mysql-cutover.sql`
- `data/backup/bracket_2025-mariadb-export.sql`
- `data/backup/bracket_2025-mariadb-export.mysql8.fixed.sql`

## Quick verification

```bash
ss -tulpen | grep :3030
curl -I http://127.0.0.1:3030
```

Expected response includes:
- `HTTP/1.1 302 Found`
- `Location: http://127.0.0.1:3030/login`

## Notes

- `/all` depends on DB helper functions from `sql/getter-functions.sql`.
- If DB is refreshed from another source, re-run:

```bash
: "${BRACKET_DB_USER:?set BRACKET_DB_USER}"
: "${BRACKET_DB_PASSWORD:?set BRACKET_DB_PASSWORD}"
mysql -u"$BRACKET_DB_USER" -p"$BRACKET_DB_PASSWORD" bracket_2025 < /home/hunter/dev/Bracket/sql/getter-functions.sql
```

- MariaDB compatibility fix for `/update_points`:
  - File: `lib/Bracket/Model/DBIC.pm`
  - Replaced MySQL CTE+UPDATE syntax (`WITH ... UPDATE`) with MariaDB-safe `UPDATE ... JOIN (subquery)`.
  - This resolves SQL syntax errors triggered from admin `update_points` route.
