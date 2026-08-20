# Omaramp 📻

Native status bar retro music player controller and real-time audio visualizer for Omarchy.

Inspired by Winamp & [cliamp](https://github.com/brianstrauch/cliamp).

[![Omarchy Plugin](https://img.shields.io/badge/omarchy-plugin-blue.svg)](https://omarchyplugins.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

![Omaramp Preview](preview.png)

## Features

- **Retro Winamp HUD**: Digital LED time counter (`01:23 / 03:45`), KBPS/Stereo badges, track marquee ticker, and smooth playhead scrubber.
- **37 Live Visualizer Styles**: Categorized selector featuring:
  - **Classic & VU**: Bars, Classic LED, Peaks, Columns, Bars Dot, Bars Outline, Bricks, Stereo VU, ASCII.
  - **Waves & Scopes**: Siri Wave (Apple iOS 9 algorithm), Sine Wave (standing acoustic harmonics), SoundCloud Wave (ultra-thin asymmetrical), Telegram Wave (voice capsule pills), DAW Peak Wave (RMS + True Peak dual-layer), LED Scrubber (discrete matrix blocks), Heatmap Wave (thermal energy gradient), Baseline Wave (grounded floor spectrum), XY Scope, Waveform, Heartbeat.
  - **Synth & Retro**: Retro Synth, Flame, Pulse, Matrix, Terrain, Binary, Logo, Mosaic.
  - **Particles & Nature**: Sand, Firework, Geyser, Firefly, Sakura, Bubbles, Rain, Butterfly, Scatter.
- **10-Band Equalizer & DSP Effects**:
  - 10-Band Pro EQ presets: *Flat, Bass Boost, Rock, Electronic, Pop, Vocal Clarity, Acoustic, Treble Boost, Late Night*.
  - **3D Spatial Audio Widener**: Binaural stereo expansion.
  - **EBU R128 Dynamic Loudness Normalizer**: Anti-earblast volume evening.
- **Synced Lyrics**: Live word-by-word synced lyrics powered by lrclib.net.
- **Streaming & YouTube Integration**:
  - Instant YouTube track search with auto-thumbnail prefetching.
  - FIFO streaming audio playback (no disk download needed).
  - YouTube & Spotify playlist importer.
- **Full Transport Deck**: Play/Pause, Next, Prev, Stop, Shuffle, Repeat, Volume slider, and Speed controls (0.5x–2.0x).
- **Keyboard Shortcuts**: `Space` (play/pause), `Left`/`Right` (seek), `Up`/`Down` (volume), `/` (search), `m` (mute), `Esc` (close).
- **Zero-Overhead Idle**: Sub-process sleep and lightweight PipeWire monitoring when paused or closed.
- **Status Bar Widget**:
  - **Left Click**: Toggle popup player panel.
  - **Middle Click**: Instant Play/Pause toggle.
  - **Right Click**: Skip to next track.
  - **Mouse Wheel**: Smooth volume adjustment directly from the bar.

## Installation

```bash
omarchy plugin add https://github.com/JoeJoeflyn/omaramp --enable
omarchy restart shell
```

### Enable in Omarchy

If adding manually to your status bar:

```bash
omarchy plugin enable omaramp right
omarchy restart shell
```

## Shell / IPC Commands

Control Omaramp from your terminal, scripts, or window manager hotkeys:

```bash
# Toggle player panel
omarchy-shell shell summon omaramp
omarchy-shell shell toggle omaramp

# Playback
omarchy-shell omaramp play
omarchy-shell omaramp pause
omarchy-shell omaramp toggle
omarchy-shell omaramp stop

# Navigation
omarchy-shell omaramp next
omarchy-shell omaramp prev

# Play a stream URL or YouTube link
omarchy-shell omaramp playUrl "https://www.youtube.com/watch?v=..."
```

## License

MIT License © 2026 JoeJoeflyn
