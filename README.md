# Omaramp 📻

Native status bar retro music player controller and live spectrum visualizer for Omarchy.

Inspired by [cliamp](https://github.com/brianstrauch/cliamp).

[![Omarchy Plugin](https://img.shields.io/badge/omarchy-plugin-blue.svg)](https://omarchyplugins.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

![Omaramp Preview](preview.png)

## Features

- **Retro Winamp HUD**: Digital LED time counter (`01:23 / 03:45`), KBPS/Stereo badges, and track marquee ticker.
- **Live 24-Band Spectrum Visualizer**: Animated retro equalizer canvas with falling peak LED indicators, 29 visualizer modes.
- **Full Transport Deck**: Play/Pause, Next, Prev, Stop, Shuffle, Repeat cycle, and volume slider.
- **Album Art**: Thumbnail display in now-playing bar and track list.
- **Seek Bar**: Hover for time tooltip, click or drag to scrub.
- **Keyboard Shortcuts**: Space (play/pause), arrows (seek/volume), `/` (search), `m` (mute).
- **Synced Lyrics**: Fetches from lrclib.net, shows current line synced to playback position.
- **Resume on Startup**: Remembers last track and position, offers to resume.
- **Crossfade**: Smooth volume fade out/in when switching tracks.
- **Playback Speed**: Cycle through 0.5x–2.0x speed control.
- **Album Art Backdrop**: Blurred track artwork as ambient panel background.
- **Quick Queue / Stream Input**: Paste YouTube, SoundCloud, stream URLs, or local audio file paths to play or queue instantly.
- **Playlist & History Browser**: Browse and play directly from recently played tracks and saved local playlists.
- **Zero-Overhead Idle**: Uses 0% CPU and negligible memory when not in use.
- **Bar Widget Controls**:
  - **Left Click**: Open/toggle popup player panel.
  - **Middle Click**: Instant Play/Pause toggle.
  - **Right Click**: Skip to next track.
  - **Mouse Wheel**: Smooth volume adjustment directly from the bar.

## Installation

```

### Enable in Omarchy

Enable `omaramp` in your status bar:

```bash
omarchy plugin enable omaramp right
omarchy restart shell
```

## Shell / IPC Commands

Control Omaramp from your terminal, scripts, or keyboard shortcuts:

```bash
# Toggle player panel
omarchy-shell shell summon omaramp
omarchy-shell shell toggle omaramp

# Play / Pause
omarchy-shell omaramp play
omarchy-shell omaramp pause
omarchy-shell omaramp toggle

# Navigation
omarchy-shell omaramp next
omarchy-shell omaramp prev
omarchy-shell omaramp stop

# Play a stream URL or YouTube link
omarchy-shell omaramp playUrl "https://www.youtube.com/watch?v=..."
```

## Removal

```bash
omarchy plugin remove omaramp --yes
```

This removes the plugin checkout and bar entry. Cached data in `~/.cache/omaramp/` is left behind — remove it manually if you no longer need it:

```bash
rm -rf ~/.cache/omaramp
```

## License

MIT License © 2026 JoeJoeflyn
