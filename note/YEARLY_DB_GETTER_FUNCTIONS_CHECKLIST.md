# Yearly DB Getter Functions Checklist (Bracket Production)

## Why this exists
During 2026 production cutover, bracket_2026 was missing required MySQL functions (get_winner, get_loser) and app paths failed until they were loaded manually.

This note is a hard guardrail for 2027+ cutovers.

## Required routines
- get_winner (FUNCTION)
- get_loser (FUNCTION)

## Apply during yearly schema rollover
Run after creating/loading bracket_<year> and before declaring prod healthy.

mysql -h127.0.0.1 -P3306 -uroot -p<password> bracket_<year> < /home/hunter/Bracket/sql/getter-functions.sql

Example (2027):
mysql -h127.0.0.1 -P3306 -uroot -p<password> bracket_2027 < /home/hunter/Bracket/sql/getter-functions.sql

## Verify routines
SELECT ROUTINE_NAME, ROUTINE_TYPE
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA = bracket_<year>
  AND ROUTINE_NAME IN (get_winner, get_loser)
ORDER BY ROUTINE_NAME;

Expected:
- get_loser | FUNCTION
- get_winner | FUNCTION

## Quick smoke checks
1. Frontdoor (https://bracket.huntana.com/) redirects normally to login.
2. Upstream app (http://127.0.0.1:3333/) responds with expected redirect/HTML.
3. One authenticated bracket flow works without DB function errors.

## Incident reference
- Date: 2026-03-19
- Actual prod fix: loaded /home/hunter/Bracket/sql/getter-functions.sql into bracket_2026 and verified routines existed.
