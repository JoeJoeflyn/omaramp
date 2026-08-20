// Scope — Lissajous XY oscilloscope with smooth phase rotation & phosphor trace
.pragma library

function render(ctx, d) {
  var wave = d.wave || [], w = d.width, h = d.height
  var n = wave.length
  var acc = d.accent

  var col = "#00ff88"
  if (acc) {
    if (typeof acc === "string" && acc.charAt(0) === "#" && acc.length === 7) col = acc
    else if (acc.r !== undefined) col = "rgba(" + Math.round(acc.r * 255) + "," + Math.round(acc.g * 255) + "," + Math.round(acc.b * 255) + ",0.9)"
  }

  ctx.lineWidth = 1.6
  ctx.strokeStyle = col
  ctx.beginPath()

  if (n > 4 && d.playing) {
    var baseDelay = Math.floor(n / 4)
    // Slower, smooth Lissajous wobble (0.005 instead of 0.02)
    var wobble = Math.sin(d.frame * 0.006) * (n / 8)
    var delay = Math.max(1, Math.min(n - 1, Math.floor(baseDelay + wobble)))
    var plotPoints = Math.min(n - delay, 256)
    var step = Math.max(1, Math.floor((n - delay) / plotPoints))

    for (var i = 0; i + delay < n; i += step) {
      var x = Math.floor((wave[i] + 1.0) * 0.5 * (w - 1))
      var y = Math.floor((1.0 - wave[i + delay]) * 0.5 * (h - 1))
      x = Math.max(2, Math.min(w - 3, x))
      y = Math.max(2, Math.min(h - 3, y))
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
  } else {
    ctx.arc(w / 2, h / 2, 2, 0, Math.PI * 2)
  }
  ctx.stroke()
}
