#!/usr/bin/env python3
"""Omaramp audio controller powered by mpv headless IPC with YouTube & local file support."""
import sys
import os
import subprocess
import json
import socket
import time
import re
import signal
import shutil
import urllib.request
import urllib.parse
try:
    import tomllib
except ImportError:
    tomllib = None

RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR")
if RUNTIME_DIR and os.path.isdir(RUNTIME_DIR):
    RUN_DIR = os.path.join(RUNTIME_DIR, "omaramp")
else:
    RUN_DIR = os.path.expanduser("~/.cache/omaramp/run")

os.makedirs(RUN_DIR, mode=0o700, exist_ok=True)
try:
    os.chmod(RUN_DIR, 0o700)
except Exception:
    pass

SOCK_PATH = os.path.join(RUN_DIR, "mpv.sock")
STREAM_FIFO = os.path.join(RUN_DIR, "stream.fifo")
STREAM_PID_FILE = os.path.join(RUN_DIR, "stream_ytdlp.pid")
SPECTRUM_PID_FILE = os.path.join(RUN_DIR, "spectrum.pid")

CACHE_DIR = os.path.expanduser("~/.cache/omaramp")
AUDIO_CACHE_DIR = os.path.join(CACHE_DIR, "audio")
HISTORY_PATH = os.path.expanduser("~/.config/cliamp/history.toml")
NOW_PLAYING_PATH = os.path.join(CACHE_DIR, "now_playing.json")
QUEUE_PATH = os.path.join(CACHE_DIR, "queue.json")
STREAM_CACHE_PATH = os.path.join(CACHE_DIR, "stream_cache.json")

def get_cached_stream_url(url):
    if not url or not os.path.exists(STREAM_CACHE_PATH):
        return None
    try:
        with open(STREAM_CACHE_PATH, "r", encoding="utf-8") as f:
            cache = json.load(f)
        entry = cache.get(url)
        if entry:
            if time.time() - entry.get("timestamp", 0) < 14400:
                return entry.get("direct_url")
    except Exception:
        pass
    return None

def set_cached_stream_url(url, direct_url):
    if not url or not direct_url:
        return
    try:
        cache = {}
        if os.path.exists(STREAM_CACHE_PATH):
            try:
                with open(STREAM_CACHE_PATH, "r", encoding="utf-8") as f:
                    cache = json.load(f)
            except Exception:
                cache = {}
        cache[url] = {
            "direct_url": direct_url,
            "timestamp": time.time()
        }
        if len(cache) > 100:
            oldest = sorted(cache.keys(), key=lambda k: cache[k].get("timestamp", 0))[:20]
            for k in oldest:
                cache.pop(k, None)
        with open(STREAM_CACHE_PATH, "w", encoding="utf-8") as f:
            json.dump(cache, f)
    except Exception:
        pass

os.makedirs(AUDIO_CACHE_DIR, mode=0o700, exist_ok=True)
os.makedirs(os.path.expanduser("~/.config/cliamp"), mode=0o700, exist_ok=True)
os.makedirs(CACHE_DIR, mode=0o700, exist_ok=True)
try:
    os.chmod(CACHE_DIR, 0o700)
    os.chmod(AUDIO_CACHE_DIR, 0o700)
except Exception:
    pass

def get_process_starttime(pid):
    """Retrieve process start time from /proc/<pid>/stat to detect PID reuse."""
    try:
        with open(f"/proc/{pid}/stat", "r") as f:
            stat_content = f.read()
        rparen = stat_content.rfind(")")
        if rparen != -1:
            fields = stat_content[rparen + 2:].split()
            if len(fields) >= 20:
                return int(fields[19])
    except Exception:
        pass
    return None

def verify_process_identity(pid, expected_signature, expected_starttime):
    """Verify that PID is alive, owned by current user, strictly matches expected starttime and cmdline signature."""
    if not isinstance(pid, int) or pid <= 0:
        return False
    if not isinstance(expected_starttime, int) or expected_starttime <= 0:
        return False
    if not expected_signature:
        return False

    proc_dir = f"/proc/{pid}"
    if not os.path.isdir(proc_dir):
        return False
    try:
        # 1. Check process ownership
        stat = os.stat(proc_dir)
        if stat.st_uid != os.getuid():
            return False

        # 2. Strictly check starttime to guarantee PID has not been recycled
        cur_starttime = get_process_starttime(pid)
        if cur_starttime is None or cur_starttime != expected_starttime:
            return False

        # 3. Check cmdline signature
        cmdline_file = os.path.join(proc_dir, "cmdline")
        with open(cmdline_file, "rb") as f:
            raw_cmdline = f.read().decode("utf-8", errors="replace")
        args = [a for a in raw_cmdline.split("\x00") if a]
        full_cmd = " ".join(args)
        if isinstance(expected_signature, str):
            if expected_signature not in full_cmd:
                return False
        elif isinstance(expected_signature, (list, tuple)):
            for sig in expected_signature:
                if sig not in full_cmd:
                    return False
        return True
    except Exception:
        return False

