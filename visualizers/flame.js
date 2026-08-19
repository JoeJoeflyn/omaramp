// Flame — vis_flame.go: doom-fire heat propagation
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, frame = d.frame
  var fRows = Math.floor(h / 2)
  var fCols = Math.floor(w / 4)
  var s = d.state
  if (!s.flameHeat || s.flameHeat.length !== fRows * fCols) {
    s.flameHeat = new Array(fRows * fCols).fill(0)
    s.flameRng = 0xF1A3C0DE
  }
  var heat = s.flameHeat
  var rngVal = s.flameRng

  // Source (bottom) row: per-column heat from spectrum + sparkle
  for (var fx = 0; fx < fCols; fx++) {
    var pos = fx / Math.max(1, fCols - 1) * (count - 1)
    var bi = Math.floor(pos)
    var frac = pos - bi
    var src = (bands[bi] || 0) * (1 - frac) + (bands[Math.min(bi+1, count-1)] || 0) * frac
    rngVal = (rngVal * 1664525 + 1013904223) & 0xFFFFFFFF
    var sparkle = ((rngVal >> 16) % 100) / 100.0 * 0.18
    var base = 0.30 + 0.70 * src + sparkle
    if (base > 1.05) base = 1.05
    heat[fx] = base
  }

  // Propagate heat upward with wind jitter + decay
  for (var fy = fRows - 1; fy >= 1; fy--) {
    var hf = fy / Math.max(1, fRows - 1)
    var decayBase = 0.010 + 0.028 * hf
    for (var fx2 = 0; fx2 < fCols; fx2++) {
      rngVal = (rngVal * 1664525 + 1013904223) & 0xFFFFFFFF
      var offset = ((rngVal >> 16) % 3) - 1
      var decayJitter = ((rngVal >> 24) % 100) / 100.0 * 0.018
      var sourceX = Math.max(0, Math.min(fCols - 1, fx2 + offset))
      var next = heat[(fy - 1) * fCols + sourceX] - decayBase - decayJitter
      heat[fy * fCols + fx2] = Math.max(0, next)
    }
  }
  s.flameRng = rngVal

  // Render: yellow core, red body, stippled tips
  for (var ry = 0; ry < fRows; ry++) {
    for (var rx = 0; rx < fCols; rx++) {
      var v = heat[ry * fCols + rx]
      if (v < 0.10) continue
      if (v < 0.25 && H.scatterHash(0, ry, rx, frame) > v * 4) continue
      var py = h - 1 - ry * 2
      var px = rx * 4
      ctx.fillStyle = v >= 0.55 ? "#ffaa00" : "#ff3300"
      ctx.fillRect(px, py - 1, 4, 2)
    }
  }
}
