"""A local stand-in for instagram.com, for testing Commonplace's Instagram sign-in.

It serves a sign-in page for the app's web view, the Saved list and post
lookups the app reads, and a fake CDN for the videos. Nothing here talks to
Instagram, and no real account is involved.

Run:
    python tool/mock_instagram_server.py          # listens on :8788
Then build the app against it (debug builds only):
    flutter run --dart-define=INSTAGRAM_BASE_URL=http://10.0.2.2:8788 \\
                --dart-define=GEMINI_BASE_URL=http://10.0.2.2:8787

Sign in with any username and password. To act as the owner on Instagram:
    curl "localhost:8788/mock/save?caption=Pasta%20tip"           # save a reel
    curl "localhost:8788/mock/save?kind=carousel&caption=Interview" # a carousel
    curl localhost:8788/mock/signout                                # Instagram ends the session
    curl localhost:8788/mock/state                                  # what's saved
"""

from __future__ import annotations

import html
import json
import secrets
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8788
WEB_APP_ID = "936619743392459"
ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
PAGE_SIZE = 12
# Post JSON stores CDN links with this placeholder host; each response swaps
# in the host the client used (the emulator sees the PC as 10.0.2.2).
CDN_HOST = "cdn.mock.invalid"


def shortcode(pk: int) -> str:
    out = ""
    while pk:
        pk, r = divmod(pk, 64)
        out = ALPHABET[r] + out
    return out or "A"


class State:
    sessions: dict[str, str] = {}  # sessionid -> username
    posts: dict[str, dict] = {}
    saved: list[str] = []  # pks, newest save first
    next_pk = 3_412_345_678_901_230_000


def make_post(kind: str, caption: str, user: str) -> dict:
    State.next_pk += 1
    pk = State.next_pk
    base = f"http://{CDN_HOST}/cdn/{pk}"

    def video(name: str) -> dict:
        return {
            "media_type": 2,
            "video_versions": [
                {"type": 101, "url": f"{base}-{name}-1080.mp4", "width": 1080, "height": 1920},
                {"type": 102, "url": f"{base}-{name}-720.mp4", "width": 720, "height": 1280},
                {"type": 103, "url": f"{base}-{name}-360.mp4", "width": 360, "height": 640},
            ],
            "image_versions2": {"candidates": [{"url": f"{base}-{name}-cover.jpg", "width": 1080, "height": 1920}]},
        }

    def image(name: str) -> dict:
        return {
            "media_type": 1,
            "image_versions2": {
                "candidates": [
                    {"url": f"{base}-{name}-1440.jpg", "width": 1440, "height": 1800},
                    {"url": f"{base}-{name}-640.jpg", "width": 640, "height": 800},
                ]
            },
        }

    post: dict = {
        "pk": str(pk),
        "id": f"{pk}_17841400000000000",
        "code": shortcode(pk),
        "taken_at": int(time.time()) - 86_400,
        "user": {"pk": "17841400000000000", "username": user, "full_name": user.title(), "is_private": False},
        "caption": {"text": caption} if caption else None,
        "like_count": 1234,
        "comment_count": 56,
    }
    if kind == "photo":
        post.update(image("a"), product_type="feed")
    elif kind == "carousel":
        post.update(
            media_type=8,
            product_type="carousel_container",
            carousel_media=[dict(image(f"c{i}"), pk=f"{pk}{i}") for i in range(3)] + [dict(video("c3"), pk=f"{pk}3")],
        )
    else:
        post.update(video("v"), product_type="clips")
    State.posts[str(pk)] = post
    return post


def seed() -> None:
    if State.posts:
        return
    # Saved earlier, oldest first; each gets a matching canned note from the Gemini mock.
    for kind, caption, user in [
        ("reel", "3 SEO tips nobody tells you. Save this for your next blog post.", "seo.with.sam"),
        ("carousel", "Interview answers that actually work: tell a story, quantify, end with a question.", "career.notes"),
        ("reel", "Pasta water should taste like the sea. Salt it hard and save a cup before draining.", "cook.with.ana"),
    ]:
        State.saved.insert(0, make_post(kind, caption, user)["pk"])
    # Not saved: for trying Share -> Commonplace with a link.
    unsaved = make_post("reel", "How to answer 'tell me about yourself' in an interview.", "career.notes")
    print(f"  seeded 3 saved posts; an unsaved reel to share: https://www.instagram.com/reel/{unsaved['code']}/")


