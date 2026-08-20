// Peaks — vis_classic_peak.go: physics-based falling caps
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, barW = d.barW, gap = d.gap
  var s = d.state
  if (!s.peakPos || s.peakPos.length !== count) {
    s.peakPos = new Array(count).fill(0)
    s.peakVel = new Array(count).fill(0)
    s.peakHold = new Array(count).fill(0)
  }
  var peakPos = s.peakPos, peakVel = s.peakVel, peakHold = s.peakHold
  var dt = 0.016, gravity = 9.5, launchBase = 0.8, launchGain = 1.4, launchMax = 1.7, apexHold = 0.08
  for (var p = 0; p < count; p++) {
    var px = p * (barW + gap)
    var level = d.playing ? (bands[p] || 0) : 0
    if (peakVel[p] === 0 && peakPos[p] <= level + 0.01) {
      if (level > peakPos[p]) {
        var delta = level - peakPos[p]
        peakPos[p] = level
        peakVel[p] = Math.min(launchMax, launchBase + launchGain * delta)
        peakHold[p] = 0
      }
    }
    if (peakHold[p] > 0) {
      peakHold[p] = Math.max(0, peakHold[p] - dt)
    } else {
      var prevVel = peakVel[p]
      peakPos[p] += peakVel[p] * dt
      peakVel[p] -= gravity * dt
      if (peakPos[p] > 1.0) peakPos[p] = 1.0
      if (prevVel > 0 && peakVel[p] <= 0 && peakPos[p] > level + 0.01) {
        peakVel[p] = 0
        peakHold[p] = apexHold
      }
      if (peakPos[p] <= level) {
        peakPos[p] = level
        peakVel[p] = 0
        peakHold[p] = 0
      }
    }
    var barH = Math.round(level * h)
    for (var y = 0; y < barH; y++) {
      ctx.fillStyle = H.specColor(y / h)
      ctx.fillRect(px, h - 1 - y, barW, 1)
    }
    if (peakPos[p] > level + 0.01) {
      var peakY = h - Math.round(peakPos[p] * h)
      ctx.fillStyle = "#ffffff"
      ctx.fillRect(px, peakY, barW, 2)
    }
  }
}
