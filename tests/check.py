#!/usr/bin/env python3
"""Backend checks that need no network and no mpv. Run: python3 tests/check.py"""
import fcntl, json, os, sys, tempfile
import urllib.request   # the backend imports it only inside its network functions; the patches below need it loaded

tmpdir = tempfile.TemporaryDirectory()
tmp = tmpdir.name
os.environ["HOME"] = os.environ["XDG_RUNTIME_DIR"] = tmp   # the module keeps its state under these
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import cliamp_ctl as c


def video(i):
    return {"videoRenderer": {"videoId": "vid%08d" % i, "title": {"runs": [{"text": "T%d" % i}]}}}


def token(t):
    return {"continuationItemRenderer": {"continuationEndpoint": {"continuationCommand": {"token": t}}}}


# 1. search follows the continuation token page by page, drops repeats and stops at the limit
first = {"contents": {"twoColumnSearchResultsRenderer": {"primaryContents": {"sectionListRenderer": {"contents": [
    {"itemSectionRenderer": {"contents": [video(i) for i in range(19)]}}, token("page2")]}}}}}
second = {"onResponseReceivedCommands": [{"appendContinuationItemsAction": {"continuationItems": [
    {"itemSectionRenderer": {"contents": [video(18)] + [video(i) for i in range(19, 31)]}}, token("page3")]}}]}
sent = []


class Reply:
    def __init__(self, body): self.body = body
    def __enter__(self): return self
    def __exit__(self, *a): return False
    def read(self, size=-1):
        data = json.dumps(self.body).encode()
        return data if size < 0 else data[:size]


def fake_urlopen(req, timeout=None):
    sent.append(json.loads(req.data))
    return Reply([first, second][len(sent) - 1])


c.urllib.request.urlopen = fake_urlopen
found = c.search_youtube_innertube("anything", 25)
assert [r["id"] for r in found] == ["vid%08d" % i for i in range(25)], found
assert len(sent) == 2 and sent[0]["query"] == "anything" and sent[1]["continuation"] == "page2"
sent.clear()
assert len(c.search_youtube_innertube("anything", 10)) == 10 and len(sent) == 1

# 2. a list row is found by its url, even when the panel's row number is stale
played = []
c.play_item = lambda url, title=None, artist=None, **kw: played.append(url) or {"success": True}
c.atomic_write_json(c.LAST_SEARCH_PATH, [{"url": "/a", "title": "A"}, {"url": "/b", "title": "B"}, {"url": "/c", "title": "C"}])
c.save_queue([{"url": "/queued"}])
assert c.play_playlist_action("Search Results", 0, "/c")["success"]
assert played[-1] == "/c" and c.read_playback_context()["index"] == 2
assert c.read_queue() == [{"url": "/queued"}]            # search results and recents leave the queue alone
c.save_playlists([{"name": "Mix", "tracks": [{"url": "/x"}, {"url": "/y"}, {"url": "/x"}]}])
assert c.play_playlist_action("Mix", 2, "/x")["success"]
assert c.read_playback_context()["index"] == 2           # the same song twice: the row number stands
assert c.read_queue() == []                              # a playlist started on purpose clears the queue
assert not c.play_playlist_action("No Such List", 0)["success"]

# 3. Repeat One restarts the track and starts it again (mpv pauses at the end of a file)
cmds = []
c.send_mpv_cmd = lambda cmd, timeout=1.0: cmds.append(cmd) or {"error": "success", "data": True}
c.set_play_mode({"repeat": "one"})
assert c.next_track()["action"] == "repeat_one"
assert cmds == [["seek", 0, "absolute"], ["set_property", "pause", False]], cmds

# 4. when a track ends, only one of the status pollers moves on
held = os.open(c.ADVANCE_LOCK_FILE, os.O_CREAT | os.O_RDWR, 0o600)
fcntl.flock(held, fcntl.LOCK_EX)
assert c.advance_once() is False
os.close(held)
assert c.advance_once() is True

# 5. A temporary LRCLIB failure (or a legacy empty cache entry) must not hide lyrics forever.
from unittest.mock import patch
import hashlib
from types import SimpleNamespace

key = hashlib.sha256(b"test song|test artist").hexdigest()[:16]
lyrics_path = os.path.join(c.LYRICS_DIR, f"{key}.json")
c.atomic_write_json(lyrics_path, {"synced": "", "plain": "", "source": ""})
with patch.object(c.urllib.request, "urlopen", side_effect=TimeoutError) as lookup:
    assert not c.fetch_lyrics("Test Song", "Test Artist")["synced"]
    assert lookup.called, "a legacy negative cache prevented the lookup"
