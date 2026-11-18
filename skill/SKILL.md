---
name: sk-pages
description: Use when an agent has made an HTML page, report, dashboard, chart or small static site that a person should open, and needs to hand back a link. Publishes it to the estate's SK Pages site with the sk-pages CLI, privately behind the SSO login or public by link, and can post the link in a Nextcloud Talk thread for feedback. Use this instead of chat artifacts, local file paths or attachments.
---

# sk-pages

SK Pages gives you a place on the web. A page you publish gets a link you can hand
to your people instead of a local path or a chat artifact.

- **Private** (default): `<base url>/<agent>/<page>/`, behind the estate's SSO login.
- **Public** (`--public`): `<base url>/p/<random>/<page>/`, no login, for sending to
  someone outside. Anyone with the link can open it.

Run `sk-pages config` to see the base URL and Talk room this host uses.

## Publish

```bash
sk-pages publish report.html                      # one file  -> <base>/<agent>/report/
sk-pages publish ./site --name fleet-board        # a directory with index.html (CSS, JS, images)
sk-pages publish report.html --public             # public link, no login
sk-pages publish report.html --talk               # also post the link in Talk (new thread "Page: report")
sk-pages publish report.html --thread 1234        # post into the Talk thread you are already working in
```

- stdout is only the URL: `url=$(sk-pages publish report.html)`. Hand that link back.
- Republishing the same name replaces the page at the **same link** (public links
  too). Publish a fix under the same name; do not invent a new one.
- `--agent NAME` picks the folder (default `$SKAGENT`, else `$USER`). Publish under
  your own name.
- `--talk` posts in `SKPAGES_TALK_ROOM` (else `NC_TALK_ROOM_TOKEN`); `--talk-room
  TOKEN` picks another room. Replies in that thread are feedback on the page: edit,
  republish, answer in the same thread.

Other commands: `sk-pages list [--agent NAME]`, `sk-pages rm <agent>/<page>`,
`sk-pages init`, `sk-pages config`, `sk-pages --version`.

## What a page can and cannot do

Every page is served with a strict Content-Security-Policy:

- **Works:** inline `<script>` and `<style>`, images (`data:`, `https:`), scripts from
  cdnjs.cloudflare.com, cdn.jsdelivr.net and unpkg.com, styles from those and
  fonts.googleapis.com, fonts from fonts.gstatic.com. Pin exact library versions.
- **Blocked:** `fetch`, XHR and WebSocket to anything but the page's own origin, form
  posts, being framed by other sites, `<base>` changes, plugins. A page cannot call an
  API or send data anywhere. Bake the data into the page (inline JSON) when you build
  it.
- Pages are untrusted content by design. Never put secrets in a page, public or not.

## Setup on a host

```bash
git clone https://github.com/smilinTux/skpages && cd skpages && ./install.sh
```

Then write `~/.config/sk-pages/config` (no secrets) and the credentials file:

```bash
# ~/.config/sk-pages/config
SKPAGES_BASE_URL=https://pages.example.org
SKPAGES_TALK_ROOM=<talk room token>        # optional
SKPAGES_ENV=/path/to/credentials.env       # optional, default ~/.config/sk-pages/env

# credentials file (mode 600)
NC_URL=https://cloud.example.org
NC_USER=<account allowed to write the pages folder>
NC_APP_PASSWORD=<app password>
```

Needs only `bash` and `curl`. Full docs: https://github.com/smilinTux/skpages
