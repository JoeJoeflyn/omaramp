#!/usr/bin/env python3
"""Omaramp audio controller powered by mpv headless IPC with YouTube & local file support."""
import sys
import os
import subprocess
import json
import socket
import time
import re
import urllib.request
import urllib.parse

SOCK_PATH = f"/tmp/omaramp_mpv_{os.getuid()}.sock"
STREAM_FIFO = f"/tmp/omaramp_stream_{os.getuid()}"
CACHE_DIR = os.path.expanduser("~/.cache/omaramp")
AUDIO_CACHE_DIR = os.path.join(CACHE_DIR, "audio")
HISTORY_PATH = os.path.expanduser("~/.config/cliamp/history.toml")
NOW_PLAYING_PATH = os.path.join(CACHE_DIR, "now_playing.json")

os.makedirs(AUDIO_CACHE_DIR, exist_ok=True)
os.makedirs(os.path.expanduser("~/.config/cliamp"), exist_ok=True)
os.makedirs(CACHE_DIR, exist_ok=True)

def save_now_playing(title, artist, url="", pos=0):
    try:
        with open(NOW_PLAYING_PATH, "w", encoding="utf-8") as f:
            json.dump({"title": title or "", "artist": artist or "", "url": url or "", "pos": pos}, f)
    except Exception:
        pass

