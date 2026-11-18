#!/usr/bin/env bash
# Scrub check (FRAMEWORK_AND_INSTANCE_STANDARD section 2.4): this public repo must not
# carry estate facts. Fails on IPv4 addresses other than loopback, domains outside the
# allowlist, home or mount paths, em or en dashes, and any term in the operator
# denylist (one extended regex per line, # comments), read from $SKPAGES_SCRUB_DENYLIST.
#
#   tests/scrub.sh              PR mode: the denylist is optional
#   tests/scrub.sh --release    release mode: fails closed without the denylist
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2
release=0; [ "${1:-}" = "--release" ] && release=1
fail=0
files=$(git ls-files 2>/dev/null || find . -type f -not -path './.git/*')
files=$(printf '%s\n' "$files" | grep -v -E '^(LICENSE|CODE_OF_CONDUCT\.md|tests/scrub\.sh)$')

report() { echo "FAIL $1"; printf '%s\n' "$2" | sed 's/^/     /' | head -20; fail=1; }

# shellcheck disable=SC2086
hits=$(grep -n -I -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' $files | grep -v -E '\b(127\.0\.0\.1|0\.0\.0\.0)\b' \
    | grep -v -E 'version|v[0-9]|caddy:|@v?[0-9]' || true)
[ -z "$hits" ] || report "IPv4 addresses" "$hits"

allow='example\.(org|com|net)|skworld\.io|github\.com|githubusercontent\.com|cdnjs\.cloudflare\.com|cdn\.jsdelivr\.net|unpkg\.com|fonts\.googleapis\.com|fonts\.gstatic\.com|caddyserver\.com|nextcloud\.com|keepachangelog\.com|semver\.org|contributor-covenant\.org|apache\.org|goauthentik\.io|shellcheck\.net|mermaid\.js\.org|ts\.net|tailscale\.com'
# shellcheck disable=SC2086
hits=$(grep -n -I -o -E '\b[a-z0-9-]+(\.[a-z0-9-]+)*\.(it|io|com|org|net|de|uk|dev|app|cloud|me)\b' $files \
    | grep -v -E "(^|[^a-z0-9-])($allow)$" | grep -v -E ':[a-z0-9_-]+\.(sh|py|md|yml|yaml|html|json|txt|io)$' || true)
hits=$(printf '%s\n' "$hits" | grep -v -E '\.(md|sh|py|yml|yaml)$' | grep -v '^$' || true)
[ -z "$hits" ] || report "domains outside the allowlist" "$hits"

# shellcheck disable=SC2086
hits=$(grep -n -I -E '/home/[a-z]|/Users/[A-Za-z]|/mnt/[a-z]|/var/data/[a-z]' $files || true)
[ -z "$hits" ] || report "home or mount paths" "$hits"

# shellcheck disable=SC2086
hits=$(grep -n -I -P '[\x{2013}\x{2014}]' $files || true)
[ -z "$hits" ] || report "em or en dashes" "$hits"

deny="${SKPAGES_SCRUB_DENYLIST:-}"
if [ -n "$deny" ] && [ -s "$deny" ]; then
    # shellcheck disable=SC2086
    hits=$(grep -n -I -i -E -f <(grep -v -E '^\s*(#|$)' "$deny") $files || true)
    [ -z "$hits" ] || report "operator denylist terms" "$(printf '%s\n' "$hits" | cut -d: -f1,2)"
elif [ "$release" = 1 ]; then
    echo "FAIL release scrub needs SKPAGES_SCRUB_DENYLIST (fails closed)"; fail=1
else
    echo "note: no operator denylist (set SKPAGES_SCRUB_DENYLIST); PR mode continues"
fi

[ "$fail" = 0 ] && echo "ok   scrub clean"
exit "$fail"
