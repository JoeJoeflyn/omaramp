import QtQuick
import qs.Commons
import qs.Ui

// Transport controls + volume slider
Row {
  id: root
  property var p  // Panel root

  width: parent ? parent.width : 0
  spacing: Style.space(6)

  // Shuffle toggle
  PanelActionButton {
    iconText: "\uf074"; tooltipText: "Shuffle: " + (p.shuffleMode ? "ON" : "OFF")
    foreground: p.shuffleMode ? Color.accent : p.dim
    hoverColor: Color.accent; fontFamily: p.fontFamily
    anchors.verticalCenter: parent.verticalCenter
    onClicked: p.toggleShuffle()
  }

  // Previous Track
  PanelActionButton {
    iconText: "\uf048"; tooltipText: "Previous Track"
    foreground: p.foreground; hoverColor: Color.accent; fontFamily: p.fontFamily
    anchors.verticalCenter: parent.verticalCenter
    onClicked: p.prevTrack()
  }

  // Primary Play / Pause Action Button
  Rectangle {
    width: Style.space(30); height: Style.space(30); radius: width / 2
    anchors.verticalCenter: parent.verticalCenter
    color: playMouse.pressed ? Qt.darker(Color.accent, 1.2) : (playMouse.containsMouse ? Qt.lighter(Color.accent, 1.15) : Color.accent)

    Text {
      anchors.centerIn: parent
      text: p.isPlaying ? "\uf04c" : "\uf04b"
      color: "#000000"
      font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true
    }

    MouseArea {
      id: playMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
      onClicked: p.togglePlayback()
    }
  }

  // Next Track
  PanelActionButton {
    iconText: "\uf051"; tooltipText: "Next Track"
    foreground: p.foreground; hoverColor: Color.accent; fontFamily: p.fontFamily
    anchors.verticalCenter: parent.verticalCenter
    onClicked: p.nextTrack()
  }

  // Repeat Mode
  PanelActionButton {
    iconText: "\uf01e"; tooltipText: "Repeat: " + p.repeatMode.toUpperCase()
    foreground: p.repeatMode !== "off" ? Color.accent : p.dim
    hoverColor: Color.accent; fontFamily: p.fontFamily
    anchors.verticalCenter: parent.verticalCenter
    onClicked: p.cycleRepeat()
  }

  // Stop Playback
  PanelActionButton {
    iconText: "\uf04d"; tooltipText: "Stop Playback"
    foreground: p.foreground; hoverColor: p.urgent; fontFamily: p.fontFamily
    anchors.verticalCenter: parent.verticalCenter
    onClicked: p.stop()
  }

  Item { width: Style.space(4) }

  // Volume Section
  Row {
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(5)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: p.volumePct === 0 ? "\uf026" : (p.volumePct < 50 ? "\uf027" : "\uf028")
      color: p.volumePct === 0 ? p.urgent : (volIconMouse.containsMouse ? Color.accent : p.dim)
      font.family: p.fontFamily; font.pixelSize: Style.font.caption
      MouseArea {
        id: volIconMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: p.toggleMute()
      }
    }

    Item {
      width: Style.space(64); height: Style.space(16)
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: Style.space(4); radius: Style.space(2); color: "#1a1c23"

        Rectangle {
          width: Math.max(Style.space(2), parent.width * (p.volumePct / 100.0))
          height: parent.height; radius: Style.space(2); color: Color.accent
        }
      }

      MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onPositionChanged: function(mouse) {
          if (pressed) p.setVolume(Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100))))
        }
        onClicked: function(mouse) {
          p.setVolume(Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100))))
        }
      }
    }
  }
}
