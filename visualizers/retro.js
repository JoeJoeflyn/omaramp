// Retro — vis_retro.go: 80s synthwave (sun + perspective grid + band wave)
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, w = d.width, h = d.height, count = d.count, frame = d.frame
  var horizon = h * 0.4
  var cx = w / 2.0

  // Striped sun semicircle
  var sunR = horizon * 0.85
  ctx.fillStyle = "#ffaa00"
  for (var sy = 0; sy < horizon; sy++) {
    var rowDist = horizon - sy
    if (rowDist > sunR) continue
    var halfW = Math.sqrt(sunR * sunR - rowDist * rowDist)
    if (rowDist < sunR * 0.5) {
      var sw = Math.max(1, Math.floor(sunR * 0.15))
      if (Math.floor(rowDist / sw) % 2 === 1) continue
    }
    ctx.fillRect(cx - halfW, sy, halfW * 2, 1)
  }

  // Perspective grid — vertical lines converging to vanishing point
  ctx.strokeStyle = "rgba(255, 0, 200, 0.3)"
  ctx.lineWidth = 1
  var numV = 18
  for (var vi = 0; vi <= numV; vi++) {
    ctx.beginPath()
    ctx.moveTo(cx, horizon)
    ctx.lineTo(vi * w / numV, h)
    ctx.stroke()
  }
  // Horizontal lines scrolling toward viewer
  var scroll = (frame * 0.08) % 1.0
  var numH = 10
  for (var hi = 0; hi < numH; hi++) {
    var z = (hi + scroll) / numH
    if (z > 1.0) z -= 1.0
    var hy = horizon + 1 + z * z * (h - horizon - 2)
    if (hy > horizon && hy < h) {
      ctx.beginPath()
      ctx.moveTo(0, hy)
      ctx.lineTo(w, hy)
      ctx.stroke()
    }
  }

  // Audio wave at horizon — cosine-interpolated FFT bands
  ctx.strokeStyle = "#ff0066"
  ctx.lineWidth = 2
  ctx.beginPath()
  var maxWave = horizon * 0.85
  for (var rx = 0; rx < w; rx++) {
    var bandF = rx / (w - 1) * (count - 1)
    var bi = Math.floor(bandF)
    var frac = bandF - bi
    var t = (1 - Math.cos(frac * Math.PI)) / 2
    var level = d.playing ? Math.max(0.0, bi >= count - 1 ? (bands[count-1] || 0) :
                (bands[bi] || 0) * (1 - t) + (bands[bi+1] || 0) * t) : 0
    var ry = horizon - level * maxWave
    if (rx === 0) ctx.moveTo(rx, ry)
    else ctx.lineTo(rx, ry)
  }
  ctx.stroke()
}
