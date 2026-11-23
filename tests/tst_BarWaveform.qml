import QtQuick
import QtTest
import ".." as Omaramp

Rectangle {
  width: 56; height: 26; color: "black"
  QtObject {
    id: track
    property bool isPlaying: false
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
    width: 48; height: 18; anchors.centerIn: parent
    foreground: "white"
  }
  TestCase {
    name: "BarWaveform"
    when: windowShown

    function litWidth(image) {
      var columns = 0
      for (var x = 0; x < image.width; ++x) {
        for (var y = 0; y < image.height; ++y) {
          if (Math.max(image.red(x,y), image.green(x,y), image.blue(x,y)) > 80) {
            ++columns
            break
          }
        }
      }
      return columns
    }

    function test_visibleAcrossPlaybackStates() {
      // Assert on actual pixels, including before the lazy player exists.
      tryVerify(() => litWidth(grabImage(icon)) >= 20)
      var resting = grabImage(icon)
      icon.player = track
      track.isPlaying = true
      track.visActive = true
      ++track.visFrame
      tryVerify(() => { var im = grabImage(icon); return !im.equals(resting) && litWidth(im) >= 20 })
      var quiet = grabImage(icon)
      track.visBands = Array(24).fill(0.95)
      ++track.visFrame
      tryVerify(() => !grabImage(icon).equals(quiet), 1500, 'the selected waveform changes with the audio')
      var loud = grabImage(icon)
      track.visMode = 'bars'
      tryVerify(() => { var im = grabImage(icon); return !im.equals(loud) && litWidth(im) >= 20 })
      track.visActive = false
      tryVerify(() => grabImage(icon).equals(resting))
      track.isPlaying = false
      compare(grabImage(icon).equals(resting), true)
    }
  }
}
