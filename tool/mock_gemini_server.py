"""A free, local stand-in for the Gemini REST API, for testing Commonplace.

It speaks the same endpoints the app uses (generateContent and the resumable
Files API), checks that requests have the documented shape, and answers with
canned but realistic notes. Nothing leaves your machine and nothing is billed.

Run:
    python tool/mock_gemini_server.py            # listens on :8787
Then build the app against it (debug builds only):
    flutter run --dart-define=GEMINI_BASE_URL=http://10.0.2.2:8787
(10.0.2.2 is the host machine as seen from the Android emulator.)

Any key starting with "AQ." (new AI Studio keys) or "AIza" (older ones) is
accepted. A key containing "RATELIMIT" answers 429 (per-minute limit), and
one containing "DAILYLIMIT" answers 429 with a per-day quota violation, like
a free key that is used up for the day.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
# Long enough to see the "Reading the reel" state. MOCK_DELAY=40 makes it slow
# enough to leave the app mid-note and check that it keeps going.
DELAY_SECONDS = float(os.environ.get("MOCK_DELAY", "2.5"))

EXTRACTION = {
    "transcript": (
        "Three SEO tips nobody tells you. Tip one. Write your title like the exact "
        "question people type into Google, not a clever headline. Tip two. Put the "
        "direct answer in your first one hundred words, because that is what gets "
        "pulled into the snippet. Tip three. Stop writing new posts every week. Go "
        "back and update your old posts that already rank on page two. Fresh content "
        "climbs fast. Save this so you actually do it."
    ),
    "on_screen_text": [
        "3 SEO tips nobody tells you",
        "1. Title = the question people search",
        "2. Answer in the first 100 words",
        "3. Refresh posts stuck on page 2",
    ],
    "visual_notes": "",
    "language": "en",
    "creator_handle": "seo.with.sam",
}

NOTES = {
    "seo": {
        "title": "Write titles like the question people search",
        "summary": (
            "Three small SEO habits that get posts found: question-shaped titles, "
            "answering early, and refreshing what already almost ranks."
        ),
        "key_points": [
            {
                "text": "Phrase your title as the exact question people type into Google, not a clever headline.",
                "highlight": "the exact question people type",
            },
            {
                "text": "Put the direct answer in the first hundred words, since that is what gets pulled into the snippet.",
                "highlight": "direct answer in the first hundred words",
            },
            {
                "text": "Update old posts already sitting on page two instead of writing new ones every week.",
                "highlight": "Update old posts already sitting on page two",
            },
        ],
        "actions": [
            "Rewrite one old title as the question it answers",
            "Move the answer into the first paragraph of your top post",
            "List five posts ranking on page two and refresh one this week",
        ],
        "topic": "SEO",
        "tags": ["titles", "featured snippets", "content refresh"],
    },
    "cooking": {
        "title": "Salt pasta water like the sea, then save a cup",
        "summary": "Two habits that make weeknight pasta taste like a restaurant's.",
        "key_points": [
            {
                "text": "Salt the water until it tastes like the sea; it's the only chance to season the pasta itself.",
                "highlight": "tastes like the sea",
            },
            {
                "text": "Save a cup of starchy pasta water and stir it into the sauce so it clings.",
                "highlight": "a cup of starchy pasta water",
            },
        ],
        "actions": ["Taste the water before the pasta goes in tonight"],
        "topic": "Cooking",
        "tags": ["pasta", "weeknight"],
    },
    "career": {
        "title": "Answer 'tell me about yourself' in three parts",
        "summary": "A simple present, past, future structure for the first interview question.",
        "key_points": [
            {
                "text": "Start with what you do now and one result you are proud of.",
                "highlight": "one result you are proud of",
            },
            {
                "text": "Connect your past roles to why this job is the obvious next step.",
                "highlight": "the obvious next step",
            },
        ],
        "actions": ["Write your 60-second answer and say it out loud twice"],
        "topic": "Career",
        "tags": ["interviews"],
    },
}


def pick_note(prompt: str) -> dict:
    # Only look at the reel's material, not the instructions (which mention
    # example topics like "Cooking").
    m = prompt.split("Material:", 1)[-1].lower()
    if any(w in m for w in ("pasta", "recipe", "cook", "salt")):
        return NOTES["cooking"]
    if any(w in m for w in ("interview", "resume", "career", "job")):
        return NOTES["career"]
    return NOTES["seo"]


def gemini_response(payload: dict, media_seconds: int = 0, model: str = "gemini-flash-latest") -> bytes:
    # Token counts shaped like Gemini's: about 66 tokens per frame (one a
    # second) plus 32 per second of sound for video.
    video, audio = 66 * media_seconds, 32 * media_seconds
    text = 900
    out = len(json.dumps(payload)) // 4
    return json.dumps(
        {
            "candidates": [
                {
                    "content": {"role": "model", "parts": [{"text": json.dumps(payload)}]},
                    "finishReason": "STOP",
                }
            ],
            # The concrete model behind the alias, as Gemini reports it.
            "modelVersion": "gemini-3.5-flash-lite" if "lite" in model else "gemini-3.8-flash",
            "usageMetadata": {
                "promptTokenCount": video + audio + text,
                "candidatesTokenCount": out,
                "thoughtsTokenCount": 40,
                "totalTokenCount": video + audio + text + out + 40,
                "promptTokensDetails": [
                    {"modality": "VIDEO", "tokenCount": video},
                    {"modality": "AUDIO", "tokenCount": audio},
                    {"modality": "TEXT", "tokenCount": text},
                ],
            },
        }
    ).encode()


def error(code: int, status: str, message: str) -> bytes:
    return json.dumps({"error": {"code": code, "status": status, "message": message}}).encode()


class Handler(BaseHTTPRequestHandler):
    uploads: dict[str, dict] = {}

    def _send(self, code: int, body: bytes, headers: dict[str, str] | None = None) -> None:
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _key_ok(self) -> bool:
        key = self.headers.get("x-goog-api-key", "")
        if not key.startswith(("AQ.", "AIza")):
            self._send(400, error(400, "INVALID_ARGUMENT", "API key not valid. Please pass a valid API key."))
            return False
        if "RATELIMIT" in key:
            self._send(429, error(429, "RESOURCE_EXHAUSTED", "Quota exceeded for the free tier."))
            return False
        if "DAILYLIMIT" in key:
            body = json.loads(error(429, "RESOURCE_EXHAUSTED", "You exceeded your current quota."))
            body["error"]["details"] = [
                {
                    "@type": "type.googleapis.com/google.rpc.QuotaFailure",
                    "violations": [{"quotaId": "GenerateRequestsPerDayPerProjectPerModel-FreeTier"}],
                }
            ]
            self._send(429, json.dumps(body).encode())
            return False
        return True

    def do_GET(self) -> None:  # key check, file state polling
        model = re.fullmatch(r"/v1beta/models/([\w.-]+)", self.path)
        if model:
            if self._key_ok():
                print(f"  key check for {model.group(1)}: ok")
                self._send(200, json.dumps({"name": f"models/{model.group(1)}", "displayName": model.group(1)}).encode())
            return
        m = re.fullmatch(r"/v1beta/(files/[\w-]+)", self.path)
        if m and self._key_ok():
            info = self.uploads.get(m.group(1))
            if info is None:
                self._send(404, error(404, "NOT_FOUND", "file not found"))
                return
            self._send(
                200,
                json.dumps(
                    {"name": m.group(1), "uri": info["uri"], "state": "ACTIVE", "videoMetadata": {"videoDuration": "45s"}}
                ).encode(),
            )
            return
        self._send(404, error(404, "NOT_FOUND", self.path))

    def do_DELETE(self) -> None:  # files are deleted once read
        m = re.fullmatch(r"/v1beta/(files/[\w-]+)", self.path)
        if m and self._key_ok():
            self.uploads.pop(m.group(1), None)
            print(f"  deleted {m.group(1)}")
            self._send(200, b"{}")
            return
        self._send(404, error(404, "NOT_FOUND", self.path))

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)

        if self.path == "/upload/v1beta/files":
            if not self._key_ok():
                return
            assert self.headers.get("X-Goog-Upload-Protocol") == "resumable"
            assert self.headers.get("X-Goog-Upload-Command") == "start"
            session = uuid.uuid4().hex[:8]
            self._send(200, b"{}", {"x-goog-upload-url": f"http://{self.headers['Host']}/upload-session/{session}"})
            print(f"  upload start: {self.headers.get('X-Goog-Upload-Header-Content-Length')} bytes")
            return

        if self.path.startswith("/upload-session/"):
            name = f"files/{self.path.rsplit('/', 1)[1]}"
            uri = f"http://{self.headers['Host']}/v1beta/{name}"
            self.uploads[name] = {"uri": uri, "bytes": len(raw)}
            print(f"  upload done: {len(raw)} bytes -> {name}")
            self._send(200, json.dumps({"file": {"name": name, "uri": uri, "state": "PROCESSING"}}).encode())
            return

        m = re.fullmatch(r"/v1beta/models/([\w.-]+):generateContent", self.path)
        if not m:
            self._send(404, error(404, "NOT_FOUND", self.path))
            return
        if not self._key_ok():
            return
        try:
            body = json.loads(raw)
            parts = body["contents"][0]["parts"]
            config = body["generationConfig"]
            assert config["responseMimeType"] == "application/json"
            assert isinstance(config["responseJsonSchema"], dict)
        except (KeyError, IndexError, AssertionError, json.JSONDecodeError) as e:
            self._send(400, error(400, "INVALID_ARGUMENT", f"malformed request: {e!r}"))
            return

        media = [p for p in parts if "inlineData" in p or "fileData" in p]
        text = "\n".join(p.get("text", "") for p in parts)
        time.sleep(DELAY_SECONDS)
        thinking = config.get("thinkingConfig", {}).get("thinkingLevel", "default")
        fps = [p.get("videoMetadata", {}).get("fps", 1) for p in media]
        if media and "key_points" in json.dumps(config["responseJsonSchema"]):
            print(f"  [{m.group(1)}] read + note in one request, {len(media)} media part(s), fps {fps}, thinking {thinking}")
            # Only the owner's caption says what the reel is about; the
            # prompt itself mentions example topics like "Cooking".
            caption = text.split("when saving it:", 1)[1] if "when saving it:" in text else ""
            note = pick_note(f"Material:{caption}")
            self._send(200, gemini_response({**EXTRACTION, **note}, media_seconds=45, model=m.group(1)))
        elif media:
            sizes = [len(p["inlineData"]["data"]) if "inlineData" in p else p["fileData"]["fileUri"] for p in media]
            print(f"  [{m.group(1)}] extract from {len(media)} media part(s): {sizes}, thinking {thinking}")
            self._send(200, gemini_response(EXTRACTION, media_seconds=45, model=m.group(1)))
        else:
            note = pick_note(text)
            print(f"  [{m.group(1)}] distill -> {note['title']!r}")
            self._send(200, gemini_response(note, model=m.group(1)))

    def log_message(self, fmt: str, *args) -> None:
        print(f"{self.command} {self.path.split('?')[0]} -> {args[1] if len(args) > 1 else ''}")


if __name__ == "__main__":
    print(f"Mock Gemini listening on http://0.0.0.0:{PORT} (free, local, nothing is sent anywhere)")
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
