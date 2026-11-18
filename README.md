# SK Pages: give your agent a voice on the internet

`Status: active` · `Version: 1.0.0` · `Maturity-tier: T0 (N/A, no key material)` · `Phase: Active (v1)`

Your agent builds a report, a dashboard or a small site, runs `sk-pages publish`, and
hands you a link. Private pages sit behind your SSO login. Public pages get a link
nobody can guess. The pages live in your own Nextcloud, on your own machines.

```console
$ sk-pages publish weekly-spend.html --talk
https://pages.example.org/my-agent/weekly-spend/
sk-pages: link posted in Talk room abc123, thread 4711
```

- **One command for any agent.** Claude Code, Codex, Hermes, Pi, OpenCode or a cron
  job: anything that can run `bash` and `curl` can publish. Installs as an
  [skskills](https://github.com/smilinTux/skskills) skill so every runtime knows how.
- **One copy of every page.** Pages are uploaded over WebDAV into a Nextcloud folder
  (a group folder, so no single account owns it). Versioned, searchable, backed up,
  and the web server only reads it.
- **Private by default.** Everything outside `/p/` needs a login (Authentik, or your
  tailnet). `--public` puts a page under `/p/<random>/`, which cannot be listed.
- **Feedback in Talk.** `--talk` posts the link in a Nextcloud Talk thread; replies
  there go back to the agent, which republishes to the same link.
- **Pages cannot phone home.** A strict Content-Security-Policy lets a page run its own
  scripts and load common CDNs, but blocks sending data anywhere.

## Quickstart

```bash
git clone https://github.com/smilinTux/skpages && cd skpages
./install.sh                                  # CLI on PATH (+ skill, if skskills is installed)

mkdir -p ~/.config/sk-pages
cat > ~/.config/sk-pages/config <<'EOF'
SKPAGES_BASE_URL=https://pages.example.org
EOF
cat > ~/.config/sk-pages/env <<'EOF'
NC_URL=https://cloud.example.org
NC_USER=my-agent
NC_APP_PASSWORD=xxxxx-xxxxx-xxxxx-xxxxx-xxxxx
EOF
chmod 600 ~/.config/sk-pages/env

sk-pages init                                 # creates skpages/ and skpages/p/
sk-pages publish report.html                  # prints the link
```

The server side (a read-only Caddy in front of that folder) is in
[SOP.md section 5](./SOP.md#5-release--deploy): on SKStacks with Traefik and Authentik,
standalone with Docker, or on a **Tailscale** tailnet with no public DNS at all.

## Commands

| Command | Does |
|---|---|
| `sk-pages publish FILE\|DIR [--public] [--talk\|--talk-room T\|--thread ID] [--agent A] [--name N]` | Upload, print the link (stdout is only the URL) |
| `sk-pages list [--agent A]` | List an agent's pages |
| `sk-pages rm AGENT/NAME` | Remove a page (Nextcloud keeps it in trash) |
| `sk-pages init` | Create the folder layout |
| `sk-pages config` | Show the settings in effect (never secrets) |
| `sk-pages --version` | Version |

## Docs

- [SOP.md](./SOP.md): architecture, deploy (SKStacks, standalone, Tailscale), configuration, troubleshooting
- [SECURITY.md](./SECURITY.md): threat model, why pages get their own origin
- [skill/SKILL.md](./skill/SKILL.md): what an agent reads before publishing
- [CONTRIBUTING.md](./CONTRIBUTING.md) · [CHANGELOG.md](./CHANGELOG.md) · [AGENTS.md](./AGENTS.md)
- Site: https://skpages.skworld.io

## Related projects / See also

- ⬆️ **Depends on:** [skhub](https://skhub.skworld.io) (Nextcloud) for storage, WebDAV and Talk; [sksso](https://github.com/smilinTux/skstacks/tree/main/v1/ansible/optional/sksso) (Authentik) for the private-page login.
- ⬆️ **Deployed by:** [skstacks](https://github.com/smilinTux/skstacks) `optional/skpages`, the Swarm role with Traefik labels and the Authentik wiring.
- ⬇️ **Used by:** [skcapstone](https://github.com/smilinTux/skcapstone) agents and any [skskills](https://github.com/smilinTux/skskills) runtime that needs to hand a person a link.
- ↔️ **Siblings:** [skcomms](https://github.com/smilinTux/skcomms) (agent messaging), [skmemory](https://github.com/smilinTux/skmemory) (what the agent remembers; SK Pages is what it shows).
- 📐 **Standards:** [sk-standards](https://github.com/smilinTux/sk-standards): repo docs, framework and instance, testing and CI.

## License

Apache-2.0, see [LICENSE](./LICENSE).
