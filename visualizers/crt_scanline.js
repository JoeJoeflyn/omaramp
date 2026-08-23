// CRT Retro Vector Terminal — Authentic radar oscilloscope with 2D Lissajous vector scope & scanlines
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var wave = d.wave || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var cx = w / 2.0, cy = h / 2.0

  var bass = H.bandAvg(bands, 0, 5)
  var mids = H.bandAvg(bands, 5, 14)
  var highs = H.bandAvg(bands, 14, 24)
  var totalEnergy = bass * 0.5 + mids * 0.35 + highs * 0.15
  var beatDrop = d.beatDrop || 0

  var ar = (d.accent && d.accent.r !== undefined) ? d.accent.r : 0.0
  var ag = (d.accent && d.accent.g !== undefined) ? d.accent.g : 0.9
  var ab = (d.accent && d.accent.b !== undefined) ? d.accent.b : 0.4
  var cr = Math.round(ar * 255), cg = Math.round(ag * 255), cb = Math.round(ab * 255)

  // 1. CRT Raster Scanlines
  ctx.fillStyle = "rgba(0, 0, 0, 0.35)"
  for (var sy = 0; sy < h; sy += 2) {
    ctx.fillRect(0, sy, w, 1)
  }

  // 2. CRT Radar Vector Crosshairs (Safe radius strictly inside box)
  var scopeRadius = Math.min(w * 0.28, h * 0.38)
  ctx.strokeStyle = "rgba(" + cr + "," + cg + "," + cb + ", 0.20)"
  ctx.lineWidth = 1.0

  ctx.beginPath()
  ctx.arc(cx, cy, scopeRadius, 0, Math.PI * 2)
  ctx.arc(cx, cy, scopeRadius * 0.5, 0, Math.PI * 2)
  ctx.stroke()

  ctx.beginPath()
  ctx.moveTo(cx - scopeRadius - 8, cy)
  ctx.lineTo(cx + scopeRadius + 8, cy)
  ctx.moveTo(cx, cy - scopeRadius - 5)
  ctx.lineTo(cx, cy + scopeRadius + 5)
  ctx.stroke()

  if (!isPlaying || totalEnergy < 0.005) {
    var flick = 0.30 + Math.sin(frame * 0.15) * 0.05
    ctx.fillStyle = "rgba(255, 255, 255, " + flick.toFixed(2) + ")"
    ctx.beginPath()
    ctx.arc(cx, cy, 2.5, 0, Math.PI * 2)
    ctx.fill()
    return
  }

  // 3. Central 2D Lissajous XY Vector Beam (Real Waveform Tracking)
  var numPoints = 64
  var points = []
  var waveLen = wave.length
  var phase = frame * (0.02 + totalEnergy * 0.03)

  for (var i = 0; i <= numPoints; i++) {
    var theta = (i / numPoints) * Math.PI * 2.0
    var waveValX = 0.0, waveValY = 0.0

    if (waveLen > 0) {
      var idxX = Math.floor((i / numPoints) * (waveLen - 1))
      var idxY = (idxX + Math.floor(waveLen / 4)) % waveLen
      waveValX = wave[idxX] || 0.0
      waveValY = wave[idxY] || 0.0
    } else {
      var bIdx = Math.min(bands.length - 1, Math.floor((i / numPoints) * (bands.length - 1)))
      var bAmp = bands[bIdx] || 0.0
      waveValX = Math.sin(theta * 2.0 + phase) * bAmp
      waveValY = Math.cos(theta * 1.5 - phase * 0.8) * bAmp
    }

    var rDeflect = scopeRadius * (0.60 + bass * 0.30 + beatDrop * 0.20)
    var px = cx + Math.cos(theta) * rDeflect + (waveValX * (scopeRadius * 0.40))
    var py = cy + Math.sin(theta) * (rDeflect * 0.80) + (waveValY * (scopeRadius * 0.35))
    points.push({ x: px, y: py })
  }

  // Phosphor Bloom Halo
  ctx.strokeStyle = "rgba(" + cr + "," + cg + "," + cb + ", 0.25)"
  ctx.lineWidth = 4.0
  ctx.beginPath()
  for (var p = 0; p < points.length; p++) {
    if (p === 0) ctx.moveTo(points[p].x, points[p].y)
    else ctx.lineTo(points[p].x, points[p].y)
  }
  ctx.stroke()

  // Core Vector Beam
  ctx.strokeStyle = "rgba(255, 255, 255, 0.95)"
  ctx.lineWidth = 1.3
  ctx.beginPath()
  for (var p = 0; p < points.length; p++) {
    if (p === 0) ctx.moveTo(points[p].x, points[p].y)
    else ctx.lineTo(points[p].x, points[p].y)
  }
  ctx.stroke()

  // 4. Side Vector Spectrum Meters
  var meterBars = 6
  var barW = 3
  for (var side = -1; side <= 1; side += 2) {
    var startX = side === -1 ? 16 : w - 16 - (meterBars * 6)
    for (var b = 0; b < meterBars; b++) {
      var bVal = bands[b * 3] || 0.0
      var barH = Math.max(2, Math.floor(bVal * (h * 0.55)))
      var bx = startX + b * 6
      var by = cy - (barH / 2)

      ctx.fillStyle = "rgba(" + cr + "," + cg + "," + cb + ", " + (0.35 + bVal * 0.55).toFixed(2) + ")"
      ctx.fillRect(bx, by, barW, barH)

      ctx.fillStyle = "rgba(255, 255, 255, 0.85)"
      ctx.fillRect(bx, by, barW, 1)
      ctx.fillRect(bx, by + barH - 1, barW, 1)
    }
  }
}
