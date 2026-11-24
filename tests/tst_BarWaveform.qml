import QtQuick
import QtTest
import ".." as Omaramp

Rectangle {
  width: 27; height: 26; color: "black"
  QtObject {
    id: track
    property string playbackState: "stopped"
    readonly property bool isPlaying: playbackState === "playing"
    property bool visActive: false
    property string visMode: "telegram_wave"
    property int visFrame: 0
    property var visBands: Array(24).fill(0.15)
    property var visWave: []
    property var visLR: [0.2, 0.2]
    property color foreground: "white"
    property color dim: "gray"
    property color dynamicAccent: "orange"
    property real progress: 0.5
  }
  Omaramp.BarWaveform {
    id: icon
    width: parent.width - 8; height: 18; anchors.centerIn: parent
    foreground: "white"
  }
  TestCase {
    name: "BarWaveform"
    when: windowShown

    function litColumns(image) {
      var columns = []
      for (var x = 0; x < image.width; ++x) {
        for (var y = 0; y < image.height; ++y) {
          if (Math.max(image.red(x,y), image.green(x,y), image.blue(x,y)) > 80) {
            columns.push(x)
            break
          }
        }
      }
      return columns
    }

    function test_visibleAcrossPlaybackStates() {
      // Assert on actual pixels, including before the lazy player exists.
      tryVerify(() => {
        var columns = litColumns(grabImage(icon))
        return columns.filter((x, i) => i === 0 || x > columns[i - 1] + 1).length === 4
      }, 1500, 'startup shows four bars, not a wide placeholder')
      var resting = grabImage(icon)
      var showsLive = () => {
        var im = grabImage(icon)
        return !im.equals(resting) && litColumns(im).length >= im.width / 2
      }
      icon.player = track
      track.playbackState = "buffering"
      tryVerify(() => grabImage(icon).equals(resting))
      track.playbackState = "playing"
      track.visActive = true
      ++track.visFrame
      tryVerify(showsLive)
      var quiet = grabImage(icon)
      track.visBands = Array(24).fill(0.95)
      ++track.visFrame
      tryVerify(() => !grabImage(icon).equals(quiet), 1500, 'the selected waveform changes with the audio')
      var loud = grabImage(icon)
      track.visMode = 'bars'
      tryVerify(() => !grabImage(icon).equals(loud) && showsLive())
      track.visActive = false
      tryVerify(() => grabImage(icon).equals(resting))
      track.visActive = true
      ++track.visFrame
      tryVerify(showsLive)
      track.playbackState = "paused"
      tryVerify(() => grabImage(icon).equals(resting))
      track.playbackState = "playing"
      ++track.visFrame
      tryVerify(showsLive)
      // Stop even if the last spectrum frame still exists.
      track.playbackState = "stopped"
      tryVerify(() => grabImage(icon).equals(resting))
    }
  }
}
