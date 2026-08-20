import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "omaramp"
  ipcTarget: "omaramp"
  manageIpc: false

  property var anchorItem: null
  property bool openedFromHotkey: false
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ---- State
  property bool isRunning: false
  property string playbackState: "stopped"
  readonly property bool isPlaying: playbackState === "playing"
  property string currentTrack: "No track loaded"
  property string currentArtist: ""
  property string currentUrl: ""
  property string artPath: ""
  property string artColor: ""
  property color dynamicAccent: (artColor !== "" && isPlaying) ? artColor : Color.accent
  Behavior on dynamicAccent { ColorAnimation { duration: 500; easing.type: Easing.InOutQuad } }
  property string timeCurrent: "00:00"
  property string timeTotal: "00:00"
  property int curSecs: 0
  property int totalSecs: 0
  property real progress: 0.0
  property real playbackSpeed: 1.0
  property int volumePct: 80
  property real volumeDb: 0.0
  property bool shuffleMode: false
  property string repeatMode: "off"
  property string eqText: "Custom"
  property var audioFx: ({ "eq": "Flat", "loudnorm": false, "spatial": false })
  property int _preMuteVol: 80

  property var historyList: []
  property var playlistsList: []
  property var searchResults: []
  property bool isSearching: false
  property string searchQuery: ""
  property string loadingVid: ""
  property string selectedTab: "history"
  property string urlInputText: ""
  property string visMode: "scrubber_wave"
  property bool visPickerOpen: false
  property bool eqPickerOpen: false
  property var visModes: ["bars", "bars_dot", "bars_outline", "bricks", "columns", "classic_led", "peaks", "wave", "scope", "heartbeat", "sine", "siriwave", "scrubber_wave", "retro", "scatter", "flame", "pulse", "matrix", "binary", "butterfly", "sakura", "firework", "bubbles", "rain", "terrain", "logo", "firefly", "geyser", "mosaic", "sand", "stereo", "ascii"]

  // Visualizer state
  property var visBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  property var visPeaks: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  property var visWave: []
  property int visFrame: 0
  property var _visState: ({})
  property var resumeInfo: null
  property bool resumeVisible: false

  // ---- Lifecycle
  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    root.refresh()
    loadHistory()
    loadPlaylists()
    runCmd(["start_spectrum"])
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    root.refresh()
    loadHistory()
    loadPlaylists()
    runCmd(["start_spectrum"])
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.visPickerOpen = false
    root.eqPickerOpen = false
    root.controller.hide()
    runCmd(["stop_spectrum"])
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // ---- Actions
  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function togglePlayback() { runCmd(["toggle"]) }
  function play() { runCmd(["play"]) }
  function pause() { runCmd(["pause"]) }
  function stop() { runCmd(["stop"]) }
  function nextTrack() { runCmd(["next"]) }
  function prevTrack() { runCmd(["prev"]) }
  function toggleShuffle() { runCmd(["shuffle"]) }
  function cycleRepeat() { runCmd(["repeat"]) }

  function adjustVolume(delta) {
    setVolume(Math.max(0, Math.min(100, root.volumePct + delta)))
  }

  function setVolume(pct) {
    root.volumePct = pct
    runCmd(["volume_pct", String(pct)])
  }

  function toggleMute() {
    if (root.volumePct > 0) {
      root._preMuteVol = root.volumePct
      setVolume(0)
    } else {
      var target = (root._preMuteVol && root._preMuteVol > 0) ? root._preMuteVol : 80
      setVolume(target)
    }
  }

  function seekTo(sec) { runCmd(["seek", String(sec)]) }
  function cycleSpeed() {
    var speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    var cur = root.playbackSpeed
    var idx = 0
    for (var i = 0; i < speeds.length; i++) { if (Math.abs(speeds[i] - cur) < 0.05) { idx = i; break } }
    var next = speeds[(idx + 1) % speeds.length]
    root.playbackSpeed = next
    runCmd(["speed", String(next)])
  }
  function setEq(preset) {
    root.eqText = preset
    runCmd(["set_eq", preset])
  }
  function toggleLoudnorm() {
    runCmd(["toggle_loudnorm"])
    var next = !(root.audioFx && root.audioFx.loudnorm)
    root.audioFx = { eq: root.eqText, loudnorm: next, spatial: root.audioFx ? root.audioFx.spatial : false }
  }
  function toggleSpatial() {
    runCmd(["toggle_spatial"])
    var next = !(root.audioFx && root.audioFx.spatial)
    root.audioFx = { eq: root.eqText, loudnorm: root.audioFx ? root.audioFx.loudnorm : false, spatial: next }
  }
  function importPlaylist(url, name) {
    if (!url || !url.trim()) return
    runCmd(["import_playlist", url.trim(), name || ""])
    Qt.callLater(loadPlaylists)
  }
  function doResume() { runCmd(["resume"]); root.resumeVisible = false; root.loadingVid = "" }

  function playUrl(url, title, artist) {
    if (!url || !url.trim()) return
    var u = url.trim()
    root.loadingVid = u
    root.currentTrack = title || "Buffering..."
    root.currentArtist = artist || ""
    root.playbackState = "buffering"
    runCmd(["play_item", u, title || "", artist || ""])
    root.urlInputText = ""
  }

  function queueUrl(url, title, artist) {
    if (!url || !url.trim()) return
    runCmd(["queue", url.trim(), title || "", artist || ""])
    root.urlInputText = ""
    loadHistory()
  }

  function searchTracks(query) {
    if (!query || !query.trim()) return
    var q = query.trim()
    if (q.indexOf("http://") === 0 || q.indexOf("https://") === 0) {
      if (q.indexOf("list=") !== -1 || q.indexOf("/playlist/") !== -1 || q.indexOf("/album/") !== -1) {
        importPlaylist(q)
        root.selectedTab = "playlists"
        return
      }
      playUrl(q)
      return
    }
    root.isSearching = true
    root.searchQuery = q
    root.selectedTab = "search"
    searchProc.command = ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "search", q]
    searchProc.running = true
  }

  function clearSearch() {
    root.searchQuery = ""
    root.searchResults = []
    root.isSearching = false
    root.selectedTab = "history"
  }

  function loadPlaylist(name) { runCmd(["load", name]) }
  function playPlaylist(pl) {
    if (!pl || !pl.tracks || pl.tracks.length === 0) return
    var t0 = pl.tracks[0]
    playUrl(t0.url || (t0.title + " " + t0.artist), t0.title, t0.artist)
    for (var i = 1; i < pl.tracks.length; i++) {
      var t = pl.tracks[i]
      queueUrl(t.url || (t.title + " " + t.artist), t.title, t.artist)
    }
  }

  function stopDaemon() {
    runCmd(["stop_daemon"])
    root.isRunning = false
    root.playbackState = "stopped"
  }

  function loadHistory() {
    if (!historyProc.running) historyProc.running = true
  }

  function loadPlaylists() {
    if (!playlistsProc.running) playlistsProc.running = true
  }

  function runCmd(args) {
    actionProc.command = ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", "")].concat(args)
    actionProc.running = true
  }

  // ---- Processes
  Process {
    id: statusProc
    command: ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text || "{}")
          root.isRunning = data.running === true
          root.playbackState = String(data.state || "stopped")
          var newTrack = String(data.track || "No track loaded")
          var newUrl = String(data.url || "")
          var trackChanged = newTrack !== root.currentTrack
          root.currentTrack = newTrack
          root.currentArtist = String(data.artist || "")
          root.currentUrl = newUrl
          root.artPath = String(data.art_path || "")
          root.artColor = String(data.art_color || "")
          if (trackChanged && playerComp.lyricsVisible && playerComp.lyricsTrack !== newTrack) {
            playerComp.fetchLyrics()
          }
          root.timeCurrent = String(data.time_current || "00:00")
          root.timeTotal = String(data.time_total || "00:00")
          root.curSecs = Number(data.cur_secs || 0)
          if (playerComp.lyricsVisible) playerComp.updateLyricsPosition(root.curSecs)
          root.totalSecs = Number(data.total_secs || 0)
          root.progress = Number(data.progress || 0.0)
          root.volumePct = (data.volume_pct !== undefined && data.volume_pct !== null) ? Number(data.volume_pct) : 80
          root.playbackSpeed = Number(data.speed || 1.0)
          root.volumeDb = Number(data.volume_db || 0.0)
          root.shuffleMode = data.shuffle === true
          root.repeatMode = String(data.repeat || "off")
          root.eqText = String(data.eq || "Custom")
          if (data.audio_fx) root.audioFx = data.audio_fx
          if (data.resume && root.playbackState === "stopped") {
            root.resumeInfo = data.resume
            root.resumeVisible = true
          } else {
            root.resumeVisible = false
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: searchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.searchResults = JSON.parse(text || "[]") }
        catch (e) { root.searchResults = [] }
        root.isSearching = false
      }
    }
  }

  Process {
    id: historyProc
    command: ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "history", "30"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.historyList = JSON.parse(text || "[]") }
        catch (e) { root.historyList = [] }
      }
    }
  }

  Process {
    id: playlistsProc
    command: ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "playlists"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.playlistsList = JSON.parse(text || "[]") }
        catch (e) { root.playlistsList = [] }
      }
    }
  }

  Process {
    id: actionProc
    onExited: function() {
      root.loadingVid = ""
      root.refresh()
      if (root.opened) loadHistory()
    }
  }

  // Poll timer
  Timer {
    id: pollTimer
    interval: root.opened ? 1000 : ((root.settings && root.settings.pollIntervalSec ? root.settings.pollIntervalSec : 2) * 1000)
    running: true; repeat: true; triggeredOnStart: true
    onTriggered: root.refresh()
  }

  readonly property var _xdg: Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000"
  readonly property string spectrumPath: "/dev/shm/omaramp_spectrum_" + _xdg.split("/").pop() + ".json"

  FileView {
    id: specFile
    path: root.spectrumPath
    watchChanges: true; printErrors: false
    onFileChanged: root.updateSpectrumData(text())
    onLoaded: root.updateSpectrumData(text())
  }

  function updateSpectrumData(raw) {
    if (!root.opened) return
    if (!root.isPlaying) {
      var decayedBands = [], decayedPeaks = [], hasAny = false
      for (var k = 0; k < 24; k++) {
        var b = Math.max(0, (root.visBands[k] || 0) * 0.8 - 0.02)
        var p = Math.max(0, (root.visPeaks[k] || 0) * 0.8 - 0.02)
        decayedBands.push(b); decayedPeaks.push(p)
        if (b > 0 || p > 0) hasAny = true
      }
      root.visBands = decayedBands; root.visPeaks = decayedPeaks
      if (hasAny && playerComp) playerComp.requestPaint()
      return
    }

    var content = raw
    if (!content && specFile) { try { content = specFile.text() } catch (e) {} }
    if (!content) return

    try {
      var data = JSON.parse(content)
      var bands = data.bands || data
      if (Array.isArray(bands) && bands.length >= 24) {
        var newBands = [], newPeaks = []
        for (var i = 0; i < 24; i++) {
          var target = Math.min(1.0, Math.max(0.0, Number(bands[i]) || 0.0))
          var prevPeak = root.visPeaks[i] || 0.0
          newBands.push(target)
          newPeaks.push(Math.max(target, prevPeak - 0.03))
        }
        root.visBands = newBands; root.visPeaks = newPeaks
        root.visWave = Array.isArray(data.wave) ? data.wave : []
        root.visFrame++
        if (playerComp) playerComp.requestPaint()
      }
    } catch (e) {}
  }

  Timer {
    id: visTimer
    interval: 35; running: root.opened; repeat: true
    onTriggered: {
      if (root.isPlaying) specFile.reload()
      else root.updateSpectrumData("")
    }
  }

  // IPC
  IpcHandler {
    target: "omaramp"
    function open() { root.openFromHotkey() }
    function close() { root.close() }
    function show() { root.openFromHotkey() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function refresh() { root.refresh() }
    function play() { root.play() }
    function pause() { root.pause() }
    function stop() { root.stop() }
    function next() { root.nextTrack() }
    function prev() { root.prevTrack() }
    function playUrl(url: string) { root.playUrl(url) }
  }

  // ---- Popup Window
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight + Style.space(16), Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: trackList.urlInput.activeFocus

      Component.onCompleted: {
        if (keyCatcher.parent && keyCatcher.parent.parent) {
          var card = keyCatcher.parent.parent
          card.x = Qt.binding(function() {
            var sw = panel.screen ? panel.screen.width : (panel.anchorItem && panel.anchorItem.Window.window ? panel.anchorItem.Window.window.width : 1920)
            return sw - panel.contentWidth - panel.margin
          })
        }
      }

      onCloseRequested: {
        if (root.eqPickerOpen) root.eqPickerOpen = false
        else if (root.visPickerOpen) root.visPickerOpen = false
        else if (playerComp.lyricsVisible) playerComp.toggleLyrics()
        else root.close()
      }
      onActivateRequested: root.togglePlayback()
      onMoveRequested: function(dx, dy) {
        if (dy < 0) root.adjustVolume(5)
        else if (dy > 0) root.adjustVolume(-5)
        else if (dx > 0) root.seekTo(Math.min(root.totalSecs, root.curSecs + 5))
        else if (dx < 0) root.seekTo(Math.max(0, root.curSecs - 5))
      }
      onTextKey: function(t) {
        if (t === "/") { trackList.urlInput.forceActiveFocus(); trackList.urlInput.selectAll() }
        else if (t === "m") root.toggleMute()
      }

      // Blurred album art background
      Image {
        anchors.fill: parent
        source: root.artPath
        fillMode: Image.PreserveAspectCrop
        visible: root.artPath !== ""
        opacity: 0.12
        smooth: true
        z: -1
      }

      Column {
        id: mainColumn
        width: parent.width - Style.space(20)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(8)
        topPadding: Style.space(6)
        bottomPadding: Style.space(8)

        BorderSurface {
          visible: root.resumeVisible
          width: parent.width; implicitHeight: Style.space(28)
          radius: Style.cornerRadius
          color: Qt.rgba(0.04, 0.04, 0.05, 0.95)
          borderSpec: Border.flat(Color.accent, 1)

          Row {
            anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(6)
            Text { anchors.verticalCenter: parent.verticalCenter; text: "\uf0e2"; color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            Text {
              width: parent.width - Style.space(80); anchors.verticalCenter: parent.verticalCenter
              text: root.resumeInfo ? "Resume: " + (root.resumeInfo.title || "last track") : ""
              color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter; text: "Resume"; color: Color.accent
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.doResume() }
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter; text: "\uf00d"; color: root.dim
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.resumeVisible = false }
            }
          }
        }

        Player { id: playerComp; p: root }

        Transport { p: root }

        PanelSeparator { foreground: root.foreground }

        TrackList { id: trackList; p: root; visible: !playerComp.lyricsVisible && !root.visPickerOpen && !root.eqPickerOpen }

        // Visualizer Picker (Lazy loaded on demand)
        Loader {
          visible: root.visPickerOpen && !root.eqPickerOpen
          active: root.visPickerOpen
          width: parent.width
          source: "VisPicker.qml"
          onLoaded: { if (item) item.p = root }
        }

        // Equalizer Profile Picker (Lazy loaded on demand)
        Loader {
          visible: root.eqPickerOpen
          active: root.eqPickerOpen
          width: parent.width
          source: "EqPicker.qml"
          onLoaded: { if (item) item.p = root }
        }

        // Lyrics view — replaces track list when toggled
        Item {
          visible: playerComp.lyricsVisible && !root.visPickerOpen && !root.eqPickerOpen
          width: parent.width
          height: Style.space(200)

          BorderSurface {
            anchors.fill: parent
            radius: Style.cornerRadius
            color: Qt.rgba(0.05, 0.05, 0.07, 0.85)
            borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

            Row {
              id: lyricsHeader
              anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf10d"
                color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption
              }
              Text {
                width: parent.width - Style.space(40); anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "Lyrics — " + (root.currentTrack || "No track")
                color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                font.bold: true; elide: Text.ElideRight
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf00d"
                color: closeLyricsMouse.containsMouse ? Color.accent : root.dim
                font.family: root.fontFamily; font.pixelSize: Style.font.caption
                MouseArea {
                  id: closeLyricsMouse
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
                  onClicked: playerComp.toggleLyrics()
                }
              }
            }

            Text {
              visible: playerComp.lyricsLines.length === 0
              anchors.centerIn: parent
              text: "No synced lyrics available"
              color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption
            }

            Column {
              visible: playerComp.lyricsLines.length > 0
              anchors.centerIn: parent
              width: parent.width - Style.space(24)
              spacing: Style.space(8)

              Text {
                width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: {
                  var i = playerComp.lyricsCurrentIdx - 1
                  return (i >= 0 && playerComp.lyricsLines[i]) ? playerComp.lyricsLines[i].text : ""
                }
                color: Qt.rgba(1, 1, 1, 0.25); font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: {
                  var i = playerComp.lyricsCurrentIdx
                  if (i < 0 || !playerComp.lyricsLines[i]) return "♪ ♪ ♪"
                  return playerComp.lyricsLines[i].text || "♪"
                }
                color: Color.accent; font.family: root.fontFamily
                font.pixelSize: Style.font.body; font.bold: true
              }

              Text {
                width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                textFormat: Text.PlainText
                text: {
                  var i = playerComp.lyricsCurrentIdx + 1
                  if (i < 0 || !playerComp.lyricsLines[i]) return ""
                  return playerComp.lyricsLines[i].text || ""
                }
                color: Qt.rgba(1, 1, 1, 0.35); font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
      }
    }
  }
}
