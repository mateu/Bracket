# 2026 Scrape + Import Plan (Bracket)

## Goal
Load 2026 tournament field data reproducibly into `bracket_2026` after DB clone/prune.

## Principles
- Deterministic input → deterministic DB state
- Preserve raw source snapshot
- Separate extract/normalize/load/verify
- Commit all artifacts for replay in production

## Artifacts
- Source notes snapshot: `note/import-data/2026-espn-source-notes.txt`
- Normalized CSV (tracked): `note/import-data/2026-teams.csv`
- Loader SQL: `script/import_2026_field.sql`
- Verification SQL: `script/verify_2026_field.sql`

## Canonical teams CSV format
```csv
team_id,seed,team_name,region_id,region_name,round1_game_id,slot
1,1,Auburn,1,South,1,A
2,16,AL St/St Francis,1,South,1,B
...
64,15,Wofford,4,Midwest,53,B
```

## Load strategy
1. Load CSV into staging table `stg_teams_2026`
2. Update `region` names from staged `region_id/region_name`
3. Update `team` records by `team.id` (`seed`, `name`, `region`)
4. Rebuild `game_team_graph` from staged `round1_game_id, team_id`
5. Keep `game` and `game_graph` unchanged unless tournament format changed

## Verification gates
- Team count = 64
- Region count = 4
- 16 teams per region
- Seeds 1..16 appear exactly once per region
- Round-1 mapping has 32 games × 2 teams each

## Production replay checklist
- Reuse same raw payload file(s)
- Reuse same normalized CSV
- Reuse same SQL scripts
- Capture verification output in run log
- Commit hash from dev run referenced in prod run note
