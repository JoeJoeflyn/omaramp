// Scope — cliamp vis_scope.go: Lissajous XY oscilloscope with interpolation
.pragma library

function render(ctx, d) {
  var wave = d.wave, w = d.width, h = d.height
  var n = wave.length
  ctx.lineWidth = 1.5
  ctx.strokeStyle = "#00ff66"
  ctx.beginPath()
  if (n > 4 && d.playing) {
    var baseDelay = Math.floor(n / 4)
    var wobble = Math.sin(d.frame * 0.02) * (n / 8)
    var delay = Math.max(1, Math.min(n - 1, Math.floor(baseDelay + wobble)))
    var plotPoints = Math.min(n - delay, 512)
    var step = Math.max(1, Math.floor((n - delay) / plotPoints))
    var prevX = -1, prevY = -1
    for (var i = 0; i + delay < n; i += step) {
      var x = Math.floor((wave[i] + 1.0) * 0.5 * (w - 1))
      var y = Math.floor((1.0 - wave[i + delay]) * 0.5 * (h - 1))
      x = Math.max(0, Math.min(w - 1, x))
      y = Math.max(0, Math.min(h - 1, y))
      if (i === 0) {
        ctx.moveTo(x, y)
      } else {
        var dx = x - prevX, dy = y - prevY
        var adx = Math.abs(dx), ady = Math.abs(dy)
        var steps = Math.max(adx, ady)
        if (steps > 0 && steps < 30) {
          for (var s = 1; s < steps; s++) {
            ctx.lineTo(prevX + Math.floor(dx * s / steps), prevY + Math.floor(dy * s / steps))
          }
        }
        ctx.lineTo(x, y)
      }
      prevX = x; prevY = y
    }
  } else {
    ctx.moveTo(w / 2, h / 2)
  }
  ctx.stroke()
}
