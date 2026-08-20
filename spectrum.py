#!/usr/bin/env python3
"""Real-time FFT spectrum + waveform capture for Omaramp via PipeWire."""
import os, sys, time, math, struct, subprocess, signal
import numpy as np

OUT_FILE = f"/dev/shm/omaramp_spectrum_{os.getuid()}.json"
RATE = 44100
CHUNK = 2048  # 2048-sample FFT — 44100/2048=21.5Hz/bin, Nyquist 22050 covers 12kHz+
NUM_BANDS = 24
WAVE_SAMPLES = 128  # raw waveform points for scope/wave modes

min_f, max_f = 20.0, 16000.0  # match cliamp legacySpectrumEdges 20-16000
edges = [min_f * ((max_f / min_f) ** (i / float(NUM_BANDS))) for i in range(NUM_BANDS + 1)]
bin_edges = [max(1, min(CHUNK // 2, int(round(f * CHUNK / RATE)))) for f in edges]
for i in range(1, len(bin_edges)):
    if bin_edges[i] <= bin_edges[i - 1]:
        bin_edges[i] = bin_edges[i - 1] + 1

HANNING = np.hanning(CHUNK)

decay_bands = [0.0] * NUM_BANDS

def get_monitor_target():
    try:
        res = subprocess.run(["pactl", "get-default-sink"], capture_output=True, text=True, timeout=2)
        sink = res.stdout.strip()
        return sink + ".monitor" if sink else None
    except Exception:
        return None

def run():
    global decay_bands
    cmd = ["pw-record", "--raw", "--channels=1", "--format=s16", f"--rate={RATE}"]
    monitor = get_monitor_target()
    if monitor:
        cmd += ["--target", monitor]
    cmd.append("-")
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    except Exception:
        return

    def cleanup(sig, frame):
        try: proc.terminate()
        except Exception: pass
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
            raw = [s / 32768.0 for s in samples]  # unwindowed for waveform
            # numpy FFT with Hanning window — 1000× faster than recursive Python FFT
            norm = np.array(raw, dtype=np.float64) * HANNING
            spectrum = np.fft.rfft(norm)
            mags = np.abs(spectrum) / (CHUNK / 2.0)

            cur_bands = []
            for i in range(NUM_BANDS):
                lo, hi = bin_edges[i], bin_edges[i + 1]
                avg_mag = float(mags[lo:hi].mean()) if hi > lo else float(mags[lo])
                db = 20.0 * math.log10(avg_mag + 1e-10)
                # -96dB floor with 96dB dynamic range
                norm_val = max(0.0, (db + 96.0) / 96.0)
                # Treble tilt: match cliamp's log-spaced edges + boost highs for
                # compressed streams (YouTube/MP3). Up to 5× at band 23.
                tilt = 1.0 + (i / float(NUM_BANDS)) * 4.0
                mag = min(1.0, norm_val * tilt)
                if mag > decay_bands[i]:
                    # fast attack like cliamp 0.6/0.4
                    decay_bands[i] = mag * 0.6 + decay_bands[i] * 0.4
                else:
                    # slow decay like cliamp 0.25/0.75
                    decay_bands[i] = max(0.0, mag * 0.25 + decay_bands[i] * 0.75)
                cur_bands.append(round(decay_bands[i], 3))

            # Downsample raw waveform for scope/wave modes, with gain
            step = max(1, CHUNK // WAVE_SAMPLES)
            wave_raw = [raw[i] for i in range(0, CHUNK, step)][:WAVE_SAMPLES]
            # Normalize: amplify quiet signals so waveform is visible
            peak = max(abs(x) for x in wave_raw) if wave_raw else 0
            gain = min(50.0, 0.7 / peak) if peak > 0.001 else 1.0
            wave = [round(max(-1.0, min(1.0, x * gain)), 4) for x in wave_raw]

            tmp_out = OUT_FILE + ".tmp"
            with open(tmp_out, "w", encoding="utf-8") as f:
                f.write('{"bands":[' + ",".join(str(b) for b in cur_bands) +
                        '],"wave":[' + ",".join(str(w) for w in wave) + ']}')
            os.replace(tmp_out, OUT_FILE)

        except Exception:
            time.sleep(0.03)

if __name__ == "__main__":
    run()
