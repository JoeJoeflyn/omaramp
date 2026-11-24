import QtQuick

Item {
  id: root
  property var player: null
  required property color foreground
  readonly property bool live: !!player && player.isPlaying && player.visActive

  Loader {
    anchors.fill: parent
    active: root.live
    sourceComponent: Visualizer { p: root.player; compact: true }
  }

  // The old equalizer at its resting heights, with all four bars on one baseline.
  Row {
    visible: !root.live
    anchors.centerIn: parent
    height: 12
    spacing: 2
    scale: root.height / 18
    Repeater {
      model: [4, 10, 7, 5]
      Rectangle {
        required property int modelData
        anchors.bottom: parent.bottom
        width: 2; height: modelData; radius: 1
        color: root.foreground
      }
    }
  }
}
