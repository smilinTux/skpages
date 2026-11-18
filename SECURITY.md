# Security Policy: skpages

## Reporting a vulnerability

Do not open a public issue. Use GitHub private vulnerability reporting on
[smilinTux/skpages](https://github.com/smilinTux/skpages) (Security tab, "Report a
vulnerability"). We follow the
[SECURITY_DISCLOSURE_STANDARD](https://github.com/smilinTux/sk-standards/blob/main/standards/SECURITY_DISCLOSURE_STANDARD.md).

## Threat model

Pages are written by agents, and an agent can be wrong or prompt-injected. So **every
page is treated as untrusted HTML.** The design follows from that.

| Threat | Control | Evidence |
|---|---|---|
| A page steals the viewer's Nextcloud session (stored XSS) | Pages are served on their **own origin**, never from the Nextcloud domain. Nextcloud itself forces `.html` downloads for exactly this reason (see its Notes app fix, CVE-2023-39955). | Architecture in `SOP.md` section 2 |
| A page sends data out (tokens, what the viewer types) | CSP `connect-src 'self'`, `form-action 'none'`, `base-uri 'self'`, `object-src 'none'` | `tests/test_caddy.sh` header checks |
| A page is framed for clickjacking | `frame-ancestors 'self'` (plus `X-Frame-Options: DENY` from the SKStacks front) | `tests/test_caddy.sh` |
| The web server is used to change pages | Docroot mounted **read-only**; Caddy `admin off` | `deploy/standalone/docker-compose.yml`, `Caddyfile` |
| Hidden files leak (`.env`, `.git`, half uploads) | `.*` and `*.part` return 404 and are hidden from listings | `tests/test_caddy.sh` |
| Public links are enumerated | `/p/` and `/p/<token>/` return 404; tokens are 144 random bits | `tests/test_caddy.sh`, `tests/test_cli.sh` |
| Private pages reached without login | Login enforced in front (Traefik forward-auth, tailnet) or in Caddy (`SKPAGES_AUTH=authentik`); only `/p/` bypasses it | `tests/test_caddy.sh` authentik mode |
| Publisher credentials leak | App passwords only; curl reads them from a file descriptor, never argv; `sk-pages config` never prints them | `tests/test_cli.sh` |

**Out of scope:** what a person does with a public link once they have it (anyone with
it can open the page), and content an agent chooses to publish. Never put secrets in a
page, public or private.

## Secret handling

- `NC_APP_PASSWORD` lives in the environment or a mode-600 credentials file, never in
  `~/.config/sk-pages/config`, the skill, or the repo.
- Revoke an agent's publishing by removing its account from `sk-pages-publishers` and
  deleting its app password.

## Dependency posture

Runtime: `bash`, `curl`, and the pinned `caddy:2.11.8-alpine` image. No package
dependencies. Bump the image in one PR across `deploy/standalone/docker-compose.yml`,
`tests/test_caddy.sh` and the docs, with the tests green.
