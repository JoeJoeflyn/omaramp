import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Visualizer style selector with instant categorized picking
BorderSurface {
  id: root
  property var p  // Panel root
  property string selectedCategory: "all"

  readonly property var allModes: [
    // Classic & VU
    { id: "bars", name: "Bars", category: "classic", icon: "\uf080" },
    { id: "classic_led", name: "Classic LED", category: "classic", icon: "\uf111" },
    { id: "peaks", name: "Peaks", category: "classic", icon: "\uf012" },
    { id: "columns", name: "Columns", category: "classic", icon: "\uf0db" },
    { id: "bars_dot", name: "Bars Dot", category: "classic", icon: "\uf141" },
    { id: "bars_outline", name: "Bars Outline", category: "classic", icon: "\uf096" },
    { id: "bricks", name: "Bricks", category: "classic", icon: "\uf0c9" },
    { id: "stereo", name: "Stereo VU", category: "classic", icon: "\uf025" },
    { id: "ascii", name: "ASCII", category: "classic", icon: "\uf121" },

    // Wave & Scope
    { id: "siriwave", name: "Siri Wave", category: "scope", icon: "\uf179" },
    { id: "scrubber_wave", name: "Scrubber Wave", category: "scope", icon: "\uf080" },
    { id: "soundcloud_wave", name: "SoundCloud Wave", category: "scope", icon: "\uf1be" },
    { id: "dj_spectral", name: "DJ Spectral Wave", category: "scope", icon: "\uf025" },
    { id: "voice_pill", name: "Voice Pill Wave", category: "scope", icon: "\uf130" },
    { id: "wave", name: "Waveform", category: "scope", icon: "\uf21e" },
    { id: "scope", name: "XY Scope", category: "scope", icon: "\uf1fe" },
    { id: "sine", name: "Sine Wave", category: "scope", icon: "\uf1d8" },
    { id: "heartbeat", name: "Heartbeat", category: "scope", icon: "\uf004" },

    // Synth & Retro
    { id: "retro", name: "Retro Synth", category: "retro", icon: "\uf185" },
    { id: "flame", name: "Flame", category: "retro", icon: "\uf06d" },
    { id: "pulse", name: "Pulse", category: "retro", icon: "\uf111" },
    { id: "matrix", name: "Matrix", category: "retro", icon: "\uf108" },
    { id: "terrain", name: "Terrain", category: "retro", icon: "\uf06e" },
    { id: "binary", name: "Binary", category: "retro", icon: "\uf120" },
    { id: "logo", name: "Logo", category: "retro", icon: "\uf005" },
    { id: "mosaic", name: "Mosaic", category: "retro", icon: "\uf009" },

    // Particles & Nature
    { id: "sand", name: "Sand", category: "particle", icon: "\uf252" },
    { id: "firework", name: "Firework", category: "particle", icon: "\uf0e7" },
    { id: "geyser", name: "Geyser", category: "particle", icon: "\uf0d0" },
    { id: "firefly", name: "Firefly", category: "particle", icon: "\uf0eb" },
    { id: "sakura", name: "Sakura", category: "particle", icon: "\uf004" },
    { id: "bubbles", name: "Bubbles", category: "particle", icon: "\uf111" },
    { id: "rain", name: "Rain", category: "particle", icon: "\uf043" },
    { id: "butterfly", name: "Butterfly", category: "particle", icon: "\uf1d8" },
    { id: "scatter", name: "Scatter", category: "particle", icon: "\uf005" }
  ]

  readonly property var filteredModes: {
    if (selectedCategory === "all") return allModes
    var res = []
    for (var i = 0; i < allModes.length; i++) {
      if (allModes[i].category === selectedCategory) res.push(allModes[i])
    }
    return res
  }

  width: parent ? parent.width : 0
  implicitHeight: Style.space(200)
  radius: Style.cornerRadius
  color: Qt.rgba(0.05, 0.05, 0.07, 0.95)
  borderSpec: Border.controlSpec("normal", p ? p.foreground : "#fff", Color.accent)

  Column {
    anchors.fill: parent
    anchors.margins: Style.space(8)
    spacing: Style.space(6)

    // Header with title and close button
    Row {
      width: parent.width
      spacing: Style.space(6)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf0d0"
        color: Color.accent; font.family: p ? p.fontFamily : "sans-serif"; font.pixelSize: Style.font.caption
      }

      Text {
        width: parent.width - Style.space(48)
        anchors.verticalCenter: parent.verticalCenter
        text: "Visualizer Styles (35)"
        color: p ? p.foreground : "#fff"
        font.family: p ? p.fontFamily : "sans-serif"
        font.pixelSize: Style.font.caption; font.bold: true
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf00d"
        color: closePickerMouse.containsMouse ? Color.accent : (p ? p.dim : "#888")
        font.family: p ? p.fontFamily : "sans-serif"; font.pixelSize: Style.font.caption
        MouseArea {
          id: closePickerMouse
          anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
          onClicked: if (p) p.visPickerOpen = false
        }
      }
    }

    // Category Tabs
    Row {
      width: parent.width
      spacing: Style.space(4)

      Repeater {
        model: [
          { id: "all", label: "All" },
          { id: "classic", label: "Classic" },
          { id: "scope", label: "Scope" },
          { id: "retro", label: "Retro" },
          { id: "particle", label: "Particles" }
        ]
        delegate: Rectangle {
          id: tabPill
          readonly property bool isSelected: root.selectedCategory === modelData.id
          width: tabLabel.implicitWidth + Style.space(10); height: Style.space(18)
          radius: Style.space(9)
          color: isSelected ? Color.accent : (tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

          Text {
            id: tabLabel
            anchors.centerIn: parent
            text: modelData.label
            color: tabPill.isSelected ? "#000000" : (p ? p.foreground : "#fff")
            font.family: p ? p.fontFamily : "sans-serif"
            font.pixelSize: Style.font.caption * 0.85
            font.bold: tabPill.isSelected
          }

          MouseArea {
            id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.selectedCategory = modelData.id
          }
        }
      }
    }

    // Modes Grid / Flow inside Flickable
    Flickable {
      width: parent.width
      height: parent.height - Style.space(46)
      contentWidth: width; contentHeight: flowGrid.implicitHeight
      clip: true; boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Flow {
        id: flowGrid
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.filteredModes
          delegate: Rectangle {
            id: chip
            readonly property bool isActive: p && p.visMode === modelData.id
            width: chipContent.implicitWidth + Style.space(12)
            height: Style.space(22)
            radius: Style.space(4)
            color: isActive ? Color.accent : (chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0.1, 0.1, 0.14, 0.8))
            border.width: 1
            border.color: isActive ? Color.accent : (chipMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4) : Qt.rgba(1, 1, 1, 0.06))

            Row {
              id: chipContent
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                text: modelData.icon
                color: chip.isActive ? "#000000" : (chipMouse.containsMouse ? Color.accent : (p ? p.dim : "#888"))
                font.family: p ? p.fontFamily : "sans-serif"
                font.pixelSize: Style.font.caption * 0.8
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: modelData.name
                color: chip.isActive ? "#000000" : (chipMouse.containsMouse ? Color.accent : (p ? p.foreground : "#fff"))
                font.family: p ? p.fontFamily : "sans-serif"
                font.pixelSize: Style.font.caption * 0.85
                font.bold: chip.isActive
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: chipMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (p) {
                  p.visMode = modelData.id
                  p.requestPaint()
                }
              }
            }
          }
        }
      }
    }
  }
}
