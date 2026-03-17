# Production Perl Stack Rollout (repo-local first)

## Goal
Use repo-local Perl modules at `/home/hunter/Bracket/local` as the default test/runtime stack on production, and keep `/home/hunter/perl5` as an explicit fallback only.

## Forward plan
1. Ensure deps are installed into repo-local path:
   - `cd /home/hunter/Bracket`
   - `cpanm --notest --local-lib-contained local --installdeps .`
2. Verify validator test with repo-local only:
   - `PERL5LIB=/home/hunter/Bracket/local/lib/perl5:/home/hunter/Bracket/local/lib/perl5/x86_64-linux-gnu-thread-multi prove -lv t/bracket_validator.t`
3. Keep helper behavior canonical:
   - `script/test-env.sh` uses repo-local first
   - global perl fallback only when explicitly enabled (`ALLOW_GLOBAL_PERL5=1`)
4. (Optional service hardening) add systemd user override for `bracket-psgi.service`:
   - set `Environment=PERL5LIB=/home/hunter/Bracket/local/lib/perl5:/home/hunter/Bracket/local/lib/perl5/x86_64-linux-gnu-thread-multi`

## Rollback path
If runtime/test behavior regresses after switching to repo-local:

### Fast rollback (tests/CLI)
- Run with global tree explicitly:
  - `ALLOW_GLOBAL_PERL5=1 script/test-env.sh`

### Service rollback
1. Remove or disable the service PERL5LIB override.
2. Reload/restart user service:
   - `systemctl --user daemon-reload`
   - `systemctl --user restart bracket-psgi.service`
3. Re-verify health:
   - `curl -I http://127.0.0.1:3333/` (expect `302` to `/login`)

## Notes
- Keep one canonical dependency source active by default.
- Mixing repo-local and global module trees should be opt-in and temporary.
