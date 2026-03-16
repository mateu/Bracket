-- verify_2026.sql
-- Run against bracket_2026

SELECT COUNT(*) AS players FROM player;
SELECT COUNT(*) AS picks FROM pick;
SELECT COUNT(*) AS region_scores FROM region_score;
SELECT COUNT(*) AS sessions FROM session;
SELECT COUNT(*) AS tokens FROM token;
SELECT COUNT(*) AS teams FROM team;
SELECT COUNT(*) AS games FROM game;
SELECT COUNT(*) AS winners_set FROM game WHERE winner IS NOT NULL;
SELECT round_out, COUNT(*) AS c FROM team GROUP BY round_out ORDER BY round_out;
