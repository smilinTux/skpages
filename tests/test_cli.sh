#!/usr/bin/env bash
# End-to-end tests for sk-pages against tests/mock_nextcloud.py.
# Needs bash, curl, python3. Run: tests/test_cli.sh
# Checks are strings run through eval, so single quotes and "unused" captures are intended.
# shellcheck disable=SC2016,SC2034
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CLI="$HERE/../skill/sk-pages"
WORK="$(mktemp -d)"
PORT="${MOCK_PORT:-18765}"
trap 'kill "$MOCK_PID" 2>/dev/null; rm -rf "$WORK"' EXIT

mkdir -p "$WORK/dav" "$WORK/home" "$WORK/site/assets"
MOCK_USER=tester MOCK_PASS=secret python3 "$HERE/mock_nextcloud.py" "$WORK/dav" "$PORT" &
MOCK_PID=$!
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$PORT/" && break; sleep 0.1; done

export HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config"
unset NC_URL NC_USER NC_APP_PASSWORD SKPAGES_BASE_URL SKPAGES_ENV SKPAGES_TALK_ROOM NC_TALK_ROOM_TOKEN
export SKAGENT=tester-agent

pass=0 fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

echo '<h1>report</h1>' >"$WORK/My Report.html"
echo '<h1>site</h1>' >"$WORK/site/index.html"
echo 'body{}' >"$WORK/site/assets/app.css"
echo 'x' >"$WORK/site/.secret"

# Settings and credentials come from files, as on a real host.
mkdir -p "$XDG_CONFIG_HOME/sk-pages"
cat >"$XDG_CONFIG_HOME/sk-pages/config" <<EOF
SKPAGES_BASE_URL=https://pages.example.org/
SKPAGES_TALK_ROOM=room1
EOF
cat >"$XDG_CONFIG_HOME/sk-pages/env" <<EOF
NC_URL=http://127.0.0.1:$PORT
NC_USER=tester
NC_APP_PASSWORD=secret
EOF

check "version prints" '[ "$("$CLI" --version)" = "sk-pages 1.0.0" ]'
check "config shows base url, hides password" \
    '"$CLI" config | grep -q "https://pages.example.org" && ! "$CLI" config | grep -q secret'
check "init creates folders" '"$CLI" init >/dev/null && [ -d "$WORK/dav/skpages/p" ]'

url=$("$CLI" publish "$WORK/My Report.html" 2>/dev/null)
check "publish file prints clean url" '[ "$url" = "https://pages.example.org/tester-agent/my-report/" ]'
check "file stored as index.html" '[ -f "$WORK/dav/skpages/tester-agent/my-report/index.html" ]'

url=$("$CLI" publish "$WORK/site" --name "Fleet Board" 2>/dev/null)
check "publish dir uses slug name" '[ "$url" = "https://pages.example.org/tester-agent/fleet-board/" ]'
check "dir assets uploaded" '[ -f "$WORK/dav/skpages/tester-agent/fleet-board/assets/app.css" ]'
check "dotfiles not uploaded" '[ ! -e "$WORK/dav/skpages/tester-agent/fleet-board/.secret" ]'

u1=$("$CLI" publish "$WORK/My Report.html" --public 2>/dev/null)
u2=$("$CLI" publish "$WORK/My Report.html" --public 2>/dev/null)
check "public url under /p/<token>/" '[[ "$u1" =~ ^https://pages\.example\.org/p/[A-Za-z0-9_-]{24}/my-report/$ ]]'
check "republish keeps public link" '[ "$u1" = "$u2" ]'

u3=$(SKPAGES_PUBLIC_BASE_URL=https://box.tailnet.example.org:8443/ "$CLI" publish "$WORK/My Report.html" --public 2>/dev/null)
check "public links use SKPAGES_PUBLIC_BASE_URL when set" '[ "$u3" = "https://box.tailnet.example.org:8443/${u1#https://pages.example.org/}" ]'
u4=$(SKPAGES_PUBLIC_BASE_URL=https://box.tailnet.example.org:8443 "$CLI" publish "$WORK/My Report.html" 2>/dev/null)
check "private links keep SKPAGES_BASE_URL" '[ "$u4" = "https://pages.example.org/tester-agent/my-report/" ]'

check "list shows pages" '"$CLI" list | grep -q "fleet-board/"'

out=$("$CLI" publish "$WORK/My Report.html" --talk 2>"$WORK/err")
check "--talk keeps stdout to the url" '[ "$out" = "https://pages.example.org/tester-agent/my-report/" ]'
check "--talk posts in configured room with a new thread" \
    'tail -n1 "$WORK/dav/.talk.jsonl" | grep -q "\"room\": \"room1\".*\"threadTitle\": \"Page: my-report\""'
check "republish says Updated" 'tail -n1 "$WORK/dav/.talk.jsonl" | grep -q "Updated page: my-report"'
check "--talk reports thread on stderr" 'grep -q "thread 10[0-9]" "$WORK/err"'

"$CLI" publish "$WORK/My Report.html" --thread 7 >/dev/null 2>&1
check "--thread posts into that thread" 'tail -n1 "$WORK/dav/.talk.jsonl" | grep -q "\"threadId\": \"7\""'

"$CLI" publish "$WORK/My Report.html" --thread 404 >/dev/null 2>"$WORK/err"
check "deleted thread falls back to a new one" \
    'grep -q "not usable" "$WORK/err" && tail -n1 "$WORK/dav/.talk.jsonl" | grep -q "threadTitle\": \"Page: my-report"'

check "rm removes a page" '"$CLI" rm tester-agent/my-report >/dev/null && [ ! -e "$WORK/dav/skpages/tester-agent/my-report" ]'
check "missing file fails" '! "$CLI" publish "$WORK/nope.html" 2>/dev/null'
check "dir without index.html fails" 'mkdir "$WORK/empty" && ! "$CLI" publish "$WORK/empty" 2>/dev/null'

NC_APP_PASSWORD=wrong "$CLI" publish "$WORK/My Report.html" >/dev/null 2>&1
check "environment wins over credentials file (wrong password fails)" '[ $? -ne 0 ]'

msg=$(SKPAGES_CONFIG=/dev/null "$CLI" list 2>&1)
check "missing base url is a clear error" '[[ "$msg" == *"SKPAGES_BASE_URL not set"* ]]'

check "password never in curl argv" '! grep -n "\-u \"\$NC_USER" "$CLI"'

echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
