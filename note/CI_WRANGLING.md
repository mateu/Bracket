# CI wrangling notes

## Current PR CI target
- Workflow: `.github/workflows/perl-tests.yml`
- Goal: keep one trustworthy PR signal that exercises the full deterministic non-POD suite.

## What we learned
1. Running old Bracket Perl/Catalyst dependencies via full CPAN recursion in GitHub Actions is brittle and noisy.
2. Prefer Ubuntu/Debian packaged Perl modules first for the app/runtime stack.
3. `t/bracket_validator.t` uses SQLite in test setup, so CI needs `DBD::SQLite` (`libdbd-sqlite3-perl`) even if production commonly uses MySQL.
4. For CI, using the packaged Perl stack directly is more reliable than trying to recreate the repo-local `./local` environment first.

## Current strategy
- Install packaged Catalyst/DBIx/FormHandler/etc. modules with `apt-get`
- Run explicit non-POD regression tests directly with `prove -Ilib -It/lib -lv`.
- Keep the test list explicit in workflow YAML to avoid accidental drift from optional POD checks.

## Rule of thumb
When CI fails, prefer the next smallest deterministic fix over broad dependency magic.
