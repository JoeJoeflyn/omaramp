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
    function openFiles(): void { root.withPanel(p => p.pickLocalFiles()) }
    function addFile(path: string): void { root.addLocalFiles([path]) }
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

  // BarIconButton optically shrinks art to glyph size. Give the spectrum a
  // real, fixed-width drawing surface without changing the button hit target per frame.
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    fontSize: Style.bar.iconFont
    labelVisible: false
    hasVisualContent: true
    fixedWidth: vertical ? -1 : Math.ceil(content.implicitWidth) + Style.space(8)
    fixedHeight: vertical ? Style.bar.iconSlot : -1
    active: !!root.player && (root.opened || root.player.isPlaying)
    tooltipText: {
      if (!root.hasTrack) return "Omaramp"
      var a = root.player.currentArtist.slice(0, 160)
      return "Omaramp: " + (a ? a + " - " : "") + root.player.currentTrack.slice(0, 300)
    }

    Row {
      id: content
      anchors.centerIn: parent
      spacing: Style.space(4)
      scale: button.pressScale
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: text !== ""
        text: titleMetrics.text ? titleMetrics.elidedText : ""
        textFormat: Text.PlainText
        color: button.active ? button.activeColor : button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
      }
      BarWaveform {
        anchors.verticalCenter: parent.verticalCenter
        width: button.vertical ? Math.max(1, button.barSize - Style.space(6)) : Style.space(48)
        height: Math.min(button.barSize, Style.space(18))
        player: root.player
        foreground: button.foreground
      }
    }

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.nextTrack()
      else if (b === Qt.MiddleButton) root.togglePlayback()
      else root.togglePanel()
    }
  }

  function addLocalFiles(paths) {
    withPanel(p => p.addLocalFiles(paths))
  }

  function droppedPaths(urls) {
    var paths = []
    for (var i = 0; i < urls.length; i++) {
      var match = /^file:\/\/(?:localhost)?(\/[^?#]*)(?:[?#].*)?$/i.exec(String(urls[i]))
      if (!match) continue
      try {
        var path = decodeURIComponent(match[1])
        if (path.indexOf("\u0000") === -1) paths.push(path)
      } catch (e) { /* An invalid URI must not discard other files in the drop. */ }
    }
    return paths
  }

  // Drop files/folders from a file manager onto the bar icon. The panel can't
  // be a drop target: it closes as soon as another window is clicked.
  DropArea {
    id: dropArea
    anchors.fill: parent
    keys: ["text/uri-list"]
    onDropped: function(drop) {
      var paths = root.droppedPaths(drop.urls)
      if (paths.length === 0) return
      drop.acceptProposedAction()
      root.addLocalFiles(paths)
    }
  }

  Rectangle {
    anchors.fill: parent
    visible: dropArea.containsDrag
    color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25)
    border.color: Color.accent
    border.width: 1
    radius: Style.cornerRadius
  }

  WheelHandler {
    target: button
    onWheel: function(event) {
      if (event.angleDelta.y > 0) root.adjustVolume(5)
      else if (event.angleDelta.y < 0) root.adjustVolume(-5)
    }
  }
}
