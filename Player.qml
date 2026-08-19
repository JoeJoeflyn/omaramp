import QtQuick
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
  implicitHeight: hud.implicitHeight + Style.space(12) + (lyricsVisible ? lyricsPanel.height : 0)

  property bool lyricsVisible: false
  property string lyricsSynced: ""
  property string lyricsPlain: ""
  property var lyricsLines: []
  property int lyricsCurrentIdx: -1

  function toggleLyrics() {
    lyricsVisible = !lyricsVisible
    if (lyricsVisible && lyricsLines.length === 0) fetchLyrics()
  }

  function fetchLyrics() {
    lyricsProc.running = true
  }

  function parseSyncedLyrics(raw) {
    // Parse [mm:ss.xx] timestamped lines
    var lines = []
    var re = /\[(\d+):(\d+\.\d+)\](.*)/g
    var match
    while ((match = re.exec(raw)) !== null) {
      var min = parseInt(match[1])
      var sec = parseFloat(match[2])
      lines.push({ time: min * 60 + sec, text: match[3].trim() })
    }
    if (lines.length === 0 && raw) {
      // Plain lyrics — no timestamps
      lyricsPlain = raw
      lyricsLines = raw.split("\n").map(function(t) { return { time: -1, text: t.trim() } })
    } else {
      lyricsLines = lines
    }
  }

  function updateLyricsPosition(curSecs) {
    if (!lyricsVisible || lyricsLines.length === 0) return
    var idx = -1
    for (var i = 0; i < lyricsLines.length; i++) {
      if (lyricsLines[i].time >= 0 && lyricsLines[i].time <= curSecs) idx = i
      else if (lyricsLines[i].time >= 0 && lyricsLines[i].time > curSecs) break
    }
    if (idx !== lyricsCurrentIdx) {
      lyricsCurrentIdx = idx
      lyricsFlick.contentY = Math.max(0, idx * Style.space(16) - lyricsFlick.height / 2 + Style.space(8))
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

          // Lyrics toggle
          Text {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: "\uf086"
            color: root.lyricsVisible ? Color.accent : (lyricsMouse.containsMouse ? Color.accent : p.dim)
            font.family: p.fontFamily; font.pixelSize: Style.font.caption

            MouseArea {
              id: lyricsMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleLyrics()
            }
          }
        }
      }

      // Track Title Marquee
      BorderSurface {
        width: parent.width
        implicitHeight: Style.space(36)
        radius: Style.space(3)
        color: "#0c0d10"
        borderSpec: Border.flat(Qt.darker(Color.accent, 1.8), 1)

        Row {
          anchors.fill: parent
          anchors.margins: Style.space(4)
          spacing: Style.space(6)

          Image {
            visible: p.artPath !== ""
            width: Style.space(28); height: Style.space(28)
            anchors.verticalCenter: parent.verticalCenter
            source: p.artPath !== "" ? "file://" + p.artPath : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 56; sourceSize.height: 56
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: p.isPlaying ? "\uf04b" : (p.playbackState === "paused" ? "\uf04c" : "\uf04d")
            color: p.isPlaying ? "#00ff66" : Color.accent
            font.family: p.fontFamily; font.pixelSize: Style.font.caption
          }

          Text {
            width: parent.width - Style.space(20) - (p.artPath !== "" ? Style.space(34) : 0)
            anchors.verticalCenter: parent.verticalCenter
            text: {
              if (!p.isRunning) return "daemon idle — click play to start"
              var a = p.currentArtist, t = p.currentTrack
              return (a ? a + " - " : "") + t
            }
            color: p.isPlaying ? "#00ff66" : p.foreground
            font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall
            font.bold: true; elide: Text.ElideRight
          }
        }
      }

      // Visualizer Canvas
      Item {
        width: parent.width
        height: Style.space(42)

        Canvas {
          id: visCanvas
          anchors.fill: parent

          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var count = 24, gap = 3
            var barW = Math.floor((width - (count - 1) * gap) / count)
            var fn = root._renderers[p.visMode]
            if (fn) fn(ctx, {
              bands: p.visBands, wave: p.visWave, frame: p.visFrame,
              playing: p.isPlaying, width: width, height: height, S: 4,
              count: count, barW: barW, gap: gap,
              accent: Color.accent, foreground: p.foreground, dim: p.dim,
              state: p._visState
            })
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var idx = p.visModes.indexOf(p.visMode)
            p.visMode = p.visModes[(idx + 1) % p.visModes.length]
            visCanvas.requestPaint()
          }
        }

        // Mode label — click to open picker grid
        Text {
          id: visLabel
          anchors.right: parent.right; anchors.bottom: parent.bottom
          text: root._modeLabels[p.visMode] || p.visMode
          color: Qt.rgba(1, 1, 1, 0.5)
          font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8; font.bold: true

          MouseArea {
            id: labelMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: visPicker.visible = !visPicker.visible
            onEntered: parent.color = Color.accent
            onExited: parent.color = Qt.rgba(1, 1, 1, 0.5)
          }
        }

        // Visualizer picker grid
        BorderSurface {
          id: visPicker
          visible: false
          anchors.fill: parent
          color: Qt.rgba(0.05, 0.05, 0.06, 0.95)
          radius: Style.cornerRadius
          borderSpec: Border.flat(Color.accent, 1)

          Flickable {
            anchors.fill: parent
            anchors.margins: Style.space(4)
            contentWidth: grid.width; contentHeight: grid.height
            clip: true; boundsBehavior: Flickable.StopAtBounds

            Grid {
              id: grid
              columns: 4; spacing: Style.space(2)

              Repeater {
                model: p.visModes
                delegate: Rectangle {
                  width: (grid.width - Style.space(6)) / 4
                  height: Style.space(16)
                  radius: Style.space(2)
                  color: modelData === p.visMode ? Color.accent : (modeMouse.containsMouse ? Qt.lighter(Color.accent, 1.5) : "transparent")
                  border.color: modelData === p.visMode ? Color.accent : Qt.rgba(1, 1, 1, 0.1)
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: root._modeLabels[modelData] || modelData
                    color: modelData === p.visMode ? "#0c0d10" : p.foreground
                    font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.7
                    font.bold: modelData === p.visMode
                    elide: Text.ElideRight
                    width: parent.width - Style.space(4)
                    horizontalAlignment: Text.AlignHCenter
                  }

                  MouseArea {
                    id: modeMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      p.visMode = modelData
                      visCanvas.requestPaint()
                      visPicker.visible = false
                    }
                  }
                }
              }
            }
          }

          // Click outside grid to close
          MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: visPicker.visible = false
          }
        }
      }

      // Lyrics panel
      BorderSurface {
        id: lyricsPanel
        visible: root.lyricsVisible
        width: parent.width
        implicitHeight: Style.space(120)
        radius: Style.cornerRadius
        color: Qt.rgba(0.04, 0.04, 0.05, 0.9)
        borderSpec: Border.flat(Qt.rgba(1, 1, 1, 0.08), 1)

        Flickable {
          id: lyricsFlick
          anchors.fill: parent; anchors.margins: Style.space(4)
          contentWidth: width; contentHeight: lyricsCol.implicitHeight
          clip: true; boundsBehavior: Flickable.StopAtBounds

          Column {
            id: lyricsCol
            width: parent.width; spacing: Style.space(2)

            Repeater {
              model: root.lyricsLines
              delegate: Text {
                width: parent.width
                text: modelData.text || "♪"
                color: index === root.lyricsCurrentIdx ? Color.accent : (modelData.text ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.1))
                font.family: p.fontFamily
                font.pixelSize: index === root.lyricsCurrentIdx ? Style.font.bodySmall : Style.font.caption
                font.bold: index === root.lyricsCurrentIdx
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
              }
            }

            Text {
              visible: root.lyricsLines.length === 0
              width: parent.width
              text: "No lyrics found"
              color: p.dim; horizontalAlignment: Text.AlignHCenter
              font.family: p.fontFamily; font.pixelSize: Style.font.caption
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
  }

  Process {
    id: lyricsProc
    command: ["python3", Qt.resolvedUrl("cliamp_ctl.py").replace("file://", ""), "lyrics", p.currentTrack, p.currentArtist]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text || "{}")
          if (d.synced) root.parseSyncedLyrics(d.synced)
          else if (d.plain) root.parseSyncedLyrics(d.plain)
          else root.lyricsLines = []
        } catch (e) { root.lyricsLines = [] }
      }
    }
  }
}
