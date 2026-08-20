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
    "stereo": VisStereo.render, "ascii": VisAscii.render
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
    "stereo": "Stereo", "ascii": "Ascii"
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
          borderSpec: Border.flat(Qt.rgba(1, 1, 1, 0.08), 1)
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
            color: Color.accent
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
                  color: p.isPlaying ? Color.accent : p.foreground
                  font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }

                Text {
                  id: titleText2
                  visible: titleScroller.needsScroll
                  textFormat: Text.PlainText
                  text: titleClip.fullTitle
                  color: p.isPlaying ? Color.accent : p.foreground
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
        height: Style.space(48)
        radius: Style.space(4)
        color: "#08090b"
        borderSpec: Border.flat(Qt.rgba(1, 1, 1, 0.08), 1)

        Canvas {
          id: visCanvas
          anchors.fill: parent
          anchors.margins: Style.space(3)

          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var count = 24, gap = 3
            var barW = Math.floor((width - (count - 1) * gap) / count)
            var fn = root._renderers[p.visMode]
            if (fn) fn(ctx, {
              bands: p.visBands, wave: p.visWave, frame: p.visFrame,
              playing: p.isPlaying, width: width, height: height, S: 2,
              count: count, barW: barW, gap: gap,
              accent: Color.accent, foreground: p.foreground, dim: p.dim,
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

      // Seek Bar
      Item {
        id: seekBar
        width: parent.width
        implicitHeight: Style.space(12)
        property int hoverSecs: -1

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width; height: Style.space(4); radius: Style.space(2)
          color: Color.popups.border

          Rectangle {
            width: Math.max(Style.space(4), parent.width * p.progress)
            height: parent.height; radius: Style.space(2); color: Color.accent
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
          y: -height - 2

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
