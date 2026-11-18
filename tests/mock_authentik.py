#!/usr/bin/env python3
"""Stand-in for an Authentik outpost, for tests/test_caddy.sh.

GET /outpost.goauthentik.io/auth/caddy: 200 with X-Authentik-Username when the request
carries the cookie "authentik_session=good", else 302 to a login URL (what the real
outpost does for a browser without a session). Any other /outpost.goauthentik.io/ path
answers 200 "outpost" so the test can see the callback was proxied, not served by Caddy.

Usage: mock_authentik.py PORT
"""
import http.server
import sys


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.path.startswith("/outpost.goauthentik.io/auth/caddy"):
            if "authentik_session=good" in (self.headers.get("Cookie") or ""):
                self.send_response(200)
                self.send_header("X-Authentik-Username", "tester")
                self.end_headers()
            else:
                self.send_response(302)
                self.send_header("Location", "https://sso.example.org/login")
                self.end_headers()
            return
        if self.path.startswith("/outpost.goauthentik.io/"):
            body = b"outpost"
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_response(404)
        self.end_headers()


http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
