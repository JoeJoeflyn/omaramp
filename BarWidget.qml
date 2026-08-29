import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omaramp"

  function ensurePanel() {
    if (!panelLoader.active) {
      panelLoader.active = true
    }
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  function togglePanel() {
    ensurePanel()
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
    else Qt.callLater(function() { if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey() })
  }

  function togglePlayback() {
    ensurePanel()
    if (panelLoader.item && panelLoader.item.togglePlayback) panelLoader.item.togglePlayback()
    else Qt.callLater(function() { if (panelLoader.item && panelLoader.item.togglePlayback) panelLoader.item.togglePlayback() })
  }

  function nextTrack() {
    ensurePanel()
    if (panelLoader.item && panelLoader.item.nextTrack) panelLoader.item.nextTrack()
    else Qt.callLater(function() { if (panelLoader.item && panelLoader.item.nextTrack) panelLoader.item.nextTrack() })
  }

  function adjustVolume(delta) {
    ensurePanel()
    if (panelLoader.item && panelLoader.item.adjustVolume) panelLoader.item.adjustVolume(delta)
    else Qt.callLater(function() { if (panelLoader.item && panelLoader.item.adjustVolume) panelLoader.item.adjustVolume(delta) })
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    ensurePanel()
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
    else Qt.callLater(function() { if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey() })
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: false
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.iconSlot
    active: panelLoader.item && (panelLoader.item.opened || panelLoader.item.isPlaying)
    tooltipText: {
      if (!panelLoader.item) return "Omaramp"
      var t = panelLoader.item.currentTrack
      var a = panelLoader.item.currentArtist
      if (panelLoader.item.isPlaying) return "Omaramp (Playing): " + (a ? a + " - " : "") + t
      return "Omaramp (Stopped)"
    }

    iconComponent: Component {
      Item {
        anchors.fill: parent

        // 1. Live Animated Equalizer Waves when PLAYING (Active & Bright)
        Item {
          anchors.centerIn: parent
          width: Style.space(16)
          height: Style.space(12)
          visible: panelLoader.item && panelLoader.item.isPlaying

          Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(2)

            Rectangle {
              id: bar1
              width: Style.space(2)
              height: Style.space(4)
              radius: 1
              color: root.bar ? (root.bar.barForeground || root.bar.foreground || "#ffffff") : "#ffffff"
              anchors.bottom: parent.bottom

              SequentialAnimation on height {
                running: panelLoader.item && panelLoader.item.isPlaying
                loops: Animation.Infinite
                NumberAnimation { to: Style.space(11); duration: 320; easing.type: Easing.InOutQuad }
                NumberAnimation { to: Style.space(4); duration: 280; easing.type: Easing.InOutQuad }
                NumberAnimation { to: Style.space(9); duration: 240; easing.type: Easing.InOutQuad }
                NumberAnimation { to: Style.space(3); duration: 260; easing.type: Easing.InOutQuad }
              }
            }

            Rectangle {
              id: bar2
              width: Style.space(2)
              height: Style.space(10)
              radius: 1
              color: root.bar ? (root.bar.barForeground || root.bar.foreground || "#ffffff") : "#ffffff"
              anchors.bottom: parent.bottom

              SequentialAnimation on height {
                running: panelLoader.item && panelLoader.item.isPlaying
                loops: Animation.Infinite
                NumberAnimation { to: Style.space(3); duration: 250; easing.type: Easing.InOutQuad }
                NumberAnimation { to: Style.space(12); duration: 340; easing.type: Easing.InOutQuad }
                NumberAnimation { to: Style.space(6); duration: 220; easing.type: Easing.InOutQuad }
                NumberAnimation { to: Style.space(11); duration: 290; easing.type: Easing.InOutQuad }
              }
            }

            Rectangle {
              id: bar3
              width: Style.space(2)
              height: Style.space(7)
              radius: 1
              color: root.bar ? (root.bar.barForeground || root.bar.foreground || "#ffffff") : "#ffffff"
              anchors.bottom: parent.bottom

              SequentialAnimation on height {
                running: panelLoader.item && panelLoader.item.isPlaying
                loops: Animation.Infinite
                NumberAnimation { to: Style.space(12); duration: 290; easing.type: Easing.InOutQuad }
                NumberAnimation { to: Style.space(5); duration: 270; easing.type: Easing.InOutQuad }
                NumberAnimation { to: Style.space(10); duration: 310; easing.type: Easing.InOutQuad }
                NumberAnimation { to: Style.space(4); duration: 230; easing.type: Easing.InOutQuad }
              }
            }

            Rectangle {
              id: bar4
              width: Style.space(2)
              height: Style.space(5)
              radius: 1
              color: root.bar ? (root.bar.barForeground || root.bar.foreground || "#ffffff") : "#ffffff"
              anchors.bottom: parent.bottom

              SequentialAnimation on height {
                running: panelLoader.item && panelLoader.item.isPlaying
                loops: Animation.Infinite
                NumberAnimation { to: Style.space(4); duration: 260; easing.type: Easing.InOutQuad }
                NumberAnimation { to: Style.space(11); duration: 310; easing.type: Easing.InOutQuad }
                NumberAnimation { to: Style.space(5); duration: 240; easing.type: Easing.InOutQuad }
                NumberAnimation { to: Style.space(9); duration: 280; easing.type: Easing.InOutQuad }
              }
            }
          }
        }

        // 2. Static Icon when STOPPED or PAUSED
        Text {
          anchors.centerIn: parent
          visible: !panelLoader.item || !panelLoader.item.isPlaying
          text: (panelLoader.item && panelLoader.item.playbackState === "paused") ? "\uf04c" : "\uf001"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.bar.iconFont
          color: (panelLoader.item && panelLoader.item.opened)
            ? (root.bar ? (root.bar.barForeground || root.bar.foreground || "#ffffff") : "#ffffff")
            : ((panelLoader.item && panelLoader.item.playbackState === "paused")
                ? (panelLoader.item ? panelLoader.item.dim : Color.foreground)
                : (root.bar ? root.bar.foreground : Color.foreground))
        }
      }
    }

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.nextTrack()
      else if (b === Qt.MiddleButton) root.togglePlayback()
      else root.togglePanel()
    }
  }

  WheelHandler {
    target: button
    onWheel: function(event) {
      if (event.angleDelta.y > 0) root.adjustVolume(5)
      else if (event.angleDelta.y < 0) root.adjustVolume(-5)
    }
  }
}
