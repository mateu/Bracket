#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PERL_VER="$(perl -MConfig -e 'print $Config{version}')"

LOCAL_LIBS=(
  "$ROOT_DIR/local/lib/perl5"
  "$ROOT_DIR/local/lib/perl5/x86_64-linux-gnu-thread-multi"
  "$ROOT_DIR/local/lib/perl5/$PERL_VER"
  "$ROOT_DIR/local/lib/perl5/$PERL_VER/x86_64-linux-gnu-thread-multi"
)

PERL5LIB_BUILT=""
for d in "${LOCAL_LIBS[@]}"; do
  [[ -d "$d" ]] || continue
  if [[ -z "$PERL5LIB_BUILT" ]]; then
    PERL5LIB_BUILT="$d"
  else
    PERL5LIB_BUILT="$PERL5LIB_BUILT:$d"
  fi
done

if [[ "${ALLOW_GLOBAL_PERL5:-0}" == "1" ]]; then
  for d in /home/hunter/perl5/lib/perl5 /home/hunter/perl5/lib/perl5/x86_64-linux-gnu-thread-multi; do
    [[ -d "$d" ]] || continue
    PERL5LIB_BUILT="$PERL5LIB_BUILT:$d"
  done
fi

export PATH="$ROOT_DIR/local/bin:$PATH"
export PERL5LIB="$PERL5LIB_BUILT${PERL5LIB:+:$PERL5LIB}"

cd "$ROOT_DIR"

if [[ $# -eq 0 ]]; then
  exec prove -lv t/bracket_validator.t
else
  exec "$@"
fi
