# AGENTS.md — Bracket contributor notes

## Test/runtime environment (important)
This repo uses a **repo-local Perl stack** under `local/`.
If you run tests without this environment, you may see `Can't locate ... in @INC` (e.g. Moose).

Always run commands through:

```bash
script/test-env.sh <command>
```

Examples:

```bash
script/test-env.sh prove -lv t/player_all_sorting.t
script/test-env.sh prove -lr t
script/test-env.sh perl -Ilib -MBracket::Controller::Player -e 1
```

## What `script/test-env.sh` sets
- Prepends repo-local `local/bin` to `PATH`
- Builds `PERL5LIB` from repo-local paths in `local/lib/perl5/...`
- Optionally appends `/home/hunter/perl5/...` only when `ALLOW_GLOBAL_PERL5=1`

## Rule of thumb
- Do **not** run bare `prove` or bare `perl` for project validation.
- Use `script/test-env.sh ...` so @INC is deterministic and matches app runtime expectations.
