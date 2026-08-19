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

# Continuous logarithmic frequency sub-bands from 40Hz to 12kHz
min_f = 40.0
max_f = 12000.0
edges = [min_f * ((max_f / min_f) ** (i / float(NUM_BANDS))) for i in range(NUM_BANDS + 1)]
bin_edges = [max(1, min(CHUNK // 2, int(round(f * CHUNK / RATE)))) for f in edges]
for i in range(1, len(bin_edges)):
    if bin_edges[i] <= bin_edges[i - 1]:
        bin_edges[i] = bin_edges[i - 1] + 1

# Precompute Hanning window
HANNING = [0.5 * (1.0 - math.cos(2.0 * math.pi * n / (CHUNK - 1))) for n in range(CHUNK)]

# Precompute twiddle factors for FFT
def fft(x):
    N = len(x)
    if N <= 1:
        return x
    even = fft(x[0::2])
    odd = fft(x[1::2])
    T = [math.e ** (-2j * math.pi * k / N) * odd[k] for k in range(N // 2)]
    return [even[k] + T[k] for k in range(N // 2)] + [even[k] - T[k] for k in range(N // 2)]

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
            norm = [samples[n] / 32768.0 * HANNING[n] for n in range(CHUNK)]
            spectrum = fft(norm)
            mags = [abs(spectrum[k]) / (CHUNK / 2.0) for k in range(CHUNK // 2)]

            cur_bands = []
            for i in range(NUM_BANDS):
                start_k = bin_edges[i]
                end_k = bin_edges[i + 1]
                chunk_mags = mags[start_k:end_k]
                avg_mag = sum(chunk_mags) / max(1, len(chunk_mags))
                
                # Dynamic range scaling (dB scale + high frequency pre-emphasis)
                db = 20.0 * math.log10(avg_mag + 1e-5)
                norm_val = max(0.0, (db + 42.0) / 42.0)
                tilt = 1.0 + (i / float(NUM_BANDS)) * 1.6
                mag = min(1.0, norm_val * tilt)

                # Smooth attack & decay
                if mag > decay_bands[i]:
                    decay_bands[i] = mag
                else:
                    decay_bands[i] = max(0.0, decay_bands[i] * 0.82 - 0.015)

                cur_bands.append(round(decay_bands[i], 3))

            # Write atomic JSON to shared memory
            tmp_out = OUT_FILE + ".tmp"
            with open(tmp_out, "w", encoding="utf-8") as f:
                f.write("[" + ",".join(str(b) for b in cur_bands) + "]")
            os.replace(tmp_out, OUT_FILE)

        except Exception:
            time.sleep(0.03)

if __name__ == "__main__":
    run()
