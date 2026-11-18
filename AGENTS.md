# AGENTS.md (skpages)

SK Pages: a CLI and skill that let agents publish HTML pages to a read-only, SSO-gated
site backed by a Nextcloud folder. Read [README.md](./README.md) for the overview and
[SOP.md](./SOP.md) for operations. Standard: [AGENT_INSTRUCTIONS_STANDARD](https://github.com/smilinTux/sk-standards/blob/main/standards/AGENT_INSTRUCTIONS_STANDARD.md).

## Source of truth and invariants

- `skill/sk-pages` is the only copy of the CLI. `install.sh` links it; never fork it
  into another repo.
- `deploy/standalone/Caddyfile` is the reference for the serving rules. The SKStacks
  role template must keep the same behaviour; change both in step.
- stdout of `sk-pages publish` is exactly the URL. Everything else goes to stderr.
- A Talk failure never fails a publish.
- Secrets never reach argv, the config file, logs, or `sk-pages config` output.
- `/p/` and `/p/<token>/` must stay unlistable.

## Commands

```bash
# install
./install.sh
# test (what CI runs)
tests/test_cli.sh && tests/test_caddy.sh && tests/scrub.sh
# lint
shellcheck skill/sk-pages install.sh tests/*.sh
# docs gate
python3 <path-to-sk-standards>/scripts/docs_check.py --repo .
```

## Start here

1. `skill/sk-pages`: the CLI.
2. `deploy/standalone/Caddyfile`: serving rules and headers.
3. `deploy/standalone/auth/authentik.caddy`: in-Caddy SSO for public exposure.
4. `tests/test_cli.sh`: behaviour contract of the CLI.

## Rules

- **Writing style:** no em dashes (U+2014) and no en dashes (U+2013) anywhere: code,
  comments, docs, commits, PR bodies. Use commas, parentheses, colons or a new sentence.
  Hyphens are fine.
- **Branch and commit:** never commit to `main`. Branch, commit as soon as a fast check
  passes and before any long verification, then open a PR.
- **Attribution:** a `Co-Authored-By` trailer names the agent that actually did the work,
  or is left out.
- **Version:** bump `SKPAGES_VERSION` in `skill/sk-pages`, `skill/skill.yaml`, README
  header and SOP section 9 together, with a CHANGELOG entry.

## Privacy

Never put any of these in code, docs, tests, fixtures, commits or the site: host names,
LAN or tailnet IPs, estate names, personal names or data, credentials, and for this
repo: real Nextcloud URLs, account names, group folder ids, Talk room tokens. Enforced
by: `tests/scrub.sh` (plus the operator denylist in CI).

## Hazards

- `set -o pipefail` in tests: a command that is expected to fail, piped into `grep`,
  fails the check. Capture output first, then match.
- Talk JSON may be compact or spaced (`"threadId":1` or `"threadId": 1`); parse both.
- Caddy runs `handle` before `respond`: deny rules must be `handle` blocks above the
  file servers, or they never fire.
- Tailscale Funnel opens a whole port. Never Funnel the port that serves private pages
  with `SKPAGES_AUTH=none`.

## See also

- [skstacks](https://github.com/smilinTux/skstacks) `v1/ansible/optional/skpages`: the Swarm role.
- [skskills](https://github.com/smilinTux/skskills): how the skill reaches every runtime.
- [SK_REPO_DOC_STANDARD](https://github.com/smilinTux/sk-standards/blob/main/standards/SK_REPO_DOC_STANDARD.md)