with patch.object(c.urllib.request, "urlopen", return_value=Reply([{"syncedLyrics": "[00:02] Hello"}])) as lookup:
    assert c.fetch_lyrics("Test Song", "Test Artist")["synced"] == "[00:02] Hello"
    assert lookup.call_count == 1
with patch.object(c.urllib.request, "urlopen", side_effect=AssertionError("positive cache missed")):
    assert c.fetch_lyrics("Test Song", "Test Artist")["synced"] == "[00:02] Hello"

# 6. Never resolve a direct stream with TLS verification disabled.
url = "https://www.youtube.com/watch?v=aaaaaaaaaaa"
fresh = "https://media.example/fresh"
with patch.object(c.subprocess, "run", return_value=SimpleNamespace(stdout=fresh, returncode=0)) as extract:
    assert c.resolve_youtube_stream_url(url) == fresh
    resolver_command = extract.call_args.args[0]
    assert "--no-check-certificates" not in resolver_command

# Validate the actual argv against the installed yt-dlp when available. --version
# exits before checking all options; --list-extractors checks them without network.
if c.shutil.which("yt-dlp"):
    parsed = c.subprocess.run(resolver_command[:-2] + ["--list-extractors"], capture_output=True, text=True, timeout=5)
    assert parsed.returncode == 0, parsed.stderr

from importlib import reload
reload(c)  # restore real play_item and IPC after the navigation checks

# 7. An accepted loadfile is not yet playback: wait for the matching entry's load result.
class MPVSocket:
    def __init__(self, messages):
        payload = b"".join(json.dumps(x).encode() + b"\n" for x in messages)
        self.chunks = iter([payload[:15], payload[15:], b""])

    def __enter__(self): return self
    def __exit__(self, *a): pass
    def settimeout(self, timeout): pass
    def connect(self, path): pass
    def sendall(self, data): pass
    def recv(self, size): return next(self.chunks)

open(c.SOCK_PATH, "w").close()
for event, expected in [("file-loaded", True), ("end-file", False)]:
    events = [
        {"request_id": 1, "error": "success", "data": {"playlist_entry_id": 9}},
        {"event": "end-file", "playlist_entry_id": 8, "reason": "error"},
        {"event": "start-file", "playlist_entry_id": 9},
        {"event": event, "playlist_entry_id": 9, "reason": "error", "file_error": "loading failed"},
    ]
    with patch.object(c, "_MPV_REQ_ID", 0), patch.object(c.socket, "socket", return_value=MPVSocket(events)):
        assert (c.load_mpv_file(fresh)["error"] == "success") is expected

# The retry bypasses the broken cache and preserves the requested seek position.
stale = "https://media.example/stale"
c.set_cached_stream_url(url, stale)
with patch.object(c, "start_mpv_daemon", return_value=True), patch.object(c, "start_spectrum_daemon"), \
     patch.object(c, "save_youtube_meta"), patch.object(c, "send_mpv_cmd", return_value={"error": "success"}), \
     patch.object(c, "_spawn_detached"), patch.object(c.subprocess, "run", return_value=SimpleNamespace(stdout=fresh, returncode=0)) as extract, \
     patch.object(c, "load_mpv_file", side_effect=[{"error": "loading failed"}, {"error": "success"}]) as load:
    assert c.play_item(url, "Test Song", "Test Artist", pos=32)["success"]
    assert [call.args for call in load.call_args_list] == [(stale, 32), (fresh, 32)]
    assert c.get_cached_stream_url(url) == fresh and extract.call_count == 1
with patch.object(c, "start_mpv_daemon", return_value=True), patch.object(c.subprocess, "run", return_value=SimpleNamespace(stdout=fresh, returncode=0)), \
     patch.object(c, "load_mpv_file", return_value={"error": "loading failed"}) as load:
    assert not c.play_item(url)["success"]
    assert load.call_count == 3 and load.call_args.args[0] == url  # cached, fresh, watch URL; no loop
    assert c.get_cached_stream_url(url) is None

# 8. Synthetic tones stay in their frequency range; opposite stereo phases
# don't cancel the spectrum, and the meter reports each channel separately.
import math, struct
import spectrum as s


def tone(hz, left, right):
    samples = [math.sin(2 * math.pi * hz * i / s.RATE) * 32767 for i in range(s.CHUNK)]
    return struct.pack(f"<{len(samples) * 2}h", *(int(vol * x) for x in samples for vol in (left, right)))


