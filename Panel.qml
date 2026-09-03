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
  property real curSecs: 0.0
  property real totalSecs: 0.0
  property real progress: 0.0
  property real playbackSpeed: 1.0
  property int volumePct: 80
  property real volumeDb: 0.0
  property bool shuffleMode: false
  property string repeatMode: "off"
  property string currentPlaylistName: ""
  property int currentPlaylistIndex: -1
  property real _lastStatusTime: 0
  property string eqText: "Custom"
  property var audioFx: ({ "eq": "Flat", "loudnorm": false, "spatial": false })
  property int _preMuteVol: 80

  property var historyList: []
  property var playlistsList: []
  property var queueList: []
  property int queueCount: 0
  property var searchResults: []
  property bool isSearching: false
  property string searchQuery: ""
  property string loadingVid: ""
  property string selectedTab: "history"
  property string urlInputText: ""
  property string visMode: "siriwave"
  property bool visPickerOpen: false
  property bool eqPickerOpen: false
  property var visModes: ["bars", "bars_dot", "bars_outline", "bricks", "columns", "classic_led", "peaks", "wave", "scope", "heartbeat", "sine", "siriwave", "soundcloud_wave", "telegram_wave", "daw_wave", "led_scrubber", "heatmap_wave", "grounded_wave", "glsl_plasma", "glsl_audio_tunnel", "glsl_electric_sphere", "plasma", "osc_warp", "crt_scanline", "cyber_tunnel", "retro", "scatter", "flame", "pulse", "matrix", "binary", "butterfly", "sakura", "firework", "bubbles", "rain", "terrain", "logo", "firefly", "geyser", "mosaic", "sand", "stereo", "ascii"]

  // Visualizer state
  property var visBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  property var visPeaks: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  property var visWave: []
  property int visFrame: 0
  property var _visState: ({})
  property var resumeInfo: null
  property bool resumeVisible: false
  property var activePlaylist: null
  property bool isImportingPl: false
  property string plImportError: ""

  onOpenedChanged: {
    if (opened) {
      // Pre-warm mpv so it's ready before the user clicks a song.
      // This eliminates cold-start delay after reboot.
      if (!root.isRunning) warmupProc.running = true
    } else {
      stopSpectrum()
      root.visPickerOpen = false
      root.eqPickerOpen = false
      setCenterHoverRevealSuppressed(false)
    }
  }

  // ---- Lifecycle
  Component.onCompleted: {
    loadPlaylists()
    loadHistory()
    loadQueue()
    warmupTimer.restart()
  }

  Timer {
    id: warmupTimer
    interval: 350; repeat: false; running: false
    onTriggered: {
      if (!root.isRunning && !warmupProc.running) warmupProc.running = true
    }
  }

  function startSpectrum() {
    spectrumProc.running = false
    spectrumProc.command = ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "start_spectrum"]
    spectrumProc.running = true
  }

  function stopSpectrum() {
    spectrumProc.running = false
    spectrumProc.command = ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "stop_spectrum"]
    spectrumProc.running = true
  }

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    root.controller.show()
    Qt.callLater(function() {
      root.refresh()
      loadHistory()
      loadPlaylists()
      loadQueue()
      startSpectrum()
    })
  }

  function openFromHotkey() {
    openedFromHotkey = true
    root.controller.show()
    Qt.callLater(function() {
      root.refresh()
      loadHistory()
      loadPlaylists()
      loadQueue()
      startSpectrum()
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.visPickerOpen = false
    root.eqPickerOpen = false
    root.controller.hide()
    stopSpectrum()
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
    root.playbackState = (root.playbackState === "playing") ? "paused" : "playing"
    runCmd(["toggle"])
  }
  function play() {
    root.playbackState = "playing"
    runCmd(["play"])
  }
  function pause() {
    root.playbackState = "paused"
    runCmd(["pause"])
  }
  function stop() {
    root.playbackState = "stopped"
    runCmd(["stop"])
  }
  function nextTrack() {
    if (root.activePlaylist && root.currentPlaylistName === root.activePlaylist.name && root.currentPlaylistIndex >= 0) {
      var nextIdx = root.currentPlaylistIndex + 1
      if (nextIdx < root.activePlaylist.tracks.length) {
        root.currentPlaylistIndex = nextIdx
        var t = root.activePlaylist.tracks[nextIdx]
        if (t) {
          root.currentTrack = t.title || ""
          root.currentArtist = t.artist || ""
          root.playbackState = "buffering"
        }
      } else if (root.repeatMode === "all" && root.activePlaylist.tracks.length > 0) {
        root.currentPlaylistIndex = 0
        var t0 = root.activePlaylist.tracks[0]
        if (t0) {
          root.currentTrack = t0.title || ""
          root.currentArtist = t0.artist || ""
          root.playbackState = "buffering"
        }
      }
    }
    runCmd(["next"])
    loadQueue()
  }

  function prevTrack() {
    if (root.curSecs <= 3.0 && root.activePlaylist && root.currentPlaylistName === root.activePlaylist.name && root.currentPlaylistIndex > 0) {
      var prevIdx = root.currentPlaylistIndex - 1
      root.currentPlaylistIndex = prevIdx
      var t = root.activePlaylist.tracks[prevIdx]
      if (t) {
        root.currentTrack = t.title || ""
        root.currentArtist = t.artist || ""
        root.playbackState = "buffering"
      }
    }
    runCmd(["prev"])
    loadQueue()
  }
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
  function setVisMode(mode) {
    if (!mode) return
    root.visMode = mode
    runCmd(["set_vis_mode", mode])
    if (playerComp) playerComp.requestPaint()
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
    if (!url || !url.trim() || root.isImportingPl) return
    root.isImportingPl = true
    root.plImportError = ""
    root.selectedTab = "playlists"
    root.activePlaylist = null
    importPlProc.command = ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "import_playlist", url.trim(), name || ""]
    importPlProc.running = true
  }

  function deletePlaylist(name) {
    if (!name) return
    if (root.activePlaylist && root.activePlaylist.name === name) {
      root.activePlaylist = null
    }
    runCmd(["delete_playlist", name])
    Qt.callLater(loadPlaylists)
  }

  function openPlaylist(pl) {
    if (!pl) return
    if (pl.system || pl.name === "Recently Played") {
      var recents = []
      for (var i = 0; i < root.historyList.length; i++) {
        var h = root.historyList[i]
        recents.push({
          title: h.title || "Track",
          artist: h.artist || "",
          duration: h.duration_secs ? (Math.floor(h.duration_secs / 60) + ":" + (h.duration_secs % 60 < 10 ? "0" + (h.duration_secs % 60) : (h.duration_secs % 60))) : "",
          url: h.path || (h.title + " " + h.artist)
        })
      }
      root.activePlaylist = { name: "Recently Played", tracks: recents, system: true }
    } else {
      root.activePlaylist = pl
    }
  }

  function closePlaylist() {
    root.activePlaylist = null
  }

  function doResume() {
    root.playbackState = "playing"
    root.loadingVid = root.resumeInfo ? root.resumeInfo.url : ""
    root.resumeVisible = false
    runCmd(["resume"])
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
    loadQueue()
    loadHistory()
  }

  function loadQueue() {
    if (!queueProc.running) queueProc.running = true
  }

  function clearQueue() {
    runCmd(["queue_clear"])
    loadQueue()
  }

  function removeFromQueue(idx) {
    runCmd(["queue_remove", String(idx)])
    loadQueue()
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

  function playPlaylist(pl) {
    if (!pl || !pl.tracks || pl.tracks.length === 0) return
    playPlaylistTrack(pl, 0)
  }

  function playPlaylistTrack(pl, index) {
    if (!pl || !pl.tracks || pl.tracks.length === 0) return
    var idx = index || 0
    root.activePlaylist = pl
    root.currentPlaylistName = pl.name || "Playlist"
    root.currentPlaylistIndex = idx
    var t = pl.tracks[idx]
    if (t) {
      root.loadingVid = t.url || (t.title + " " + t.artist)
      root.currentTrack = t.title || "Buffering..."
      root.currentArtist = t.artist || ""
      root.playbackState = "buffering"
    }
    runCmd(["play_playlist", pl.name || "Playlist", String(idx)])
    loadQueue()
    loadHistory()
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
    actionProc.running = false
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
          if (!(root.loadingVid !== "" && data.state === "stopped" && actionProc.running))
            root.playbackState = data.state || "stopped"
          var newTrack = String(data.track || "Omaramp")
          var newUrl = String(data.url || "")
          var trackChanged = (newTrack !== root.currentTrack) || (newUrl !== root.currentUrl)
          root.currentTrack = newTrack
          root.currentArtist = String(data.artist || "")
          root.currentUrl = newUrl
          root.currentPlaylistName = String(data.playlist_name || "")
          root.currentPlaylistIndex = (data.playlist_index !== undefined) ? Number(data.playlist_index) : -1
          root.artPath = String(data.art_path || "")
          root.artColor = String(data.art_color || "")
          if (trackChanged && playerComp.lyricsVisible && playerComp.lyricsTrack !== newTrack) {
            playerComp.fetchLyrics()
          }
          root.timeCurrent = String(data.time_current || "00:00")
          root.timeTotal = String(data.time_total || "00:00")
          root.curSecs = Number(data.cur_secs || 0)
          root._lastStatusTime = Date.now()
          if (playerComp.lyricsVisible) playerComp.updateLyricsPosition(root.curSecs)
          root.totalSecs = Number(data.total_secs || 0)
          root.progress = Number(data.progress || 0.0)
          root.volumePct = (data.volume_pct !== undefined && data.volume_pct !== null) ? Number(data.volume_pct) : 80
          root.playbackSpeed = Number(data.speed || 1.0)
          root.volumeDb = Number(data.volume_db || 0.0)
          root.shuffleMode = data.shuffle === true
          root.repeatMode = String(data.repeat || "off")
          root.queueCount = (data.queue_count !== undefined) ? Number(data.queue_count) : 0
          root.eqText = String(data.eq || "Custom")
          if (data.audio_fx) root.audioFx = data.audio_fx
          if (data.vis_mode && String(data.vis_mode) !== root.visMode && !root.visPickerOpen) {
            root.visMode = String(data.vis_mode)
          }
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
    id: queueProc
    command: ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "queue_list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.queueList = JSON.parse(text || "[]") }
        catch (e) { root.queueList = [] }
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
    command: ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "history", "40"]
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
    id: importPlProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isImportingPl = false
        try {
          var res = JSON.parse(text || "{}")
          if (res.success) {
            root.plImportError = ""
            loadPlaylists()
          } else {
            root.plImportError = res.error || "Failed to import playlist"
          }
        } catch (e) {
          root.plImportError = "Error importing playlist"
        }
      }
    }
  }

  Process {
    id: actionProc
    onExited: function() {
      root.loadingVid = ""
      root.refresh()
      if (root.opened) loadHistory()
      // On cold start (first play after reboot) mpv needs 1-4s to boot + buffer.
      // Poll again at 1s and 3.5s so the UI catches the playing state.
      coldStartTimer.restart()
    }
  }

  Timer {
    id: coldStartTimer
    interval: 350; repeat: false; running: false
    onTriggered: {
      root.refresh()
      coldStartTimer2.restart()
    }
  }

  Timer {
    id: coldStartTimer2
    interval: 1000; repeat: false; running: false
    onTriggered: root.refresh()
  }

  // Silently pre-warms the mpv daemon when the panel opens.
  // Runs start_daemon which is a no-op if mpv is already running.
  Process {
    id: warmupProc
    command: ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "start_daemon"]
    onExited: root.refresh()
  }

  Process {
    id: spectrumProc
  }

  // Poll timer
  Timer {
    id: pollTimer
    interval: root.opened ? 500 : ((root.settings && root.settings.pollIntervalSec ? root.settings.pollIntervalSec : 2) * 1000)
    running: true; repeat: true; triggeredOnStart: true
    onTriggered: root.refresh()
  }

  readonly property string _home: Quickshell.env("HOME") || ""
  readonly property string _xdg: Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + (Quickshell.env("UID") || "1000"))
  readonly property string spectrumPath: _xdg + "/omaramp/spectrum.json"

  FileView {
    id: specFile
    path: root.spectrumPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.updateSpectrumData(text())
    onLoadFailed: {}
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
      if (root.isPlaying) {
        specFile.reload()
        if (playerComp && playerComp.lyricsVisible && root._lastStatusTime > 0) {
          var elapsed = (Date.now() - root._lastStatusTime) / 1000.0
          playerComp.updateLyricsPosition(root.curSecs + elapsed * root.playbackSpeed)
        }
      } else {
        root.updateSpectrumData("")
      }
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
      onTabRequested: function(direction) { root.switchPanel(direction) }
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
        asynchronous: true
        sourceSize.width: 120
        sourceSize.height: 120
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

            Item {
              id: lyricsHeader
              anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
              anchors.margins: Style.space(8)
              implicitHeight: Style.space(20)

              Row {
                anchors.left: parent.left
                anchors.right: closeLyricsBtn.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "\uf10d"
                  color: Color.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                }
                Text {
                  width: parent.width - Style.space(24)
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: "Lyrics — " + (root.currentTrack || "No track")
                  color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                  font.bold: true; elide: Text.ElideRight
                }
              }

              // Close icon pushed to top far right
              Item {
                id: closeLyricsBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(20); height: Style.space(20)

                Text {
                  anchors.centerIn: parent
                  text: "\uf00d"
                  color: closeLyricsMouse.containsMouse ? Color.accent : root.dim
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption
                }
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

            ListView {
              id: lyricsList
              visible: playerComp.lyricsLines.length > 0
              anchors.top: lyricsHeader.bottom
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(8)
              clip: true
              model: playerComp.lyricsLines
              spacing: Style.space(6)
              boundsBehavior: Flickable.StopAtBounds

              Connections {
                target: playerComp
                function onLyricsCurrentIdxChanged() {
                  if (playerComp.lyricsCurrentIdx >= 0 && playerComp.lyricsCurrentIdx < playerComp.lyricsLines.length) {
                    lyricsList.positionViewAtIndex(playerComp.lyricsCurrentIdx, ListView.Center)
                  }
                }
              }

              delegate: Item {
                required property var modelData
                required property int index
                readonly property bool isCurrent: index === playerComp.lyricsCurrentIdx
                readonly property bool isPast: playerComp.lyricsCurrentIdx >= 0 && index < playerComp.lyricsCurrentIdx
                width: lyricsList.width
                implicitHeight: lyricText.implicitHeight + Style.space(4)

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: modelData.time >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: {
                    if (modelData.time >= 0) {
                      root.seekTo(modelData.time)
                    }
                  }
                }

                Text {
                  id: lyricText
                  anchors.left: parent.left
                  anchors.right: parent.right
                  horizontalAlignment: Text.AlignHCenter
                  wrapMode: Text.Wrap
                  textFormat: Text.PlainText
                  text: modelData.text || "♪"
                  color: isCurrent ? root.dynamicAccent : (isPast ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.65))
                  font.family: root.fontFamily
                  font.pixelSize: isCurrent ? Style.font.body : Style.font.caption
                  font.bold: isCurrent
                  Behavior on color { ColorAnimation { duration: 250 } }
                }
              }
            }
          }
        }
      }
    }
  }
}
