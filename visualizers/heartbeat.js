// Heartbeat — cliamp vis_heartbeat.go: ECG trace with shaped waveform + dashed baseline
.pragma library

function render(ctx, d) {
  var wave = d.wave, w = d.width, h = d.height
  var n = wave.length
  var midY = h / 2.0
  var amp = h * 0.45
  var ypos = new Array(w)
  if (n > 1 && d.playing) {
    for (var x = 0; x < w; x++) {
      var i = Math.floor(x * n / w)
      if (i >= n) i = n - 1
      var s = wave[i] || 0
      var shaped = s * Math.abs(s)
      ypos[x] = Math.max(0, Math.min(h - 1, Math.floor(midY - shaped * amp)))
    }
    ctx.strokeStyle = "#00ff66"
    ctx.lineWidth = 2
    ctx.beginPath()
    for (var x2 = 0; x2 < w; x2++) {
      if (x2 === 0) ctx.moveTo(x2, ypos[x2])
      else ctx.lineTo(x2, ypos[x2])
    }
    ctx.stroke()
  }
  // Dashed baseline (cliamp: on 6, off 4)
  ctx.strokeStyle = "rgba(0, 255, 100, 0.3)"
  ctx.lineWidth = 1
  ctx.beginPath()
  for (var x3 = 0; x3 < w; x3 += 10) {
    ctx.moveTo(x3, midY)
    ctx.lineTo(x3 + 6, midY)
  }
  ctx.stroke()
}