def terminate_tracked_pid(pid_file, expected_signature):
    """Safely terminate only the specific process if its identity matches the tracked JSON record with bound starttime.
    Legacy or malformed PID files are strictly cleaned up without signaling."""
    if not os.path.exists(pid_file):
        return
    try:
        with open(pid_file, "r", encoding="utf-8") as f:
            content = f.read().strip()

        # Strictly require JSON record containing bound starttime — reject legacy numeric formats
        if not content.startswith("{"):
            return

        data = json.loads(content)
        pid = data.get("pid")
        expected_starttime = data.get("starttime")
        sig = data.get("signature") or expected_signature

        if (isinstance(pid, int) and pid > 0 and 
            isinstance(expected_starttime, int) and expected_starttime > 0 and
            verify_process_identity(pid, expected_signature=sig, expected_starttime=expected_starttime)):
            try:
                os.kill(pid, signal.SIGTERM)
                for _ in range(6):
                    time.sleep(0.05)
                    if not verify_process_identity(pid, expected_signature=sig, expected_starttime=expected_starttime):
                        break
                if verify_process_identity(pid, expected_signature=sig, expected_starttime=expected_starttime):
                    os.kill(pid, signal.SIGKILL)
            except Exception:
                pass
    except Exception:
        pass
    finally:
        try:
            os.remove(pid_file)
        except Exception:
            pass