silence = [0.0] * s.NUM_BANDS
for numpy in [False, True] if s.HAVE_NUMPY else [False]:
    bass, wave, l_r = s.analyze_frame(tone(86, 0.5, -0.5), silence, numpy)
    assert max(bass[:7]) > 0.45 and max(bass[12:]) < 0.02
    assert len(wave) == s.WAVE_SAMPLES and max(wave) > 0.3
    assert all(abs(level - 0.354) < 0.02 for level in l_r)
    high, wave, l_r = s.analyze_frame(tone(6500, 0.0, 0.35), silence, numpy)
    assert high.index(max(high)) >= 19 and l_r[0] == 0 < l_r[1]
    assert all(-1 <= val <= 1 for val in wave)
    bands, wave, l_r = s.analyze_frame(tone(86, 0, 0), silence, numpy)
    assert not any(bands + wave + l_r)

# 9. The status poll reads all its properties over one connection: replies may come in any
# order with events between them, a property mpv lacks is still answered, and an mpv that is
# gone, or that never answers, reads as not running.
import socket, threading, time


def fake_mpv(reply):
    if os.path.exists(c.SOCK_PATH):
        os.remove(c.SOCK_PATH)
    server = socket.socket(socket.AF_UNIX)
    server.bind(c.SOCK_PATH)
    server.listen(1)
    seen = []

    def serve():
        conn, _ = server.accept()
        with conn:
            buf = b""
            while buf.count(b"\n") < 8:
                buf += conn.recv(65536)
            reqs = [json.loads(line) for line in buf.splitlines()]
            seen.append(reqs)
            if reply:
                out = [{"event": "audio-reconfig"}]
                for r in reversed(reqs):
                    name = r["command"][1]
                    out.append({"request_id": r["request_id"], "error": "property unavailable"} if name == "duration"
                               else {"request_id": r["request_id"], "error": "success", "data": reply.get(name)})
                    out.append({"event": "property-change"})
                conn.sendall("".join(json.dumps(o) + "\n" for o in out).encode())
            else:
                threading.Event().wait(1.5)
        server.close()

    threading.Thread(target=serve, daemon=True).start()
    return seen


state = {"idle-active": False, "time-pos": 12.5, "pause": False, "media-title": "Artist - Song",
         "volume": 70, "speed": 1.0, "eof-reached": False}
seen = fake_mpv(state)
st = c.get_status(allow_advance=False)
assert len(seen) == 1 and len(seen[0]) == 8, "one connection carries every property"
assert st["running"] and st["state"] == "playing" and st["cur_secs"] == 12.5 and st["volume_pct"] == 70
assert st["total_secs"] == 0 and st["speed"] == 1.0
fake_mpv(None)
started = time.monotonic()
assert c.get_status(allow_advance=False)["running"] is False
assert time.monotonic() - started < 1.5
os.remove(c.SOCK_PATH)
dead = socket.socket(socket.AF_UNIX)
dead.bind(c.SOCK_PATH)
dead.close()                       # a socket file nobody listens on: an mpv that died
assert c.get_status(allow_advance=False)["running"] is False and not os.path.exists(c.SOCK_PATH)
assert c.get_mpv_properties(["pause"]) is None

# 10. Direct drops and directory drops use the same audio filter and queue order.
from pathlib import Path

with tempfile.TemporaryDirectory() as folder:
    root = Path(folder)
    sub = root / "album"
    sub.mkdir()
    for name in ["notes.txt", "song B.MP3", "song A.wav", "album/c.flac"]:
        (root / name).touch()
    first, second, third = [str(root / name) for name in ("song A.wav", "song B.MP3", "album/c.flac")]
    with patch.object(c, "play_item", return_value={"success": True}) as play:
        c.save_queue([{"url": "/already-queued"}])
        assert not c.add_local([str(root / "notes.txt")])["success"]
        play.assert_not_called()
        assert c.add_local([str(root / "notes.txt"), folder]) == {"success": True, "count": 3}
        play.assert_called_once_with(first)
        assert [t["url"] for t in c.read_queue()] == ["/already-queued", second, third]
        with patch.object(c.subprocess, "run", return_value=SimpleNamespace(returncode=0, stdout=second + "\n", stderr="")):
            assert c.pick_local() == {"success": True, "count": 1}
            play.assert_called_with(second)
    with patch.object(c, "play_item") as play:
        for code, expected in [(1, True), (2, False)]:
            with patch.object(c.subprocess, "run", return_value=SimpleNamespace(returncode=code, stdout="", stderr="portal unavailable")):
                result = c.pick_local()
                assert result["success"] is expected
                if not expected: assert "portal unavailable" in result["error"]
        play.assert_not_called()

print("ok: playback, stream recovery, TLS, lyrics cache, stereo spectrum, status poll and local files")
