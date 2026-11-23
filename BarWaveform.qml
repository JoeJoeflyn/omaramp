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

  // The icon is still a waveform before the first track, while paused and if
  // capture drops out. No fake animation or idle audio capture.
  Row {
    id: rest
    visible: !root.live
    anchors.centerIn: parent
    height: parent.height
    spacing: Math.max(1, Math.floor(root.width / 20))
    readonly property var levels: [0.23, 0.48, 0.78, 0.43, 1, 0.65, 0.34, 0.74, 0.45, 0.23]
    Repeater {
      model: rest.levels
      Rectangle {
        required property real modelData
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(1, (root.width - (rest.levels.length - 1) * rest.spacing) / rest.levels.length)
        height: Math.max(2, Math.round(rest.height * modelData))
        radius: width / 2
        color: root.foreground
      }
    }
  }
}
