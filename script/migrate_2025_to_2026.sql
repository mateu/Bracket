-- migrate_2025_to_2026.sql
-- Run against bracket_2026 ONLY after clone from bracket_2025

DELETE FROM pick;
DELETE FROM region_score;
DELETE FROM session;
DELETE FROM token;

UPDATE game SET winner = NULL, lower_seed = 0;
UPDATE team SET round_out = 7;
UPDATE player SET points = 0;