LOGIN_PAGE = """<!DOCTYPE html>
<html><head><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Log in (mock)</title>
<style>
 body{{font-family:sans-serif;margin:0;padding:32px 24px;background:#fafafa;color:#262626}}
 .box{{max-width:350px;margin:0 auto;background:#fff;border:1px solid #dbdbdb;padding:32px 28px}}
 h1{{font-size:28px;margin:0 0 6px;text-align:center}} p.n{{text-align:center;color:#8e8e8e;font-size:13px;margin:0 0 24px}}
 input{{width:100%;box-sizing:border-box;padding:10px;margin:4px 0;border:1px solid #dbdbdb;border-radius:3px;font-size:14px;background:#fafafa}}
 button{{width:100%;padding:9px;margin-top:12px;border:0;border-radius:8px;background:#0095f6;color:#fff;font-weight:600;font-size:14px}}
 .err{{color:#ed4956;font-size:14px;text-align:center}}
</style></head><body><div class="box">
<h1>Instagram</h1><p class="n">Local mock for testing, not the real site</p>
{error}
<form method="post" action="/accounts/login/ajax/">
<input name="username" placeholder="Phone number, username, or email" autocomplete="username">
<input name="password" type="password" placeholder="Password" autocomplete="current-password">
<button type="submit">Log in</button></form></div></body></html>"""

ONETAP_PAGE = """<!DOCTYPE html>
<html><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>Save login info (mock)</title>
<style>body{{font-family:sans-serif;padding:40px 24px;text-align:center;color:#262626}}a{{color:#0095f6;font-weight:600}}</style>
</head><body><h2>Save your login info?</h2><p>Signed in as @{user}.</p><p><a href="/">Not now</a></p></body></html>"""

