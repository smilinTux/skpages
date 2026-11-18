# Contributing to skpages

1. **Branch** from `main` (`feat/...`, `fix/...`, `docs/...`). Never push to `main`.
2. **Test first** where there is logic: add the failing case to `tests/test_cli.sh` or
   `tests/test_caddy.sh`, then make it pass.
3. **Run the gate** locally (CI runs the same):
   ```bash
   tests/test_cli.sh && tests/test_caddy.sh && tests/scrub.sh
   shellcheck skill/sk-pages install.sh tests/*.sh
   ```
4. **Commit** as soon as a fast check passes, then run the long checks. Conventional
   prefixes (`feat:`, `fix:`, `docs:`, `test:`, `ci:`). A `Co-Authored-By` trailer names
   the agent or person that actually did the work, or is left out.
5. **Changelog:** user-visible changes add a line under `## [Unreleased]` in
   `CHANGELOG.md`.
6. **Open a PR.** One review, green CI, then merge.

**Writing style:** no em or en dashes anywhere (code, docs, commits). `tests/scrub.sh`
enforces it.

**No estate facts:** this is a public framework repo. No host names, IPs, real domains,
people or account names, folder ids. Examples use `example.org`. Your own values go in
your `~/.config/sk-pages/config`, never here.

Standards: [sk-standards](https://github.com/smilinTux/sk-standards).
