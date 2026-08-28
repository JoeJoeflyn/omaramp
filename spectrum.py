#!/usr/bin/env python3
"""Real-time ultra-low-overhead FFT spectrum + waveform capture for Omaramp via PipeWire."""
import os, sys, time, math, subprocess, signal
import numpy as np

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

OUT_FILE = os.path.join(RUN_DIR, "spectrum.json")
RATE = 44100
CHUNK = 2048  # 2048-sample FFT — 44100/2048=21.5Hz/bin, Nyquist 22050 covers 12kHz+
NUM_BANDS = 24
WAVE_SAMPLES = 128  # raw waveform points for scope/wave modes

min_f, max_f = 20.0, 16000.0
edges = [min_f * ((max_f / min_f) ** (i / float(NUM_BANDS))) for i in range(NUM_BANDS + 1)]
bin_edges = [max(1, min(CHUNK // 2, int(round(f * CHUNK / RATE)))) for f in edges]
for i in range(1, len(bin_edges)):
    if bin_edges[i] <= bin_edges[i - 1]:
        bin_edges[i] = bin_edges[i - 1] + 1

HANNING = np.hanning(CHUNK).astype(np.float32)
decay_bands = np.zeros(NUM_BANDS, dtype=np.float32)
TILTS = np.array([1.0 + (i / float(NUM_BANDS)) * 4.0 for i in range(NUM_BANDS)], dtype=np.float32)

def get_monitor_target():
    try:
        res = subprocess.run(["pactl", "get-default-sink"], capture_output=True, text=True, timeout=1.0)
        sink = res.stdout.strip()
        if sink:
            return sink + ".monitor"
    except Exception:
        pass
    return None

def start_recorder():
    monitor = get_monitor_target()
    try:
        cmd = ["parec", "--format=s16le", f"--rate={RATE}", "--channels=1", "--latency-msec=20"]
        if monitor:
            cmd += ["-d", monitor]
        return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    try:
        cmd = ["pw-record", "--raw", "--channels=1", "--format=s16", f"--rate={RATE}"]
        if monitor:
            cmd += ["--target", monitor]
        cmd.append("-")
        return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except Exception:
        return None

def run():
    global decay_bands
    proc = start_recorder()

    def cleanup(sig, frame):
        try:
            if proc:
                proc.terminate()
        except Exception:
            pass
        sys.exit(0)

    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    chunk_bytes = CHUNK * 2
    empty_reads = 0

    while True:
        try:
            if proc is None or proc.poll() is not None:
                time.sleep(0.5)
                proc = start_recorder()
                if proc is None:
                    time.sleep(1.0)
                    continue
                empty_reads = 0

            data = proc.stdout.read(chunk_bytes)
            if not data or len(data) < chunk_bytes:
                empty_reads += 1
                if empty_reads > 25:
                    try:
                        if proc:
                            proc.terminate()
                    except Exception:
                        pass
                    proc = start_recorder()
                    empty_reads = 0
                time.sleep(0.02)
                continue
            empty_reads = 0

            # Zero-copy C numpy buffer conversion (100x faster than struct.unpack)
            raw_int16 = np.frombuffer(data, dtype=np.int16)
            raw = raw_int16.astype(np.float32) * (1.0 / 32768.0)

            # FFT with Hanning window
            norm = raw * HANNING
            spectrum = np.fft.rfft(norm)
            mags = np.abs(spectrum) * (2.0 / CHUNK)

            # Band spectrum aggregation
            cur_bands = []
            for i in range(NUM_BANDS):
                lo, hi = bin_edges[i], bin_edges[i + 1]
                avg_mag = float(np.mean(mags[lo:hi])) if hi > lo else float(mags[lo])
                db = 20.0 * math.log10(avg_mag + 1e-10)
                norm_val = max(0.0, (db + 96.0) / 96.0)
                mag = min(1.0, norm_val * float(TILTS[i]))

                if mag > decay_bands[i]:
                    decay_bands[i] = mag * 0.6 + decay_bands[i] * 0.4
                else:
                    decay_bands[i] = max(0.0, mag * 0.25 + decay_bands[i] * 0.75)
                cur_bands.append(round(float(decay_bands[i]), 3))

            # Trigger alignment for oscilloscope waveform
            trig_idx = 0
            search_len = min(CHUNK // 2, 400)
            for i in range(1, search_len):
                if raw[i - 1] <= 0.0 and raw[i] > 0.0:
                    trig_idx = i
                    break

            step = max(1, (CHUNK - trig_idx) // WAVE_SAMPLES)
            indices = [trig_idx + i * step for i in range(WAVE_SAMPLES) if (trig_idx + i * step) < CHUNK]
            wave_raw = raw[indices].tolist() if indices else []
            if len(wave_raw) < WAVE_SAMPLES:
                wave_raw += [0.0] * (WAVE_SAMPLES - len(wave_raw))

            # Normalization
            peak = max(abs(x) for x in wave_raw) if wave_raw else 0
            gain = min(35.0, 0.75 / peak) if peak > 0.005 else 1.0
            wave = [round(max(-1.0, min(1.0, float(x * gain))), 4) for x in wave_raw]

            # Fast atomic write with 0o600 permissions
            tmp_out = OUT_FILE + ".tmp"
            fd = os.open(tmp_out, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with open(fd, "w", encoding="utf-8") as f:
                f.write('{"bands":[' + ",".join(str(b) for b in cur_bands) +
                        '],"wave":[' + ",".join(str(w) for w in wave) + ']}')
            try:
                os.chmod(tmp_out, 0o600)
            except Exception:
                pass
            os.replace(tmp_out, OUT_FILE)
            try:
                os.chmod(OUT_FILE, 0o600)
            except Exception:
                pass

        except Exception:
            time.sleep(0.05)

if __name__ == "__main__":
    run()