HOME_PAGE = """<!DOCTYPE html>
<html><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>Instagram (mock)</title></head>
<body style="font-family:sans-serif;padding:40px 24px;color:#262626"><h2>Home</h2><p>Signed in as @{user}.</p></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: bytes, ctype: str = "application/json", headers: list[tuple[str, str]] | None = None) -> None:
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        for k, v in headers or []:
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _json(self, obj: dict, code: int = 200, headers: list[tuple[str, str]] | None = None) -> None:
        body = json.dumps(obj).replace(CDN_HOST, self.headers.get("Host", f"localhost:{PORT}"))
        self._send(code, body.encode(), headers=headers)

    def _redirect(self, to: str, headers: list[tuple[str, str]] | None = None) -> None:
        self._send(302, b"", "text/plain", [("Location", to)] + (headers or []))

    def _cookies(self) -> dict[str, str]:
        out = {}
        for part in self.headers.get("Cookie", "").split(";"):
            if "=" in part:
                k, v = part.split("=", 1)
                out[k.strip()] = v.strip()
        return out

    def _user(self) -> str | None:
        return State.sessions.get(self._cookies().get("sessionid", ""))

    def do_GET(self) -> None:
        seed()
        url = urlparse(self.path)
        q = {k: v[0] for k, v in parse_qs(url.query).items()}
        path = url.path

        if path.startswith("/cdn/"):
            size = 300_000 if path.endswith(".mp4") else 60_000
            ctype = "video/mp4" if path.endswith(".mp4") else "image/jpeg"
            self._send(200, b"\x00" * size, ctype)
            return

        if path == "/mock/save":
            post = make_post(q.get("kind", "reel"), q.get("caption", ""), q.get("user", "cook.with.ana"))
            State.saved.insert(0, post["pk"])
            print(f"  owner saved {post['code']} ({q.get('kind', 'reel')}): {q.get('caption', '')[:50]!r}")
            self._json({"saved": post["code"], "pk": post["pk"]})
            return
        if path == "/mock/signout":
            State.sessions.clear()
            print("  Instagram ended every session")
            self._json({"signed_out": True})
            return
        if path == "/mock/state":
            self._json({"saved": [State.posts[pk]["code"] for pk in State.saved], "sessions": len(State.sessions)})
            return

        user = self._user()
        if path in ("/accounts/login/", "/accounts/login"):
            if user:
                self._redirect("/")
            else:
                self._send(200, LOGIN_PAGE.format(error="").encode(), "text/html; charset=utf-8")
            return
        if path == "/accounts/onetap/":
            self._send(200, ONETAP_PAGE.format(user=html.escape(user or "?")).encode(), "text/html; charset=utf-8")
            return
        if path == "/":
            if not user:
                self._redirect("/accounts/login/")
            else:
                self._send(200, HOME_PAGE.format(user=html.escape(user)).encode(), "text/html; charset=utf-8")
            return

        if path.startswith("/api/v1/"):
            self._api(path, q, user)
            return
        self._send(404, b"not found", "text/plain")

    def _api(self, path: str, q: dict[str, str], user: str | None) -> None:
        problems = []
        if self.headers.get("X-IG-App-ID") != WEB_APP_ID:
            problems.append("X-IG-App-ID missing")
        if self.headers.get("X-CSRFToken") != self._cookies().get("csrftoken"):
            problems.append("X-CSRFToken doesn't match the cookie")
        if problems:
            print(f"  ! request shape: {', '.join(problems)}")
            self._json({"message": "useragent mismatch", "status": "fail"}, 400)
            return
        if not user:
            self._json({"message": "login_required", "require_login": True, "status": "fail"}, 401)
            return

        claim = [("x-ig-set-www-claim", "hmac.AR3mock" + secrets.token_hex(4))]
        if path == "/api/v1/feed/saved/posts/":
            start = int(q.get("max_id", "0") or 0)
            page = State.saved[start : start + PAGE_SIZE]
            more = start + PAGE_SIZE < len(State.saved)
            print(f"  saved list page from {start}: {len(page)} posts")
            self._json(
                {
                    "items": [{"media": State.posts[pk]} for pk in page],
                    "num_results": len(page),
                    "more_available": more,
                    "next_max_id": str(start + PAGE_SIZE) if more else None,
                    "auto_load_more_enabled": True,
                    "status": "ok",
                },
                headers=claim,
            )
            return
        if path.startswith("/api/v1/media/") and path.endswith("/info/"):
            pk = path.split("/")[4]
            post = State.posts.get(pk)
            if post is None:
                self._json({"message": "Media not found or unavailable", "status": "fail"}, 400)
                return
            print(f"  post {post['code']} looked up")
            self._json({"items": [post], "num_results": 1, "more_available": False, "status": "ok"}, headers=claim)
            return
        if path.startswith("/api/v1/users/") and path.endswith("/info/"):
            self._json({"user": {"pk": path.split("/")[4], "username": user}, "status": "ok"})
            return
        self._json({"message": "not found", "status": "fail"}, 404)

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        form = {k: v[0] for k, v in parse_qs(self.rfile.read(length).decode()).items()}
        if self.path.startswith("/accounts/login/ajax"):
            username = form.get("username", "").strip().lstrip("@")
            if not username or not form.get("password"):
                self._send(200, LOGIN_PAGE.format(error='<p class="err">Enter a username and password.</p>').encode(), "text/html; charset=utf-8")
                return
            sid = f"17841400000000000%3A{secrets.token_hex(8)}%3A1"
            State.sessions[sid] = username
            print(f"  signed in as @{username}")
            cookies = [
                ("Set-Cookie", f"csrftoken={secrets.token_hex(16)}; Path=/; Max-Age=31449600"),
                ("Set-Cookie", "ds_user_id=17841400000000000; Path=/; Max-Age=7776000"),
                ("Set-Cookie", f"sessionid={sid}; Path=/; HttpOnly; Max-Age=31536000"),
            ]
            self._redirect("/accounts/onetap/?next=%2F", cookies)
            return
        self._send(404, b"not found", "text/plain")

    def log_message(self, fmt: str, *args) -> None:
        print(f"{self.command} {self.path.split('?')[0]} -> {args[1] if len(args) > 1 else ''}")


if __name__ == "__main__":
    print(f"Mock Instagram listening on http://0.0.0.0:{PORT} (local only; nothing is sent to Instagram)")
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
