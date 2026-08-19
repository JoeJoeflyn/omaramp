import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omaramp"

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
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  function togglePlayback() {
    if (panelLoader.item && panelLoader.item.togglePlayback) panelLoader.item.togglePlayback()
  }

  function nextTrack() {
    if (panelLoader.item && panelLoader.item.nextTrack) panelLoader.item.nextTrack()
  }

  function adjustVolume(delta) {
    if (panelLoader.item && panelLoader.item.adjustVolume) panelLoader.item.adjustVolume(delta)
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
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
    active: true
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
    slotSize: (panelLoader.item && panelLoader.item.isPlaying && (root.settings.showTitleInBar !== false)) ? Style.bar.statusSlot : Style.bar.iconSlot
    tooltipText: {
      if (!panelLoader.item) return "Omaramp"
      var t = panelLoader.item.currentTrack
      var a = panelLoader.item.currentArtist
      if (panelLoader.item.isPlaying) return "Omaramp: " + (a ? a + " - " : "") + t
      return "Omaramp (Stopped)"
    }

    iconComponent: Component {
      Item {
        anchors.fill: parent

        Row {
          anchors.centerIn: parent
          spacing: Style.space(6)

          // Music Note / Equalizer Icon
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (panelLoader.item && panelLoader.item.isPlaying) ? "\uf8cf" : "\uf001"
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.bar.iconFont
            color: (panelLoader.item && panelLoader.item.opened)
              ? (root.bar && root.bar.activeColor ? root.bar.activeColor : Color.accent)
              : ((panelLoader.item && panelLoader.item.isPlaying)
                  ? Color.accent
                  : (root.bar ? root.bar.foreground : Color.foreground))
          }

          // Compact Title Text (when playing)
          Text {
            visible: panelLoader.item && panelLoader.item.isPlaying && (root.settings.showTitleInBar !== false)
            anchors.verticalCenter: parent.verticalCenter
            text: {
              if (!panelLoader.item) return ""
              var a = panelLoader.item.currentArtist
              var t = panelLoader.item.currentTrack
              return (a ? a + " - " : "") + t
            }
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            color: root.bar ? root.bar.foreground : Color.foreground
            elide: Text.ElideRight
            maximumLineCount: 1
          }
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
