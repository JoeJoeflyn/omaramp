#!/usr/bin/env python3
"""Real-time ultra-low-overhead FFT spectrum + waveform capture for Omaramp via PipeWire/Pulse."""
import os, sys, time, math, subprocess, signal, select, struct, cmath, json

try:
    import numpy as np
    HAVE_NUMPY = True
except ImportError:
    HAVE_NUMPY = False

RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR")
if RUNTIME_DIR and os.path.isdir(RUNTIME_DIR):
    RUN_DIR = os.path.join(RUNTIME_DIR, "omaramp")
else:
    RUN_DIR = os.path.expanduser("~/.cache/omaramp/run")

OUT_FILE = os.path.join(RUN_DIR, "spectrum.json")

RATE = 44100
CHUNK = 2048
NUM_BANDS = 24
WAVE_SAMPLES = 128

min_f, max_f = 20.0, 16000.0
edges = [min_f * ((max_f / min_f) ** (i / float(NUM_BANDS))) for i in range(NUM_BANDS + 1)]
# A low band may be narrower than a single FFT bin. Share the nearest bin
# instead of forcing every band rightward and losing the real bass range.
bin_ranges = []
for low, high in zip(edges, edges[1:]):
    lo = max(1, math.ceil(low * CHUNK / RATE))
    hi = max(1, math.ceil(high * CHUNK / RATE))
    if lo == hi:
        lo = max(1, round(math.sqrt(low * high) * CHUNK / RATE))
        hi = lo + 1
    bin_ranges.append((lo, hi))

HANNING = [0.5 * (1.0 - math.cos(2.0 * math.pi * i / (CHUNK - 1))) for i in range(CHUNK)]


