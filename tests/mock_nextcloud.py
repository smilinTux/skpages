#!/usr/bin/env python3
"""A tiny stand-in for the parts of Nextcloud that sk-pages talks to.

WebDAV under /remote.php/dav/files/<user>/ (MKCOL, PUT, PROPFIND, DELETE) backed by a
real directory, and the Talk chat endpoint (POST .../spreed/api/v1/chat/<token>),
which records every post to <root>/.talk.jsonl. Basic auth is checked against
MOCK_USER / MOCK_PASS. Thread id 404 is treated as a deleted thread (400), like Talk.

Usage: mock_nextcloud.py ROOT PORT
"""
import base64
import http.server
import json
import os
import shutil
import sys
import urllib.parse

ROOT, PORT = sys.argv[1], int(sys.argv[2])
USER, PASS = os.environ.get("MOCK_USER", "tester"), os.environ.get("MOCK_PASS", "secret")
DAV = f"/remote.php/dav/files/{USER}/"
TALK = "/ocs/v2.php/apps/spreed/api/v1/chat/"
_next_thread = [100]


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _authed(self):
        want = "Basic " + base64.b64encode(f"{USER}:{PASS}".encode()).decode()
        if self.headers.get("Authorization") != want:
            self._reply(401)
            return False
        return True

    def _reply(self, code, body=b"", ctype="text/plain"):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _local(self):
        path = urllib.parse.unquote(urllib.parse.urlparse(self.path).path)
        if not path.startswith(DAV):
            return None
        rel = os.path.normpath(path[len(DAV):]).lstrip("/")
        if rel.startswith(".."):
            return None
        return os.path.join(ROOT, rel) if rel != "." else ROOT

    def _body(self):
        return self.rfile.read(int(self.headers.get("Content-Length", 0) or 0))

    def do_MKCOL(self):
        if not self._authed():
            return
        p = self._local()
        if p is None or not os.path.isdir(os.path.dirname(p)):
            return self._reply(409)
        if os.path.exists(p):
            return self._reply(405)
        os.mkdir(p)
        self._reply(201)

    def do_PUT(self):
        if not self._authed():
            return
        p = self._local()
        if p is None or not os.path.isdir(os.path.dirname(p)):
            return self._reply(409)
        with open(p, "wb") as f:
            f.write(self._body())
        self._reply(201)

    def do_DELETE(self):
        if not self._authed():
            return
        p = self._local()
        if p is None or not os.path.exists(p):
            return self._reply(404)
        shutil.rmtree(p) if os.path.isdir(p) else os.remove(p)
        self._reply(204)

    def do_PROPFIND(self):
        if not self._authed():
            return
        p = self._local()
        if p is None or not os.path.exists(p):
            return self._reply(404)
        href = urllib.parse.urlparse(self.path).path
        hrefs = [href]
        if os.path.isdir(p) and self.headers.get("Depth", "1") != "0":
            base = href if href.endswith("/") else href + "/"
            hrefs += [base + urllib.parse.quote(n) + ("/" if os.path.isdir(os.path.join(p, n)) else "")
                      for n in sorted(os.listdir(p))]
        xml = '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">' + "".join(
            f"<d:response><d:href>{h}</d:href></d:response>" for h in hrefs) + "</d:multistatus>"
        self._reply(207, xml.encode(), "application/xml")

    def do_POST(self):
        if not self._authed():
            return
        path = urllib.parse.urlparse(self.path).path
        if not path.startswith(TALK) or self.headers.get("OCS-APIRequest") != "true":
            return self._reply(404)
        form = dict(urllib.parse.parse_qsl(self._body().decode()))
        thread = form.get("threadId")
        if thread == "404":
            return self._reply(400, b'{"ocs":{"meta":{"statuscode":400}}}', "application/json")
        if not thread and form.get("threadTitle"):
            _next_thread[0] += 1
            thread = str(_next_thread[0])
        rec = {"room": path[len(TALK):], "message": form.get("message"), "threadId": thread,
               "threadTitle": form.get("threadTitle")}
        with open(os.path.join(ROOT, ".talk.jsonl"), "a") as f:
            f.write(json.dumps(rec) + "\n")
        data = {"id": 1, "message": rec["message"]}
        if thread:
            data["threadId"] = int(thread)
        self._reply(201, json.dumps({"ocs": {"data": data}}).encode(), "application/json")


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
