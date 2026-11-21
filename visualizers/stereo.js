// Stereo — vis_stereo.go: RMS level + peak meters
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var h = d.height, w = d.width, s = d.state
  var halfH = h / 2.0
  var lr = d.lr || [0, 0]
  if (!s.vuPeak) s.vuPeak = [0, 0]
  // L meter on top, R meter below, both grow right
  for (var c = 0; c < 2; c++) {
    // RMS of that channel on a 48 dB scale
    var rms = d.playing ? (lr[c] || 0) : 0
    var level = rms > 0 ? Math.max(0, Math.min(1, (20 * Math.log10(rms) + 48) / 48)) : 0
    s.vuPeak[c] = Math.max(level, s.vuPeak[c] - 0.012)
    var y = c * halfH + 2, mh = halfH - 4
    // One rect per colour band (green, yellow, red) up to the level
    for (var t = 0; t < 3; t++) {
      var x0 = w * 0.3 * t, x1 = Math.min(w * level, t < 2 ? w * 0.3 * (t + 1) : w)
      if (x1 <= x0) break
      ctx.fillStyle = H.specColor(0.3 * t)
      ctx.fillRect(x0, y, x1 - x0, mh)
    }
    if (s.vuPeak[c] > level + 0.01) { ctx.fillStyle = "#ffffff"; ctx.fillRect(Math.min(w - 2, w * s.vuPeak[c]), y, 2, mh) }
  }
  // Separator + labels
  ctx.strokeStyle = "rgba(255,255,255,0.1)"; ctx.lineWidth = 1
  ctx.beginPath(); ctx.moveTo(0, halfH); ctx.lineTo(w, halfH); ctx.stroke()
  ctx.fillStyle = d.dim; ctx.font = "8px monospace"
  ctx.fillText("L", 2, halfH - 4); ctx.fillText("R", 2, h - 4)
}
