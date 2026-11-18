# Changelog

All notable changes to this project are documented here. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions follow
[SemVer](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-11-18

### Added
- `sk-pages` CLI: `publish` (file or directory, `--public`, `--agent`, `--name`),
  `list`, `rm`, `init`, `config`, `--version`, over Nextcloud WebDAV. Credentials go to
  curl on a file descriptor, never argv. Public links keep their token on republish.
- `--talk`, `--talk-room`, `--thread`: post the link in a Nextcloud Talk thread
  ("Page: NAME"), falling back to a new thread when Talk rejects the old one.
- Settings file `~/.config/sk-pages/config`, separate credentials file, environment
  wins over both. `SKPAGES_PUBLIC_BASE_URL` for public links served elsewhere.
- skskills skill (`skill/SKILL.md`, `skill/skill.yaml`) and `install.sh`.
- Standalone server: `deploy/standalone/Caddyfile` (read-only docroot, CSP, hidden
  dotfiles, unlistable `/p/`) with `SKPAGES_AUTH=none|authentik`, and a compose file.
- Tailscale deploy guide: tailnet only, tailnet plus Funnel for `/p/`, Funnel plus
  Authentik.
- Tests: CLI against a mock Nextcloud, Caddy rules against the real image in both auth
  modes, scrub check. CI on every push and PR.
