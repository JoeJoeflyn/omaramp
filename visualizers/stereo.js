// Stereo — vis_stereo.go: RMS level + peak meters
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, wave = d.wave, h = d.height, w = d.width, count = d.count
  var halfH = h / 2.0
  // RMS from waveform (uses stereo RMS, we have mono)
  var swSum = 0, swPeak = 0
  for (var i = 0; i < wave.length; i++) {
    var v = Math.abs(wave[i])
    swSum += v * v
    if (v > swPeak) swPeak = v
  }
  var swRms = Math.sqrt(swSum / Math.max(1, wave.length))
  var stLevel = swRms > 0 ? Math.max(0, Math.min(1, (20 * Math.log10(swRms) + 48) / 48)) : 0
  var stPeak = swPeak > 0 ? Math.max(0, Math.min(1, (20 * Math.log10(swPeak) + 48) / 48)) : 0
  // L uses lower bands, R uses upper bands
  var lSum = 0, rSum = 0, lCnt = 0, rCnt = 0
  for (var si = 0; si < count; si++) {
    if (si < count / 2) { lSum += (bands[si] || 0); lCnt++ }
    else { rSum += (bands[si] || 0); rCnt++ }
  }
  var lLevel = d.playing ? Math.max(stLevel, lSum / Math.max(1, lCnt)) : 0
  var rLevel = d.playing ? Math.max(stLevel, rSum / Math.max(1, rCnt)) : 0
  // L meter (top, grows right)
  var lCells = Math.floor(w * lLevel)
  for (var lc = 0; lc < lCells; lc++) {
    var n = lc / Math.max(1, w - 1)
    ctx.fillStyle = H.specColor(n)
    ctx.fillRect(lc, 2, 1, halfH - 4)
  }
  var lPeakCell = Math.floor(w * stPeak) - 1
  if (lPeakCell >= 0 && lPeakCell < w) { ctx.fillStyle = "#ffffff"; ctx.fillRect(lPeakCell, 2, 1, halfH - 4) }
  // R meter (bottom, grows right)
  var rCells = Math.floor(w * rLevel)
  for (var rc = 0; rc < rCells; rc++) {
    var n2 = rc / Math.max(1, w - 1)
    ctx.fillStyle = H.specColor(n2)
    ctx.fillRect(rc, halfH + 2, 1, halfH - 4)
  }
  var rPeakCell = Math.floor(w * stPeak) - 1
  if (rPeakCell >= 0 && rPeakCell < w) { ctx.fillStyle = "#ffffff"; ctx.fillRect(rPeakCell, halfH + 2, 1, halfH - 4) }
  // Separator + labels
  ctx.strokeStyle = "rgba(255,255,255,0.1)"; ctx.lineWidth = 1
  ctx.beginPath(); ctx.moveTo(0, halfH); ctx.lineTo(w, halfH); ctx.stroke()
  ctx.fillStyle = d.dim; ctx.font = "8px monospace"
  ctx.fillText("L", 2, halfH - 4); ctx.fillText("R", 2, h - 4)
}
