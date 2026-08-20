// Apple Sound Wave — Apple Music & Dynamic Island rounded capsule audio bars (|||)
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0

  // 24 Apple rounded capsule bars
  var numBars = 24
  var resampled = H.resampleBandsLinear(bands, numBars)
  var bass = H.bandAvg(resampled, 0, 4)
  var beatDrop = d.beatDrop || 0

  // Calculate layout dimensions
  var gap = Math.max(2, Math.floor(w / 80))
  var barWidth = Math.floor((w - (numBars - 1) * gap - 8) / numBars)
  var totalW = numBars * barWidth + (numBars - 1) * gap
  var startX = Math.floor((w - totalW) / 2)

  // Apple Gradient Palette (Dynamic Accent to Electric Cyan / Magenta / Apple White)
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

  // Draw each Apple capsule bar centered on midY
  for (var i = 0; i < numBars; i++) {
    var bx = startX + i * (barWidth + gap)
    var energy = isPlaying ? (resampled[i] || 0) : 0.04

    // Dynamic Island / Apple Voice Memo spring height
    var minH = barWidth
    var maxH = h * 0.82
    var kickBoost = (i >= 2 && i <= 8) ? (beatDrop * (h * 0.20)) : 0
    var barH = Math.max(minH, minH + (energy * (maxH - minH)) + kickBoost)

    var by = midY - (barH / 2.0)
    var radius = barWidth / 2.0

    // Apple Vertical Gradient
    var grad = ctx.createLinearGradient(0, by, 0, by + barH)
    grad.addColorStop(0, "rgba(255, 255, 255, 0.95)")
    grad.addColorStop(0.35, "rgba(" + Math.min(255, ar + 40) + "," + Math.min(255, ag + 30) + ", 255, 0.90)")
    grad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.70)")

    ctx.fillStyle = grad
    ctx.beginPath()

    // Draw smooth rounded pill / capsule
    if (typeof ctx.roundRect === "function") {
      ctx.roundRect(bx, by, barWidth, barH, radius)
    } else {
      ctx.moveTo(bx + radius, by)
      ctx.lineTo(bx + barWidth - radius, by)
      ctx.arc(bx + barWidth - radius, by + radius, radius, -Math.PI / 2, Math.PI / 2)
      ctx.lineTo(bx + radius, by + barH)
      ctx.arc(bx + radius, by + barH - radius, radius, Math.PI / 2, (3 * Math.PI) / 2)
      ctx.closePath()
    }
    ctx.fill()
  }

  // Apple center baseline glow
  ctx.strokeStyle = "rgba(255, 255, 255, 0.10)"
  ctx.lineWidth = 1.0
  ctx.beginPath()
  ctx.moveTo(0, midY)
  ctx.lineTo(w, midY)
  ctx.stroke()
}
