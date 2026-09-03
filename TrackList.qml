import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

// Search input + tabs + scrollable track list
Column {
  id: root
  property var p  // Panel root
  property alias urlInput: urlInput

  width: parent ? parent.width : 0
  spacing: Style.space(6)

  function isTrackCurrent(itemUrl, itemTitle, itemArtist) {
    if (!p || p.currentTrack === "No track loaded" || p.currentTrack === "") return false
    var curU = p.currentUrl ? p.currentUrl.trim() : ""
    var itmU = itemUrl ? itemUrl.trim() : ""
    
    // Direct URL match
    if (curU !== "" && itmU !== "" && curU === itmU) return true
    
    // YouTube video ID match
    if (curU !== "" && itmU !== "") {
      var curM = curU.match(/(?:v=|youtu\.be\/)([0-9A-Za-z_-]{11})/)
      var itmM = itmU.match(/(?:v=|youtu\.be\/)([0-9A-Za-z_-]{11})/)
      if (curM && itmM && curM[1] === itmM[1]) return true
    }
    
    // Fallback title / artist matching
    var curT = p.currentTrack ? p.currentTrack.trim().toLowerCase() : ""
    var itmT = itemTitle ? itemTitle.trim().toLowerCase() : ""
    if (curT !== "" && itmT !== "") {
      if (curT === itmT || curT.indexOf(itmT) !== -1 || itmT.indexOf(curT) !== -1) return true
    }
    return false
  }

  // Search / URL Input Bar
  Row {
    width: parent.width
    spacing: Style.space(4)

    BorderSurface {
      id: searchBox
      width: parent.width - Style.space(36)
      implicitHeight: Style.space(26)
      radius: Style.cornerRadius
      color: Color.popups.background
      borderSpec: Border.controlSpec(urlInput.activeFocus ? "focused" : "normal", p.foreground, Color.accent)
      clip: true

      Item {
        anchors.fill: parent
        anchors.leftMargin: Style.space(6)
        anchors.rightMargin: Style.space(6)

        Text {
          id: searchIcon
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: "\uf002"
          color: p.dim
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption
        }

        TextInput {
          id: urlInput
          anchors.left: searchIcon.right
          anchors.leftMargin: Style.space(6)
          anchors.right: clearBtn.visible ? clearBtn.left : parent.right
          anchors.rightMargin: clearBtn.visible ? Style.space(4) : 0
          anchors.verticalCenter: parent.verticalCenter
          text: p.urlInputText
          onTextChanged: p.urlInputText = text
          color: p.foreground
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption
          selectByMouse: true
          clip: true
          onAccepted: p.searchTracks(text)

          Text {
            visible: !urlInput.text && !urlInput.activeFocus
            text: "Search songs, artists, or paste URL..."
            color: p.dim
            font.family: p.fontFamily
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            elide: Text.ElideRight
          }
        }

        Text {
          id: clearBtn
          visible: urlInput.text.length > 0
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: "\uf00d"
          color: clearMouse.containsMouse ? Color.accent : p.dim
          font.family: p.fontFamily
          font.pixelSize: Style.font.caption

          MouseArea {
            id: clearMouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { urlInput.text = ""; p.clearSearch() }
          }
        }
      }
    }

    PanelActionButton {
      iconText: p.isSearching ? "\uf110" : "\uf002"
      tooltipText: "Search"
      foreground: p.foreground; hoverColor: Color.accent; fontFamily: p.fontFamily
      enabled: p.urlInputText.trim().length > 0 && !p.isSearching
      onClicked: p.searchTracks(p.urlInputText)
    }
  }

  // Styled Pill Tabs + Daemon Status
  Row {
    width: parent.width
    spacing: Style.space(4)

    // Search Tab Pill
    BorderSurface {
      visible: p.selectedTab === "search" || p.searchResults.length > 0 || p.isSearching
      implicitHeight: Style.space(22)
      implicitWidth: searchTabText.implicitWidth + Style.space(14)
      radius: Style.cornerRadius
      color: p.selectedTab === "search" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : "transparent"
      borderSpec: p.selectedTab === "search" ? Border.flat(Color.accent, 1) : Border.none

      Text {
        id: searchTabText
        anchors.centerIn: parent
        text: "Search (" + p.searchResults.length + ")"
        color: p.selectedTab === "search" ? Color.accent : p.dim
        font.family: p.fontFamily; font.pixelSize: Style.font.caption
        font.bold: p.selectedTab === "search"
      }

      MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
        onClicked: p.selectedTab = "search"
      }
    }

    // Recents Tab Pill
    BorderSurface {
      implicitHeight: Style.space(22)
      implicitWidth: recentsTabText.implicitWidth + Style.space(14)
      radius: Style.cornerRadius
      color: p.selectedTab === "history" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : "transparent"
      borderSpec: p.selectedTab === "history" ? Border.flat(Color.accent, 1) : Border.none

      Text {
        id: recentsTabText
        anchors.centerIn: parent
        text: "Recents (" + p.historyList.length + ")"
        color: p.selectedTab === "history" ? Color.accent : p.dim
        font.family: p.fontFamily; font.pixelSize: Style.font.caption
        font.bold: p.selectedTab === "history"
      }

      MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
        onClicked: { p.selectedTab = "history"; p.loadHistory() }
      }
    }

    // Queue Tab Pill
    BorderSurface {
      implicitHeight: Style.space(22)
      implicitWidth: queueTabText.implicitWidth + Style.space(14)
      radius: Style.cornerRadius
      color: p.selectedTab === "queue" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : "transparent"
      borderSpec: p.selectedTab === "queue" ? Border.flat(Color.accent, 1) : Border.none

      Text {
        id: queueTabText
        anchors.centerIn: parent
        text: "Queue (" + (p.queueList ? p.queueList.length : p.queueCount) + ")"
        color: p.selectedTab === "queue" ? Color.accent : p.dim
        font.family: p.fontFamily; font.pixelSize: Style.font.caption
        font.bold: p.selectedTab === "queue"
      }

      MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
        onClicked: { p.selectedTab = "queue"; p.loadQueue() }
      }
    }

    // Playlists Tab Pill
    BorderSurface {
      implicitHeight: Style.space(22)
      implicitWidth: plTabText.implicitWidth + Style.space(14)
      radius: Style.cornerRadius
      color: p.selectedTab === "playlists" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : "transparent"
      borderSpec: p.selectedTab === "playlists" ? Border.flat(Color.accent, 1) : Border.none

      Text {
        id: plTabText
        anchors.centerIn: parent
        text: "Playlists (" + p.playlistsList.length + ")"
        color: p.selectedTab === "playlists" ? Color.accent : p.dim
        font.family: p.fontFamily; font.pixelSize: Style.font.caption
        font.bold: p.selectedTab === "playlists"
      }

      MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true
        onClicked: { p.selectedTab = "playlists"; p.loadPlaylists() }
      }
    }

    Item { width: Style.space(4) }

    // Daemon status icon
    PanelActionButton {
      iconText: "\uf011"
      tooltipText: p.isRunning ? "Stop background daemon" : "Daemon idle"
      foreground: p.isRunning ? p.foreground : p.dim
      hoverColor: p.urgent; fontFamily: p.fontFamily
      onClicked: { if (p.isRunning) p.stopDaemon(); else p.play() }
    }
  }

  // Scrollable Track / Playlist Container
  Flickable {
    width: parent.width
    implicitHeight: Style.space(168)
    contentWidth: width
    contentHeight: listCol.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: listCol
      width: parent.width
      spacing: Style.space(3)

      // ==========================================
      // SEARCH TAB CONTENT
      // ==========================================
      Item {
        visible: p.selectedTab === "search" && p.isSearching
        width: parent.width; implicitHeight: Style.space(40)
        Row {
          anchors.centerIn: parent; spacing: Style.space(8)
          Text { anchors.verticalCenter: parent.verticalCenter; text: "\uf110"; color: Color.accent; font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall; RotationAnimator on rotation { running: p.isSearching; from: 0; to: 360; duration: 1000; loops: Animation.Infinite } }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "Searching for \"" + p.searchQuery + "\"..."; color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption }
        }
      }

      Item {
        visible: p.selectedTab === "search" && !p.isSearching && p.searchResults.length === 0 && p.searchQuery !== ""
        width: parent.width; implicitHeight: Style.space(40)
        Text { anchors.centerIn: parent; text: "No tracks found for \"" + p.searchQuery + "\""; color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption }
      }

      Repeater {
        model: (p.selectedTab === "search" && !p.isSearching) ? p.searchResults : []
        delegate: BorderSurface {
          id: sRow
          readonly property bool isCurrent: root.isTrackCurrent(modelData.url, modelData.title, modelData.artist)
          width: parent.width; implicitHeight: Style.space(32); radius: Style.cornerRadius
          color: isCurrent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.14) : (sRowMouse.containsMouse ? Style.hoverFillFor(p.foreground, Color.accent) : "transparent")
          borderSpec: isCurrent ? Border.flat(Color.accent, 1) : Border.none

          MouseArea {
            id: sRowMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { if (modelData.url) p.playUrl(modelData.url, modelData.title, modelData.artist) }
          }

          Row {
            anchors.fill: parent; anchors.margins: Style.space(4); spacing: Style.space(6)

            // Thumbnail
            BorderSurface {
              width: Style.space(24); height: Style.space(24); radius: Style.space(3)
              color: Qt.rgba(0.1, 0.1, 0.14, 0.9); borderSpec: Border.none
              anchors.verticalCenter: parent.verticalCenter

              Image {
                visible: modelData.thumb !== undefined && modelData.thumb !== ""
                anchors.fill: parent
                asynchronous: true
                source: (modelData.thumb && (modelData.thumb.indexOf("http://") === 0 || modelData.thumb.indexOf("https://") === 0 || modelData.thumb.indexOf("file://") === 0)) ? modelData.thumb : (modelData.thumb ? "file://" + modelData.thumb : "")
                fillMode: Image.PreserveAspectCrop; sourceSize.width: 48; sourceSize.height: 48
              }
              Text {
                visible: !modelData.thumb
                anchors.centerIn: parent; text: "\uf001"; color: sRow.isCurrent ? Color.accent : p.dim
                font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8
              }
            }

            // Play / Loading status icon
            Text {
              visible: p.loadingVid === modelData.url
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf110"; color: Color.accent; font.family: p.fontFamily; font.pixelSize: Style.font.caption
              RotationAnimator on rotation { running: visible; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
            }

            Text {
              visible: p.loadingVid !== modelData.url
              anchors.verticalCenter: parent.verticalCenter
              text: sRow.isCurrent && p.isPlaying ? "\uf04c" : "\uf04b"
              color: sRow.isCurrent ? Color.accent : (sRowMouse.containsMouse ? Color.accent : p.dim)
              font.family: p.fontFamily; font.pixelSize: Style.font.caption
            }

            // Title & Artist
            Column {
              width: parent.width - Style.space(90)
              anchors.verticalCenter: parent.verticalCenter; spacing: 1

              Text {
                width: parent.width; textFormat: Text.PlainText
                text: modelData.title || "Track"
                color: sRow.isCurrent ? Color.accent : p.foreground
                font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                elide: Text.ElideRight
              }
              Text {
                visible: modelData.artist !== ""
                width: parent.width; textFormat: Text.PlainText
                text: modelData.artist || ""
                color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.82
                elide: Text.ElideRight
              }
            }

            // Add to Queue button
            Text {
              z: 2
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf067"
              color: sQueueMouse.containsMouse ? Color.accent : p.dim
              font.family: p.fontFamily; font.pixelSize: Style.font.caption
              MouseArea {
                id: sQueueMouse
                anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: p.queueUrl(modelData.url, modelData.title, modelData.artist)
              }
            }

            // Duration
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.duration || ""
              color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption
            }
          }
        }
      }

      // ==========================================
      // RECENTS TAB CONTENT
      // ==========================================
      Repeater {
        model: p.selectedTab === "history" ? p.historyList : []
        delegate: BorderSurface {
          id: hRow
          readonly property bool isCurrent: root.isTrackCurrent(modelData.path, modelData.title, modelData.artist)
          width: parent.width; implicitHeight: Style.space(32); radius: Style.cornerRadius
          color: isCurrent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.14) : (hRowMouse.containsMouse ? Style.hoverFillFor(p.foreground, Color.accent) : "transparent")
          borderSpec: isCurrent ? Border.flat(Color.accent, 1) : Border.none

          MouseArea {
            id: hRowMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { if (modelData.path) p.playUrl(modelData.path, modelData.title, modelData.artist) }
          }

          Row {
            anchors.fill: parent; anchors.margins: Style.space(4); spacing: Style.space(6)

            // Thumbnail
            BorderSurface {
              width: Style.space(24); height: Style.space(24); radius: Style.space(3)
              color: Qt.rgba(0.1, 0.1, 0.14, 0.9); borderSpec: Border.none
              anchors.verticalCenter: parent.verticalCenter

              Image {
                visible: modelData.thumb !== undefined && modelData.thumb !== ""
                anchors.fill: parent
                asynchronous: true
                source: (modelData.thumb && (modelData.thumb.indexOf("http://") === 0 || modelData.thumb.indexOf("https://") === 0 || modelData.thumb.indexOf("file://") === 0)) ? modelData.thumb : (modelData.thumb ? "file://" + modelData.thumb : "")
                fillMode: Image.PreserveAspectCrop; sourceSize.width: 48; sourceSize.height: 48
              }
              Text {
                visible: !modelData.thumb
                anchors.centerIn: parent; text: "\uf001"; color: hRow.isCurrent ? Color.accent : p.dim
                font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8
              }
            }

            // Play / Loading icon
            Text {
              visible: p.loadingVid === modelData.path
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf110"; color: Color.accent; font.family: p.fontFamily; font.pixelSize: Style.font.caption
              RotationAnimator on rotation { running: visible; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
            }

            Text {
              visible: p.loadingVid !== modelData.path
              anchors.verticalCenter: parent.verticalCenter
              text: hRow.isCurrent && p.isPlaying ? "\uf04c" : "\uf04b"
              color: hRow.isCurrent ? Color.accent : (hRowMouse.containsMouse ? Color.accent : p.dim)
              font.family: p.fontFamily; font.pixelSize: Style.font.caption
            }

            // Title & Artist
            Column {
              width: parent.width - Style.space(90)
              anchors.verticalCenter: parent.verticalCenter; spacing: 1

              Text {
                width: parent.width; textFormat: Text.PlainText
                text: modelData.title || "Track"
                color: hRow.isCurrent ? Color.accent : p.foreground
                font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                elide: Text.ElideRight
              }
              Text {
                visible: modelData.artist !== ""
                width: parent.width; textFormat: Text.PlainText
                text: modelData.artist || ""
                color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.82
                elide: Text.ElideRight
              }
            }

            // Add to Queue button
            Text {
              z: 2
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf067"
              color: hQueueMouse.containsMouse ? Color.accent : p.dim
              font.family: p.fontFamily; font.pixelSize: Style.font.caption
              MouseArea {
                id: hQueueMouse
                anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: p.queueUrl(modelData.path, modelData.title, modelData.artist)
              }
            }

            // Duration
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: {
                var s = modelData.duration_secs || 0
                var m = Math.floor(s / 60), sec = s % 60
                return (m > 0 || sec > 0) ? (m + ":" + (sec < 10 ? "0" + sec : sec)) : ""
              }
              color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption
            }
          }
        }
      }

      // ==========================================
      // QUEUE TAB CONTENT
      // ==========================================
      Column {
        visible: p.selectedTab === "queue"
        width: parent.width
        spacing: Style.space(4)

        // Queue Header Bar
        BorderSurface {
          visible: p.queueList && p.queueList.length > 0
          width: parent.width; implicitHeight: Style.space(28); radius: Style.cornerRadius
          color: Color.popups.background
          borderSpec: Border.controlSpec("normal", p.foreground, Color.accent)

          Row {
            anchors.fill: parent; anchors.margins: Style.space(4); spacing: Style.space(6)
            Text {
              width: parent.width - Style.space(80); anchors.verticalCenter: parent.verticalCenter
              text: "Up Next (" + p.queueList.length + " tracks)"
              color: Color.accent; font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
              elide: Text.ElideRight
            }

            BorderSurface {
              implicitHeight: Style.space(20); implicitWidth: clearQText.implicitWidth + Style.space(10)
              radius: Style.cornerRadius
              color: clearQMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.25) : "transparent"
              borderSpec: Border.none
              anchors.verticalCenter: parent.verticalCenter

              Text {
                id: clearQText; anchors.centerIn: parent
                text: "\uf1f8 Clear"
                color: clearQMouse.containsMouse ? p.urgent : p.dim
                font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.85
              }
              MouseArea {
                id: clearQMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: p.clearQueue()
              }
            }
          }
        }

        // Empty state
        Text {
          visible: !p.queueList || p.queueList.length === 0
          text: "Queue is empty\nClick '+' on any song to add to queue"
          color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter; width: parent.width
        }

        // Queued tracks
        Repeater {
          model: p.selectedTab === "queue" ? p.queueList : []
          delegate: BorderSurface {
            id: qRow
            width: parent.width; implicitHeight: Style.space(32); radius: Style.cornerRadius
            color: qRowMouse.containsMouse ? Style.hoverFillFor(p.foreground, Color.accent) : "transparent"
            borderSpec: Border.none

            MouseArea {
              id: qRowMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                p.playUrl(modelData.url, modelData.title, modelData.artist)
                p.removeFromQueue(index)
              }
            }

            Row {
              anchors.fill: parent; anchors.margins: Style.space(4); spacing: Style.space(6)

              Text {
                width: Style.space(18); horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
                text: (index + 1) < 10 ? ("0" + (index + 1)) : String(index + 1)
                color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8
              }

              // Thumbnail
              BorderSurface {
                width: Style.space(24); height: Style.space(24); radius: Style.space(3)
                color: Qt.rgba(0.1, 0.1, 0.14, 0.9); borderSpec: Border.none
                anchors.verticalCenter: parent.verticalCenter

                Image {
                  visible: modelData.thumb !== undefined && modelData.thumb !== ""
                  anchors.fill: parent
                  source: (modelData.thumb && (modelData.thumb.indexOf("http://") === 0 || modelData.thumb.indexOf("https://") === 0 || modelData.thumb.indexOf("file://") === 0)) ? modelData.thumb : (modelData.thumb ? "file://" + modelData.thumb : "")
                  fillMode: Image.PreserveAspectCrop; sourceSize.width: 48; sourceSize.height: 48
                }
                Text {
                  visible: !modelData.thumb
                  anchors.centerIn: parent; text: "\uf001"; color: p.dim
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8
                }
              }

              // Title & Artist
              Column {
                width: parent.width - Style.space(80); anchors.verticalCenter: parent.verticalCenter; spacing: 1

                Text {
                  width: parent.width; textFormat: Text.PlainText
                  text: modelData.title || "Track"
                  color: p.foreground; font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                  elide: Text.ElideRight
                }
                Text {
                  visible: modelData.artist !== ""
                  width: parent.width; textFormat: Text.PlainText
                  text: modelData.artist || ""
                  color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.82
                  elide: Text.ElideRight
                }
              }

              // Remove button
              BorderSurface {
                z: 2
                width: Style.space(20); height: Style.space(20); radius: Style.cornerRadius
                color: qDelMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.25) : "transparent"
                borderSpec: Border.none
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent; text: "\uf00d"
                  color: qDelMouse.containsMouse ? p.urgent : p.dim
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.85
                }
                MouseArea {
                  id: qDelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: p.removeFromQueue(index)
                }
              }
            }
          }
        }
      }

      // ==========================================
      // PLAYLISTS TAB CONTENT
      // ==========================================
      Column {
        visible: p.selectedTab === "playlists"
        width: parent.width
        spacing: Style.space(6)

        // ----------------------------------------------------
        // SUBVIEW 1: ACTIVE PLAYLIST TRACKS BROWSER
        // ----------------------------------------------------
        Column {
          visible: p.activePlaylist !== null
          width: parent.width
          spacing: Style.space(4)

          // Header Card with Back, Title, Play All, Delete
          BorderSurface {
            width: parent.width; implicitHeight: Style.space(32); radius: Style.cornerRadius
            color: Color.popups.background
            borderSpec: Border.controlSpec("normal", p.foreground, Color.accent)

            Row {
              anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(8)

              // Back button
              BorderSurface {
                width: Style.space(22); height: Style.space(20); radius: Style.cornerRadius
                color: backMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                borderSpec: Border.none
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent; text: "\uf060"
                  color: backMouse.containsMouse ? Color.accent : p.foreground
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption
                }
                MouseArea {
                  id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: p.closePlaylist()
                }
              }

              // Title + Count
              Text {
                width: parent.width - Style.space(130)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: (p.activePlaylist ? p.activePlaylist.name : "") + " (" + ((p.activePlaylist && p.activePlaylist.tracks) ? p.activePlaylist.tracks.length : 0) + ")"
                color: Color.accent; font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                elide: Text.ElideRight
              }

              // Play All Button
              BorderSurface {
                implicitHeight: Style.space(20)
                implicitWidth: playAllText.implicitWidth + Style.space(10)
                radius: Style.cornerRadius
                color: playAllMouse.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                borderSpec: Border.none
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  id: playAllText; anchors.centerIn: parent
                  text: "\uf04b Play All"
                  color: playAllMouse.containsMouse ? "#000000" : Color.accent
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.85; font.bold: true
                }
                MouseArea {
                  id: playAllMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: p.playPlaylist(p.activePlaylist)
                }
              }

              // Delete button
              BorderSurface {
                visible: p.activePlaylist && !p.activePlaylist.system
                width: Style.space(20); height: Style.space(20); radius: Style.cornerRadius
                color: delPlMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.25) : "transparent"
                borderSpec: Border.none
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent; text: "\uf1f8"
                  color: delPlMouse.containsMouse ? p.urgent : p.dim
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption
                }
                MouseArea {
                  id: delPlMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: p.deletePlaylist(p.activePlaylist.name)
                }
              }
            }
          }

          // Empty playlist notice
          Text {
            visible: p.activePlaylist && (!p.activePlaylist.tracks || p.activePlaylist.tracks.length === 0)
            text: "No tracks found in this playlist"
            color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter; width: parent.width
          }

          // Individual tracks inside active playlist
          Repeater {
            model: (p.activePlaylist && p.activePlaylist.tracks) ? p.activePlaylist.tracks : []
            delegate: BorderSurface {
              id: plTrackRow
              readonly property bool isCurrent: (p.activePlaylist && p.currentPlaylistName === p.activePlaylist.name && p.currentPlaylistIndex === index) || root.isTrackCurrent(modelData.url, modelData.title, modelData.artist)
              width: parent.width; implicitHeight: Style.space(28); radius: Style.cornerRadius
              color: isCurrent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : (plTrackRowMouse.containsMouse ? Style.hoverFillFor(p.foreground, Color.accent) : "transparent")
              borderSpec: isCurrent ? Border.flat(Color.accent, 1) : Border.none

              MouseArea {
                id: plTrackRowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (p.activePlaylist) {
                    p.playPlaylistTrack(p.activePlaylist, index)
                  } else {
                    p.playUrl(modelData.url, modelData.title, modelData.artist)
                  }
                }
              }

              Row {
                anchors.fill: parent; anchors.margins: Style.space(4); spacing: Style.space(6)

                // Track Number
                Text {
                  width: Style.space(18); horizontalAlignment: Text.AlignRight
                  anchors.verticalCenter: parent.verticalCenter
                  text: (index + 1) < 10 ? ("0" + (index + 1)) : String(index + 1)
                  color: plTrackRow.isCurrent ? Color.accent : p.dim
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8
                }

                // Play icon
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: plTrackRow.isCurrent && p.isPlaying ? "\uf04c" : "\uf04b"
                  color: plTrackRow.isCurrent ? Color.accent : (plTrackRowMouse.containsMouse ? Color.accent : p.dim)
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8
                }

                // Title & Artist
                Column {
                  width: parent.width - Style.space(90); anchors.verticalCenter: parent.verticalCenter; spacing: 1
                  Text {
                    width: parent.width; textFormat: Text.PlainText
                    text: modelData.title || "Track"
                    color: plTrackRow.isCurrent ? Color.accent : p.foreground
                    font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                    elide: Text.ElideRight
                  }
                  Text {
                    visible: modelData.artist !== ""
                    width: parent.width; textFormat: Text.PlainText
                    text: modelData.artist || ""
                    color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8
                    elide: Text.ElideRight
                  }
                }

                // Add to Queue Button
                Text {
                  z: 2
                  anchors.verticalCenter: parent.verticalCenter
                  text: "\uf067"
                  color: plQueueMouse.containsMouse ? Color.accent : p.dim
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption
                  MouseArea {
                    id: plQueueMouse
                    anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: p.queueUrl(modelData.url, modelData.title, modelData.artist)
                  }
                }

                // Duration
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.duration || ""
                  color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption
                }
              }
            }
          }
        }

        // ----------------------------------------------------
        // SUBVIEW 2: PLAYLISTS OVERVIEW & IMPORT BAR
        // ----------------------------------------------------
        Column {
          visible: p.activePlaylist === null
          width: parent.width
          spacing: Style.space(4)

          // Importing status banner
          BorderSurface {
            visible: p.isImportingPl
            width: parent.width; implicitHeight: Style.space(28); radius: Style.cornerRadius
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
            borderSpec: Border.flat(Color.accent, 1)

            Row {
              anchors.centerIn: parent; spacing: Style.space(6)
              Text { anchors.verticalCenter: parent.verticalCenter; text: "\uf110"; color: Color.accent; font.family: p.fontFamily; font.pixelSize: Style.font.caption; RotationAnimator on rotation { running: p.isImportingPl; from: 0; to: 360; duration: 1000; loops: Animation.Infinite } }
              Text { anchors.verticalCenter: parent.verticalCenter; text: "Importing playlist tracks..."; color: p.foreground; font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
            }
          }

          // Import error notice
          Text {
            visible: p.plImportError !== ""
            text: p.plImportError
            color: p.urgent; font.family: p.fontFamily; font.pixelSize: Style.font.caption
          }

          // List of Playlists
          Repeater {
            model: p.playlistsList
            delegate: BorderSurface {
              id: plCard
              width: parent.width; implicitHeight: Style.space(34); radius: Style.cornerRadius
              color: plCardMouse.containsMouse ? Style.hoverFillFor(p.foreground, Color.accent) : Color.popups.background
              borderSpec: Border.controlSpec("normal", p.foreground, Color.accent)

              // Main row click opens playlist
              MouseArea {
                id: plCardMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: p.openPlaylist(modelData)
              }

              Row {
                anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.system ? "\uf017" : "\uf0ca"
                  color: Color.accent; font.family: p.fontFamily; font.pixelSize: Style.font.caption
                }

                Column {
                  width: parent.width - Style.space(90); anchors.verticalCenter: parent.verticalCenter; spacing: 1
                  Text {
                    width: parent.width; textFormat: Text.PlainText
                    text: modelData.name || "Playlist"
                    color: p.foreground; font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                    elide: Text.ElideRight
                  }
                  Text {
                    text: modelData.count + " tracks"
                    color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.85
                  }
                }

                // Quick Play All button
                BorderSurface {
                  z: 2
                  width: Style.space(22); height: Style.space(22); radius: Style.cornerRadius
                  color: plPlayMouse.containsMouse ? Color.accent : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
                  borderSpec: Border.none
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    anchors.centerIn: parent; text: "\uf04b"
                    color: plPlayMouse.containsMouse ? "#000000" : Color.accent
                    font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8
                  }
                  MouseArea {
                    id: plPlayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (modelData.system) {
                        p.openPlaylist(modelData)
                        p.playPlaylist(p.activePlaylist)
                      } else {
                        p.playPlaylist(modelData)
                      }
                    }
                  }
                }

                // Delete playlist button
                BorderSurface {
                  z: 2
                  visible: !modelData.system
                  width: Style.space(22); height: Style.space(22); radius: Style.cornerRadius
                  color: plDelMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.25) : "transparent"
                  borderSpec: Border.none
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    anchors.centerIn: parent; text: "\uf1f8"
                    color: plDelMouse.containsMouse ? p.urgent : p.dim
                    font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.85
                  }
                  MouseArea {
                    id: plDelMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: p.deletePlaylist(modelData.name)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
