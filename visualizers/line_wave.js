// Line Wave — Thin filled silhouette waveform (SoundCloud / LineDrawer style)
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0

  var numSamples = 80
  var resampled = H.resampleBandsLinear(bands, numSamples)
  var beatDrop = d.beatDrop || 0
  var progress = d.progress !== undefined ? d.progress : 0

  // Dynamic accent color
  var acc = d.accent
  var ar = 100, ag = 180, ab = 255
  if (acc) {
    if (typeof acc === "string" && acc.charAt(0) === "#" && acc.length === 7) {
      ar = parseInt(acc.substr(1, 2), 16)
      ag = parseInt(acc.substr(3, 2), 16)
      ab = parseInt(acc.substr(5, 2), 16)
    } else if (acc.r !== undefined && acc.g !== undefined && acc.b !== undefined) {
      ar = Math.round(acc.r <= 1.0 ? acc.r * 255 : acc.r)
      ag = Math.round(acc.g <= 1.0 ? acc.g * 255 : acc.g)
      ab = Math.round(acc.b <= 1.0 ? acc.b * 255 : acc.b)
    }
  }

  var margin = 6
  var drawW = w - margin * 2
  var playheadX = margin + progress * drawW

  // Build height array from song envelope + live audio
  var heights = []
  for (var i = 0; i < numSamples; i++) {
    var env = Math.sin((i / numSamples) * Math.PI)
    var shape = 0.15 + env * 0.45 + Math.sin(i * 0.7 + 1.2) * 0.12
    var energy = isPlaying ? (resampled[i] || 0) : 0.0
    var kick = (i >= 3 && i <= 15) ? (beatDrop * (h * 0.18)) : 0
    var barH = Math.max(2, (shape * (h * 0.30)) + (energy * (h * 0.55)) + kick)
    heights.push(Math.min(h * 0.88, barH))
  }

  // Helper: draw filled silhouette path (top half + mirrored bottom)
  function drawSilhouette(clipLeft, clipRight, fillStyle) {
    ctx.save()
    ctx.beginPath()
    ctx.rect(clipLeft, 0, clipRight - clipLeft, h)
    ctx.clip()

    ctx.beginPath()
    // Top contour
    for (var j = 0; j < numSamples; j++) {
      var x = margin + (j / (numSamples - 1)) * drawW
      var halfH = heights[j] / 2.0
      if (j === 0) ctx.moveTo(x, midY - halfH)
      else ctx.lineTo(x, midY - halfH)
    }
    // Bottom contour (reverse)
    for (var k = numSamples - 1; k >= 0; k--) {
      var x2 = margin + (k / (numSamples - 1)) * drawW
      var halfH2 = heights[k] / 2.0 * 0.85
      ctx.lineTo(x2, midY + halfH2)
    }
    ctx.closePath()
    ctx.fillStyle = fillStyle
    ctx.fill()
    ctx.restore()
  }

  // Played portion: vivid accent gradient
  var playedGrad = ctx.createLinearGradient(0, midY - h * 0.4, 0, midY + h * 0.3)
  playedGrad.addColorStop(0, "rgba(255, 255, 255, 0.95)")
  playedGrad.addColorStop(0.3, "rgba(" + Math.min(255, ar + 40) + "," + Math.min(255, ag + 30) + ", 255, 0.90)")
  playedGrad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.75)")
  drawSilhouette(margin, playheadX, playedGrad)

  // Unplayed portion: muted translucent
  drawSilhouette(playheadX, margin + drawW, "rgba(255, 255, 255, 0.18)")

  // Playhead needle
  if (isPlaying && drawW > 0) {
    ctx.fillStyle = "#ffffff"
    ctx.fillRect(playheadX - 1, midY - h * 0.44, 2, h * 0.88)
  }
}
