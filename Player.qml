import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

import "visualizers/bars.js" as VisBars
import "visualizers/bars_dot.js" as VisBarsDot
import "visualizers/bars_outline.js" as VisBarsOutline
import "visualizers/bricks.js" as VisBricks
import "visualizers/columns.js" as VisColumns
import "visualizers/classic_led.js" as VisClassicLED
import "visualizers/peaks.js" as VisPeaks
import "visualizers/wave.js" as VisWave
import "visualizers/scope.js" as VisScope
import "visualizers/heartbeat.js" as VisHeartbeat
import "visualizers/retro.js" as VisRetro
import "visualizers/scatter.js" as VisScatter
import "visualizers/flame.js" as VisFlame
import "visualizers/pulse.js" as VisPulse
import "visualizers/matrix.js" as VisMatrix
import "visualizers/binary.js" as VisBinary
import "visualizers/butterfly.js" as VisButterfly
import "visualizers/sakura.js" as VisSakura
import "visualizers/firework.js" as VisFirework
import "visualizers/bubbles.js" as VisBubbles
import "visualizers/rain.js" as VisRain
import "visualizers/terrain.js" as VisTerrain
import "visualizers/logo.js" as VisLogo
import "visualizers/firefly.js" as VisFirefly
import "visualizers/geyser.js" as VisGeyser
import "visualizers/mosaic.js" as VisMosaic
import "visualizers/sand.js" as VisSand
import "visualizers/stereo.js" as VisStereo
import "visualizers/ascii.js" as VisAscii
import "visualizers/sine.js" as VisSine
import "visualizers/siriwave.js" as VisSiriWave
import "visualizers/scrubber_wave.js" as VisScrubberWave
import "visualizers/soundcloud_wave.js" as VisSoundCloudWave
import "visualizers/dj_spectral.js" as VisDJSpectral
import "visualizers/voice_pill.js" as VisVoicePill