def analyze_frame(data, previous, use_numpy=HAVE_NUMPY):
    if use_numpy:
        stereo = np.frombuffer(data, dtype="<i2").reshape(-1, 2).astype(np.float32) / 32768
        raw = stereo.mean(axis=1)
        lr = np.sqrt((stereo * stereo).mean(axis=0)).tolist()
        fft = np.fft.rfft(stereo * np.asarray(HANNING)[:, None], axis=0)
        mags = np.sqrt((np.abs(fft) ** 2).mean(axis=1)) * (4.0 / CHUNK)
        louder = stereo[:, int(lr[1] > lr[0])]
    else:
        samples = struct.unpack(f"<{CHUNK * 2}h", data)
        left, right = ([x / 32768 for x in samples[i::2]] for i in range(2))
        raw = [(l + r) * 0.5 for l, r in zip(left, right)]
        lr = [math.sqrt(sum(s * s for s in ch) / CHUNK) for ch in (left, right)]
        ffts = [_pure_fft([x * window for x, window in zip(ch, HANNING)]) for ch in (left, right)]
        mags = [math.hypot(abs(l), abs(r)) * (4.0 / (CHUNK * math.sqrt(2)))
                for l, r in zip(ffts[0][:CHUNK // 2], ffts[1][:CHUNK // 2])]
        louder = right if lr[1] > lr[0] else left

    bands = []
    for i, (lo, hi) in enumerate(bin_ranges):
        db = 20 * math.log10(float(max(mags[lo:hi])) + 1e-10)
        # Modest treble compensation in dB; do not multiply normalized bars into clipping.
        target = min(1.0, max(0.0, (db + 72.0 + i * 0.35) / 72.0))
        weight = 0.65 if target > previous[i] else 0.30
        value = target * weight + previous[i] * (1.0 - weight)
        bands.append(value if value > 0.001 else 0.0)

    # Hold a fixed time scale and average each bucket (rather than aliasing
    # samples at a varying stride). Only use one channel if the mix cancels.
    if max(abs(x) for x in raw) < 0.25 * max(lr):
        raw = louder
    step = 6
    end = CHUNK - WAVE_SAMPLES * step
    start = next((i for i in range(1, end + 1) if raw[i - 1] <= 0 < raw[i]), 0)
    wave = [float(sum(raw[i:i + step]) / step) for i in range(start, start + WAVE_SAMPLES * step, step)]
    gain = min(3.0, 0.9 / max(0.001, max(abs(x) for x in wave)))
    return bands, [round(x * gain, 4) for x in wave], lr

def _pure_fft(x):
    N = len(x)
    if N <= 1:
        return x
    even = _pure_fft(x[0::2])
    odd = _pure_fft(x[1::2])
    T = [cmath.exp(-2j * math.pi * k / N) * odd[k] for k in range(N // 2)]
    return [even[k] + T[k] for k in range(N // 2)] + [even[k] - T[k] for k in range(N // 2)]

def get_monitor_target():
    # 1. pactl
    try:
        res = subprocess.run(["pactl", "get-default-sink"], capture_output=True, text=True, timeout=1.0)
        sink = res.stdout.strip()
        if sink:
            return sink + ".monitor"
    except Exception:
        pass

    # 2. wpctl (WirePlumber / PipeWire native)
    try:
        res = subprocess.run(["wpctl", "inspect", "@DEFAULT_AUDIO_SINK@"], capture_output=True, text=True, timeout=1.0)
        for line in res.stdout.splitlines():
            if "node.name" in line:
                parts = line.split("=", 1)
                if len(parts) == 2:
                    name = parts[1].strip().strip('"').strip()
                    if name:
                        return name + ".monitor"
    except Exception:
        pass

    return None

def stop_recorder(proc):
    if proc is None:
        return None
    try:
        proc.terminate()
    except Exception:
        pass
    try:
        if proc.stdout:
            try:
                proc.stdout.close()
            except Exception:
                pass
    except Exception:
        pass
    try:
        proc.wait(timeout=1)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass
    return None

def start_recorder(prefer_pipewire=False):
    monitor = get_monitor_target()
    pulse = ["parec", "--format=s16le", f"--rate={RATE}", "--channels=2", "--latency-msec=20",
             "-d", monitor or "@DEFAULT_MONITOR@"]
    # Target sink monitor ports, not the default microphone on fallback.
    native = ["pw-record", "--raw", "--channels=2", "--format=s16", f"--rate={RATE}",
              "--latency=25ms", "--properties={ stream.capture.sink = true }"]
    if monitor:
        native += ["--target", monitor.removesuffix(".monitor")]
    native.append("-")
    for cmd in ([native, pulse] if prefer_pipewire else [pulse, native]):
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        except OSError:
            continue
        os.set_blocking(proc.stdout.fileno(), False)
        return proc
    return None

def run():
    os.makedirs(RUN_DIR, mode=0o700, exist_ok=True)
    decay_bands = [0.0] * NUM_BANDS
    prefer_pipewire = False
    proc = start_recorder(prefer_pipewire)

    def cleanup(sig, frame):
        stop_recorder(proc)
        sys.exit(0)

    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    chunk_bytes = CHUNK * 4  # 16-bit stereo
    pending = bytearray()
    empty_reads = 0
    stalls = 0

    while True:
        try:
            if proc is None or proc.poll() is not None:
                proc = stop_recorder(proc)
                time.sleep(0.5)
                prefer_pipewire = not prefer_pipewire
                proc = start_recorder(prefer_pipewire)
                if proc is None:
                    time.sleep(1.0)
                    continue
                decay_bands = [0.0] * NUM_BANDS
                pending.clear()
                empty_reads = 0
                stalls = 0

            try:
                ready, _, _ = select.select([proc.stdout], [], [], 1.0)
            except Exception:
                ready = []
            if not ready:
                stalls += 1
                if stalls >= 5:
                    proc = stop_recorder(proc)
                continue
            stalls = 0

            try:
                data = proc.stdout.read(chunk_bytes)
            except Exception:
                data = None
            if data:
                # ponytail: non-blocking reads return short fragments; accumulate
                pending += data
                empty_reads = 0
            else:
                empty_reads += 1
                if empty_reads > 50:
                    proc = stop_recorder(proc)
                time.sleep(0.02)
                continue
            if len(pending) < chunk_bytes:
                continue
            data = bytes(pending[:chunk_bytes])
            del pending[:chunk_bytes]
            empty_reads = 0

            decay_bands, wave, lr = analyze_frame(data, decay_bands)
            json_payload = json.dumps({
                "bands": [round(b, 3) for b in decay_bands], "wave": wave,
                "lr": [round(x, 4) for x in lr], "captured_at": time.time_ns() // 1_000_000,
            }, separators=(",", ":"))

            tmp_out = OUT_FILE + ".tmp"
            fd = os.open(tmp_out, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with open(fd, "w", encoding="utf-8") as f:
                f.write(json_payload)
            os.replace(tmp_out, OUT_FILE)

        except Exception:
            time.sleep(0.05)

if __name__ == "__main__":
    run()
