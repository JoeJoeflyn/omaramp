// Wave — vis_wave.go: raw audio oscilloscope
.pragma library

function render(ctx, d) {
  var wave = d.wave, w = d.width, h = d.height
  ctx.lineWidth = 2
  ctx.strokeStyle = d.accent
  ctx.beginPath()
  var n = wave.length
  var midY = h / 2.0
  if (n > 1 && d.playing) {
    for (var x = 0; x < w; x++) {
      var i = Math.floor(x * n / w)
      var s = wave[i] || 0
      var y = midY - s * (h / 2.2)
      if (x === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
  } else {
    ctx.moveTo(0, midY)
    ctx.lineTo(w, midY)
  }
  ctx.stroke()
}