def read_now_playing():
    try:
        with open(NOW_PLAYING_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def send_mpv_cmd(cmd_list, timeout=1.0):
    if not os.path.exists(SOCK_PATH):
        return None
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect(SOCK_PATH)
        payload = json.dumps({"command": cmd_list}) + "\n"
        s.sendall(payload.encode("utf-8"))
        res = s.recv(4096).decode("utf-8")
        s.close()
        for line in res.splitlines():
            line = line.strip()
            if line:
                return json.loads(line)
    except Exception:
        return None
    return None

def is_mpv_running():
    if not os.path.exists(SOCK_PATH):
        return False
    res = send_mpv_cmd(["get_property", "idle-active"])
    return res is not None and res.get("error") == "success"

def start_spectrum_daemon():
    try:
        res = subprocess.run(["pgrep", "-f", "omaramp/spectrum.py"], capture_output=True, text=True)
        if not res.stdout.strip():
            spec_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "spectrum.py")
            subprocess.Popen(["python3", spec_script], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except Exception:
        pass

def stop_spectrum_daemon():
    try:
        subprocess.run(["pkill", "-f", "omaramp/spectrum.py"], capture_output=True)
    except Exception:
        pass

def start_mpv_daemon():
    if not is_mpv_running():
        if os.path.exists(SOCK_PATH):
            try:
                os.remove(SOCK_PATH)
            except Exception:
                pass
        cmd = [
            "mpv",
            "--no-video",
            "--idle=yes",
            "--ao=pipewire,pulse,alsa",
            "--ytdl-format=bestaudio/best",
            "--ytdl-raw-options=extractor-args=youtube:player_client=mweb",
            f"--input-ipc-server={SOCK_PATH}",
            "--keep-open=yes",
            "--volume=80"
        ]
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        for _ in range(15):
            time.sleep(0.1)
            if os.path.exists(SOCK_PATH):
                break

def record_history(title, artist, url, dur):
    try:
        # Escape backslashes, double quotes, and newlines for safe TOML string values
        def esc(s):
            return (s or "").replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ").replace("\r", "")
        entry = f'\n[[entry]]\nplayed_at = "{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}"\npath = "{esc(url)}"\ntitle = "{esc(title)}"\nartist = "{esc(artist)}"\nduration_secs = {int(dur or 0)}\n'
        with open(HISTORY_PATH, "a", encoding="utf-8") as f:
            f.write(entry)
    except Exception:
        pass

def parse_history(limit=30):
    if not os.path.exists(HISTORY_PATH):
        return []
    try:
        with open(HISTORY_PATH, "r", encoding="utf-8") as f:
            content = f.read()
        entries = []
        raw_blocks = content.split("[[entry]]")
        for b in reversed(raw_blocks):
            b = b.strip()
            if not b:
                continue
            item = {}
            for line in b.splitlines():
                if "=" in line:
                    k, v = line.split("=", 1)
                    k = k.strip()
                    v = v.strip().strip('"')
                    if k == "duration_secs":
                        try:
                            item[k] = int(v)
                        except ValueError:
                            item[k] = 0
                    else:
                        item[k] = v
            if item.get("title") or item.get("path"):
                # Add thumbnail path for YouTube URLs
                m = re.search(r"(?:v=|youtu\.be/)([0-9A-Za-z_-]{11})", item.get("path", ""))
                if m:
                    item["thumb"] = os.path.join(AUDIO_CACHE_DIR, f"{m.group(1)}.jpg")
                entries.append(item)
            if len(entries) >= limit:
                break
        return entries
    except Exception:
        return []

def format_seconds(secs):
    if not secs or secs < 0:
        return "00:00"
    m = int(secs // 60)
    s = int(secs % 60)
    return f"{m:02d}:{s:02d}"

def get_status():
    if not is_mpv_running():
        return {
            "running": False,
            "state": "stopped",
            "track": "No track loaded",
            "artist": "Omaramp",
            "time_current": "00:00",
            "time_total": "00:00",
            "cur_secs": 0,
            "total_secs": 0,
            "progress": 0.0,
            "volume_db": 0,
            "volume_pct": 80,
            "shuffle": False,
            "repeat": "off",
            "eq": "Custom"
        }

    try:
        np = read_now_playing()
        pos_res = send_mpv_cmd(["get_property", "time-pos"])
        dur_res = send_mpv_cmd(["get_property", "duration"])
        pause_res = send_mpv_cmd(["get_property", "pause"])
        title_res = send_mpv_cmd(["get_property", "media-title"])
        vol_res = send_mpv_cmd(["get_property", "volume"])
        speed_res = send_mpv_cmd(["get_property", "speed"])
        idle_res = send_mpv_cmd(["get_property", "idle-active"])

        is_idle = idle_res.get("data") is True if idle_res else False
        is_paused = pause_res.get("data") is True if pause_res else False

        if is_idle:
            state = "stopped"
        elif is_paused:
            state = "paused"
        else:
            state = "playing"

        cur_s = float(pos_res.get("data") or 0) if (pos_res and pos_res.get("data") is not None) else 0.0
        tot_s = float(dur_res.get("data") or 0) if (dur_res and dur_res.get("data") is not None) else 0.0
        prog = (cur_s / tot_s) if tot_s > 0 else 0.0

        raw_title = str(title_res.get("data") or "") if title_res else ""
        artist = ""
        track = raw_title or "Omaramp"
        art_path = ""
        # When streaming via FIFO, mpv shows the filename — use saved now-playing metadata
        if raw_title in ("omaramp_stream", STREAM_FIFO, os.path.basename(STREAM_FIFO)):
            np = read_now_playing()
            if np.get("title"):
                track = np["title"]
                artist = np.get("artist", "")
                # Look up thumbnail from now-playing URL
                np_url = np.get("url", "")
                if np_url:
                    m = re.search(r"(?:v=|youtu\.be/)([0-9A-Za-z_-]{11})", np_url)
                    if m:
                        thumb_f = os.path.join(AUDIO_CACHE_DIR, f"{m.group(1)}.jpg")
                        if os.path.exists(thumb_f):
                            art_path = thumb_f
        vid_match = re.match(r"^(?:play_)?([0-9A-Za-z_-]{11})\.(?:mp3|mp4|m4a|webm)$", raw_title)
        if vid_match:
            vid_id = vid_match.group(1)
            meta_f = os.path.join(AUDIO_CACHE_DIR, f"{vid_id}.json")
            if os.path.exists(meta_f):
                try:
                    with open(meta_f, "r", encoding="utf-8") as f:
                        meta = json.load(f)
                        track = meta.get("title", track)
                        artist = meta.get("artist", "")
                except Exception:
                    pass
            thumb_f = os.path.join(AUDIO_CACHE_DIR, f"{vid_id}.jpg")
            if os.path.exists(thumb_f):
                art_path = thumb_f
        elif " - " in raw_title:
            p = raw_title.split(" - ", 1)
            artist = p[0].strip()
            track = p[1].strip()

        vol_data = vol_res.get("data") if vol_res else None
        vol = int(vol_data) if vol_data is not None else 80

        if state == "playing" and cur_s > 0 and int(cur_s) % 10 == 0:
            np = read_now_playing()
            if np.get("url"):
                save_now_playing(track, artist, np.get("url", ""), int(cur_s))

        resume = {"title": np.get("title", ""), "artist": np.get("artist", ""), "url": np.get("url", ""), "pos": np.get("pos", 0)} if np.get("url") else None

        return {
            "running": True,
            "state": state,
            "track": track,
            "artist": artist,
            "art_path": art_path,
            "url": np.get("url", ""),
            "time_current": format_seconds(cur_s),
            "time_total": format_seconds(tot_s),
            "cur_secs": int(cur_s),
            "total_secs": int(tot_s),
            "progress": round(prog, 3),
            "volume_db": round((vol / 100.0) * 36.0 - 30.0, 1),
            "volume_pct": vol,
            "speed": round(float(speed_res.get("data") or 1.0), 2) if speed_res else 1.0,
            "shuffle": False,
            "repeat": "all",
            "eq": "Custom",
            "resume": resume
        }
    except Exception as e:
        return {
            "running": False,
            "state": "stopped",
            "error": str(e),
            "track": "Omaramp",
            "artist": "",
            "time_current": "00:00",
            "time_total": "00:00",
            "cur_secs": 0,
            "total_secs": 0,
            "progress": 0.0,
            "volume_db": 0,
            "volume_pct": 80,
            "shuffle": False,
            "repeat": "off",
            "eq": "Custom"
        }

def search_tracks(query, limit=10):
    if not query or not query.strip():
        return []
    cmd = [
        "yt-dlp",
        "--flat-playlist",
        "--print", "%(id)s\t%(title)s\t%(uploader)s\t%(duration_string)s",
        f"ytsearch{limit}:{query.strip()}"
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=8.0)
        results = []
        for line in (res.stdout or "").splitlines():
            parts = line.split("\t")
            if len(parts) >= 2:
                vid = parts[0].strip()
                title = parts[1].strip()
                uploader = parts[2].strip() if len(parts) > 2 else ""
                dur = parts[3].strip() if len(parts) > 3 else ""
                results.append({
                    "id": vid,
                    "url": f"https://www.youtube.com/watch?v={vid}",
                    "title": title,
                    "artist": uploader,
                    "duration": dur,
                    "thumb": os.path.join(AUDIO_CACHE_DIR, f"{vid}.jpg")
                })
                # Prefetch thumbnail in background so it's ready when shown
                thumb_f = os.path.join(AUDIO_CACHE_DIR, f"{vid}.jpg")
                if not os.path.exists(thumb_f):
                    try:
                        urllib.request.urlretrieve(f"https://img.youtube.com/vi/{vid}/mqdefault.jpg", thumb_f)
                    except Exception:
                        pass
        return results
    except Exception:
        return []


def is_youtube_url(url):
    if not url:
        return False
    parsed = urllib.parse.urlparse(url)
    return parsed.scheme in ("http", "https") and parsed.netloc in ("www.youtube.com", "youtube.com", "youtu.be", "music.youtube.com")

def is_safe_url(url):
    if not url:
        return False
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme in ("http", "https"):
        return True
    if parsed.scheme == "file":
        return False
    if not parsed.scheme and not parsed.netloc:
        return os.path.isfile(url)
    return False

LYRICS_CACHE = {}
def fetch_lyrics(title, artist, url=""):
    key = (title or "").strip().lower() + "|" + (artist or "").strip().lower()
    if key in LYRICS_CACHE:
        return LYRICS_CACHE[key]
    try:
        search_title = re.sub(r'\s*[\(\[].*[\)\]]', '', title or "").strip()
        search_artist = (artist or "").strip()

        # If title is short and we have a YouTube URL, get the real full title
        if " - " not in search_title and is_youtube_url(url or ""):
            try:
                vid = re.search(r"(?:v=|youtu\.be/)([0-9A-Za-z_-]{11})", url).group(1)
                r = subprocess.run(["yt-dlp", "--no-warnings", "--print", "%(title)s", f"https://www.youtube.com/watch?v={vid}"],
                                   capture_output=True, text=True, timeout=5)
                full_title = r.stdout.strip()
                if full_title and " - " in full_title:
                    search_title = re.sub(r'\s*[\(\[].*[\)\]]', '', full_title).strip()
                    parts = search_title.split(" - ", 1)
                    search_artist = parts[0].strip()
                    search_title = parts[1].strip()
            except Exception:
                pass

        # If title has "Artist - Track", split it
        if " - " in search_title:
            parts = search_title.split(" - ", 1)
            search_artist = parts[0].strip()
            search_title = parts[1].strip()

        # Try with artist
        data = []
        if search_artist:
            u = f"https://lrclib.net/api/search?artist_name={urllib.parse.quote(search_artist)}&track_name={urllib.parse.quote(search_title)}"
            res = urllib.request.urlopen(u, timeout=5)
            data = json.loads(res.read())
        # Fallback: track name only
        if not data:
            u = f"https://lrclib.net/api/search?q={urllib.parse.quote(search_title)}"
            res = urllib.request.urlopen(u, timeout=5)
            data = json.loads(res.read())
        result = {"synced": "", "plain": "", "source": ""}
        for e in data:
            if e.get("syncedLyrics"):
                result = {"synced": e["syncedLyrics"], "plain": e.get("plainLyrics", ""), "source": "lrclib"}
                break
        if not result["synced"]:
            for e in data:
                if e.get("plainLyrics"):
                    result = {"synced": "", "plain": e["plainLyrics"], "source": "lrclib"}
                    break
        LYRICS_CACHE[key] = result
        return result
    except Exception:
        return {"synced": "", "plain": "", "source": ""}

def save_youtube_meta(url, title, artist):
    """Save title/artist metadata and fetch thumbnail so get_status can show the real track name + art."""
    vid_id = ""
    m = re.search(r"(?:v=|youtu\.be/)([0-9A-Za-z_-]{11})", url)
    if m:
        vid_id = m.group(1)
    if vid_id and (title or artist):
        meta_f = os.path.join(AUDIO_CACHE_DIR, f"{vid_id}.json")
        try:
            with open(meta_f, "w", encoding="utf-8") as f:
                json.dump({"title": title or "", "artist": artist or ""}, f)
        except Exception:
            pass
        # Fetch thumbnail (mqdefault.jpg = 320x180, good quality for small UI)
        thumb_f = os.path.join(AUDIO_CACHE_DIR, f"{vid_id}.jpg")
        if not os.path.exists(thumb_f):
            try:
                urllib.request.urlretrieve(f"https://img.youtube.com/vi/{vid_id}/mqdefault.jpg", thumb_f)
            except Exception:
                pass

def stream_youtube(url):
    """Stream YouTube audio to mpv via a FIFO pipe — no disk download."""
    # Kill any previous yt-dlp stream process
    try:
        subprocess.run(["pkill", "-f", "yt-dlp.*omaramp_stream"], capture_output=True)
    except Exception:
        pass
    # Recreate the FIFO
    try:
        os.remove(STREAM_FIFO)
    except Exception:
        pass
    try:
        os.mkfifo(STREAM_FIFO)
    except Exception:
        pass
    # Open the FIFO read end ourselves so the writer (yt-dlp) never blocks
    # even if mpv is slow to open the read end. This prevents the deadlock
    # where open(FIFO, "wb") blocks before Popen can fork.
    read_fd = os.open(STREAM_FIFO, os.O_RDONLY | os.O_NONBLOCK)
    write_fd = os.open(STREAM_FIFO, os.O_WRONLY)
    os.close(read_fd)  # Close our dummy reader — mpv will take over
    subprocess.Popen(
        ["yt-dlp", "--no-warnings", "-f", "18/best", "-o", "-", url],
        stdout=os.fdopen(write_fd, "wb"),
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )

def fade_volume(target, steps=8, delay=0.04):
    cur_res = send_mpv_cmd(["get_property", "volume"])
    if not cur_res or cur_res.get("data") is None:
        return
    cur = float(cur_res["data"])
    if abs(cur - target) < 1:
        return
    step = (target - cur) / steps
    for i in range(steps):
        cur += step
        send_mpv_cmd(["set_property", "volume", round(cur, 1)])
        time.sleep(delay)

def play_item(url, title=None, artist=None):
    if not url or not is_safe_url(url):
        return {"success": False, "error": "unsafe url"}
    start_mpv_daemon()
    final_title = title or "Track"
    final_artist = artist or ""
    record_history(final_title, final_artist, url, 0)
    # Save current volume for fade-in target
    vol_res = send_mpv_cmd(["get_property", "volume"])
    target_vol = float(vol_res.get("data") or 80) if vol_res else 80
    # Fade out current track
    state_res = send_mpv_cmd(["get_property", "pause"])
    if state_res and state_res.get("data") is False:
        fade_volume(0, steps=6, delay=0.05)
    if is_youtube_url(url):
        save_youtube_meta(url, final_title, final_artist)
        save_now_playing(final_title, final_artist, url)
        stream_youtube(url)
        send_mpv_cmd(["loadfile", STREAM_FIFO, "replace"])
        send_mpv_cmd(["set_property", "pause", False])
        send_mpv_cmd(["set_property", "volume", 0])
        time.sleep(1.5)
        fade_volume(target_vol, steps=8, delay=0.05)
        return {"success": True}
    save_now_playing(final_title, final_artist, url)
    send_mpv_cmd(["loadfile", url, "replace"])
    send_mpv_cmd(["set_property", "pause", False])
    send_mpv_cmd(["set_property", "volume", 0])
    time.sleep(0.5)
    fade_volume(target_vol, steps=8, delay=0.05)
    return {"success": True}

def queue_item(url, title=None, artist=None):
    if not url or not is_safe_url(url):
        return {"success": False, "error": "unsafe url"}
    start_mpv_daemon()
    final_title = title or "Track"
    final_artist = artist or ""
    record_history(final_title, final_artist, url, 0)
    if is_youtube_url(url):
        save_youtube_meta(url, final_title, final_artist)
        save_now_playing(final_title, final_artist, url)
        stream_youtube(url)
        send_mpv_cmd(["loadfile", STREAM_FIFO, "append"])
        return {"success": True}
    save_now_playing(final_title, final_artist, url)
    send_mpv_cmd(["loadfile", url, "append"])
    return {"success": True}

def stop_daemon():
    if os.path.exists(SOCK_PATH):
        send_mpv_cmd(["quit"])
        try:
            os.remove(SOCK_PATH)
        except Exception:
            pass
    return {"success": True}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps(get_status()))
        sys.exit(0)

    action = sys.argv[1]
    if action == "status":
        print(json.dumps(get_status()))
    elif action == "history":
        lim = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        print(json.dumps(parse_history(lim)))
    elif action == "playlists":
        print(json.dumps([{"name": "Recently Played", "count": len(parse_history(100))}]))
    elif action == "search":
        q = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else ""
        print(json.dumps(search_tracks(q, 10)))
    elif action == "play":
        start_mpv_daemon()
        send_mpv_cmd(["set_property", "pause", False])
        print(json.dumps({"success": True}))
    elif action == "pause":
        send_mpv_cmd(["set_property", "pause", True])
        print(json.dumps({"success": True}))
    elif action == "toggle":
        start_mpv_daemon()
        send_mpv_cmd(["cycle", "pause"])
        print(json.dumps({"success": True}))
    elif action == "start_spectrum":
        start_spectrum_daemon()
        print(json.dumps({"success": True}))
    elif action == "stop_spectrum":
        stop_spectrum_daemon()
        print(json.dumps({"success": True}))
    elif action == "speed":
        s = sys.argv[2] if len(sys.argv) > 2 else "1.0"
        send_mpv_cmd(["set_property", "speed", float(s)])
        print(json.dumps({"success": True}))
    elif action == "stop":
        pos_res = send_mpv_cmd(["get_property", "time-pos"])
        np = read_now_playing()
        if np.get("url") and pos_res and pos_res.get("data"):
            save_now_playing(np.get("title", ""), np.get("artist", ""), np.get("url", ""), int(float(pos_res["data"])))
        send_mpv_cmd(["stop"])
        print(json.dumps({"success": True}))
    elif action == "next":
        send_mpv_cmd(["playlist-next"])
        print(json.dumps({"success": True}))
    elif action == "prev":
        send_mpv_cmd(["playlist-prev"])
        print(json.dumps({"success": True}))
    elif action == "seek":
        sec = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
        send_mpv_cmd(["seek", sec, "absolute"])
        print(json.dumps({"success": True}))
    elif action in ["volume", "volume_pct"]:
        pct = float(sys.argv[2]) if len(sys.argv) > 2 else 80.0
        send_mpv_cmd(["set_property", "volume", pct])
        print(json.dumps({"success": True}))
    elif action == "play_item":
        url = sys.argv[2] if len(sys.argv) > 2 else ""
        t = sys.argv[3] if len(sys.argv) > 3 else ""
        a = sys.argv[4] if len(sys.argv) > 4 else ""
        print(json.dumps(play_item(url, t, a)))
    elif action == "queue":
        url = sys.argv[2] if len(sys.argv) > 2 else ""
        t = sys.argv[3] if len(sys.argv) > 3 else ""
        a = sys.argv[4] if len(sys.argv) > 4 else ""
        print(json.dumps(queue_item(url, t, a)))
    elif action == "stop_daemon":
        print(json.dumps(stop_daemon()))
    elif action == "lyrics":
        t = sys.argv[2] if len(sys.argv) > 2 else ""
        a = sys.argv[3] if len(sys.argv) > 3 else ""
        u = sys.argv[4] if len(sys.argv) > 4 else ""
        print(json.dumps(fetch_lyrics(t, a, u)))
    elif action == "resume_info":
        np = read_now_playing()
        print(json.dumps({"title": np.get("title", ""), "artist": np.get("artist", ""), "url": np.get("url", ""), "pos": np.get("pos", 0)}))
    elif action == "resume":
        np = read_now_playing()
        url = np.get("url", "")
        if not url:
            print(json.dumps({"success": False, "error": "no saved track"}))
        else:
            pos = int(np.get("pos", 0))
            play_item(url, np.get("title", ""), np.get("artist", ""))
            if pos > 5:
                for _ in range(20):
                    time.sleep(0.5)
                    dur = send_mpv_cmd(["get_property", "duration"])
                    if dur and dur.get("data") and float(dur["data"]) > 0:
                        break
                time.sleep(1)
                send_mpv_cmd(["seek", pos, "absolute"])
            print(json.dumps({"success": True}))
    else:
        print(json.dumps({"error": f"Unknown action {action}"}))
