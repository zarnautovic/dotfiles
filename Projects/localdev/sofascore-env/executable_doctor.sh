#!/usr/bin/env bash
# Health check for the local tools setup — run via `make doctor`.
# ✔ ok · ! warning (works, but worth fixing) · ✘ broken
set -uo pipefail

ENV_DIR=$(CDPATH= cd -- "$(dirname -- "$(readlink -f -- "$0")")" && pwd)
REPO=$(sed -n 's/^SOFASCORE_REPO=//p' "$ENV_DIR/.env")
fails=0

ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
fail() { printf '  \033[31m✘\033[0m %s\n' "$*"; fails=$((fails + 1)); }
tools() { docker exec -u "$(id -u):$(id -g)" -w "$REPO" sofascore_tools "$@"; }

echo "Host"
[ -f "$REPO/composer.json" ] && ok "repo: $REPO" || fail "repo not found: $REPO (fix dot_env.tmpl in chezmoi)"
if [ "$(command -v php)" = "$ENV_DIR/bin/php" ]; then
  ok "shims on PATH"
else
  fail "php on PATH is '$(command -v php || echo none)', expected $ENV_DIR/bin/php (open a new shell)"
fi

echo "Container"
if [ "$(docker inspect -f '{{.State.Running}}' sofascore_tools 2>/dev/null)" != true ]; then
  fail "sofascore_tools not running — make up"
  echo; echo "$fails problem(s)"; exit 1
fi
ok "sofascore_tools running"

want=$(sed -n 's/^ARG PHP_VERSION=//p' "$REPO/Dockerfile")
have=$(tools php -r 'echo PHP_VERSION;')
if [ "$have" = "$want" ]; then
  ok "PHP $have (matches the repo's Dockerfile)"
else
  warn "PHP $have, repo's Dockerfile wants $want — make up (rebuilds with the repo's versions)"
fi

[ "$(tools php -r 'echo (int) (function_exists("apcu_enabled") && apcu_enabled());')" = 1 ] \
  && ok "APCu enabled for CLI" || fail "APCu not enabled for CLI (is docker/base/php/99-sofa.ini mounted?)"
tz=$(tools php -r 'echo ini_get("date.timezone");')
[ "$tz" = UTC ] && ok "date.timezone=UTC" || fail "date.timezone='$tz', expected UTC"

echo "Dependencies"
if [ ! -f "$REPO/vendor/composer/installed.json" ]; then
  fail "vendor/ missing — make install"
else
  if [ "$REPO/composer.lock" -nt "$REPO/vendor/composer/installed.json" ]; then
    warn "composer.lock is newer than vendor/ — make install"
  else
    ok "vendor/ up to date with composer.lock"
  fi
  if out=$(tools composer check-platform-reqs --no-interaction 2>&1); then
    ok "composer platform requirements satisfied"
  else
    fail "composer platform requirements:"
    grep -iE 'missing|failed' <<<"$out" | sed 's/^/      /'
  fi
fi

echo "Test services (make test-up)"
for svc in postgres:5555 redis:6380 elasticsearch:9201 beanstalk:11301; do
  name=${svc%%:*} port=${svc##*:}
  if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
    ok "$name :$port"
  else
    warn "$name :$port not reachable (only needed for tests — make test-up)"
  fi
done

echo
if [ "$fails" -eq 0 ]; then echo "All good."; else echo "$fails problem(s)"; exit 1; fi
