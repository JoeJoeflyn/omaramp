// Sound Wave — Continuous rounded capsule waveform bars (Voice Memos / SoundCloud style)
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0

  // 36 smooth rounded waveform capsule bars
  var numBars = 36
  var resampled = H.resampleBandsLinear(bands, numBars)
  var beatDrop = d.beatDrop || 0

  var gap = 3
  var barW = Math.max(3, Math.floor((w - (numBars - 1) * gap - 8) / numBars))
  var totalW = numBars * barW + (numBars - 1) * gap
  var startX = Math.floor((w - totalW) / 2)

  // Dynamic accent color
  var acc = d.accent
  var ar = 120, ag = 190, ab = 255
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

  for (var i = 0; i < numBars; i++) {
    var bx = startX + i * (barW + gap)
    var energy = isPlaying ? (resampled[i] || 0) : 0.04

    var minH = barW
    var maxH = h * 0.86
    var kickBoost = (i >= 3 && i <= 10) ? (beatDrop * (h * 0.22)) : 0
    var barH = Math.max(minH, minH + (energy * (maxH - minH)) + kickBoost)

    var by = midY - (barH / 2.0)
    var r = barW / 2.0

    // Symmetrical gradient (white/bright crest -> vibrant accent body)
    var grad = ctx.createLinearGradient(0, by, 0, by + barH)
    grad.addColorStop(0, "rgba(255, 255, 255, 0.95)")
    grad.addColorStop(0.35, "rgba(" + Math.min(255, ar + 40) + "," + Math.min(255, ag + 30) + ", 255, 0.90)")
    grad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.75)")

    ctx.fillStyle = grad
    ctx.beginPath()
    ctx.arc(bx + r, by + r, r, Math.PI, 0, false)
    ctx.lineTo(bx + barW, by + barH - r)
    ctx.arc(bx + r, by + barH - r, r, 0, Math.PI, false)
    ctx.closePath()
    ctx.fill()
  }

  // Faint center reference baseline
  ctx.strokeStyle = "rgba(255, 255, 255, 0.08)"
  ctx.lineWidth = 1.0
  ctx.beginPath()
  ctx.moveTo(0, midY)
  ctx.lineTo(w, midY)
  ctx.stroke()
}
