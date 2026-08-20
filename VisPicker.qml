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
    { id: "bars", name: "Bars", category: "classic", icon: "📊" },
    { id: "classic_led", name: "Classic LED", category: "classic", icon: "🟢" },
    { id: "peaks", name: "Peaks", category: "classic", icon: "📶" },
    { id: "columns", name: "Columns", category: "classic", icon: "🏛" },
    { id: "bars_dot", name: "Bars Dot", category: "classic", icon: "⠿" },
    { id: "bars_outline", name: "Bars Outline", category: "classic", icon: "🔲" },
    { id: "bricks", name: "Bricks", category: "classic", icon: "🧱" },
    { id: "stereo", name: "Stereo VU", category: "classic", icon: "🎛" },
    { id: "ascii", name: "ASCII", category: "classic", icon: "▓" },

    // Wave & Scope
    { id: "wave", name: "Waveform", category: "scope", icon: "〰" },
    { id: "scope", name: "XY Scope", category: "scope", icon: "🕸" },
    { id: "heartbeat", name: "Heartbeat", category: "scope", icon: "💓" },

    // Synth & Retro
    { id: "retro", name: "Retro Synth", category: "retro", icon: "🌅" },
    { id: "flame", name: "Flame", category: "retro", icon: "🔥" },
    { id: "pulse", name: "Pulse", category: "retro", icon: "💫" },
    { id: "matrix", name: "Matrix", category: "retro", icon: "🟢" },
    { id: "terrain", name: "Terrain", category: "retro", icon: "⛰" },
    { id: "binary", name: "Binary", category: "retro", icon: "01" },
    { id: "logo", name: "Logo", category: "retro", icon: "🅰" },
    { id: "mosaic", name: "Mosaic", category: "retro", icon: "🟨" },

    // Particles & Nature
    { id: "sand", name: "Sand", category: "particle", icon: "⏳" },
    { id: "firework", name: "Firework", category: "particle", icon: "🎆" },
    { id: "geyser", name: "Geyser", category: "particle", icon: "⛲" },
    { id: "firefly", name: "Firefly", category: "particle", icon: "✨" },
    { id: "sakura", name: "Sakura", category: "particle", icon: "🌸" },
    { id: "bubbles", name: "Bubbles", category: "particle", icon: "🫧" },
    { id: "rain", name: "Rain", category: "particle", icon: "🌧" },
    { id: "butterfly", name: "Butterfly", category: "particle", icon: "🦋" },
    { id: "scatter", name: "Scatter", category: "particle", icon: "🌌" }
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
        text: "Visualizer Styles (29)"
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
