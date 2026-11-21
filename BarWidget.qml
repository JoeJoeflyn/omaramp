import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omaramp"

  readonly property var player: panelLoader.item
  readonly property bool hasTrack: player !== null && player.currentUrl !== "" &&
    (player.isPlaying || player.playbackState === "paused")
  property var pendingPanelCalls: []

  // ---- Equalizer: the bar icon's four bars follow the music (kick, bass, mids, highs).
  // Each bar mixes how loud its bands are within their recent range with how sharply they
  // rise over their recent average, so it jumps on a beat and settles between beats, in quiet
  // songs as in loud ones. Tuned on real music (bars past 70% in about one frame in six).
  // Without spectrum data (the recorder not running yet) the bars run a canned loop instead.
  readonly property bool eqLive: !!player && player.visActive === true
  readonly property var eqGroups: [[2, 5], [6, 10], [11, 16], [17, 22]]   // spectrum.py band ranges
  property var eqLevels: [0, 0, 0, 0]
  property var _eqAvg: [-1, -1, -1, -1]
  property var _eqTop: [0.02, 0.02, 0.02, 0.02]
  property var _eqPeak: [0, 0, 0, 0]
  property var _eqFloor: [1, 1, 1, 1]

  onEqLiveChanged: {
    _eqAvg = [-1, -1, -1, -1]
    _eqTop = [0.02, 0.02, 0.02, 0.02]
    _eqPeak = [0, 0, 0, 0]
    _eqFloor = [1, 1, 1, 1]
  }

  function updateEq() {
    if (!eqLive) return
    var bands = player.visBands
    var avg = _eqAvg.slice(), top = _eqTop.slice(), peak = _eqPeak.slice(), floor = _eqFloor.slice()
    var levels = []
    for (var g = 0; g < 4; g++) {
      var from = eqGroups[g][0], to = eqGroups[g][1], sum = 0
      for (var i = from; i <= to; i++) sum += bands[i] || 0
      var v = sum / (to - from + 1)
      peak[g] = Math.max(v, peak[g] - 0.01)
      floor[g] = Math.min(v, floor[g] + 0.01)
      var loud = Math.max(0, Math.min(1, (v - floor[g]) / Math.max(0.06, peak[g] - floor[g])))
      if (avg[g] < 0) avg[g] = v
      var rise = Math.max(0, v - avg[g])
      avg[g] += 0.25 * (v - avg[g])
      top[g] = Math.max(rise, top[g] * 0.97, 0.02)
      levels.push(Math.max(0, Math.min(1, 0.3 * loud + 0.7 * rise / top[g])))
    }
    _eqAvg = avg; _eqTop = top; _eqPeak = peak; _eqFloor = floor
    eqLevels = levels
  }

  Connections {
    target: root.player
    function onVisBandsChanged() { root.updateEq() }
  }

  function withPanel(action) {
    if (player) action(player)
    else {
      pendingPanelCalls.push(action)
      panelLoader.active = true
    }
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() { withPanel(p => p.toggle()) }
  function togglePlayback() { withPanel(p => p.togglePlayback()) }
  function nextTrack() { withPanel(p => p.nextTrack()) }
  function adjustVolume(delta) { withPanel(p => p.adjustVolume(delta)) }

  readonly property bool opened: player ? player.opened === true : false

  function open() { withPanel(p => p.openFromHotkey()) }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  // Register with the bar widget, not the lazy panel. Playback commands load the
  // controller if needed but don't open the popout.
  ShellIpc {
    target: "omaramp"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function refresh(): void { root.broadcast("refresh") }
    function play(): void { root.withPanel(p => p.play()) }
    function togglePlayback(): void { root.togglePlayback() }
    function pause(): void { root.withPanel(p => p.pause()) }
    function stop(): void { root.withPanel(p => p.stop()) }
    function next(): void { root.nextTrack() }
    function prev(): void { root.withPanel(p => p.prevTrack()) }
    function playUrl(url: string): void { root.withPanel(p => p.playUrl(url)) }
  }

  // The panel holds the poller that moves on to the next track. A shell or plugin reload
  // drops it, so when the player is already running it is loaded again right away.
  Process {
    running: true
    command: ["test", "-S", (Quickshell.env("XDG_RUNTIME_DIR") ||
      ((Quickshell.env("HOME") || "") + "/.cache/omaramp/run")) +
      (Quickshell.env("XDG_RUNTIME_DIR") ? "/omaramp/mpv.sock" : "/mpv.sock")]
    onExited: function(exitCode) { if (exitCode === 0) panelLoader.active = true }
  }

  Loader {
    id: panelLoader
    active: false
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      var actions = root.pendingPanelCalls
      root.pendingPanelCalls = []
      for (var i = 0; i < actions.length; i++) actions[i](item)
    }
  }

  TextMetrics {
    id: titleMetrics
    font.family: button.fontFamily
    font.pixelSize: button.fontSize
    text: !root.vertical && root.setting("showTitleInBar", true) && root.hasTrack
      ? root.player.currentTrack.slice(0, 300).replace(/\s+/g, " ").trim() : ""
    elide: Text.ElideRight
    elideWidth: Style.space(140)
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelText: titleMetrics.text ? titleMetrics.elidedText : ""
    slotSize: Style.bar.iconSlot + (labelText ? Math.ceil(Math.min(titleMetrics.advanceWidth, titleMetrics.elideWidth)) + Style.space(4) : 0)
    active: !!root.player && (root.opened || root.player.isPlaying)
    tooltipText: {
      if (!root.hasTrack) return "Omaramp"
      var a = root.player.currentArtist.slice(0, 160)
      return "Omaramp: " + (a ? a + " - " : "") + root.player.currentTrack.slice(0, 300)
    }

    iconComponent: Component {
      Item {
        anchors.fill: parent

        // 1. Equalizer while PLAYING. The bars are drawn scaled, not resized: the bar
        // follows the geometry of everything inside an icon (IconContentBounds), and a
        // height change on every frame of four looping animations kept the shell's main
        // thread near a full core for as long as music played. They move even with
        // Hyprland's animations off: the user wants them as the playing indicator.
        Row {
          id: eqBars
          anchors.centerIn: parent
          height: Style.space(12)
          spacing: Style.space(2)
          visible: panelLoader.item && panelLoader.item.isPlaying

          Repeater {
            // Each bar's resting height and the heights it moves through, in twelfths, with the ms per move
            model: [
              { rest: 4, to: [11, 4, 9, 3], ms: [320, 280, 240, 260] },
              { rest: 10, to: [3, 12, 6, 11], ms: [250, 340, 220, 290] },
              { rest: 7, to: [12, 5, 10, 4], ms: [290, 270, 310, 230] },
              { rest: 5, to: [4, 11, 5, 9], ms: [260, 310, 240, 280] }
            ]

            delegate: Rectangle {
              id: eqBar
              required property var modelData
              required property int index
              readonly property real liveLevel: root.eqLevels[index] || 0
              width: Style.space(2)
              height: eqBars.height
              radius: 1
              color: root.bar ? (root.bar.barForeground || root.bar.foreground || "#ffffff") : "#ffffff"
              transform: Scale {
                id: eqScale
                origin.y: eqBar.height
                yScale: eqBar.modelData.rest / 12
                // Glides between spectrum frames, which come about 21 times a second
                Behavior on yScale {
                  enabled: root.eqLive
                  NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                }
              }

              onLiveLevelChanged: if (root.eqLive) eqScale.yScale = 0.15 + 0.85 * liveLevel

              SequentialAnimation {
                running: eqBars.visible && !root.eqLive
                loops: Animation.Infinite
                onStopped: eqScale.yScale = eqBar.modelData.rest / 12
                NumberAnimation { target: eqScale; property: "yScale"; to: eqBar.modelData.to[0] / 12; duration: eqBar.modelData.ms[0]; easing.type: Easing.InOutQuad }
                NumberAnimation { target: eqScale; property: "yScale"; to: eqBar.modelData.to[1] / 12; duration: eqBar.modelData.ms[1]; easing.type: Easing.InOutQuad }
                NumberAnimation { target: eqScale; property: "yScale"; to: eqBar.modelData.to[2] / 12; duration: eqBar.modelData.ms[2]; easing.type: Easing.InOutQuad }
                NumberAnimation { target: eqScale; property: "yScale"; to: eqBar.modelData.to[3] / 12; duration: eqBar.modelData.ms[3]; easing.type: Easing.InOutQuad }
              }
            }
          }
        }

        // 2. Static Icon when STOPPED or PAUSED
        Text {
          anchors.centerIn: parent
          visible: !panelLoader.item || !panelLoader.item.isPlaying
          text: (panelLoader.item && panelLoader.item.playbackState === "paused") ? "\uf04c" : "\uf001"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.bar.iconFont
          color: (panelLoader.item && panelLoader.item.opened)
            ? (root.bar ? (root.bar.barForeground || root.bar.foreground || "#ffffff") : "#ffffff")
            : ((panelLoader.item && panelLoader.item.playbackState === "paused")
                ? (panelLoader.item ? panelLoader.item.dim : Color.foreground)
                : (root.bar ? root.bar.foreground : Color.foreground))
        }
      }
    }

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.nextTrack()
      else if (b === Qt.MiddleButton) root.togglePlayback()
      else root.togglePanel()
    }
  }

  WheelHandler {
    target: button
    onWheel: function(event) {
      if (event.angleDelta.y > 0) root.adjustVolume(5)
      else if (event.angleDelta.y < 0) root.adjustVolume(-5)
    }
  }
}
