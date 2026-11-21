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
  property double loadingSince: 0
  property string lastError: ""
  property string _lastCmd: ""
  property double _lastCmdAt: 0
  property bool _refreshPending: false
  property bool _stopping: false
  property string _pendingVis: ""
  property string selectedTab: "history"
  property string urlInputText: ""
  property string visMode: "siriwave"
  property bool visPickerOpen: false
  property bool eqPickerOpen: false
  property var visModes: ["bars", "bars_dot", "bars_outline", "bricks", "columns", "classic_led", "peaks", "wave", "scope", "heartbeat", "sine", "siriwave", "soundcloud_wave", "telegram_wave", "led_scrubber", "heatmap_wave", "glsl_plasma", "glsl_audio_tunnel", "glsl_electric_sphere", "osc_warp", "crt_scanline", "cyber_tunnel", "retro", "scatter", "flame", "pulse", "matrix", "butterfly", "sakura", "firework", "bubbles", "rain", "terrain", "logo", "firefly", "geyser", "mosaic", "sand", "stereo", "ascii"]

  // Visualizer state
  readonly property var _silentBands: Array(24).fill(0)
  property var visBands: _silentBands
  property bool visActive: false
  property double _spectrumSince: 0
  property double _lastSpectrumAt: 0
  property var visWave: []
  property int visFrame: 0
  property var _visState: ({})
  property var resumeInfo: null
  property bool resumeVisible: false
  property var activePlaylist: null
  property bool isImportingPl: false
  property string plImportError: ""
  property var visLR: [0, 0]
  property int searchLimit: 10
  property bool searchHasMore: false
  property bool isLoadingMore: false
  property bool errorVisible: false
  // The system interpreter, by path. The shell's PATH can resolve python3 to a version manager's
  // shim (mise, pyenv): ~40 ms more for every command, and no NumPy for the visualizer.
  readonly property string python: "/usr/bin/python3"
  // Every backend command goes through ctl.py, which runs cliamp_ctl from cached bytecode
  readonly property var _ctl: [python, Qt.resolvedUrl("ctl.py").toString().replace("file://", "")]
  property var _quickQ: []
  property var _queueQ: []

  onIsPlayingChanged: resetSpectrum()
  onCurrentUrlChanged: resetSpectrum()

  // The spectrum feeds the panel's visualizer and the bar icon's equalizer, so it runs while
  // music plays or the panel is open. It stops a few seconds after neither holds, so a track
  // change (playing, then buffering, then playing) does not restart it.
  readonly property bool spectrumWanted: opened || isPlaying
  onSpectrumWantedChanged: {
    if (spectrumWanted) {
      spectrumStopTimer.stop()
      startSpectrum()
    } else {
      spectrumStopTimer.restart()
    }
  }

  Timer {
    id: spectrumStopTimer
    interval: 5000; repeat: false; running: false
    onTriggered: if (!root.spectrumWanted) root.stopSpectrum()
  }

  onOpenedChanged: {
    root._visState = ({})
    if (opened) {
      if (playerComp) playerComp.requestPaint()
      // Pre-warm mpv so it's ready before the user clicks a song.
      // This eliminates cold-start delay after reboot.
      if (!root.isRunning) warmupProc.running = true
    } else {
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
    // A spectrum daemon left running by a previous shell stops unless music is playing by then
    spectrumStopTimer.restart()
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
    spectrumProc.command = root._ctl.concat(["start_spectrum"])
    spectrumProc.running = true
  }

  function stopSpectrum() {
    spectrumProc.running = false
    spectrumProc.command = root._ctl.concat(["stop_spectrum"])
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
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.visPickerOpen = false
    root.eqPickerOpen = false
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
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  // ---- Actions
  function refresh() {
    if (statusProc.running) { root._refreshPending = true; return }
    statusProc.running = true
  }

  function togglePlayback() {
    root.loadingVid = root.currentUrl || "pending"
    root.loadingSince = Date.now()
    root.playbackState = (root.playbackState === "playing") ? "paused" : "playing"
    runCmd(["toggle"])
  }
  function play() {
    root.loadingVid = root.currentUrl || "pending"
    root.loadingSince = Date.now()
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
    root.loadingVid = root.currentUrl || "pending"
    root.loadingSince = Date.now()
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
    root.loadingVid = root.currentUrl || "pending"
    root.loadingSince = Date.now()
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
  function toggleShuffle() { runQuick(["shuffle"]) }
  function cycleRepeat() { runQuick(["repeat"]) }

  function adjustVolume(delta) {
    setVolume(Math.max(0, Math.min(100, root.volumePct + delta)))
  }

  function setVolume(pct) {
    root.volumePct = pct
    runQuick(["volume_pct", String(pct)])
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

  function seekTo(sec) { runQuick(["seek", String(sec)]) }
  function cycleSpeed() {
    var speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    var cur = root.playbackSpeed
    var idx = 0
    for (var i = 0; i < speeds.length; i++) { if (Math.abs(speeds[i] - cur) < 0.05) { idx = i; break } }
    var next = speeds[(idx + 1) % speeds.length]
    root.playbackSpeed = next
    runQuick(["speed", String(next)])
  }
  function setEq(preset) {
    root.eqText = preset
    runQuick(["set_eq", preset])
  }
  function setVisMode(mode) {
    if (!mode) return
    root.visMode = mode
    root._pendingVis = mode
    pendingVisTimer.restart()
    runQuick(["set_vis_mode", mode])
    if (playerComp) playerComp.requestPaint()
  }
  function toggleLoudnorm() {
    runQuick(["toggle_loudnorm"])
    var next = !(root.audioFx && root.audioFx.loudnorm)
    root.audioFx = { eq: root.eqText, loudnorm: next, spatial: root.audioFx ? root.audioFx.spatial : false }
  }
  function toggleSpatial() {
    runQuick(["toggle_spatial"])
    var next = !(root.audioFx && root.audioFx.spatial)
    root.audioFx = { eq: root.eqText, loudnorm: root.audioFx ? root.audioFx.loudnorm : false, spatial: next }
  }
  function importPlaylist(url, name) {
    if (!url || !url.trim() || root.isImportingPl) return
    root.isImportingPl = true
    root.plImportError = ""
    root.selectedTab = "playlists"
    root.activePlaylist = null
    importPlProc.command = root._ctl.concat(["import_playlist", url.trim(), name || ""])
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
          url: h.path || h.url || ""
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
    root.loadingSince = Date.now()
    root.resumeVisible = false
    runCmd(["resume"])
  }

  function playUrl(url, title, artist) {
    if (!url || !url.trim()) return
    var u = url.trim()
    root.loadingVid = u
    root.loadingSince = Date.now()
    root.currentTrack = title || "Buffering..."
    root.currentArtist = artist || ""
    root.playbackState = "buffering"
    runCmd(["play_item", u, title || "", artist || ""])
    root.urlInputText = ""
  }

  function queueUrl(url, title, artist) {
    if (!url || !url.trim()) return
    runQueueCmd(["queue", url.trim(), title || "", artist || ""])
    root.urlInputText = ""
    loadQueue()
    loadHistory()
  }

  function loadQueue() {
    if (!queueProc.running) queueProc.running = true
  }

  function clearQueue() {
    runQueueCmd(["queue_clear"])
    loadQueue()
  }

  function removeFromQueue(idx) {
    runQueueCmd(["queue_remove", String(idx)])
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
    root.isLoadingMore = false
    root.searchQuery = q
    root.selectedTab = "search"
    root.searchLimit = 10
    _runSearch()
  }

  // Ten more results for the same search; the list stays on screen while they load
  function searchMore() {
    if (root.isSearching || root.isLoadingMore || !root.searchHasMore) return
    root.isLoadingMore = true
    root.searchLimit += 10
    _runSearch()
  }

  function _runSearch() {
    // A newer search replaces the one that is still running
    searchProc.running = false
    searchProc.command = root._ctl.concat(["search", "--limit=" + root.searchLimit, root.searchQuery])
    searchProc.running = true
  }

  function clearSearch() {
    root.searchQuery = ""
    root.searchResults = []
    root.searchHasMore = false
    root.isSearching = false
    root.isLoadingMore = false
    searchProc.running = false
    root.selectedTab = "history"
  }

  function playPlaylist(pl) {
    if (!pl || !pl.tracks || pl.tracks.length === 0) return
    playPlaylistTrack(pl, 0)
  }

  function playPlaylistTrack(pl, index) {
    if (!pl || !pl.tracks || pl.tracks.length === 0) return
    var idx = index || 0
    if (root.activePlaylist !== pl) root.activePlaylist = pl
    var t = pl.tracks[idx]
    if (!t) return
    playFromList(pl.name || "Playlist", idx, t.url || t.path, t.title, t.artist)
  }

  // Plays row `index` of a named list: a playlist, "Search Results" or "Recently Played".
  function playFromList(name, index, url, title, artist) {
    var u = (url || "").trim()
    root.currentPlaylistName = name
    root.currentPlaylistIndex = index
    root.currentTrack = title || "Buffering..."
    root.currentArtist = artist || ""
    // Point at the new track at once, so its row lights up before the first status arrives
    if (/^(https?:\/\/|\/)/.test(u)) root.currentUrl = u
    root.playbackState = "buffering"
    root.loadingVid = u || "pending"
    root.loadingSince = Date.now()
    // Always go through play_playlist so the Python side saves the
    // playback context (tracks + index). Otherwise next/prev have no
    // context to advance through and silently fall back to "No next track".
    runCmd(["play_playlist", name, String(index), u])
    loadQueue()
    loadHistory()
  }

  function stopDaemon() {
    root._stopping = true
    stoppingTimer.restart()
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
    if (["play_item", "play_playlist", "toggle", "play", "next", "prev"].indexOf(args[0]) !== -1) {
      var key = args.join("")
      var now = Date.now()
      if (key === root._lastCmd && now - root._lastCmdAt < 400) return
      root._lastCmd = key
      root._lastCmdAt = now
    }
    actionProc.running = false
    actionProc.command = root._ctl.concat(args)
    actionProc.running = true
  }

  // Quick settings (volume, seek, EQ...) and queue edits each have their own process and run one
  // after another, so they never kill a song that is still loading, or each other.
  function runQuick(args) { _push(root._quickQ, quickProc, args, true) }
  function runQueueCmd(args) { _push(root._queueQ, queueMutProc, args, false) }

  function _push(q, proc, args, newestOnly) {
    if (newestOnly) {
      // A dragged slider sends many values; of those still waiting only the newest is worth running
      for (var i = 0; i < q.length; i++) {
        if (q[i][0] === args[0]) { q[i] = args; return }
      }
    }
    q.push(args)
    if (!proc.running) _runNext(q, proc)
  }

  function _runNext(q, proc) {
    if (q.length === 0) return
    proc.command = root._ctl.concat(q.shift())
    proc.running = true
  }

  function showError(msg) {
    root.lastError = String(msg || "").substring(0, 300)
    root.errorVisible = true
    errorTimer.restart()
  }

  // Every command prints one JSON object; a failed one carries the reason
  function showResult(text) {
    try {
      var res = JSON.parse(text || "{}")
      if (res && res.success === false && res.error) {
        root.loadingVid = ""
        showError(res.error)
      }
    } catch (e) {}
  }

  // ---- Processes
  Process {
    id: statusProc
    command: root._ctl.concat(["status"])
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text || "{}")
          if (!root._stopping) {
          root.isRunning = data.running === true
          var _st = data.state || "stopped"
          if (_st === "playing" || _st === "paused") root.loadingVid = ""
          else if (_st === "stopped" && root.loadingVid !== "" && (Date.now() - root.loadingSince > 15000)) {
            root.loadingVid = ""
            root.showError("Track failed to load")
          }
          if (!(root.loadingVid !== "" && _st === "stopped" && actionProc.running))
            root.playbackState = _st
          var newTrack = String(data.track || "Omaramp")
          var newUrl = String(data.url || "")
          root.currentTrack = newTrack
          root.currentArtist = String(data.artist || "")
          root.currentUrl = newUrl
          root.currentPlaylistName = String(data.playlist_name || "")
          root.currentPlaylistIndex = (data.playlist_index !== undefined) ? Number(data.playlist_index) : -1
          root.artPath = String(data.art_path || "")
          root.artColor = String(data.art_color || "")
          if (playerComp.lyricsVisible && (playerComp.lyricsTrack !== newTrack ||
              playerComp.lyricsArtist !== root.currentArtist || playerComp.lyricsUrl !== newUrl)) {
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
          // A saved style that no longer exists keeps the current one
          if (data.vis_mode && root.visModes.indexOf(String(data.vis_mode)) !== -1 && String(data.vis_mode) !== root.visMode && !root.visPickerOpen && root._pendingVis === "") {
            root.visMode = String(data.vis_mode)
          }
          if (root._pendingVis !== "" && data.vis_mode && String(data.vis_mode) === root._pendingVis) root._pendingVis = ""
          if (data.resume && root.playbackState === "stopped") {
            root.resumeInfo = data.resume
            root.resumeVisible = true
          } else {
            root.resumeVisible = false
          }
          }
        } catch (e) {}
        if (root._refreshPending) { root._refreshPending = false; root.refresh() }
      }
    }
  }

  Process {
    id: queueProc
    command: root._ctl.concat(["queue_list"])
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
      id: searchOut
      waitForEnd: true
    }
    onExited: function(exitCode, exitStatus) {
      // exitStatus 1 is a search that a newer one replaced, or that was cleared
      if (exitStatus !== 0 || root.searchQuery === "") return
      var found = []
      try { found = JSON.parse(searchOut.text || "[]") } catch (e) {}
      // "Show more" that came back with nothing new keeps what is on screen
      if (!root.isLoadingMore || found.length > root.searchResults.length) root.searchResults = found
      // A full page means there is probably more; the backend stops at 50
      root.searchHasMore = found.length >= root.searchLimit && root.searchLimit < 50
      root.isSearching = false
      root.isLoadingMore = false
    }
  }

  Process {
    id: historyProc
    command: root._ctl.concat(["history", "40"])
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
    command: root._ctl.concat(["playlists"])
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
    stdout: StdioCollector {
      id: actionOut
      waitForEnd: true
      onStreamFinished: root.showResult(text)
    }
    onExited: function(exitCode, exitStatus) {
      // exitStatus 1 is a command a newer click replaced (SIGTERM), not a failure
      if (exitStatus === 0 && exitCode !== 0) root.showError(actionOut.text || "Command failed")
      root.refresh()
      if (root.opened) loadHistory()
      // On cold start (first play after reboot) mpv needs 1-4s to boot + buffer.
      // Poll again at 1s and 3.5s so the UI catches the playing state.
      coldStartTimer.restart()
    }
  }

  Process {
    id: queueMutProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.showResult(text)
    }
    onExited: function() {
      loadQueue()
      root._runNext(root._queueQ, queueMutProc)
    }
  }

  Process {
    id: quickProc
    onExited: function() {
      root._runNext(root._quickQ, quickProc)
      if (!quickProc.running) root.refresh()
    }
  }

  Timer {
    id: errorTimer
    interval: 4000; repeat: false; running: false
    onTriggered: root.errorVisible = false
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

  Timer {
    id: stoppingTimer
    interval: 2000; repeat: false; running: false
    onTriggered: root._stopping = false
  }

  Timer {
    id: pendingVisTimer
    interval: 2000; repeat: false; running: false
    onTriggered: root._pendingVis = ""
  }

  // Silently pre-warms the mpv daemon when the panel opens.
  // Runs start_daemon which is a no-op if mpv is already running.
  Process {
    id: warmupProc
    command: root._ctl.concat(["start_daemon"])
    stdout: StdioCollector {
      id: warmupOut
      waitForEnd: true
    }
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0 || exitStatus !== 0) {
        root.showError(warmupOut.text || "Daemon warmup failed")
      } else {
        try {
          var res = JSON.parse(warmupOut.text || "{}")
          if (res && res.success === false) root.showError(res.error || "Daemon warmup failed")
        } catch (e) {}
      }
      root.refresh()
    }
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

  readonly property string spectrumPath: (Quickshell.env("XDG_RUNTIME_DIR")
    ? Quickshell.env("XDG_RUNTIME_DIR") + "/omaramp"
    : (Quickshell.env("HOME") || "") + "/.cache/omaramp/run") + "/spectrum.json"

  FileView {
    id: specFile
    path: root.spectrumPath
    printErrors: false
    onLoaded: root.updateSpectrumData(text())
  }

  function resetSpectrum() {
    root._spectrumSince = Date.now()
    root._lastSpectrumAt = 0
    root.visActive = false
    root.visBands = root._silentBands
    root.visWave = []
    root.visLR = [0, 0]
    root._visState = ({})
    if (playerComp) playerComp.requestPaint()
  }

  function updateSpectrumData(raw) {
    if (!root.isPlaying || !raw || raw.length > 8192) return
    try {
      var data = JSON.parse(raw)
      var at = data.captured_at
      var now = Date.now()
      if (!Number.isFinite(at) || at <= root._lastSpectrumAt || at < root._spectrumSince ||
          now - at > 350 || at > now + 50 || !Array.isArray(data.bands) || data.bands.length !== 24) return
      var clamp = (v, min) => Number.isFinite(v) ? Math.max(min, Math.min(1, v)) : 0
      root._lastSpectrumAt = at
      root.visBands = data.bands.map(v => clamp(v, 0))
      root.visActive = true
      // With the panel closed only the bar icon's equalizer reads the bands
      if (!root.opened) return
      root.visWave = Array.isArray(data.wave) ? data.wave.slice(0, 128).map(v => clamp(v, -1)) : []
      root.visLR = Array.isArray(data.lr) ? data.lr.slice(0, 2).map(v => clamp(v, 0)) : [0, 0]
      root.visFrame++
    } catch (e) {}
  }

  Timer {
    interval: 33; running: root.isPlaying; repeat: true
    onTriggered: {
      if (root.visActive && Date.now() - root._lastSpectrumAt > 350) root.resetSpectrum()
      specFile.reload()
      if (playerComp && playerComp.lyricsVisible && root._lastStatusTime > 0) {
        var elapsed = (Date.now() - root._lastStatusTime) / 1000.0
        playerComp.updateLyricsPosition(root.curSecs + elapsed * root.playbackSpeed)
      }
    }
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
            // Prefer the active screen of the KeyboardPanel itself; fall back
            // to the anchor window's screen and finally to a sane default.
            // Reading window.width on the bar's PanelWindow can otherwise
            // return the virtual desktop width (multi-monitor), which parks
            // the card off-screen and leaves the dismiss area unreachable.
            var sw = 0
            if (panel.screen) sw = panel.screen.width
            else if (panel.anchorWindow && panel.anchorWindow.screen) sw = panel.anchorWindow.screen.width
            else if (panel.anchorItem && panel.anchorItem.Window && panel.anchorItem.Window.window && panel.anchorItem.Window.window.screen)
              sw = panel.anchorItem.Window.window.screen.width
            if (!sw) sw = 1920
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
              textFormat: Text.PlainText
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

        // The track list, style picker, EQ and lyrics take turns in one area of the track
        // list's size, so the card keeps its height when one replaces another.
        Item {
          width: parent.width
          implicitHeight: trackList.implicitHeight

          TrackList { id: trackList; p: root; visible: !playerComp.lyricsVisible && !root.visPickerOpen && !root.eqPickerOpen }

          // Visualizer Picker (Lazy loaded on demand)
          Loader {
            visible: root.visPickerOpen && !root.eqPickerOpen
            active: root.visPickerOpen
            anchors.fill: parent
            source: "VisPicker.qml"
            onLoaded: { if (item) item.p = root }
          }

          // Equalizer Profile Picker (Lazy loaded on demand)
          Loader {
            visible: root.eqPickerOpen
            active: root.eqPickerOpen
            anchors.fill: parent
            source: "EqPicker.qml"
            onLoaded: { if (item) item.p = root }
          }

          // Lyrics view — replaces track list when toggled
          Item {
            visible: playerComp.lyricsVisible && !root.visPickerOpen && !root.eqPickerOpen
            anchors.fill: parent

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

      // Why a click did not play. Floats over the content, so nothing shifts.
      Rectangle {
        z: 10
        anchors.bottom: parent.bottom; anchors.bottomMargin: Style.space(8)
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - Style.space(24), errorLabel.implicitWidth + Style.space(20))
        height: errorLabel.implicitHeight + Style.space(10)
        radius: Style.cornerRadius
        color: Qt.rgba(0.04, 0.04, 0.05, 0.95)
        border.width: 1; border.color: root.urgent
        visible: root.errorVisible

        Text {
          id: errorLabel
          anchors.centerIn: parent
          width: parent.width - Style.space(20)
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: root.lastError
          color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.errorVisible = false }
      }
    }
  }
}
