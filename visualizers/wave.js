// Wave — Oscilloscope raw waveform with smooth spline interpolation & glowing trace
.pragma library

function render(ctx, d) {
  var wave = d.wave || [], w = d.width, h = d.height
  var n = wave.length
  var midY = h / 2.0
  var acc = d.accent

  var col = "#00ffff"
  if (acc) {
    if (typeof acc === "string" && acc.charAt(0) === "#" && acc.length === 7) col = acc
    else if (acc.r !== undefined) col = "rgba(" + Math.round(acc.r * 255) + "," + Math.round(acc.g * 255) + "," + Math.round(acc.b * 255) + ", 0.95)"
  }

  // Draw subtle center baseline
  ctx.strokeStyle = "rgba(255, 255, 255, 0.12)"
  ctx.lineWidth = 1.0
  ctx.beginPath()
  ctx.moveTo(0, midY)
  ctx.lineTo(w, midY)
  ctx.stroke()

  ctx.lineWidth = 2.2
  ctx.strokeStyle = col
  ctx.beginPath()

  if (n > 1 && d.playing) {
    var step = Math.max(1, Math.floor(w / n))
    var prevX = 0, prevY = midY
    ctx.moveTo(0, midY)

    for (var i = 0; i < n; i++) {
      var x = (i / (n - 1)) * w
      var s = wave[i] || 0
      var y = Math.max(2, Math.min(h - 3, midY - s * (h * 0.44)))
      if (i === 0) {
        ctx.moveTo(x, y)
      } else {
        var cpx = (prevX + x) / 2
        ctx.quadraticCurveTo(prevX, prevY, cpx, (prevY + y) / 2)
      }
      prevX = x; prevY = y
    }
    ctx.lineTo(w, prevY)
  } else {
    ctx.moveTo(0, midY)
    ctx.lineTo(w, midY)
  }
  ctx.stroke()
}
