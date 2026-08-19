# Omaramp 📻

Native status bar retro music player controller and live spectrum visualizer for Omarchy.

Inspired by [cliamp](https://github.com/brianstrauch/cliamp).

[![Omarchy Plugin](https://img.shields.io/badge/omarchy-plugin-blue.svg)](https://omarchyplugins.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

![Omaramp Preview](preview.png)

## Features

- **Retro Winamp HUD**: Digital LED time counter (`01:23 / 03:45`), KBPS/Stereo badges, and track marquee ticker.
- **Live 24-Band Spectrum Visualizer**: Animated retro equalizer canvas with falling peak LED indicators.
- **Full Transport Deck**: Play/Pause, Next, Prev, Stop, Shuffle, Repeat cycle, and volume slider.
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

## License

MIT License © 2026 JoeJoeflyn
