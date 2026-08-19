#!/usr/bin/env python3
"""Real-time 24-band FFT audio spectrum analyzer for Omaramp using PipeWire capture."""
import os
import sys
import time
import math
import struct
import subprocess
import signal

OUT_FILE = "/dev/shm/omaramp_spectrum.json"
RATE = 22050
CHUNK = 512
NUM_BANDS = 24

# 24 logarithmically spaced frequencies (50Hz to 12kHz)
FREQS = [int(50.0 * ((12000.0 / 50.0) ** (i / float(NUM_BANDS - 1)))) for i in range(NUM_BANDS)]

TABLES = []
for f in FREQS:
    w = 2.0 * math.pi * f / RATE
    cos_t = [math.cos(w * n) for n in range(CHUNK)]
    sin_t = [math.sin(w * n) for n in range(CHUNK)]
    TABLES.append((cos_t, sin_t))

decay_bands = [0.0] * NUM_BANDS

def run():
    global decay_bands
    cmd = ["pw-record", "--channels=1", "--format=s16", f"--rate={RATE}", "-"]
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except Exception:
        return

    def cleanup(sig, frame):
        try:
            proc.terminate()
        except Exception:
            pass
        sys.exit(0)

    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    while True:
        try:
            data = proc.stdout.read(CHUNK * 2)
            if not data or len(data) < CHUNK * 2:
                time.sleep(0.02)
                continue

            samples = struct.unpack(f"{CHUNK}h", data)
            norm = [s / 32768.0 for s in samples]

            cur_bands = []
            for i, (cos_t, sin_t) in enumerate(TABLES):
                re = sum(norm[n] * cos_t[n] for n in range(CHUNK))
                im = sum(norm[n] * sin_t[n] for n in range(CHUNK))
                # Scale magnitude with logarithmic weighting for balanced visual appearance
                gain = 3.5 + (i * 0.15)
                mag = min(1.0, (math.sqrt(re * re + im * im) / (CHUNK / 4.0)) * gain)
                
                # Smooth temporal decay for liquid visualizer feel
                if mag > decay_bands[i]:
                    decay_bands[i] = mag
                else:
                    decay_bands[i] = max(0.0, decay_bands[i] * 0.85 - 0.02)
                
                cur_bands.append(round(decay_bands[i], 3))

            # Write atomic JSON to shared memory
            tmp_out = OUT_FILE + ".tmp"
            with open(tmp_out, "w", encoding="utf-8") as f:
                f.write("[" + ",".join(str(b) for b in cur_bands) + "]")
            os.replace(tmp_out, OUT_FILE)
            
        except Exception:
            time.sleep(0.05)

if __name__ == "__main__":
    run()