// HUD header + visualizer canvas + seek bar
Item {
  id: root
  property var p  // Panel root

  width: parent ? parent.width : 0
  implicitHeight: hud.implicitHeight + Style.space(12)

  property bool lyricsVisible: false
  property var lyricsLines: []
  property int lyricsCurrentIdx: -1
  property string lyricsTrack: ""

  property real beatDropPulse: 0.0
  property real _bassAvg: 0.0
  property double _lastDropTime: 0

  function updateBeatDrop() {
    if (!p || !p.visBands || p.visBands.length < 3 || !p.isPlaying) {
      beatDropPulse = 0.0
      return
    }
    var subBass = (p.visBands[0] + p.visBands[1] + p.visBands[2]) / 3.0
    var avg = _bassAvg * 0.85 + subBass * 0.15
    _bassAvg = avg
    var delta = subBass - avg
    var now = Date.now()
    if (subBass > 0.40 && delta > 0.15 && (now - _lastDropTime) > 260) {
      beatDropPulse = 1.0
      _lastDropTime = now
    } else {
      beatDropPulse = Math.max(0.0, beatDropPulse * 0.88 - 0.02)
    }
  }

  function toggleLyrics() {
    lyricsVisible = !lyricsVisible
    if (lyricsVisible && lyricsTrack !== p.currentTrack) {
      fetchLyrics()
    }
  }

  function fetchLyrics() {
    lyricsLines = []
    lyricsCurrentIdx = -1
    lyricsTrack = p.currentTrack
    var cmd = ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "lyrics", p.currentTrack, p.currentArtist, p.currentUrl]
    lyricsProc.command = cmd
    Qt.callLater(function() { lyricsProc.running = true })
  }

  function parseLyrics(raw) {
    var lines = [], re = /\[(\d+):(\d+\.\d+)\](.*)/g, m
    while ((m = re.exec(raw)) !== null)
      lines.push({ time: parseInt(m[1]) * 60 + parseFloat(m[2]), text: m[3].trim() })
    lyricsLines = lines.length ? lines : (raw ? raw.split("\n").map(function(t) { return { time: -1, text: t.trim() } }) : [])
  }

  function updateLyricsPosition(sec) {
    if (!lyricsVisible || !lyricsLines.length) return
    var idx = -1
    for (var i = 0; i < lyricsLines.length; i++) {
      if (lyricsLines[i].time >= 0 && lyricsLines[i].time <= sec) idx = i
      else if (lyricsLines[i].time > sec) break
    }
    if (idx !== lyricsCurrentIdx) {
      lyricsCurrentIdx = idx
    }
  }

  readonly property var _renderers: ({
    "bars": VisBars.render, "bars_dot": VisBarsDot.render, "bars_outline": VisBarsOutline.render,
    "bricks": VisBricks.render, "columns": VisColumns.render, "classic_led": VisClassicLED.render,
    "peaks": VisPeaks.render, "wave": VisWave.render, "scope": VisScope.render,
    "heartbeat": VisHeartbeat.render, "retro": VisRetro.render, "scatter": VisScatter.render,
    "flame": VisFlame.render, "pulse": VisPulse.render, "matrix": VisMatrix.render,
    "binary": VisBinary.render, "butterfly": VisButterfly.render, "sakura": VisSakura.render,
    "firework": VisFirework.render, "bubbles": VisBubbles.render, "rain": VisRain.render,
    "terrain": VisTerrain.render, "logo": VisLogo.render, "firefly": VisFirefly.render,
    "geyser": VisGeyser.render, "mosaic": VisMosaic.render, "sand": VisSand.render,
    "stereo": VisStereo.render, "ascii": VisAscii.render, "sine": VisSine.render,
    "siriwave": VisSiriWave.render, "scrubber_wave": VisScrubberWave.render,
    "soundcloud_wave": VisSoundCloudWave.render, "dj_spectral": VisDJSpectral.render,
    "voice_pill": VisVoicePill.render
  })

  readonly property var _modeLabels: ({
    "bars": "Bars", "bars_dot": "Bars Dot", "bars_outline": "Bars Outline",
    "bricks": "Bricks", "columns": "Columns", "classic_led": "Classic LED",
    "peaks": "Peaks", "wave": "Wave", "scope": "Scope",
    "heartbeat": "Heartbeat", "retro": "Retro", "scatter": "Scatter",
    "flame": "Flame", "pulse": "Pulse", "matrix": "Matrix",
    "binary": "Binary", "butterfly": "Butterfly", "sakura": "Sakura",
    "firework": "Firework", "bubbles": "Bubbles", "rain": "Rain",
    "terrain": "Terrain", "logo": "Logo", "firefly": "Firefly",
    "geyser": "Geyser", "mosaic": "Mosaic", "sand": "Sand",
    "stereo": "Stereo", "ascii": "Ascii", "sine": "Sine Wave",
    "siriwave": "Siri Wave", "scrubber_wave": "Scrubber Wave",
    "soundcloud_wave": "SoundCloud Wave", "dj_spectral": "DJ Spectral Wave",
    "voice_pill": "Voice Pill Wave"
  })

  function requestPaint() { if (visCanvas) visCanvas.requestPaint() }

  BorderSurface {
    id: hud
    width: parent.width
    implicitHeight: col.implicitHeight + Style.space(12)
    radius: Style.cornerRadius
    color: Color.popups.background
    borderSpec: Border.controlSpec("normal", p.foreground, Color.accent)

    Column {
      id: col
      width: parent.width - Style.space(16)
      anchors.centerIn: parent
      spacing: Style.space(6)

      // Brand + LED Timer
      Item {
        width: parent.width
        implicitHeight: Style.space(18)

        Row {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(8)

          Row {
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              width: Style.space(6); height: Style.space(6); radius: width / 2
              color: p.isPlaying ? "#00ff66" : (p.isRunning ? "#ffcc00" : "#ff3333")
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: "OMARAMP"
              color: Color.accent
              font.family: p.fontFamily; font.pixelSize: Style.font.caption
              font.bold: true; font.letterSpacing: 1
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: p.timeCurrent + " / " + p.timeTotal
            color: p.isPlaying ? "#00ff66" : p.dim
            font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
          }
        }

        Text {
          id: lyricsIcon
          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
          text: "\uf10d"
          color: root.lyricsVisible ? Color.accent : (lyricsMouse.containsMouse ? Color.accent : p.dim)
          font.family: p.fontFamily; font.pixelSize: Style.font.caption
          MouseArea {
            id: lyricsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleLyrics()
            onContainsMouseChanged: lyricsTip.visible = containsMouse
          }
        }

        Text {
          id: speedIcon
          anchors.right: lyricsIcon.left; anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          text: p.playbackSpeed !== 1.0 ? p.playbackSpeed + "x" : "\uf04e"
          color: p.playbackSpeed !== 1.0 ? Color.accent : (speedMouse.containsMouse ? Color.accent : p.dim)
          font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8; font.bold: p.playbackSpeed !== 1.0
          MouseArea {
            id: speedMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: p.cycleSpeed()
            onContainsMouseChanged: speedTip.visible = containsMouse
          }
        }

        Text {
          id: eqIcon
          anchors.right: speedIcon.left; anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
          text: (p.eqText && p.eqText !== "Flat") ? p.eqText : "EQ"
          color: (p.eqText && p.eqText !== "Flat") || p.eqPickerOpen ? Color.accent : (eqMouse.containsMouse ? Color.accent : p.dim)
          font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8; font.bold: (p.eqText && p.eqText !== "Flat") || p.eqPickerOpen
          MouseArea {
            id: eqMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
              p.eqPickerOpen = !p.eqPickerOpen
              if (p.eqPickerOpen) {
                p.visPickerOpen = false
                root.lyricsVisible = false
              }
            }
            onContainsMouseChanged: eqTip.visible = containsMouse
          }
        }
      }

      // Now Playing Info (Thumbnail + Title + Artist)
      Row {
        width: parent.width
        spacing: Style.space(8)

        BorderSurface {
          width: Style.space(36); height: Style.space(36)
          radius: Style.cornerRadius
          color: Qt.rgba(0.08, 0.09, 0.12, 0.9)
          borderSpec: Border.flat(p.isPlaying ? Qt.rgba(p.dynamicAccent.r, p.dynamicAccent.g, p.dynamicAccent.b, 0.5) : Qt.rgba(1, 1, 1, 0.08), 1)
          anchors.verticalCenter: parent.verticalCenter

          Image {
            anchors.fill: parent; anchors.margins: 1
            visible: p.artPath !== ""
            source: p.artPath !== "" ? "file://" + p.artPath : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 72; sourceSize.height: 72
          }

          Text {
            anchors.centerIn: parent
            visible: p.artPath === ""
            text: "\uf001"
            color: p.dynamicAccent
            font.family: p.fontFamily; font.pixelSize: Style.font.caption
          }
        }

        Column {
          width: parent.width - Style.space(46)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Item {
            id: titleClip
            width: parent.width
            implicitHeight: titleText1.implicitHeight
            clip: true

            readonly property string fullTitle: {
              if (!p.isRunning) return "Daemon idle — click play to start"
              return p.currentTrack || "No track loaded"
            }

            Item {
              id: titleScroller
              height: parent.height
              width: titleText1.implicitWidth + (titleText1.implicitWidth > titleClip.width ? Style.space(40) + titleText2.implicitWidth : 0)

              readonly property bool needsScroll: titleText1.implicitWidth > titleClip.width
              readonly property real loopDistance: titleText1.implicitWidth + Style.space(40)

              NumberAnimation on x {
                running: titleScroller.needsScroll && p.isPlaying
                loops: Animation.Infinite
                from: 0
                to: -titleScroller.loopDistance
                duration: Math.max(2500, titleScroller.loopDistance * 32)
              }

              Row {
                spacing: Style.space(40)

                Text {
                  id: titleText1
                  textFormat: Text.PlainText
                  text: titleClip.fullTitle
                  color: p.isPlaying ? p.dynamicAccent : p.foreground
                  font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }

                Text {
                  id: titleText2
                  visible: titleScroller.needsScroll
                  textFormat: Text.PlainText
                  text: titleClip.fullTitle
                  color: p.isPlaying ? p.dynamicAccent : p.foreground
                  font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
              }

              onNeedsScrollChanged: { if (!needsScroll) x = 0 }
            }
          }

          Item {
            id: artistClip
            width: parent.width
            implicitHeight: artistText1.implicitHeight
            clip: true

            readonly property string fullArtist: p.currentArtist ? p.currentArtist : (p.isRunning ? "cliamp playback" : "omarchy audio")

            Item {
              id: artistScroller
              height: parent.height
              width: artistText1.implicitWidth + (artistText1.implicitWidth > artistClip.width ? Style.space(40) + artistText2.implicitWidth : 0)

              readonly property bool needsScroll: artistText1.implicitWidth > artistClip.width
              readonly property real loopDistance: artistText1.implicitWidth + Style.space(40)

              NumberAnimation on x {
                running: artistScroller.needsScroll && p.isPlaying
                loops: Animation.Infinite
                from: 0
                to: -artistScroller.loopDistance
                duration: Math.max(2500, artistScroller.loopDistance * 35)
              }

              Row {
                spacing: Style.space(40)

                Text {
                  id: artistText1
                  textFormat: Text.PlainText
                  text: artistClip.fullArtist
                  color: p.dim
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption
                }

                Text {
                  id: artistText2
                  visible: artistScroller.needsScroll
                  textFormat: Text.PlainText
                  text: artistClip.fullArtist
                  color: p.dim
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption
                }
              }

              onNeedsScrollChanged: { if (!needsScroll) x = 0 }
            }
          }
        }
      }

      // Visualizer Canvas Frame
      BorderSurface {
        width: parent.width
        height: Style.space(52)
        radius: Style.space(4)
        clip: true
        color: "#06070a"
        borderSpec: Border.flat(p.isPlaying ? Qt.rgba(p.dynamicAccent.r, p.dynamicAccent.g, p.dynamicAccent.b, 0.70) : Qt.rgba(1, 1, 1, 0.12), 1)

        Canvas {
          id: visCanvas
          anchors.fill: parent
          anchors.margins: Style.space(3)
          z: 4

          onPaint: {
            root.updateBeatDrop()
            var ctx = getContext("2d")
            var w = width, h = height
            ctx.clearRect(0, 0, w, h)

            // ── Animated Nebula Plasma Background ──
            if (p.isPlaying) {
              var ar = p.dynamicAccent.r, ag = p.dynamicAccent.g, ab = p.dynamicAccent.b
              var t = p.visFrame * 0.02
              var beat = root.beatDropPulse
              var bass = 0
              if (p.visBands && p.visBands.length > 4) {
                for (var bi = 0; bi < 5; bi++) bass += (p.visBands[bi] || 0)
                bass /= 5.0
              }

              // Paint 5 drifting nebula blobs at different positions
              var blobs = [
                { cx: 0.15, cy: 0.35, rx: 0.30, ry: 0.70, r: ar, g: ag * 0.4, b: ab, drift: 1.0 },
                { cx: 0.85, cy: 0.60, rx: 0.28, ry: 0.65, r: ab * 0.8, g: ar * 0.5, b: ag, drift: -0.7 },
                { cx: 0.50, cy: 0.50, rx: 0.35, ry: 0.80, r: Math.min(1, ar + 0.2), g: Math.min(1, ag + 0.15), b: Math.min(1, ab + 0.2), drift: 1.3 },
                { cx: 0.30, cy: 0.70, rx: 0.22, ry: 0.55, r: ag * 0.6, g: ab * 0.7, b: ar * 0.9, drift: -1.1 },
                { cx: 0.72, cy: 0.30, rx: 0.25, ry: 0.60, r: ab * 0.5, g: ar * 0.8, b: Math.min(1, ag + 0.3), drift: 0.9 }
              ]

              for (var i = 0; i < blobs.length; i++) {
                var bl = blobs[i]
                // Drift position with time
                var bx = (bl.cx + Math.sin(t * bl.drift + i * 1.5) * 0.12) * w
                var by = (bl.cy + Math.cos(t * bl.drift * 0.8 + i * 2.0) * 0.15) * h
                var radiusX = bl.rx * w * (1.0 + bass * 0.4 + beat * 0.3)
                var radiusY = bl.ry * h * (1.0 + bass * 0.3 + beat * 0.2)
                var radius = Math.max(radiusX, radiusY)

                var grad = ctx.createRadialGradient(bx, by, 0, bx, by, radius)
                var alpha = 0.45 + beat * 0.25 + bass * 0.15
                grad.addColorStop(0, "rgba(" + Math.round(bl.r * 255) + "," + Math.round(bl.g * 255) + "," + Math.round(bl.b * 255) + "," + alpha.toFixed(2) + ")")
                grad.addColorStop(0.6, "rgba(" + Math.round(bl.r * 180) + "," + Math.round(bl.g * 120) + "," + Math.round(bl.b * 180) + "," + (alpha * 0.35).toFixed(2) + ")")
                grad.addColorStop(1, "rgba(0,0,0,0)")

                ctx.fillStyle = grad
                ctx.fillRect(0, 0, w, h)
              }
            }

            // ── Visualizer on top ──
            var count = 24, gap = 3
            var barW = Math.floor((w - (count - 1) * gap) / count)
            var fn = root._renderers[p.visMode]
            if (fn) fn(ctx, {
              bands: p.visBands, wave: p.visWave, frame: p.visFrame,
              playing: p.isPlaying, width: w, height: h, S: 2,
              count: count, barW: barW, gap: gap,
              accent: p.dynamicAccent, foreground: p.foreground, dim: p.dim,
              beatDrop: root.beatDropPulse, progress: p.progress,
              state: p._visState
            })
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
              p.visPickerOpen = !p.visPickerOpen
              if (p.visPickerOpen && root.lyricsVisible) root.lyricsVisible = false
            } else {
              var idx = p.visModes.indexOf(p.visMode)
              p.visMode = p.visModes[(idx + 1) % p.visModes.length]
              visCanvas.requestPaint()
            }
          }
        }

        Rectangle {
          anchors.right: parent.right; anchors.bottom: parent.bottom
          anchors.margins: Style.space(3)
          width: modeText.implicitWidth + Style.space(10); height: Style.space(16)
          radius: Style.space(3)
          color: p.visPickerOpen ? Color.accent : (modeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.65))

          Text {
            id: modeText
            anchors.centerIn: parent
            text: (root._modeLabels[p.visMode] || p.visMode) + " ▾"
            color: p.visPickerOpen ? "#000000" : (modeMouse.containsMouse ? Color.accent : Qt.rgba(1, 1, 1, 0.8))
            font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.75; font.bold: true
          }

          MouseArea {
            id: modeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
              p.visPickerOpen = !p.visPickerOpen
              if (p.visPickerOpen && root.lyricsVisible) root.lyricsVisible = false
            }
          }
        }
      }

      // Waveform Scrubber (SoundCloud / WaveformScrubber style with dual-color played tint and playhead needle)
      Item {
        id: seekBar
        width: parent.width
        implicitHeight: Style.space(18)
        property int hoverSecs: -1
        property var waveformCache: []
        property string cachedTrack: ""

        // Generate track waveform profile (54 sample bars)
        function getWaveform() {
          if (cachedTrack === p.currentTrack && waveformCache.length > 0) return waveformCache
          cachedTrack = p.currentTrack
          var bars = []
          var seed = 0
          for (var c = 0; c < cachedTrack.length; c++) {
            seed = (seed * 31 + cachedTrack.charCodeAt(c)) & 0xffffff
          }
          if (seed === 0) seed = 12345
          var count = 54
          for (var i = 0; i < count; i++) {
            var env = Math.sin((i / count) * Math.PI)
            var pseudo = ((Math.sin(i * 12.9898 + seed) * 43758.5453) % 1 + 1) % 1
            var pseudo2 = ((Math.cos(i * 4.1414 + seed * 0.5) * 23421.631) % 1 + 1) % 1
            var amp = 0.15 + (env * 0.45) + (pseudo * 0.25) + (pseudo2 * 0.15)
            bars.push(Math.max(0.14, Math.min(1.0, amp)))
          }
          waveformCache = bars
          return bars
        }

        Canvas {
          id: waveScrubberCanvas
          anchors.fill: parent
          anchors.margins: Style.space(1)

          Connections {
            target: p
            function onProgressChanged() { waveScrubberCanvas.requestPaint() }
            function onDynamicAccentChanged() { waveScrubberCanvas.requestPaint() }
            function onCurrentTrackChanged() { waveScrubberCanvas.requestPaint() }
          }

          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var bars = seekBar.getWaveform()
            var count = bars.length
            var gap = 2
            var barW = Math.max(2, Math.floor((width - (count - 1) * gap) / count))
            var totalW = count * barW + (count - 1) * gap
            var startX = Math.floor((width - totalW) / 2)
            var midY = height / 2.0
            var playX = width * p.progress

            var acc = p.dynamicAccent
            var ar = Math.round(acc.r * 255), ag = Math.round(acc.g * 255), ab = Math.round(acc.b * 255)

            for (var i = 0; i < count; i++) {
              var bx = startX + i * (barW + gap)
              var barCenter = bx + barW / 2.0
              var isPlayed = barCenter <= playX
              var val = bars[i]

              var barH = Math.max(3, val * (height * 0.85))
              var by = midY - barH / 2.0
              var r = barW / 2.0

              if (isPlayed) {
                var grad = ctx.createLinearGradient(0, by, 0, by + barH)
                grad.addColorStop(0, "rgba(255, 255, 255, 0.95)")
                grad.addColorStop(0.4, "rgba(" + ar + "," + ag + "," + ab + ", 0.95)")
                grad.addColorStop(1, "rgba(" + Math.round(ar * 0.7) + "," + Math.round(ag * 0.7) + "," + Math.round(ab * 0.7) + ", 0.80)")
                ctx.fillStyle = grad
              } else {
                ctx.fillStyle = "rgba(255, 255, 255, 0.18)"
              }

              ctx.beginPath()
              ctx.arc(bx + r, by + r, r, Math.PI, 0, false)
              ctx.lineTo(bx + barW, by + barH - r)
              ctx.arc(bx + r, by + barH - r, r, 0, Math.PI, false)
              ctx.closePath()
              ctx.fill()
            }

            // Playhead Cursor Needle
            if (p.totalSecs > 0) {
              var curX = Math.max(1, Math.min(width - 1, playX))
              ctx.fillStyle = "#ffffff"
              ctx.beginPath()
              ctx.rect(curX - 1, 0, 2, height)
              ctx.fill()
            }
          }
        }

        // Hover time tooltip
        Text {
          visible: seekBar.hoverSecs >= 0 && p.totalSecs > 0
          text: {
            var s = seekBar.hoverSecs
            var m = Math.floor(s / 60), sec = s % 60
            return m + ":" + (sec < 10 ? "0" + sec : sec)
          }
          color: p.foreground; font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
          x: Math.max(0, Math.min(parent.width - width, seekMouse.mouseX - width / 2))
          y: -height - 4

          Rectangle {
            z: -1; anchors.fill: parent; anchors.margins: -2
            radius: Style.space(2); color: "#0c0d10"
            border.color: Color.accent; border.width: 1
          }
        }

        // Draggable seek area
        MouseArea {
          id: seekMouse
          anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          onPositionChanged: function(mouse) {
            if (p.totalSecs > 0) seekBar.hoverSecs = Math.floor((mouse.x / width) * p.totalSecs)
            if (pressed && p.totalSecs > 0) p.seekTo(Math.floor((mouse.x / width) * p.totalSecs))
          }
          onExited: seekBar.hoverSecs = -1
          onClicked: function(mouse) {
            if (p.totalSecs > 0) p.seekTo(Math.floor((mouse.x / width) * p.totalSecs))
          }
        }
      }
    }

    Text {
      id: lyricsTip; visible: false
      anchors.right: parent.right; anchors.rightMargin: Style.space(24)
      anchors.top: parent.top; anchors.topMargin: Style.space(2)
      text: "Lyrics"; color: Color.accent
      font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.7
      z: 9999
    }

    Text {
      id: speedTip; visible: false
      anchors.right: parent.right; anchors.rightMargin: Style.space(48)
      anchors.top: parent.top; anchors.topMargin: Style.space(2)
      text: "Speed"; color: Color.accent
      font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.7
      z: 9999
    }

    Text {
      id: eqTip; visible: false
      anchors.right: parent.right; anchors.rightMargin: Style.space(72)
      anchors.top: parent.top; anchors.topMargin: Style.space(2)
      text: "EQ: " + (p.eqText || "Flat"); color: Color.accent
      font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.7
      z: 9999
    }
  }

  Process {
    id: lyricsProc
    command: ["python3", Qt.resolvedUrl("cliamp_ctl.py").toString().replace("file://", ""), "lyrics", p.currentTrack, p.currentArtist]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.synced) root.parseLyrics(d.synced)
          else if (d.plain) root.parseLyrics(d.plain)
          else root.lyricsLines = []
        } catch (e) { root.lyricsLines = [] }
      }
    }
  }
}
