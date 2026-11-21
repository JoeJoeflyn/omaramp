# omaramp

Omarchy shell plugin. `BarWidget.qml` is the bar icon and loads the player panel (`Panel.qml`,
`Player.qml`, `TrackList.qml`). `cliamp_ctl.py` is the backend: one short process per command,
driving a headless mpv over its IPC socket. `spectrum.py` is the daemon that feeds the visualizers.

## Checks

Run all three after a change. None needs the shell, the network or mpv.

    node tests/check.js       # every visualizer on a fake canvas, style lists in sync, row matching
    python3 tests/check.py    # search paging, list contexts, Repeat One, single auto-advance, status poll
    qmllint *.qml             # syntax only; it exits 255 with no message on BarWidget.qml

## Things that bite

- Saving a file here makes the shell log "reloading: omaramp", but the QML keeps running from
  the old cache: an edit to any of it shows only after `omarchy restart shell`. The Python is
  read fresh on every command. Edit a copy and sync it when it lints.
- Nothing inside the bar icon may change x, y, width, height or scale on every frame. The bar
  follows the geometry of every item in an icon (the shell's `Ui/IconContentBounds.qml`), and
  four looping height animations kept the shell near a full core while music played. Move the
  painting instead (a `Scale` transform), as the equalizer does.
- The panel runs the backend as `/usr/bin/python3 ctl.py ...`, not `python3 cliamp_ctl.py`: the
  shell's PATH can find a version manager's Python without NumPy, and a script run directly is
  compiled again on every call.
- To see where the shell spends its time, run it with `--debug <port>` and attach
  `qmlprofiler --attach 127.0.0.1 --port <port> --interactive`.
- State lives in `~/.cache/omaramp` and `$XDG_RUNTIME_DIR/omaramp`. Point `HOME` and
  `XDG_RUNTIME_DIR` at a temp dir to try the backend without touching the real player.
- Visualizer ids are listed three times: `visModes` in `Panel.qml`, `_renderers` and
  `_modeLabels` in `Player.qml`, `allModes` in `VisPicker.qml`. `tests/check.js` fails when they drift.
- A standalone Quickshell config that loads this QML needs `//@ pragma OmarchyLoadPatch` on its
  first line. Without it the bare `Color` here is QtQuick's `Color` and every theme color is undefined.
- No new animation in the panel: see `docs/agent-devkit/` (decision D1).
