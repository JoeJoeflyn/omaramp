#!/usr/bin/env python3
"""Omaramp audio controller powered by mpv headless IPC with YouTube & local file support."""
import sys
import os
import subprocess
import json
import socket
import time
import re

SOCK_PATH = "/tmp/omaramp_mpv.sock"
HISTORY_PATH = os.path.expanduser("~/.config/cliamp/history.toml")
os.makedirs(os.path.expanduser("~/.config/cliamp"), exist_ok=True)

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
        return json.loads(res.strip().splitlines()[0])
    except Exception:
        return None

def is_mpv_running():
    if not os.path.exists(SOCK_PATH):
        return False
    res = send_mpv_cmd(["get_property", "idle-active"])
    return res is not None and res.get("error") == "success"

def start_mpv_daemon(initial_url=None):
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
            f"--input-ipc-server={SOCK_PATH}",
            "--ytdl-format=bestaudio/best",
            "--keep-open=yes",
            "--volume=80"
        ]
        if initial_url:
            cmd.append(initial_url)
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        time.sleep(0.3)

def record_history(title, artist, url, dur):
    try:
        entry = f'\n[[entry]]\nplayed_at = "{time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}"\npath = "{url}"\ntitle = "{title.replace(chr(34), "")}"\nartist = "{artist.replace(chr(34), "")}"\nduration_secs = {int(dur or 0)}\n'
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
            "mono": False,
            "speed": "1.00x",
            "eq": "Custom"
        }

    try:
        pos_res = send_mpv_cmd(["get_property", "time-pos"])
        dur_res = send_mpv_cmd(["get_property", "duration"])
        pause_res = send_mpv_cmd(["get_property", "pause"])
        title_res = send_mpv_cmd(["get_property", "media-title"])
        vol_res = send_mpv_cmd(["get_property", "volume"])
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
        if " - " in raw_title:
            p = raw_title.split(" - ", 1)
            artist = p[0].strip()
            track = p[1].strip()

        vol = int(vol_res.get("data") or 80) if vol_res else 80

        return {
            "running": True,
            "state": state,
            "track": track,
            "artist": artist,
            "time_current": format_seconds(cur_s),
            "time_total": format_seconds(tot_s),
            "cur_secs": int(cur_s),
            "total_secs": int(tot_s),
            "progress": round(prog, 3),
            "volume_db": round((vol / 100.0) * 36.0 - 30.0, 1),
            "volume_pct": vol,
            "shuffle": False,
            "repeat": "all",
            "mono": False,
            "speed": "1.00x",
            "eq": "Custom"
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
            "mono": False,
            "speed": "1.00x",
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
                    "duration": dur
                })
        return results
    except Exception:
        return []

def play_item(url):
    if not url:
        return {"success": False}
    start_mpv_daemon()
    send_mpv_cmd(["loadfile", url, "replace"])
    send_mpv_cmd(["set_property", "pause", False])
    # Fetch title & record history in background
    def fetch_meta():
        time.sleep(1.5)
        st = send_mpv_cmd(["get_property", "media-title"])
        dur = send_mpv_cmd(["get_property", "duration"])
        t = st.get("data") if st else ""
        d = dur.get("data") if dur else 0
        if t:
            art = ""
            tr = t
            if " - " in t:
                p = t.split(" - ", 1)
                art, tr = p[0].strip(), p[1].strip()
            record_history(tr, art, url, d)
    import threading
    threading.Thread(target=fetch_meta, daemon=True).start()
    return {"success": True}

def queue_item(url):
    if not url:
        return {"success": False}
    start_mpv_daemon()
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
    elif action == "stop":
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
        print(json.dumps(play_item(url)))
    elif action == "queue":
        url = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(queue_item(url)))
    elif action == "stop_daemon":
        print(json.dumps(stop_daemon()))
    else:
        print(json.dumps({"error": f"Unknown action {action}"}))
