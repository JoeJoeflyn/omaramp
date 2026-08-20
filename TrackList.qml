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

  // Tabs + Daemon Power
  Row {
    width: parent.width; spacing: Style.space(6)

    Button {
      visible: p.selectedTab === "search" || p.searchResults.length > 0 || p.isSearching
      text: "Search (" + p.searchResults.length + ")"
      fontFamily: p.fontFamily; fontSize: Style.font.caption; bordered: false
      foreground: p.selectedTab === "search" ? Color.accent : p.dim; accent: Color.accent
      onClicked: p.selectedTab = "search"
    }

    Button {
      text: "Recents (" + p.historyList.length + ")"
      fontFamily: p.fontFamily; fontSize: Style.font.caption; bordered: false
      foreground: p.selectedTab === "history" ? Color.accent : p.dim; accent: Color.accent
      onClicked: { p.selectedTab = "history"; p.loadHistory() }
    }

    Button {
      text: "Playlists (" + p.playlistsList.length + ")"
      fontFamily: p.fontFamily; fontSize: Style.font.caption; bordered: false
      foreground: p.selectedTab === "playlists" ? Color.accent : p.dim; accent: Color.accent
      onClicked: { p.selectedTab = "playlists"; p.loadPlaylists() }
    }

    Item { width: Style.space(8) }

    PanelActionButton {
      iconText: "\uf011"
      tooltipText: p.isRunning ? "Stop background daemon" : "Daemon idle"
      foreground: p.isRunning ? p.foreground : p.dim
      hoverColor: p.urgent; fontFamily: p.fontFamily
      onClicked: { if (p.isRunning) p.stopDaemon(); else p.play() }
    }
  }

  // Track List Scroller
  Flickable {
    width: parent.width; implicitHeight: Style.space(160)
    contentWidth: width; contentHeight: listCol.implicitHeight
    clip: true; boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: listCol
      width: parent.width; spacing: Style.space(2)

      // Searching indicator
      Item {
        visible: p.selectedTab === "search" && p.isSearching
        width: parent.width; implicitHeight: Style.space(40)
        Row {
          anchors.centerIn: parent; spacing: Style.space(8)
          Text { anchors.verticalCenter: parent.verticalCenter; text: "\uf110"; color: Color.accent; font.family: p.fontFamily; font.pixelSize: Style.font.bodySmall }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "Searching for \"" + p.searchQuery + "\"..."; color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption }
        }
      }

      // No results
      Item {
        visible: p.selectedTab === "search" && !p.isSearching && p.searchResults.length === 0 && p.searchQuery !== ""
        width: parent.width; implicitHeight: Style.space(40)
        Text { anchors.centerIn: parent; text: "No tracks found for \"" + p.searchQuery + "\""; color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption }
      }

      // Search Results
      Repeater {
        model: p.selectedTab === "search" && !p.isSearching ? p.searchResults : []
        delegate: BorderSurface {
          id: searchRow
          readonly property bool isCurrent: (p.currentUrl === modelData.url) || (p.currentTrack === modelData.title && p.currentTrack !== "No track loaded")
          width: parent.width; implicitHeight: Style.space(34); radius: Style.cornerRadius
          color: isCurrent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : (searchMouse.containsMouse ? Style.hoverFillFor(p.foreground, Color.accent) : "transparent")
          borderSpec: isCurrent ? Border.flat(Color.accent, 1) : Border.none

          Row {
            width: parent.width - Style.space(10); anchors.centerIn: parent; spacing: Style.space(8)

            // Rounded thumbnail
            BorderSurface {
              width: Style.space(26); height: Style.space(26); radius: Style.space(3)
              color: Qt.rgba(0.1, 0.1, 0.14, 0.9)
              borderSpec: Border.none
              anchors.verticalCenter: parent.verticalCenter

              Image {
                visible: modelData.thumb !== undefined && modelData.thumb !== ""
                anchors.fill: parent
                source: modelData.thumb ? "file://" + modelData.thumb : ""
                fillMode: Image.PreserveAspectCrop; sourceSize.width: 52; sourceSize.height: 52
              }

              Text {
                visible: !modelData.thumb
                anchors.centerIn: parent
                text: "\uf001"; color: searchRow.isCurrent ? Color.accent : p.dim
                font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8
              }
            }

            // Play / Loading icon
            Text {
              visible: p.loadingVid === modelData.url
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf110"; color: Color.accent
              font.family: p.fontFamily; font.pixelSize: Style.font.caption
              RotationAnimator on rotation { running: visible; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
            }

            Text {
              visible: p.loadingVid !== modelData.url
              anchors.verticalCenter: parent.verticalCenter
              text: searchRow.isCurrent && p.isPlaying ? "\uf04c" : "\uf04b"
              color: searchRow.isCurrent ? Color.accent : (searchMouse.containsMouse ? Color.accent : p.dim)
              font.family: p.fontFamily; font.pixelSize: Style.font.caption
            }

            // Title & Artist
            Column {
              width: parent.width - Style.space(80)
              anchors.verticalCenter: parent.verticalCenter; spacing: 1

              Text {
                width: parent.width; textFormat: Text.PlainText
                text: modelData.title || "Track"
                color: searchRow.isCurrent ? Color.accent : p.foreground
                font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width; textFormat: Text.PlainText
                text: modelData.artist || "Unknown Artist"
                color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.85
                elide: Text.ElideRight
                visible: modelData.artist !== ""
              }
            }

            // Duration
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.duration || ""
              color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption
            }
          }

          MouseArea {
            id: searchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { if (modelData.url) p.playUrl(modelData.url, modelData.title, modelData.artist) }
          }
        }
      }

      // Recently Played
      Repeater {
        model: p.selectedTab === "history" ? p.historyList : []
        delegate: BorderSurface {
          id: trackRow
          readonly property bool isCurrent: (p.currentUrl === modelData.path) || (p.currentTrack === modelData.title && p.currentTrack !== "No track loaded")
          width: parent.width; implicitHeight: Style.space(34); radius: Style.cornerRadius
          color: isCurrent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : (trackMouse.containsMouse ? Style.hoverFillFor(p.foreground, Color.accent) : "transparent")
          borderSpec: isCurrent ? Border.flat(Color.accent, 1) : Border.none

          Row {
            width: parent.width - Style.space(10); anchors.centerIn: parent; spacing: Style.space(8)

            // Rounded thumbnail
            BorderSurface {
              width: Style.space(26); height: Style.space(26); radius: Style.space(3)
              color: Qt.rgba(0.1, 0.1, 0.14, 0.9)
              borderSpec: Border.none
              anchors.verticalCenter: parent.verticalCenter

              Image {
                visible: modelData.thumb !== undefined && modelData.thumb !== ""
                anchors.fill: parent
                source: modelData.thumb ? "file://" + modelData.thumb : ""
                fillMode: Image.PreserveAspectCrop; sourceSize.width: 52; sourceSize.height: 52
              }

              Text {
                visible: !modelData.thumb
                anchors.centerIn: parent
                text: "\uf001"; color: trackRow.isCurrent ? Color.accent : p.dim
                font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8
              }
            }

            // Play / Status Icon
            Text {
              visible: p.loadingVid === modelData.path
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf110"; color: Color.accent
              font.family: p.fontFamily; font.pixelSize: Style.font.caption
              RotationAnimator on rotation { running: visible; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
            }

            Text {
              visible: p.loadingVid !== modelData.path
              anchors.verticalCenter: parent.verticalCenter
              text: trackRow.isCurrent && p.isPlaying ? "\uf04c" : "\uf04b"
              color: trackRow.isCurrent ? Color.accent : (trackMouse.containsMouse ? Color.accent : p.dim)
              font.family: p.fontFamily; font.pixelSize: Style.font.caption
            }

            // Title & Artist
            Column {
              width: parent.width - Style.space(80)
              anchors.verticalCenter: parent.verticalCenter; spacing: 1

              Text {
                width: parent.width; textFormat: Text.PlainText
                text: modelData.title || "Track"
                color: trackRow.isCurrent ? Color.accent : p.foreground
                font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width; textFormat: Text.PlainText
                text: modelData.artist || "Unknown Artist"
                color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.85
                elide: Text.ElideRight
                visible: modelData.artist !== ""
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

          MouseArea {
            id: trackMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { if (modelData.path) p.playUrl(modelData.path, modelData.title, modelData.artist) }
          }
        }
      }

      // Playlists Tab
      Column {
        visible: p.selectedTab === "playlists"
        width: parent.width
        spacing: Style.space(6)

        // Sub-view: Active Playlist Tracks Browser
        Column {
          visible: p.activePlaylist !== null
          width: parent.width
          spacing: Style.space(6)

          // Header with Back, Title, Play All, Delete
          BorderSurface {
            width: parent.width; implicitHeight: Style.space(32); radius: Style.cornerRadius
            color: Color.popups.background
            borderSpec: Border.controlSpec("normal", p.foreground, Color.accent)

            Row {
              anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(6)

              // Back button
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf060"
                color: backMouse.containsMouse ? Color.accent : p.foreground
                font.family: p.fontFamily; font.pixelSize: Style.font.caption
                MouseArea {
                  id: backMouse; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: p.closePlaylist()
                }
              }

              // Playlist title + count
              Text {
                width: parent.width - Style.space(110); anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: (p.activePlaylist ? p.activePlaylist.name : "") + " (" + ((p.activePlaylist && p.activePlaylist.tracks) ? p.activePlaylist.tracks.length : 0) + ")"
                color: Color.accent; font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                elide: Text.ElideRight
              }

              // Play All Button
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf04b Play"
                color: playAllMouse.containsMouse ? Color.accent : p.foreground
                font.family: p.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
                MouseArea {
                  id: playAllMouse; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: p.playPlaylist(p.activePlaylist)
                }
              }

              // Delete button (custom playlists only)
              Text {
                visible: p.activePlaylist && !p.activePlaylist.system
                anchors.verticalCenter: parent.verticalCenter
                text: "\uf1f8"
                color: delPlMouse.containsMouse ? p.urgent : p.dim
                font.family: p.fontFamily; font.pixelSize: Style.font.caption
                MouseArea {
                  id: delPlMouse; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: p.deletePlaylist(p.activePlaylist.name)
                }
              }
            }
          }

          // Empty state for active playlist
          Text {
            visible: p.activePlaylist && (!p.activePlaylist.tracks || p.activePlaylist.tracks.length === 0)
            text: "No tracks in this playlist"
            color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
          }

          // Active playlist track items
          Repeater {
            model: (p.activePlaylist && p.activePlaylist.tracks) ? p.activePlaylist.tracks : []
            delegate: BorderSurface {
              id: plTrackRow
              readonly property bool isCurrent: (p.currentUrl === modelData.url) || (p.currentTrack === modelData.title && p.currentTrack !== "No track loaded")
              width: parent.width; implicitHeight: Style.space(28); radius: Style.cornerRadius
              color: isCurrent ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12) : (plTrackMouse.containsMouse ? Style.hoverFillFor(p.foreground, Color.accent) : "transparent")
              borderSpec: isCurrent ? Border.flat(Color.accent, 1) : Border.none

              Row {
                width: parent.width - Style.space(8); anchors.centerIn: parent; spacing: Style.space(6)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: plTrackRow.isCurrent && p.isPlaying ? "\uf04c" : "\uf04b"
                  color: plTrackRow.isCurrent ? Color.accent : (plTrackMouse.containsMouse ? Color.accent : p.dim)
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption * 0.8
                }

                Column {
                  width: parent.width - Style.space(80); anchors.verticalCenter: parent.verticalCenter; spacing: 1
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

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.duration || ""
                  color: p.dim; font.family: p.fontFamily; font.pixelSize: Style.font.caption
                }
              }

              MouseArea {
                id: plTrackMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: p.playUrl(modelData.url, modelData.title, modelData.artist)
              }
            }
          }
        }

        // Sub-view: Playlists List & Import Bar
        Column {
          visible: p.activePlaylist === null
          width: parent.width
          spacing: Style.space(6)

          // Importing loader
          Row {
            visible: p.isImportingPl
            width: parent.width; spacing: Style.space(6)
            Text { anchors.verticalCenter: parent.verticalCenter; text: "\uf110"; color: Color.accent; font.family: p.fontFamily; font.pixelSize: Style.font.caption; RotationAnimator on rotation { running: p.isImportingPl; from: 0; to: 360; duration: 1000; loops: Animation.Infinite } }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Importing playlist tracks..."; color: p.foreground; font.family: p.fontFamily; font.pixelSize: Style.font.caption }
          }

          // Import error
          Text {
            visible: p.plImportError !== ""
            text: p.plImportError
            color: p.urgent; font.family: p.fontFamily; font.pixelSize: Style.font.caption
          }

          // Playlist cards
          Repeater {
            model: p.playlistsList
            delegate: BorderSurface {
              id: plRow
              width: parent.width; implicitHeight: Style.space(32); radius: Style.cornerRadius
              color: plMouse.containsMouse ? Style.hoverFillFor(p.foreground, Color.accent) : Color.popups.background
              borderSpec: Border.controlSpec("normal", p.foreground, Color.accent)

              Row {
                width: parent.width - Style.space(12); anchors.centerIn: parent; spacing: Style.space(8)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.system ? "\uf017" : "\uf0ca"
                  color: Color.accent; font.family: p.fontFamily; font.pixelSize: Style.font.caption
                }

                Column {
                  width: parent.width - Style.space(80); anchors.verticalCenter: parent.verticalCenter; spacing: 1
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
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "\uf04b"
                  color: plPlayMouse.containsMouse ? Color.accent : p.dim
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption
                  MouseArea {
                    id: plPlayMouse; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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

                // Delete button
                Text {
                  visible: !modelData.system
                  anchors.verticalCenter: parent.verticalCenter
                  text: "\uf1f8"
                  color: plDelMouse.containsMouse ? p.urgent : p.dim
                  font.family: p.fontFamily; font.pixelSize: Style.font.caption
                  MouseArea {
                    id: plDelMouse; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: p.deletePlaylist(modelData.name)
                  }
                }
              }

              MouseArea {
                id: plMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: p.openPlaylist(modelData)
              }
            }
          }
        }
      }
    }
  }
}
