-- verify_2026_field.sql
-- Run against bracket_2026 after import_2026_field.sql

SELECT id,name FROM region ORDER BY id;

SELECT COUNT(*) AS team_count FROM team;
SELECT region, COUNT(*) AS teams_per_region FROM team GROUP BY region ORDER BY region;
SELECT region, seed, COUNT(*) AS c
FROM team
GROUP BY region, seed
HAVING c <> 1
ORDER BY region, seed;

SELECT COUNT(*) AS non_default_round_out FROM team WHERE round_out <> 7;
SELECT COUNT(*) AS winners_set FROM game WHERE winner IS NOT NULL;
SELECT COUNT(*) AS picks_count FROM pick;
SELECT COUNT(*) AS region_score_count FROM region_score;