def save_tracked_proc(pid_file, pid, signature=None):
    """Record spawned process PID, starttime, and signature with owner-only 0o600 permissions."""
    try:
        starttime = get_process_starttime(pid)
        payload = json.dumps({
            "pid": pid,
            "signature": signature,
            "starttime": starttime,
            "saved_at": time.time()
        })
        fd = os.open(pid_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with open(fd, "w", encoding="utf-8") as f:
            f.write(payload)
        try:
            os.chmod(pid_file, 0o600)
        except Exception:
            pass
    except Exception:
        pass

def read_queue():
    if os.path.exists(QUEUE_PATH):
        try:
            with open(QUEUE_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return []

def save_queue(q_list):
    try:
        with open(QUEUE_PATH, "w", encoding="utf-8") as f:
            json.dump(q_list, f, indent=2)
    except Exception:
        pass

def add_to_queue(url, title=None, artist=None):
    real_url, final_title, final_artist = resolve_track_url(url, title, artist)
    if not real_url:
        return {"success": False, "error": "Unable to resolve track"}
    status = get_status()
    if not status.get("running") or status.get("state") in ("stopped", "idle"):
        return play_item(real_url, final_title, final_artist)
    q = read_queue()
    m = re.search(r"(?:v=|youtu\.be/)([0-9A-Za-z_-]{11})", real_url)
    thumb = os.path.join(AUDIO_CACHE_DIR, f"{m.group(1)}.jpg") if m else ""
    q.append({
        "url": real_url,
        "title": final_title,
        "artist": final_artist,
        "thumb": thumb
    })
    save_queue(q)
    return {"success": True, "queue": q}

def remove_from_queue(idx):
    q = read_queue()
    try:
        i = int(idx)
        if 0 <= i < len(q):
            q.pop(i)
            save_queue(q)
            return {"success": True, "queue": q}
    except Exception:
        pass
    return {"success": False}

def clear_queue():
    save_queue([])
    return {"success": True}

def play_next_in_queue():
    q = read_queue()
    if q:
        next_track = q.pop(0)
        save_queue(q)
        return play_item(next_track["url"], next_track.get("title"), next_track.get("artist"))
    return {"success": False, "error": "Queue empty"}

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

def is_mpv_running(timeout=0.2):
    if not os.path.exists(SOCK_PATH):
        return False
    res = send_mpv_cmd(["get_property", "idle-active"], timeout=timeout)
    return res is not None and res.get("error") == "success"

def start_spectrum_daemon():
    if os.path.exists(SPECTRUM_PID_FILE):
        try:
            with open(SPECTRUM_PID_FILE, "r", encoding="utf-8") as f:
                content = f.read().strip()
            if content.startswith("{"):
                d = json.loads(content)
                pid = d.get("pid")
                st = d.get("starttime")
                if (isinstance(pid, int) and pid > 0 and 
                    isinstance(st, int) and st > 0 and 
                    verify_process_identity(pid, expected_signature="spectrum.py", expected_starttime=st)):
                    return
        except Exception:
            pass
    try:
        spec_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "spectrum.py")
        proc = subprocess.Popen(["python3", spec_script], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        save_tracked_proc(SPECTRUM_PID_FILE, proc.pid, signature="spectrum.py")
    except Exception:
        pass

def stop_spectrum_daemon():
    terminate_tracked_pid(SPECTRUM_PID_FILE, expected_signature="spectrum.py")

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
            f"--input-ipc-server={SOCK_PATH}",
            "--title=Omaramp",
            "--script-opts=mpris-identity=Omaramp",
            "--keep-open=yes",
            "--volume=80",
            "--demuxer-lavf-probesize=32768",
            "--demuxer-lavf-buffersize=32768",
            "--cache=yes",
            "--demuxer-max-bytes=10M",
            "--demuxer-readahead-secs=30"
        ]
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        for _ in range(30):
            time.sleep(0.05)
            if is_mpv_running(timeout=0.1):
                break
        apply_audio_fx()

def record_history(title, artist, url, dur):
    try:
        def esc(s):
            return (s or "").replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ").replace("\r", "")
        entry = f'\n[[entry]]\nplayed_at = "{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}"\npath = "{esc(url)}"\ntitle = "{esc(title)}"\nartist = "{esc(artist)}"\nduration_secs = {int(dur or 0)}\n'
        with open(HISTORY_PATH, "a", encoding="utf-8") as f:
            f.write(entry)
    except Exception:
        pass

def parse_history(limit=500):
    if not os.path.exists(HISTORY_PATH):
        return []
    try:
        if tomllib:
            with open(HISTORY_PATH, "rb") as f:
                data = tomllib.load(f)
            entries = []
            seen_keys = set()
            for item in reversed(data.get("entry", [])):
                title = str(item.get("title") or "").strip()
                path = str(item.get("path") or "").strip()
                artist = str(item.get("artist") or "").strip()
                if title or path:
                    # If this is a local file path, check if it still exists on disk
                    if path and not path.startswith(("http://", "https://", "yt:", "spotify:")):
                        expanded = os.path.expanduser(path)
                        if os.path.isabs(expanded) and not os.path.exists(expanded):
                            # File was deleted/moved from disk, prune from recents list
                            continue

                    m = re.search(r"(?:v=|youtu\.be/)([0-9A-Za-z_-]{11})", path)
                    if m:
                        vid_id = m.group(1)
                        dedup_key = f"yt:{vid_id}"
                        item["thumb"] = os.path.join(AUDIO_CACHE_DIR, f"{vid_id}.jpg")
                    elif path:
                        dedup_key = f"path:{path}"
                    else:
                        dedup_key = f"meta:{title.lower()}::{artist.lower()}"

                    if dedup_key in seen_keys:
                        continue
                    seen_keys.add(dedup_key)
                    entries.append(item)
                if len(entries) >= limit:
                    break
            return entries
    except Exception:
        pass
    return []

PLAYLISTS_FILE = os.path.join(CACHE_DIR, "playlists.json")

def parse_playlists():
    if os.path.exists(PLAYLISTS_FILE):
        try:
            with open(PLAYLISTS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return []

def save_playlists(pl_list):
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(PLAYLISTS_FILE, "w", encoding="utf-8") as f:
            json.dump(pl_list, f, indent=2)
    except Exception:
        pass

def delete_playlist(name):
    if not name:
        return {"success": False}
    playlists = parse_playlists()
    playlists = [p for p in playlists if p.get("name") != name]
    save_playlists(playlists)
    return {"success": True}

def import_playlist(url, custom_name=None):
    if not url or not is_safe_url(url):
        return {"success": False, "error": "Invalid or unsafe URL"}

    tracks = []
    pl_name = (custom_name or "").strip()

    # 1. YouTube Playlist
    if "list=" in url or "youtube.com" in url or "youtu.be" in url:
        try:
            if not pl_name:
                t_cmd = ["yt-dlp", "--flat-playlist", "--print", "%(playlist_title)s", "--playlist-items", "1", "--", url]
                t_res = subprocess.run(t_cmd, capture_output=True, text=True, timeout=6.0)
                pl_name = t_res.stdout.strip().splitlines()[0] if t_res.stdout.strip() else ""
            
            cmd = [
                "yt-dlp",
                "--flat-playlist",
                "--max-downloads", "500",
                "--print", "%(id)s\t%(title)s\t%(uploader)s\t%(duration_string)s",
                "--",
                url
            ]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=12.0)
            for line in (res.stdout or "").splitlines():
                parts = line.split("\t")
                if len(parts) >= 2 and parts[0]:
                    vid = parts[0].strip()
                    t = parts[1].strip() if len(parts) > 1 else "Track"
                    a = parts[2].strip() if len(parts) > 2 else ""
                    d = parts[3].strip() if len(parts) > 3 else ""
                    tracks.append({
                        "id": vid,
                        "title": t,
                        "artist": a,
                        "duration": d,
                        "url": f"https://www.youtube.com/watch?v={vid}"
                    })
        except Exception as e:
            return {"success": False, "error": str(e)}

    # 2. Spotify Playlist / Album
    elif "spotify.com" in url:
        try:
            embed_url = url
            if "/playlist/" in url or "/album/" in url:
                embed_url = re.sub(r"spotify\.com/(playlist|album)/", r"spotify.com/embed/\1/", url)
            
            req = urllib.request.Request(embed_url, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"})
            html = urllib.request.urlopen(req, timeout=8.0).read().decode("utf-8")
            
            m = re.search(r'<script id="__NEXT_DATA__" type="application/json">([\s\S]*?)</script>', html)
            if m:
                data = json.loads(m.group(1))
                entity = data.get("props", {}).get("pageProps", {}).get("state", {}).get("data", {}).get("entity", {})
                if not pl_name:
                    pl_name = entity.get("name") or "Spotify Playlist"
                track_list = entity.get("trackList", [])
                for t in track_list:
                    title = t.get("title", "").strip()
                    artist = t.get("subtitle", "").strip()
                    dur = format_seconds(int(t.get("duration", 0) / 1000)) if t.get("duration") else ""
                    if title:
                        tracks.append({
                            "id": "",
                            "title": title,
                            "artist": artist,
                            "duration": dur,
                            "url": f"{title} {artist}"
                        })
            if not tracks:
                if not pl_name:
                    title_m = re.search(r"<title>(.*?)(?: - playlist by| \| Spotify)</title>", html)
                    pl_name = title_m.group(1).strip() if title_m else "Spotify Playlist"
                for m in re.finditer(r'itemprop="name" content="([^"]+)".*?itemprop="description" content="([^"]+)"', html):
                    t = m.group(1).strip()
                    a = m.group(2).strip()
                    tracks.append({
                        "id": "",
                        "title": t,
                        "artist": a,
                        "duration": "",
                        "url": f"{t} {a}"
                    })
        except Exception as e:
            return {"success": False, "error": str(e)}

    if not tracks:
        return {"success": False, "error": "No tracks found in playlist URL"}

    pl_name = pl_name or f"Imported Playlist ({len(tracks)})"

    playlists = parse_playlists()
    existing = False
    for pl in playlists:
        if pl.get("name") == pl_name:
            pl["tracks"] = tracks
            existing = True
            break
    if not existing:
        playlists.append({"name": pl_name, "tracks": tracks})
    
    save_playlists(playlists)
    return {"success": True, "name": pl_name, "count": len(tracks)}

def format_seconds(secs):
    if not secs or secs < 0:
        return "00:00"
    m = int(secs // 60)
    s = int(secs % 60)
    return f"{m:02d}:{s:02d}"

EQ_PRESETS = {
    "Flat": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    "Bass Boost": [7.0, 6.0, 5.0, 3.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    "Rock": [5.0, 4.0, 2.0, -1.0, -2.0, -1.0, 2.0, 4.0, 5.0, 6.0],
    "Electronic": [6.0, 5.0, 2.0, 0.0, -2.0, 2.0, 1.0, 3.0, 5.0, 6.0],
    "Pop": [-1.0, 1.0, 3.0, 4.0, 4.0, 2.0, 0.0, 1.0, 2.0, 2.0],
    "Vocal Clarity": [-3.0, -2.0, 0.0, 2.0, 4.0, 5.0, 4.0, 2.0, 0.0, -2.0],
    "Acoustic": [4.0, 3.0, 2.0, 1.0, -1.0, -1.0, 0.0, 2.0, 3.0, 3.0],
    "Treble Boost": [0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 3.0, 5.0, 7.0, 8.0],
    "Late Night": [-6.0, -4.0, -2.0, 1.0, 3.0, 3.0, 2.0, 1.0, 0.0, -1.0]
}

EQ_FREQS = [31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
EQ_CACHE_FILE = os.path.join(CACHE_DIR, "eq.json")
VIS_MODE_FILE = os.path.join(CACHE_DIR, "vis_mode.txt")

def get_vis_mode():
    if os.path.exists(VIS_MODE_FILE):
        try:
            with open(VIS_MODE_FILE, "r", encoding="utf-8") as f:
                mode = f.read().strip()
                if mode:
                    return mode
        except Exception:
            pass
    return "siriwave"

def set_vis_mode(mode):
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(VIS_MODE_FILE, "w", encoding="utf-8") as f:
            f.write(str(mode).strip())
        return {"success": True, "vis_mode": mode}
    except Exception as e:
        return {"success": False, "error": str(e)}

def get_current_eq():
    if os.path.exists(EQ_CACHE_FILE):
        try:
            with open(EQ_CACHE_FILE) as f:
                return json.load(f).get("preset", "Flat")
        except:
            pass
    return "Flat"

AUDIO_FX_FILE = os.path.join(CACHE_DIR, "audio_fx.json")

def get_audio_fx():
    default_fx = {
        "eq": get_current_eq(),
        "loudnorm": False,
        "spatial": False
    }
    if os.path.exists(AUDIO_FX_FILE):
        try:
            with open(AUDIO_FX_FILE, "r") as f:
                d = json.load(f)
                default_fx["eq"] = d.get("eq", get_current_eq())
                default_fx["loudnorm"] = d.get("loudnorm", False)
                default_fx["spatial"] = d.get("spatial", False)
        except Exception:
            pass
    return default_fx

def save_audio_fx(fx_dict):
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        with open(AUDIO_FX_FILE, "w") as f:
            json.dump(fx_dict, f)
    except Exception:
        pass

def apply_audio_fx(preset_name=None, loudnorm=None, spatial=None):
    cur = get_audio_fx()
    if preset_name is not None:
        cur["eq"] = preset_name if preset_name in EQ_PRESETS else "Flat"
        try:
            os.makedirs(CACHE_DIR, exist_ok=True)
            with open(EQ_CACHE_FILE, "w") as f:
                json.dump({"preset": cur["eq"]}, f)
        except Exception:
            pass
    if loudnorm is not None:
        cur["loudnorm"] = bool(loudnorm)
    if spatial is not None:
        cur["spatial"] = bool(spatial)
    
    save_audio_fx(cur)

    # Build libavfilter chain
    filters = []
    
    # 1. 10-band EQ
    eq_preset = cur.get("eq", "Flat")
    if eq_preset != "Flat" and eq_preset in EQ_PRESETS:
        gains = EQ_PRESETS[eq_preset]
        eq_parts = [f"equalizer=f={f}:width_type=o:width=1:gain={g}" for f, g in zip(EQ_FREQS, gains)]
        filters.extend(eq_parts)

    # 2. 3D Spatial Stereo Widener (binaural audio stage)
    if cur.get("spatial"):
        filters.append("extrastereo=m=1.6")

    # 3. Dynamic Loudness Normalizer (EBU R128 anti-earblast)
    if cur.get("loudnorm"):
        filters.append("dynaudnorm=f=150:g=15:m=10.0:p=0.95")

    if filters:
        filter_str = "lavfi=[" + ",".join(filters) + "]"
        send_mpv_cmd(["set_property", "af", filter_str])
    else:
        send_mpv_cmd(["set_property", "af", ""])

    return {"success": True, "fx": cur}

def set_eq(preset_name):
    return apply_audio_fx(preset_name=preset_name)

def get_dominant_color(img_path):
    if not img_path or not os.path.exists(img_path):
        return ""
    color_file = img_path + ".color"
    if os.path.exists(color_file):
        try:
            with open(color_file, "r") as f:
                c = f.read().strip()
                if c.startswith("#") and len(c) == 7:
                    return c
        except Exception:
            pass
    return ""

def get_status():
    cur_eq = get_current_eq()
    if not is_mpv_running():
        return {
            "running": False,
            "state": "stopped",
            "track": "No track loaded",
            "artist": "Omaramp",
            "art_path": "",
            "art_color": "",
            "time_current": "00:00",
            "time_total": "00:00",
            "cur_secs": 0,
            "total_secs": 0,
            "progress": 0.0,
            "volume_db": 0,
            "volume_pct": 80,
            "shuffle": False,
            "repeat": "off",
            "eq": cur_eq
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
            q = read_queue()
            if q:
                play_next_in_queue()
                return get_status()
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
        cur_fx = get_audio_fx()
        return {
            "running": True,
            "state": state,
            "track": track,
            "artist": artist,
            "art_path": art_path,
            "art_color": get_dominant_color(art_path),
            "url": np.get("url", ""),
            "time_current": format_seconds(cur_s),
            "time_total": format_seconds(tot_s),
            "cur_secs": round(cur_s, 2),
            "total_secs": round(tot_s, 2),
            "progress": round(prog, 3),
            "volume_db": round((vol / 100.0) * 36.0 - 30.0, 1),
            "volume_pct": vol,
            "speed": round(float(speed_res.get("data") or 1.0), 2) if speed_res else 1.0,
            "shuffle": False,
            "repeat": "all",
            "queue_count": len(read_queue()),
            "eq": cur_fx.get("eq", "Flat"),
            "audio_fx": cur_fx,
            "vis_mode": get_vis_mode(),
            "resume": resume
        }
    except Exception as e:
        cur_fx = get_audio_fx()
        return {
            "running": False,
            "state": "stopped",
            "error": str(e),
            "track": "No track loaded",
            "artist": "Omaramp",
            "art_path": "",
            "art_color": "",
            "time_current": "00:00",
            "time_total": "00:00",
            "cur_secs": 0,
            "total_secs": 0,
            "progress": 0.0,
            "volume_db": 0,
            "volume_pct": 80,
            "shuffle": False,
            "repeat": "off",
            "eq": cur_fx.get("eq", "Flat"),
            "audio_fx": cur_fx,
            "vis_mode": get_vis_mode()
        }

def resolve_spotify_url(url):
    """Resolve Spotify track URL to title, artist, and search query using Spotify oEmbed."""
    try:
        if "spotify.com/track/" in url:
            oembed_url = f"https://open.spotify.com/oembed?url={urllib.parse.quote(url)}"
            req = urllib.request.Request(oembed_url, headers={"User-Agent": "Mozilla/5.0"})
            data = json.loads(urllib.request.urlopen(req, timeout=4.0).read().decode("utf-8"))
            title = data.get("title", "").strip()
            thumb = data.get("thumbnail_url", "")
            return {"title": title, "artist": "", "thumb": thumb, "query": title}
    except Exception:
        pass
    return None

def search_tracks(query, limit=10):
    if not query or not query.strip():
        return []
    q = query.strip()

    results = []

    # 1. Fast global audio scan across user system using fd / fallback
    ext_list = ["mp3", "flac", "wav", "m4a", "ogg", "opus", "aac", "aiff", "wma"]
    found_local = []
    if shutil.which("fd"):
        try:
            fd_cmd = [
                "fd", "--max-results", str(limit), "--ignore-case",
                "--exclude", ".cache", "--exclude", ".local", "--exclude", ".git",
                "--exclude", "node_modules", "--exclude", ".gemini", "--exclude", ".npm",
                "--exclude", ".cargo", "--exclude", ".rustup"
            ]
            for ext in ext_list:
                fd_cmd.extend(["-e", ext])
            fd_cmd.extend([q, os.path.expanduser("~")])
            r = subprocess.run(fd_cmd, capture_output=True, text=True, timeout=1.5)
            for line in (r.stdout or "").splitlines():
                p = line.strip()
                if p and os.path.isfile(p):
                    found_local.append(p)
        except Exception:
            pass

    # Fallback scan across common directories if fd is missing or found nothing
    if not found_local:
        candidate_dirs = [
            os.path.expanduser("~/Music"),
            os.path.expanduser("~/Downloads"),
            os.path.expanduser("~/Desktop"),
            os.path.expanduser("~/Documents"),
            os.path.expanduser("~/Audio")
        ]
        exts = tuple("." + e for e in ext_list)
        for cdir in candidate_dirs:
            if not os.path.isdir(cdir):
                continue
            try:
                for root, _, files in os.walk(cdir):
                    for f in files:
                        if f.lower().endswith(exts) and q.lower() in f.lower():
                            full_path = os.path.join(root, f)
                            if full_path not in found_local:
                                found_local.append(full_path)
                            if len(found_local) >= limit:
                                break
                    if len(found_local) >= limit:
                        break
            except Exception:
                pass

    for full_path in found_local[:limit]:
        name = os.path.splitext(os.path.basename(full_path))[0]
        artist, title = "Local", name
        if " - " in name:
            parts = name.split(" - ", 1)
            artist, title = parts[0].strip(), parts[1].strip()
        results.append({
            "id": full_path,
            "url": full_path,
            "title": title,
            "artist": f"{artist} (Offline)",
            "duration": "Local",
            "thumb": ""
        })

    # 2. Spotify track URL resolver
    if "spotify.com/track/" in q:
        spot = resolve_spotify_url(q)
        if spot and spot.get("query"):
            q = spot["query"]

    # 3. YouTube online search
    remaining = limit - len(results)
    if remaining > 0:
        cmd = [
            "yt-dlp",
            "--flat-playlist",
            "--print", "%(id)s\t%(title)s\t%(uploader)s\t%(duration_string)s",
            "--",
            f"ytsearch{remaining}:{q}"
        ]
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=8.0)
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
        except Exception:
            pass

    # Async prefetch direct stream URLs for top results in background so clicks are instantaneous
    import threading
    for item in results[:2]:
        u = item.get("url", "")
        if is_youtube_url(u) and not get_cached_stream_url(u):
            threading.Thread(target=resolve_youtube_stream_url, args=(u,), daemon=True).start()

    return results


def is_youtube_url(url):
    if not url:
        return False
    parsed = urllib.parse.urlparse(str(url).strip())
    return parsed.scheme in ("http", "https") and parsed.netloc in ("www.youtube.com", "youtube.com", "youtu.be", "music.youtube.com")

def is_safe_url(url):
    if not url:
        return False
    u = str(url).strip()
    if u.startswith("-"):
        return False
    parsed = urllib.parse.urlparse(u)
    if parsed.scheme in ("http", "https"):
        return True
    if parsed.scheme in ("file", "data", "javascript", "vbscript"):
        return False
    if not parsed.scheme and not parsed.netloc:
        expanded = os.path.expanduser(u)
        return os.path.isfile(expanded)
    return False

LYRICS_CACHE = {}
def fetch_lyrics(title, artist, url=""):
    key = (title or "").strip().lower() + "|" + (artist or "").strip().lower()
    if key in LYRICS_CACHE:
        return LYRICS_CACHE[key]
    try:
        raw_t = (title or "").strip()
        raw_a = (artist or "").strip()

        # If title is generic and we have a YouTube URL, fetch actual video title
        if (not raw_t or raw_t in ("Omaramp", "omaramp_stream") or " - " not in raw_t) and is_youtube_url(url or ""):
            try:
                vid = re.search(r"(?:v=|youtu\.be/)([0-9A-Za-z_-]{11})", url).group(1)
                r = subprocess.run(["yt-dlp", "--no-warnings", "--print", "%(title)s", "--", f"https://www.youtube.com/watch?v={vid}"],
                                   capture_output=True, text=True, timeout=5)
                full_title = r.stdout.strip()
                if full_title:
                    raw_t = full_title
            except Exception:
                pass

        # Strip video/audio metadata tags
        clean_t = re.sub(r"(?i)\s*[\(\[](?:official|music|video|audio|lyrics?|4k|hd|remaster(?:ed)?|lyric video|visualizer|hq|clip|explicit).*?[\)\]]", "", raw_t)
        clean_t = re.sub(r"\s*[\(\[].*?[\)\]]", "", clean_t).strip()
        clean_a = raw_a

        if " - " in clean_t and not clean_a:
            parts = clean_t.split(" - ", 1)
            clean_a = parts[0].strip()
            clean_t = parts[1].strip()

        data = []
        # Strategy 1: Search with specific artist and track
        if clean_a and clean_t:
            try:
                u = f"https://lrclib.net/api/search?artist_name={urllib.parse.quote(clean_a)}&track_name={urllib.parse.quote(clean_t)}"
                req = urllib.request.Request(u, headers={"User-Agent": "Omaramp/1.0 (Linux)"})
                res = urllib.request.urlopen(req, timeout=5)
                data = json.loads(res.read().decode("utf-8"))
            except Exception:
                pass

        # Strategy 2: Query search with both artist + title
        if not data and (clean_t or clean_a):
            try:
                q_str = f"{clean_t} {clean_a}".strip()
                u = f"https://lrclib.net/api/search?q={urllib.parse.quote(q_str)}"
                req = urllib.request.Request(u, headers={"User-Agent": "Omaramp/1.0 (Linux)"})
                res = urllib.request.urlopen(req, timeout=5)
                data = json.loads(res.read().decode("utf-8"))
            except Exception:
                pass

        # Strategy 3: Fallback query with original raw title
        if not data and raw_t and raw_t != clean_t:
            try:
                u = f"https://lrclib.net/api/search?q={urllib.parse.quote(raw_t)}"
                req = urllib.request.Request(u, headers={"User-Agent": "Omaramp/1.0 (Linux)"})
                res = urllib.request.urlopen(req, timeout=5)
                data = json.loads(res.read().decode("utf-8"))
            except Exception:
                pass

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

def resolve_youtube_stream_url(url):
    """Resolve direct HTTPS stream URL for YouTube audio with 4-hour caching for instantaneous playback."""
    if not url:
        return None
    cached = get_cached_stream_url(url)
    if cached:
        return cached
    try:
        r = subprocess.run([
            "yt-dlp", "--no-warnings",
            "--extractor-args", "youtube:player_client=android,web",
            "-f", "18/bestaudio/best",
            "--no-check-certificates",
            "--no-playlist",
            "-g", "--", url
        ], capture_output=True, text=True, timeout=8)
        lines = [l.strip() for l in r.stdout.splitlines() if l.strip().startswith("http")]
        if lines:
            direct_url = lines[-1]
            set_cached_stream_url(url, direct_url)
            return direct_url
    except Exception:
        pass
    return None

def stream_youtube(url):
    """Stream YouTube audio to mpv via a secure private FIFO pipe fallback."""
    terminate_tracked_pid(STREAM_PID_FILE, expected_signature=["yt-dlp", STREAM_FIFO])
    os.makedirs(RUN_DIR, mode=0o700, exist_ok=True)
    try:
        os.chmod(RUN_DIR, 0o700)
    except Exception:
        pass

    if os.path.lexists(STREAM_FIFO):
        try:
            if os.path.islink(STREAM_FIFO) or not os.path.exists(STREAM_FIFO):
                os.unlink(STREAM_FIFO)
            else:
                stat = os.stat(STREAM_FIFO)
                if stat.st_uid != os.getuid():
                    raise PermissionError(f"FIFO {STREAM_FIFO} is not owned by current user")
                os.remove(STREAM_FIFO)
        except Exception as e:
            if not isinstance(e, FileNotFoundError):
                raise

    os.mkfifo(STREAM_FIFO, 0o600)
    try:
        os.chmod(STREAM_FIFO, 0o600)
    except Exception:
        pass

    read_fd = os.open(STREAM_FIFO, os.O_RDONLY | os.O_NONBLOCK)
    write_fd = os.open(STREAM_FIFO, os.O_WRONLY)
    os.close(read_fd)
    proc = subprocess.Popen(
        ["yt-dlp", "--no-warnings", "-f", "18/best", "-o", "-", "--", url],
        stdout=os.fdopen(write_fd, "wb"),
        stderr=subprocess.DEVNULL,
        start_new_session=True
    )
    save_tracked_proc(STREAM_PID_FILE, proc.pid, signature=["yt-dlp", STREAM_FIFO])

def resolve_track_url(url, title=None, artist=None):
    """Resolves any track item (Spotify URL, query string, or local path) to a playable URL and metadata."""
    if not url:
        return None, title, artist
    u = str(url).strip()
    if u.startswith("-"):
        return None, title, artist
    
    if "spotify.com/track/" in u:
        spot = resolve_spotify_url(u)
        if spot and spot.get("query"):
            res = search_tracks(spot["query"], limit=1)
            if res:
                return res[0]["url"], spot.get("title") or res[0]["title"], spot.get("artist") or res[0]["artist"]
        return None, title, artist
    
    parsed = urllib.parse.urlparse(u)
    if parsed.scheme in ("http", "https"):
        return u, title or "Track", artist or ""
    
    expanded = os.path.expanduser(u)
    if os.path.isfile(expanded):
        return expanded, title or os.path.splitext(os.path.basename(expanded))[0], artist or ""
    
    query = u if not (title and artist) else f"{title} {artist}"
    res = search_tracks(query, limit=1)
    if res:
        return res[0]["url"], title or res[0]["title"], artist or res[0]["artist"]
    
    return None, title, artist

def play_item(url, title=None, artist=None):
    real_url, final_title, final_artist = resolve_track_url(url, title, artist)
    if not real_url:
        return {"success": False, "error": "Unable to resolve track"}
    start_mpv_daemon()
    start_spectrum_daemon()
    record_history(final_title, final_artist, real_url, 0)
    save_now_playing(final_title, final_artist, real_url)
    
    stream_target = real_url
    if is_youtube_url(real_url):
        save_youtube_meta(real_url, final_title, final_artist)
        direct_url = resolve_youtube_stream_url(real_url)
        if direct_url:
            stream_target = direct_url
        else:
            stream_youtube(real_url)
            stream_target = STREAM_FIFO

    send_mpv_cmd(["loadfile", stream_target, "replace"])
    send_mpv_cmd(["set_property", "pause", False])
    return {"success": True}

def queue_item(url, title=None, artist=None):
    real_url, final_title, final_artist = resolve_track_url(url, title, artist)
    if not real_url:
        return {"success": False, "error": "Unable to resolve track"}
    start_mpv_daemon()
    record_history(final_title, final_artist, real_url, 0)
    save_now_playing(final_title, final_artist, real_url)
    
    stream_target = real_url
    if is_youtube_url(real_url):
        save_youtube_meta(real_url, final_title, final_artist)
        direct_url = resolve_youtube_stream_url(real_url)
        if direct_url:
            stream_target = direct_url
        else:
            stream_youtube(real_url)
            stream_target = STREAM_FIFO

    send_mpv_cmd(["loadfile", stream_target, "append"])
    return {"success": True}

def stop_daemon():
    terminate_tracked_pid(STREAM_PID_FILE, expected_signature=["yt-dlp", STREAM_FIFO])
    terminate_tracked_pid(SPECTRUM_PID_FILE, expected_signature="spectrum.py")
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
        custom = parse_playlists()
        result = [{"name": "Recently Played", "count": len(parse_history(500)), "system": True}]
        for pl in custom:
            result.append({"name": pl.get("name", "Untitled"), "count": len(pl.get("tracks", [])), "tracks": pl.get("tracks", [])})
        print(json.dumps(result))
    elif action == "import_playlist":
        u = sys.argv[2] if len(sys.argv) > 2 else ""
        n = sys.argv[3] if len(sys.argv) > 3 else None
        print(json.dumps(import_playlist(u, n)))
    elif action == "delete_playlist":
        n = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(delete_playlist(n)))
    elif action == "toggle_loudnorm":
        cur = get_audio_fx()
        print(json.dumps(apply_audio_fx(loudnorm=not cur.get("loudnorm", False))))
    elif action == "toggle_spatial":
        cur = get_audio_fx()
        print(json.dumps(apply_audio_fx(spatial=not cur.get("spatial", False))))
    elif action == "get_fx":
        print(json.dumps(get_audio_fx()))
    elif action == "search":
        q = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else ""
        print(json.dumps(search_tracks(q, 10)))
    elif action == "play":
        start_mpv_daemon()
        idle_res = send_mpv_cmd(["get_property", "idle-active"])
        if idle_res and idle_res.get("data") is True:
            q = read_queue()
            if q:
                play_next_in_queue()
            else:
                np = read_now_playing()
                if np.get("url"):
                    play_item(np.get("url"), np.get("title"), np.get("artist"))
                else:
                    hist = parse_history(1)
                    if hist and hist[0].get("path"):
                        play_item(hist[0].get("path"), hist[0].get("title"), hist[0].get("artist"))
        else:
            send_mpv_cmd(["set_property", "pause", False])
        print(json.dumps({"success": True}))
    elif action == "pause":
        send_mpv_cmd(["set_property", "pause", True])
        print(json.dumps({"success": True}))
    elif action == "toggle":
        start_mpv_daemon()
        idle_res = send_mpv_cmd(["get_property", "idle-active"])
        if idle_res and idle_res.get("data") is True:
            q = read_queue()
            if q:
                play_next_in_queue()
            else:
                np = read_now_playing()
                if np.get("url"):
                    play_item(np.get("url"), np.get("title"), np.get("artist"))
                else:
                    hist = parse_history(1)
                    if hist and hist[0].get("path"):
                        play_item(hist[0].get("path"), hist[0].get("title"), hist[0].get("artist"))
        else:
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
    elif action == "set_eq":
        preset = sys.argv[2] if len(sys.argv) > 2 else "Flat"
        print(json.dumps(set_eq(preset)))
    elif action in ["get_eq", "list_eq"]:
        print(json.dumps({"current": get_current_eq(), "presets": list(EQ_PRESETS.keys())}))
    elif action == "stop":
        pos_res = send_mpv_cmd(["get_property", "time-pos"])
        np = read_now_playing()
        if np.get("url") and pos_res and pos_res.get("data"):
            save_now_playing(np.get("title", ""), np.get("artist", ""), np.get("url", ""), int(float(pos_res["data"])))
        send_mpv_cmd(["stop"])
        print(json.dumps({"success": True}))
    elif action == "next":
        q = read_queue()
        if q:
            print(json.dumps(play_next_in_queue()))
        else:
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
    elif action in ["queue", "queue_add"]:
        url = sys.argv[2] if len(sys.argv) > 2 else ""
        t = sys.argv[3] if len(sys.argv) > 3 else ""
        a = sys.argv[4] if len(sys.argv) > 4 else ""
        print(json.dumps(add_to_queue(url, t, a)))
    elif action in ["queue_list", "get_queue"]:
        print(json.dumps(read_queue()))
    elif action == "queue_remove":
        idx = sys.argv[2] if len(sys.argv) > 2 else "0"
        print(json.dumps(remove_from_queue(idx)))
    elif action == "queue_clear":
        print(json.dumps(clear_queue()))
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
    elif action == "set_vis_mode":
        mode = sys.argv[2] if len(sys.argv) > 2 else "siriwave"
        print(json.dumps(set_vis_mode(mode)))
    elif action == "get_vis_mode":
        print(json.dumps({"vis_mode": get_vis_mode()}))
    else:
        print(json.dumps({"error": f"Unknown action {action}"}))
