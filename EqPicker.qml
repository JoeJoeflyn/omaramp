import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Equalizer & Audio Profile Selector
BorderSurface {
  id: root
  property var p  // Panel root

  readonly property var presets: [
    { id: "Flat", name: "Flat (Original)", icon: "⚖️", desc: "Pure unprocessed audio with 0 dB flat response" },
    { id: "Bass Boost", name: "Bass Boost", icon: "🔊", desc: "Enhanced low-end sub-bass & kick drum punch" },
    { id: "Rock", name: "Rock & Metal", icon: "🎸", desc: "Punchy low-mids and crisp treble drive" },
    { id: "Electronic", name: "Electronic / EDM", icon: "🎧", desc: "Deep club bass with sparkling highs" },
    { id: "Pop", name: "Pop / Modern", icon: "✨", desc: "Warm vocal focus with balanced soundstage" },
    { id: "Vocal Clarity", name: "Vocal Clarity", icon: "🎤", desc: "Clear voice boost for speech, podcasts & lyrics" },
    { id: "Acoustic", name: "Acoustic / Live", icon: "🎻", desc: "Natural warm balance for strings & instruments" },
    { id: "Treble Boost", name: "Treble Boost", icon: "🔔", desc: "Airy, crisp, high-frequency brightness" },
    { id: "Late Night", name: "Late Night Mode", icon: "🌙", desc: "Reduced bass rumble with clear quiet speech" }
  ]

  width: parent ? parent.width : 0
  implicitHeight: Style.space(200)
  radius: Style.cornerRadius
  color: Qt.rgba(0.05, 0.05, 0.07, 0.95)
  borderSpec: Border.controlSpec("normal", p ? p.foreground : "#fff", Color.accent)

  Column {
    anchors.fill: parent
    anchors.margins: Style.space(8)
    spacing: Style.space(6)

    // Header
    Row {
      width: parent.width
      spacing: Style.space(6)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf1de"
        color: Color.accent; font.family: p ? p.fontFamily : "sans-serif"; font.pixelSize: Style.font.caption
      }

      Text {
        width: parent.width - Style.space(48)
        anchors.verticalCenter: parent.verticalCenter
        text: "Equalizer Profiles (" + (p ? p.eqText : "Flat") + ")"
        color: p ? p.foreground : "#fff"
        font.family: p ? p.fontFamily : "sans-serif"
        font.pixelSize: Style.font.caption; font.bold: true
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "\uf00d"
        color: closeEqMouse.containsMouse ? Color.accent : (p ? p.dim : "#888")
        font.family: p ? p.fontFamily : "sans-serif"; font.pixelSize: Style.font.caption
        MouseArea {
          id: closeEqMouse
          anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
          onClicked: if (p) p.eqPickerOpen = false
        }
      }
    }

    // Scrollable preset list
    Flickable {
      width: parent.width
      height: parent.height - Style.space(26)
      contentWidth: width; contentHeight: presetCol.implicitHeight
      clip: true; boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Column {
        id: presetCol
        width: parent.width
        spacing: Style.space(4)

        Repeater {
          model: root.presets
          delegate: Rectangle {
            id: presetRow
            readonly property bool isActive: p && p.eqText === modelData.id
            width: parent.width
            height: Style.space(32)
            radius: Style.space(4)
            color: isActive ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : (rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
            border.width: 1
            border.color: isActive ? Color.accent : (rowMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.3) : "transparent")

            Row {
              anchors.fill: parent
              anchors.margins: Style.space(6)
              spacing: Style.space(8)

              Text {
                text: modelData.icon
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(50)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                  width: parent.width
                  text: modelData.name
                  color: presetRow.isActive ? Color.accent : (p ? p.foreground : "#fff")
                  font.family: p ? p.fontFamily : "sans-serif"
                  font.pixelSize: Style.font.caption
                  font.bold: presetRow.isActive
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: modelData.desc
                  color: p ? p.dim : "#888"
                  font.family: p ? p.fontFamily : "sans-serif"
                  font.pixelSize: Style.font.caption * 0.8
                  elide: Text.ElideRight
                }
              }

              Text {
                visible: presetRow.isActive
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf00c"
                color: Color.accent
                font.family: p ? p.fontFamily : "sans-serif"
                font.pixelSize: Style.font.caption * 0.8
              }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (p) p.setEq(modelData.id)
              }
            }
          }
        }
      }
    }
  }
}
