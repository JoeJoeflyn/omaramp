#!/usr/bin/env python3
import sys
import os
import subprocess
import json
import re
import time

CLIAMP_BIN = "/usr/bin/cliamp"
SOCK_PATH = os.path.expanduser("~/.config/cliamp/cliamp.sock")
HISTORY_PATH = os.path.expanduser("~/.config/cliamp/history.toml")

def is_daemon_running():
    if not os.path.exists(SOCK_PATH):
        return False
    try:
        res = subprocess.run([CLIAMP_BIN, "status"], capture_output=True, text=True, timeout=1.5)
        return "cliamp is not running" not in res.stderr and "cliamp is not running" not in res.stdout
    except Exception:
        return False

def ensure_daemon():
    if not is_daemon_running():
        try:
            subprocess.Popen([CLIAMP_BIN, "-d"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            time.sleep(0.3)
        except Exception:
            pass

def parse_time_to_seconds(t_str):
    try:
        parts = t_str.strip().split(":")
        if len(parts) == 2:
            return int(parts[0]) * 60 + int(parts[1])
        elif len(parts) == 3:
            return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
    except Exception:
        pass
    return 0

def get_status():
    if not os.path.exists(SOCK_PATH):
        return {
            "running": False,
            "state": "stopped",
            "track": "No track loaded",
            "artist": "cliamp",
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
        res = subprocess.run([CLIAMP_BIN, "status"], capture_output=True, text=True, timeout=1.5)
        out = (res.stdout or "") + (res.stderr or "")
        if "cliamp is not running" in out:
            return {
                "running": False,
                "state": "stopped",
                "track": "No track loaded",
                "artist": "cliamp",
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

        state = "stopped"
        track = "Unknown track"
        artist = ""
        time_cur = "00:00"
        time_tot = "00:00"
        vol_db = 0
        shuffle = False
        repeat = "off"
        mono = False
        speed = "1.00x"
        eq = "Custom"

        for line in out.splitlines():
            line = line.strip()
            if line.startswith("State:"):
                state = line.split(":", 1)[1].strip().lower()
            elif line.startswith("Track:"):
                raw_tr = line.split(":", 1)[1].strip()
                if " - " in raw_tr:
                    p = raw_tr.split(" - ", 1)
                    artist = p[0].strip()
                    track = p[1].strip()
                else:
                    track = raw_tr
            elif line.startswith("Artist:"):
                artist = line.split(":", 1)[1].strip()
            elif line.startswith("Time:") or line.startswith("Position:"):
                raw_time = line.split(":", 1)[1].strip()
                if "/" in raw_time:
                    tp = raw_time.split("/", 1)
                    time_cur = tp[0].strip()
                    time_tot = tp[1].strip()
            elif line.startswith("Volume:"):
                v_str = line.split(":", 1)[1].strip()
                m = re.search(r"(-?\d+(?:\.\d+)?)", v_str)
                if m:
                    vol_db = float(m.group(1))
            elif line.startswith("Shuffle:"):
                shuffle = line.split(":", 1)[1].strip().lower() == "on"
            elif line.startswith("Repeat:"):
                repeat = line.split(":", 1)[1].strip().lower()
            elif line.startswith("Mono:"):
                mono = line.split(":", 1)[1].strip().lower() == "on"
            elif line.startswith("Speed:"):
                speed = line.split(":", 1)[1].strip()
            elif line.startswith("EQ:"):
                eq = line.split(":", 1)[1].strip()

        cur_s = parse_time_to_seconds(time_cur)
        tot_s = parse_time_to_seconds(time_tot)
        prog = (cur_s / tot_s) if tot_s > 0 else 0.0

        # Map -30dB..+6dB to 0..100% volume
        vol_pct = max(0, min(100, int((vol_db + 30.0) / 36.0 * 100)))

        return {
            "running": True,
            "state": state,
            "track": track or "cliamp",
            "artist": artist,
            "time_current": time_cur,
            "time_total": time_tot,
            "cur_secs": cur_s,
            "total_secs": tot_s,
            "progress": round(prog, 3),
            "volume_db": vol_db,
            "volume_pct": vol_pct,
            "shuffle": shuffle,
            "repeat": repeat,
            "mono": mono,
            "speed": speed,
            "eq": eq
        }
    except Exception as e:
        return {
            "running": False,
            "state": "error",
            "error": str(e),
            "track": "cliamp",
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

def get_history(limit=30):
    try:
        res = subprocess.run([CLIAMP_BIN, "history", "--json", f"--limit={limit}"], capture_output=True, text=True, timeout=2.0)
        if res.returncode == 0 and res.stdout.strip():
            return json.loads(res.stdout)
    except Exception:
        pass
    return []

def get_playlists():
    try:
        res = subprocess.run([CLIAMP_BIN, "playlist", "list"], capture_output=True, text=True, timeout=2.0)
        lines = (res.stdout or "").splitlines()
        playlists = []
        for l in lines:
            l = l.strip()
            if not l:
                continue
            m = re.match(r"^(.+?)\s+(\d+)\s+tracks?", l)
            if m:
                playlists.append({"name": m.group(1).strip(), "count": int(m.group(2))})
            else:
                playlists.append({"name": l, "count": 0})
        return playlists
    except Exception:
        return []

def run_action(cmd, *args):
    ensure_daemon()
    full_cmd = [CLIAMP_BIN, cmd] + list(args)
    try:
        res = subprocess.run(full_cmd, capture_output=True, text=True, timeout=3.0)
        return {"success": res.returncode == 0, "output": res.stdout.strip(), "error": res.stderr.strip()}
    except Exception as e:
        return {"success": False, "error": str(e)}

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
    except Exception as e:
        return []

def stop_daemon():
    try:
        if os.path.exists(SOCK_PATH):
            subprocess.run([CLIAMP_BIN, "stop"], capture_output=True, text=True, timeout=1.0)
        pid_file = os.path.expanduser("~/.config/cliamp/cliamp.sock.pid")
        if os.path.exists(pid_file):
            with open(pid_file, "r") as f:
                pid = int(f.read().strip())
                os.kill(pid, 15)
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}

def resolve_audio_url(url):
    if not url:
        return ""
    if "youtube.com" in url or "youtu.be" in url:
        try:
            r = subprocess.run(["yt-dlp", "-g", "-f", "bestaudio", url], capture_output=True, text=True, timeout=6.0)
            if r.returncode == 0 and r.stdout.strip():
                return r.stdout.strip().splitlines()[0]
        except Exception:
            pass
    return url

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps(get_status()))
        sys.exit(0)

    action = sys.argv[1]
    if action == "status":
        print(json.dumps(get_status()))
    elif action == "history":
        lim = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        print(json.dumps(get_history(lim)))
    elif action == "playlists":
        print(json.dumps(get_playlists()))
    elif action == "search":
        q = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else ""
        print(json.dumps(search_tracks(q, 10)))
    elif action == "stop_daemon":
        print(json.dumps(stop_daemon()))
    elif action in ["play", "pause", "toggle", "next", "prev", "stop", "shuffle", "repeat", "mono"]:
        print(json.dumps(run_action(action, *sys.argv[2:])))
    elif action == "volume":
        val = sys.argv[2] if len(sys.argv) > 2 else "0"
        print(json.dumps(run_action("volume", str(val))))
    elif action == "volume_pct":
        pct = float(sys.argv[2]) if len(sys.argv) > 2 else 80.0
        db = round((pct / 100.0) * 36.0 - 30.0, 1)
        print(json.dumps(run_action("volume", str(db))))
    elif action == "seek":
        sec = sys.argv[2] if len(sys.argv) > 2 else "0"
        print(json.dumps(run_action("seek", str(sec))))
    elif action == "load":
        pl = sys.argv[2] if len(sys.argv) > 2 else "Recently Played"
        print(json.dumps(run_action("load", pl)))
    elif action == "queue":
        raw_url = sys.argv[2] if len(sys.argv) > 2 else ""
        resolved = resolve_audio_url(raw_url)
        ensure_daemon()
        print(json.dumps(run_action("queue", resolved)))
    elif action == "play_item":
        raw_url = sys.argv[2] if len(sys.argv) > 2 else ""
        resolved = resolve_audio_url(raw_url)
        ensure_daemon()
        run_action("queue", resolved)
        time.sleep(0.15)
        print(json.dumps(run_action("play")))
    else:
        print(json.dumps({"error": f"Unknown action {action}"}))
