// Pulse — vis_pulse.go: per-angle band energy, solid fill, shockwave
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, frame = d.frame
  var pcx = w / 2, pcy = h / 2
  var xScale = pcy / Math.max(1, pcx)
  var maxR = pcy - 1
  var total = 0
  for (var i = 0; i < count; i++) total += (bands[i] || 0)
  var avg = total / count
  // Shockwave
  var shockPhase = (frame * 0.10) % 1.0
  var shockR = maxR * (0.3 + 0.7 * shockPhase)
  var shockStrength = avg * avg * (1.0 - shockPhase * shockPhase)
  var breath = Math.sin(frame * 0.05) * 0.02
  var rotOffset = frame * (0.015 + avg * 0.04)
  var twoPi = 2 * Math.PI
  var bandScale = count / twoPi
  for (var py = 0; py < h; py += 2) {
    for (var px = 0; px < w; px += 2) {
      var pdx = (px - pcx) * xScale, pdy = py - pcy
      var pdist = Math.sqrt(pdx * pdx + pdy * pdy)
      if (pdist > maxR + 2) continue
      var angle = Math.atan2(pdy, pdx)
      if (angle < 0) angle += twoPi
      angle += rotOffset
      angle -= Math.floor(angle / twoPi) * twoPi
      var bandPos = angle * bandScale
      var bandIdx = Math.floor(bandPos) % count
      var nextBand = (bandIdx + 1) % count
      var frac = bandPos - Math.floor(bandPos)
      var t = (1 - Math.cos(frac * Math.PI)) / 2
      var energy = (bands[bandIdx] || 0) * (1 - t) + (bands[nextBand] || 0) * t
      var blended = energy * 0.6 + avg * 0.4
      var punch = blended * blended
      var r = maxR * (0.08 + breath + 0.92 * punch)
      var lit = false
      if (r > 0.5 && pdist <= r) lit = true
      else if (r > 0.5 && pdist < r + 1.5) {
        var edgeFade = 1.0 - (pdist - r) / 1.5
        if (H.scatterHash(bandIdx, py, px, frame) < edgeFade * 0.7) lit = true
      }
      if (shockStrength > 0.05) {
        var sd = Math.abs(pdist - shockR)
        var st = 0.6 + shockStrength * 1.5
        if (sd < st && (1.0 - sd / st) > 0.4) lit = true
      }
      if (lit) {
        var norm = pdist / Math.max(1, maxR)
        ctx.fillStyle = norm < 0.3 ? "rgba(0,255,100,0.8)" : norm < 0.6 ? "rgba(255,200,0,0.7)" : "rgba(255,50,50,0.6)"
        ctx.fillRect(px, py, 2, 2)
      }
    }
  }
}
