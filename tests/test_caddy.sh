#!/usr/bin/env bash
# Behaviour tests for deploy/standalone/Caddyfile, against the real Caddy image.
# Covers SKPAGES_AUTH=none (default) and SKPAGES_AUTH=authentik (against
# tests/mock_authentik.py). Needs docker, curl, python3. Run: tests/test_caddy.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
IMAGE="${CADDY_IMAGE:-caddy:2.11.8-alpine}"
PORT="${CADDY_PORT:-18766}"
APORT="${CADDY_AUTH_PORT:-18767}" MPORT="${MOCK_AUTH_PORT:-18768}"
CONF="$HERE/../deploy/standalone"
NAME="skpages-test-$$"
WORK="$(mktemp -d)"
trap 'docker rm -f "$NAME" "$NAME-auth" >/dev/null 2>&1; kill "$MOCK_PID" 2>/dev/null; rm -rf "$WORK"' EXIT

mkdir -p "$WORK/www/agent/demo" "$WORK/www/p/tok123/pub" "$WORK/www/agent/.git"
echo '<h1>private</h1>' >"$WORK/www/agent/demo/index.html"
echo '<h1>public</h1>' >"$WORK/www/p/tok123/pub/index.html"
echo secret >"$WORK/www/.env"
echo x >"$WORK/www/agent/.git/config"
echo x >"$WORK/www/agent/demo/upload.html.part"
chmod -R a+rX "$WORK/www"

for mode in none authentik; do
    docker run --rm -e SKPAGES_AUTH=$mode -e SKPAGES_AUTHENTIK_URL=http://127.0.0.1:9 \
        -v "$CONF:/etc/caddy:ro" "$IMAGE" caddy validate --config /etc/caddy/Caddyfile >/dev/null 2>&1 \
        || { echo "FAIL caddy validate ($mode)"; exit 1; }
    echo "ok   caddy validate ($mode)"
done

docker run -d --name "$NAME" --user "$(id -u):$(id -g)" \
    -e XDG_DATA_HOME=/tmp/d -e XDG_CONFIG_HOME=/tmp/c -p "127.0.0.1:$PORT:8080" \
    -v "$WORK/www:/srv:ro" -v "$CONF:/etc/caddy:ro" "$IMAGE" >/dev/null
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$PORT/healthz" && break; sleep 0.2; done

pass=1 fail=0
code() { curl -s -o /dev/null -w '%{http_code}' "${@:3}" "http://127.0.0.1:$1$2"; }
expect_on() {  # expect_on PORT PATH WANT [curl args...]
    local got; got=$(code "$1" "$2" "${@:4}")
    if [ "$got" = "$3" ]; then pass=$((pass + 1)); echo "ok   $2 -> $3 ${4:+($*)}"
    else fail=$((fail + 1)); echo "FAIL $2 -> $got (want $3) ${4:+($*)}"; fi
}
expect() { expect_on "$PORT" "$1" "$2"; }

expect /healthz 200
expect /agent/demo/ 200
expect /p/tok123/pub/ 200
expect /p/ 404
expect /p/tok123/ 404
expect /.env 404
expect /agent/.git/config 404
expect /agent/demo/upload.html.part 404
expect /nope 404

headers=$(curl -sI "http://127.0.0.1:$PORT/agent/demo/")
for h in "content-security-policy: default-src 'self'" "form-action 'none'" "connect-src 'self'" \
         "referrer-policy: no-referrer" "x-content-type-options: nosniff"; do
    if grep -qi -- "$h" <<<"$headers"; then pass=$((pass + 1)); echo "ok   header $h"
    else fail=$((fail + 1)); echo "FAIL header $h"; fi
done
if grep -qi '^server:' <<<"$headers"; then fail=$((fail + 1)); echo "FAIL Server header present"
else pass=$((pass + 1)); echo "ok   no Server header"; fi

listing=$(curl -s "http://127.0.0.1:$PORT/")
if grep -q '\.env' <<<"$listing"; then fail=$((fail + 1)); echo "FAIL listing shows dotfiles"
else pass=$((pass + 1)); echo "ok   listing hides dotfiles"; fi

# --- SKPAGES_AUTH=authentik: Caddy itself asks the (mock) outpost ---
python3 "$HERE/mock_authentik.py" "$MPORT" &
MOCK_PID=$!
docker run -d --name "$NAME-auth" --network host --user "$(id -u):$(id -g)" \
    -e XDG_DATA_HOME=/tmp/d -e XDG_CONFIG_HOME=/tmp/c -e SKPAGES_PORT="$APORT" \
    -e SKPAGES_AUTH=authentik -e SKPAGES_AUTHENTIK_URL="http://127.0.0.1:$MPORT" \
    -v "$WORK/www:/srv:ro" -v "$CONF:/etc/caddy:ro" "$IMAGE" >/dev/null
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$APORT/healthz" && break; sleep 0.2; done
echo "-- authentik mode"
expect_on "$APORT" /healthz 200
expect_on "$APORT" /agent/demo/ 302
expect_on "$APORT" /agent/demo/ 200 -H "Cookie: authentik_session=good"
expect_on "$APORT" /p/tok123/pub/ 200
expect_on "$APORT" /p/ 404
expect_on "$APORT" /.env 404 -H "Cookie: authentik_session=good"
body=$(curl -s "http://127.0.0.1:$APORT/outpost.goauthentik.io/callback?x=1")
if [ "$body" = outpost ]; then pass=$((pass + 1)); echo "ok   login callback reaches the outpost"
else fail=$((fail + 1)); echo "FAIL login callback did not reach the outpost: $body"; fi

echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
