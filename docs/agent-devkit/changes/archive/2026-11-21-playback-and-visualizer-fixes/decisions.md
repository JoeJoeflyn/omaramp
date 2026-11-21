# Playback and visualizer fixes decisions

### D1 — No new animations

Question: The approved design added fades for the lyrics/EQ/style-picker swap, tab and
playlist changes, the visualizer style switch and the track change. Hyprland animations are
off on the user's machine, so under Omarchy's rule for plugins they would not play. Should
they follow the system toggle or always play?
Decision: No animation is needed. All of the new fades are dropped, including the one on the
error message.
Impact: The transition items keep only their parts without motion: the track list, style
picker, EQ and lyrics share one area of a fixed size, so the card no longer resizes when one
replaces another, and a tab or playlist starts at its top. `Panel.qml`, `Player.qml` and
`TrackList.qml` carry no new animation.
Confirmed by user: 2026-11-21
