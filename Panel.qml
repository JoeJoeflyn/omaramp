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
  property string playbackState: "stopped"  // "playing" | "paused" | "stopped"
  readonly property bool isPlaying: playbackState === "playing"
  property string currentTrack: "No track loaded"
  property string currentArtist: ""
  property string timeCurrent: "00:00"
  property string timeTotal: "00:00"
  property int curSecs: 0
  property int totalSecs: 0
  property real progress: 0.0
  property int volumePct: 80
  property real volumeDb: 0.0
  property bool shuffleMode: false
  property string repeatMode: "off"
  property bool monoMode: false
  property string speedText: "1.00x"
  property string eqText: "Custom"

  property var historyList: []
  property var playlistsList: []
  property var searchResults: []
  property bool isSearching: false
  property string searchQuery: ""
  property string loadingVid: ""
  property string selectedTab: "history" // "search" | "history" | "playlists"
  property string urlInputText: ""
  property string visMode: "bars" // "bars" | "wave"

  // Visualizer animated bands state (24 bands)
  property var visBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  property var visPeaks: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

  // ---- Lifecycle
  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    root.refresh()
    loadHistory()
    loadPlaylists()
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

  function togglePlayback() {
    runCmd(["toggle"])
  }

  function play() {
    runCmd(["play"])
  }

  function pause() {
    runCmd(["pause"])
  }

  function stop() {
    runCmd(["stop"])
  }

  function nextTrack() {
    runCmd(["next"])
  }

  function prevTrack() {
    runCmd(["prev"])
  }

  function toggleShuffle() {
    runCmd(["shuffle"])
  }

  function cycleRepeat() {
    runCmd(["repeat"])
  }

  function adjustVolume(delta) {
    var newPct = Math.max(0, Math.min(100, root.volumePct + delta))
    setVolume(newPct)
  }

  function setVolume(pct) {
    root.volumePct = pct
    runCmd(["volume_pct", String(pct)])
  }

  function seekTo(sec) {
    runCmd(["seek", String(sec)])
  }

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

  function loadPlaylist(name) {
    runCmd(["load", name])
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
          root.currentTrack = String(data.track || "No track loaded")
          root.currentArtist = String(data.artist || "")
          root.timeCurrent = String(data.time_current || "00:00")
          root.timeTotal = String(data.time_total || "00:00")
          root.curSecs = Number(data.cur_secs || 0)
          root.totalSecs = Number(data.total_secs || 0)
          root.progress = Number(data.progress || 0.0)
          root.volumePct = Number(data.volume_pct || 80)
          root.volumeDb = Number(data.volume_db || 0.0)
          root.shuffleMode = data.shuffle === true
          root.repeatMode = String(data.repeat || "off")
          root.monoMode = data.mono === true
          root.speedText = String(data.speed || "1.00x")
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
        try {
          root.searchResults = JSON.parse(text || "[]")
        } catch (e) {
          root.searchResults = []
        }
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
        try {
          root.historyList = JSON.parse(text || "[]")
        } catch (e) {
          root.historyList = []
        }
      }
    }
  }

  Process {
    id: playlistsProc
    command: ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "playlists"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          root.playlistsList = JSON.parse(text || "[]")
        } catch (e) {
          root.playlistsList = []
        }
      }
    }
  }

  Process {
    id: actionProc
    onExited: function() {
      root.loadingVid = ""
      root.refresh()
      if (root.opened) {
        loadHistory()
      }
    }
  }

  // Poll timer for playback status & visualizer animation
  Timer {
    id: pollTimer
    interval: root.opened ? 1000 : ((root.settings && root.settings.pollIntervalSec ? root.settings.pollIntervalSec : 2) * 1000)
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  FileView {
    id: specFile
    path: "/dev/shm/omaramp_spectrum.json"
    watchChanges: true
    printErrors: false
    onFileChanged: root.updateSpectrumData(text())
    onLoaded: root.updateSpectrumData(text())
  }

  function updateSpectrumData(raw) {
    if (!root.opened) return
    if (!root.isPlaying) {
      var decayedBands = []
      var decayedPeaks = []
      var hasAny = false
      for (var k = 0; k < 24; k++) {
        var b = Math.max(0, (root.visBands[k] || 0) * 0.8 - 0.02)
        var p = Math.max(0, (root.visPeaks[k] || 0) * 0.8 - 0.02)
        decayedBands.push(b)
        decayedPeaks.push(p)
        if (b > 0 || p > 0) hasAny = true
      }
      root.visBands = decayedBands
      root.visPeaks = decayedPeaks
      if (hasAny && visCanvas) visCanvas.requestPaint()
      return
    }

    var content = raw
    if (!content && specFile) {
      try { content = specFile.text() } catch (e) {}
    }
    if (!content) return

    try {
      var arr = JSON.parse(content)
      if (Array.isArray(arr) && arr.length >= 24) {
        var newBands = []
        var newPeaks = []
        for (var i = 0; i < 24; i++) {
          var target = Math.min(1.0, Math.max(0.02, Number(arr[i]) || 0.0))
          var prevPeak = root.visPeaks[i] || 0.0
          var peak = Math.max(target, prevPeak - 0.03)
          newBands.push(target)
          newPeaks.push(peak)
        }
        root.visBands = newBands
        root.visPeaks = newPeaks
        if (visCanvas) visCanvas.requestPaint()
      }
    } catch (e) {}
  }

  // Real live audio FFT spectrum visualizer decay timer
  Timer {
    id: visTimer
    interval: 35
    running: root.opened
    repeat: true
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
      onCloseRequested: root.close()

      Column {
        id: mainColumn
        width: parent.width - Style.space(20)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(8)
        topPadding: Style.space(6)
        bottomPadding: Style.space(8)

        // =====================================================================
        // RETRO WINAMP / CLIAMP HUD HEADER
        // =====================================================================
        BorderSurface {
          width: parent.width
          implicitHeight: hudCol.implicitHeight + Style.space(12)
          radius: Style.cornerRadius
          color: Color.popups.background
          borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

          Column {
            id: hudCol
            width: parent.width - Style.space(16)
            anchors.centerIn: parent
            spacing: Style.space(6)

            // Top Status Badges Row
            Item {
              width: parent.width
              implicitHeight: Style.space(18)

              // Left side: Brand + LED Timer
              Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)

                // Brand / Daemon Indicator
                Row {
                  spacing: Style.space(4)
                  anchors.verticalCenter: parent.verticalCenter

                  Rectangle {
                    width: Style.space(6)
                    height: Style.space(6)
                    radius: width / 2
                    color: root.isPlaying ? "#00ff66" : (root.isRunning ? "#ffcc00" : "#ff3333")
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: "CLIAMP"
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1
                  }
                }

                // Monospace LED Timer
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.timeCurrent + " / " + root.timeTotal
                  color: root.isPlaying ? "#00ff66" : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              // Right side: KBPS / Mode Badges
              Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                BorderSurface {
                  implicitWidth: Style.space(46)
                  implicitHeight: Style.space(16)
                  radius: Style.space(2)
                  color: Style.selectedFillFor(root.foreground, Color.accent)
                  borderSpec: Border.flat(Color.accent, 1)

                  Text {
                    anchors.centerIn: parent
                    text: root.monoMode ? "MONO" : "STEREO"
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                BorderSurface {
                  implicitWidth: Style.space(38)
                  implicitHeight: Style.space(16)
                  radius: Style.space(2)
                  color: Style.selectedFillFor(root.foreground, Color.accent)
                  borderSpec: Border.flat(Color.accent, 1)

                  Text {
                    anchors.centerIn: parent
                    text: root.speedText
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            // Marquee Track Title Display
            BorderSurface {
              width: parent.width
              implicitHeight: Style.space(26)
              radius: Style.space(3)
              color: "#0c0d10"
              borderSpec: Border.flat(Qt.darker(Color.accent, 1.8), 1)

              Row {
                anchors.fill: parent
                anchors.margins: Style.space(4)
                spacing: Style.space(6)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.isPlaying ? "\uf04b" : (root.playbackState === "paused" ? "\uf04c" : "\uf04d")
                  color: root.isPlaying ? "#00ff66" : Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  width: parent.width - Style.space(20)
                  anchors.verticalCenter: parent.verticalCenter
                  text: {
                    if (!root.isRunning) return "cliamp daemon idle — click play to start"
                    var a = root.currentArtist
                    var t = root.currentTrack
                    return (a ? a + " - " : "") + t
                  }
                  color: root.isPlaying ? "#00ff66" : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                }
              }
            }

            // =================================================================
            // SPECTRUM VISUALIZER CANVAS (cliamp & Winamp Classic LED / Wave)
            // =================================================================
            Item {
              width: parent.width
              height: Style.space(42)

              Canvas {
                id: visCanvas
                anchors.fill: parent

                onPaint: {
                  var ctx = getContext("2d")
                  ctx.clearRect(0, 0, width, height)

                  var count = 24
                  var gap = 3
                  var barW = Math.floor((width - (count - 1) * gap) / count)
                  var numSegments = 14
                  var segH = 2
                  var segGap = 1

                  if (root.visMode === "wave") {
                    // Oscilloscope Waveform Mode
                    ctx.lineWidth = 2
                    ctx.strokeStyle = Color.accent
                    ctx.beginPath()
                    var midY = height / 2.0
                    for (var w = 0; w < count; w++) {
                      var wx = w * (barW + gap) + barW / 2
                      var bVal = root.isPlaying ? (root.visBands[w] || 0) : 0
                      var amp = bVal * (height / 2.2)
                      var wy = midY + ((w % 2 === 0 ? 1 : -1) * amp)
                      if (w === 0) ctx.moveTo(wx, wy)
                      else ctx.lineTo(wx, wy)
                    }
                    ctx.stroke()
                  } else {
                    // Classic LED Segmented Bars Mode
                    for (var i = 0; i < count; i++) {
                      var x = i * (barW + gap)
                      var val = root.isPlaying ? (root.visBands[i] || 0) : 0.05
                      var peak = root.isPlaying ? (root.visPeaks[i] || 0) : 0.05
                      var litSegs = Math.max(1, Math.min(numSegments, Math.round(val * numSegments)))
                      var peakSeg = Math.min(numSegments - 1, Math.round(peak * (numSegments - 1)))

                      // Draw LED segments from bottom to top
                      for (var s = 0; s < numSegments; s++) {
                        var segY = height - (s + 1) * (segH + segGap)
                        var isLit = s < litSegs
                        var isPeak = s === peakSeg && root.isPlaying && peak > 0.08

                        if (isPeak) {
                          ctx.fillStyle = root.foreground
                          ctx.fillRect(x, segY, barW, segH)
                        } else if (isLit) {
                          if (s > numSegments * 0.75) {
                            ctx.fillStyle = root.urgent
                          } else if (s > numSegments * 0.45) {
                            ctx.fillStyle = Color.accent
                          } else {
                            ctx.fillStyle = Color.accent
                          }
                          ctx.fillRect(x, segY, barW, segH)
                        } else {
                          // Unlit retro LED ghost grid
                          ctx.fillStyle = "rgba(255, 255, 255, 0.04)"
                          ctx.fillRect(x, segY, barW, segH)
                        }
                      }
                    }
                  }
                }
              }

              // Click to toggle visualizer mode (Bars vs Wave)
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.visMode = (root.visMode === "bars") ? "wave" : "bars"
                  visCanvas.requestPaint()
                }
              }
            }

            // Seek Bar Scrubber
            Item {
              width: parent.width
              implicitHeight: Style.space(12)

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Style.space(4)
                radius: Style.space(2)
                color: Color.popups.border

                Rectangle {
                  width: Math.max(Style.space(4), parent.width * root.progress)
                  height: parent.height
                  radius: Style.space(2)
                  color: Color.accent
                }
              }

              // Draggable seek area
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                  if (root.totalSecs > 0) {
                    var targetSec = Math.floor((mouse.x / width) * root.totalSecs)
                    root.seekTo(targetSec)
                  }
                }
              }
            }
          }
        }

        // =====================================================================
        // TRANSPORT CONTROLS & VOLUME DECK
        // =====================================================================
        Row {
          width: parent.width
          spacing: Style.space(4)

          // Prev Track
          PanelActionButton {
            iconText: "\uf048"
            tooltipText: "Previous Track"
            foreground: root.foreground
            hoverColor: Color.accent
            fontFamily: root.fontFamily
            onClicked: root.prevTrack()
          }

          // Play / Pause Toggle
          PanelActionButton {
            iconText: root.isPlaying ? "\uf04c" : "\uf04b"
            tooltipText: root.isPlaying ? "Pause" : "Play"
            foreground: root.isPlaying ? Color.accent : root.foreground
            hoverColor: Color.accent
            fontFamily: root.fontFamily
            onClicked: root.togglePlayback()
          }

          // Stop
          PanelActionButton {
            iconText: "\uf04d"
            tooltipText: "Stop Playback"
            foreground: root.foreground
            hoverColor: root.urgent
            fontFamily: root.fontFamily
            onClicked: root.stop()
          }

          // Next Track
          PanelActionButton {
            iconText: "\uf051"
            tooltipText: "Next Track"
            foreground: root.foreground
            hoverColor: Color.accent
            fontFamily: root.fontFamily
            onClicked: root.nextTrack()
          }

          // Shuffle
          PanelActionButton {
            iconText: "\uf074"
            tooltipText: "Shuffle: " + (root.shuffleMode ? "ON" : "OFF")
            foreground: root.shuffleMode ? Color.accent : root.dim
            hoverColor: Color.accent
            fontFamily: root.fontFamily
            onClicked: root.toggleShuffle()
          }

          // Repeat
          PanelActionButton {
            iconText: "\uf01e"
            tooltipText: "Repeat: " + root.repeatMode.toUpperCase()
            foreground: root.repeatMode !== "off" ? Color.accent : root.dim
            hoverColor: Color.accent
            fontFamily: root.fontFamily
            onClicked: root.cycleRepeat()
          }

          Item { width: Style.space(8) }

          // Volume Icon & Slider
          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.volumePct === 0 ? "\uf026" : (root.volumePct < 50 ? "\uf027" : "\uf028")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            // Mini Volume Slider Bar
            Item {
              width: Style.space(56)
              height: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Style.space(4)
                radius: Style.space(2)
                color: "#1a1c23"

                Rectangle {
                  width: Math.max(Style.space(2), parent.width * (root.volumePct / 100.0))
                  height: parent.height
                  radius: Style.space(2)
                  color: Color.accent
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: function(mouse) {
                  if (pressed) {
                    var p = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                    root.setVolume(p)
                  }
                }
                onClicked: function(mouse) {
                  var p = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                  root.setVolume(p)
                }
              }
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        // =====================================================================
        // SEARCH / URL INPUT BAR
        // =====================================================================
        Row {
          width: parent.width
          spacing: Style.space(4)

          BorderSurface {
            width: parent.width - Style.space(36)
            implicitHeight: Style.space(26)
            radius: Style.cornerRadius
            color: Color.popups.background
            borderSpec: Border.controlSpec(urlInput.activeFocus ? "focused" : "normal", root.foreground, Color.accent)

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(4)
              spacing: Style.space(4)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf002"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              TextInput {
                id: urlInput
                width: parent.width - Style.space(32)
                anchors.verticalCenter: parent.verticalCenter
                text: root.urlInputText
                onTextChanged: root.urlInputText = text
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                selectByMouse: true
                onAccepted: root.searchTracks(text)

                Text {
                  visible: !urlInput.text && !urlInput.activeFocus
                  text: "Search songs, artists, or paste URL..."
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                }
              }

              // Clear Search Button
              Text {
                visible: urlInput.text.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf00d"
                color: clearMouse.containsMouse ? Color.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption

                MouseArea {
                  id: clearMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    urlInput.text = ""
                    root.clearSearch()
                  }
                }
              }
            }
          }

          // Search / Submit button
          PanelActionButton {
            iconText: root.isSearching ? "\uf110" : "\uf002"
            tooltipText: "Search"
            foreground: root.foreground
            hoverColor: Color.accent
            fontFamily: root.fontFamily
            enabled: root.urlInputText.trim().length > 0 && !root.isSearching
            onClicked: root.searchTracks(root.urlInputText)
          }
        }

        // =====================================================================
        // DRAWER TABS: SEARCH VS HISTORY VS PLAYLISTS
        // =====================================================================
        Row {
          width: parent.width
          spacing: Style.space(6)

          // Search Results Tab (when active or has results)
          Button {
            visible: root.selectedTab === "search" || root.searchResults.length > 0 || root.isSearching
            text: "Search (" + root.searchResults.length + ")"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: false
            foreground: root.selectedTab === "search" ? Color.accent : root.dim
            accent: Color.accent
            onClicked: root.selectedTab = "search"
          }

          Button {
            text: "Recents (" + root.historyList.length + ")"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: false
            foreground: root.selectedTab === "history" ? Color.accent : root.dim
            accent: Color.accent
            onClicked: {
              root.selectedTab = "history"
              root.loadHistory()
            }
          }

          Button {
            text: "Playlists (" + root.playlistsList.length + ")"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: false
            foreground: root.selectedTab === "playlists" ? Color.accent : root.dim
            accent: Color.accent
            onClicked: {
              root.selectedTab = "playlists"
              root.loadPlaylists()
            }
          }

          Item { width: Style.space(8) }

          // Daemon Kill / Power toggle
          PanelActionButton {
            iconText: "\uf011"
            tooltipText: root.isRunning ? "Stop background daemon" : "Daemon idle"
            foreground: root.isRunning ? root.foreground : root.dim
            hoverColor: root.urgent
            fontFamily: root.fontFamily
            onClicked: {
              if (root.isRunning) root.stopDaemon()
              else root.play()
            }
          }
        }

        // =====================================================================
        // TRACK LIST SCROLLER
        // =====================================================================
        Flickable {
          width: parent.width
          implicitHeight: Style.space(160)
          contentWidth: width
          contentHeight: listCol.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: listCol
            width: parent.width
            spacing: Style.space(2)

            // Searching Status Indicator
            Item {
              visible: root.selectedTab === "search" && root.isSearching
              width: parent.width
              implicitHeight: Style.space(40)

              Row {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "\uf110"
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Searching for \"" + root.searchQuery + "\"..."
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            // No Results Found
            Item {
              visible: root.selectedTab === "search" && !root.isSearching && root.searchResults.length === 0 && root.searchQuery !== ""
              width: parent.width
              implicitHeight: Style.space(40)

              Text {
                anchors.centerIn: parent
                text: "No tracks found for \"" + root.searchQuery + "\""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            // Search Results Rows
            Repeater {
              model: root.selectedTab === "search" && !root.isSearching ? root.searchResults : []
              delegate: BorderSurface {
                id: searchRow
                width: parent.width
                implicitHeight: Style.space(32)
                radius: Style.cornerRadius
                color: searchMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                borderSpec: Border.none

                Row {
                  width: parent.width - Style.space(8)
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.loadingVid === modelData.url ? "\uf110" : "\uf04b"
                    color: root.loadingVid === modelData.url ? Color.accent : (searchMouse.containsMouse ? Color.accent : root.dim)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Column {
                    width: parent.width - Style.space(70)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                      width: parent.width
                      text: modelData.title || "Track"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      elide: Text.ElideRight
                    }

                    Text {
                      width: parent.width
                      text: modelData.artist || ""
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                      visible: modelData.artist !== ""
                    }
                  }

                  Item { width: Style.space(4) }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.duration || ""
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  id: searchMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (modelData.url) root.playUrl(modelData.url, modelData.title, modelData.artist)
                  }
                }
              }
            }

            // Recently Played Track Rows
            Repeater {
              model: root.selectedTab === "history" ? root.historyList : []
              delegate: BorderSurface {
                id: trackRow
                width: parent.width
                implicitHeight: Style.space(28)
                radius: Style.cornerRadius
                color: trackMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                borderSpec: Border.none

                Row {
                  width: parent.width - Style.space(8)
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.loadingVid === modelData.path ? "\uf110" : "\uf04b"
                    color: root.loadingVid === modelData.path ? Color.accent : (trackMouse.containsMouse ? Color.accent : root.dim)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Text {
                    width: parent.width - Style.space(60)
                    anchors.verticalCenter: parent.verticalCenter
                    text: (modelData.artist ? modelData.artist + " - " : "") + (modelData.title || "Track")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }

                  Item { width: Style.space(4) }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                      var s = modelData.duration_secs || 0
                      var m = Math.floor(s / 60)
                      var sec = s % 60
                      return (m > 0 || sec > 0) ? (m + ":" + (sec < 10 ? "0" + sec : sec)) : ""
                    }
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  id: trackMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (modelData.path) root.playUrl(modelData.path, modelData.title, modelData.artist)
                  }
                }
              }
            }

            // Playlist Items
            Repeater {
              model: root.selectedTab === "playlists" ? root.playlistsList : []
              delegate: BorderSurface {
                id: plRow
                width: parent.width
                implicitHeight: Style.space(28)
                radius: Style.cornerRadius
                color: plMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                borderSpec: Border.none

                Row {
                  width: parent.width - Style.space(8)
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf0ca"
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Text {
                    width: parent.width - Style.space(60)
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name || "Playlist"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Item { width: Style.space(4) }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.count + " tracks"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  id: plMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (modelData.name) root.loadPlaylist(modelData.name)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
