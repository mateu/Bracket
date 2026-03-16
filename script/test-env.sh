#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PATH="$ROOT_DIR/local/bin:$PATH"
export PERL5LIB="$ROOT_DIR/local/lib/perl5:$ROOT_DIR/local/lib/perl5/x86_64-linux-gnu-thread-multi:$ROOT_DIR/local/lib/perl5/5.40.1:$ROOT_DIR/local/lib/perl5/5.40.1/x86_64-linux-gnu-thread-multi${PERL5LIB:+:$PERL5LIB}"

cd "$ROOT_DIR"

if [[ $# -eq 0 ]]; then
  exec prove -lv t/bracket_validator.t
else
  exec "$@"
fi
