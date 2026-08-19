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
  property string artPath: ""
  property string timeCurrent: "00:00"
  property string timeTotal: "00:00"
  property int curSecs: 0
  property int totalSecs: 0
  property real progress: 0.0
  property int volumePct: 80
  property real volumeDb: 0.0
  property bool shuffleMode: false
  property string repeatMode: "off"
  property string eqText: "Custom"
  property int _preMuteVol: 80

  property var historyList: []
  property var playlistsList: []
  property var searchResults: []
  property bool isSearching: false
  property string searchQuery: ""
  property string loadingVid: ""
  property string selectedTab: "history"
  property string urlInputText: ""
  property string visMode: "bars"
  property var visModes: ["bars", "bars_dot", "bars_outline", "bricks", "columns", "classic_led", "peaks", "wave", "scope", "heartbeat", "retro", "scatter", "flame", "pulse", "matrix", "binary", "butterfly", "sakura", "firework", "bubbles", "rain", "terrain", "logo", "firefly", "geyser", "mosaic", "sand", "stereo", "ascii"]

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
    checkResume()
  }

  function checkResume() {
    if (root.isPlaying || root.playbackState === "paused") { root.resumeVisible = false; return }
    resumeProc.running = true
  }

  function doResume() {
    runCmd(["resume"])
    root.resumeVisible = false
    root.loadingVid = ""
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    root.refresh()
    loadHistory()
    loadPlaylists()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
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
    if (root.volumePct > 0) { root._preMuteVol = root.volumePct; setVolume(0) }
    else setVolume(root._preMuteVol || 80)
  }

  function seekTo(sec) { runCmd(["seek", String(sec)]) }

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
          root.currentTrack = String(data.track || "No track loaded")
          root.currentArtist = String(data.artist || "")
          root.artPath = String(data.art_path || "")
          root.timeCurrent = String(data.time_current || "00:00")
          root.timeTotal = String(data.time_total || "00:00")
          root.curSecs = Number(data.cur_secs || 0)
          if (playerComp.lyricsVisible) playerComp.updateLyricsPosition(root.curSecs)
          root.totalSecs = Number(data.total_secs || 0)
          root.progress = Number(data.progress || 0.0)
          root.volumePct = Number(data.volume_pct || 80)
          root.volumeDb = Number(data.volume_db || 0.0)
          root.shuffleMode = data.shuffle === true
          root.repeatMode = String(data.repeat || "off")
          root.eqText = String(data.eq || "Custom")
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

  Process {
    id: resumeProc
    command: ["python3", Qt.resolvedUrl("cliamp_ctl.py").replace("file://", ""), "resume_info"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.url) {
            root.resumeInfo = d
            root.resumeVisible = true
          } else {
            root.resumeVisible = false
          }
        } catch (e) { root.resumeVisible = false }
      }
    }
  }

  // Poll timer
  Timer {
    id: pollTimer
    interval: root.opened ? 1000 : ((root.settings && root.settings.pollIntervalSec ? root.settings.pollIntervalSec : 2) * 1000)
    running: true; repeat: true; triggeredOnStart: true
    onTriggered: root.refresh()
  }

  FileView {
    id: specFile
    path: "/dev/shm/omaramp_spectrum.json"
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
          var target = Math.min(1.0, Math.max(0.02, Number(bands[i]) || 0.0))
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
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight + Style.space(16), Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: trackList.urlInput.activeFocus
      onCloseRequested: root.close()
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

      Column {
        id: mainColumn
        width: parent.width - Style.space(20)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(8)
        topPadding: Style.space(6)
        bottomPadding: Style.space(8)

        WheelHandler {
          acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
          onWheel: function(event) {
            if (trackList.urlInput.activeFocus) return
            root.adjustVolume(event.angleDelta.y > 0 ? 5 : -5)
          }
        }

        // Resume banner
        BorderSurface {
          visible: root.resumeVisible
          width: parent.width
          implicitHeight: Style.space(28)
          radius: Style.cornerRadius
          color: Qt.rgba(0.04, 0.04, 0.05, 0.95)
          borderSpec: Border.flat(Color.accent, 1)

          Row {
            anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(6)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf0e2"; color: Color.accent
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
            }

            Text {
              width: parent.width - Style.space(80)
              anchors.verticalCenter: parent.verticalCenter
              text: root.resumeInfo ? "Resume: " + (root.resumeInfo.title || "last track") : ""
              color: root.foreground
              font.family: root.fontFamily; font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Resume"; color: Color.accent
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true

              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root.doResume()
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf00d"; color: root.dim
              font.family: root.fontFamily; font.pixelSize: Style.font.caption

              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root.resumeVisible = false
              }
            }
          }
        }

        Player { id: playerComp; p: root }

        Transport { p: root }

        PanelSeparator { foreground: root.foreground }

        TrackList { id: trackList; p: root }
      }
    }
  }
}
