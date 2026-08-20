// Apple Music Bars — Dynamic Island & Now Playing bouncy rounded capsule bars (||||)
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0

  // 5 bold Apple Dynamic Island capsule bars
  var numBars = 5
  var resampled = H.resampleBandsLinear(bands, numBars)
  var beatDrop = d.beatDrop || 0

  // Bold capsule geometry
  var barWidth = Math.max(5, Math.floor(w / 34))
  var gap = Math.max(4, Math.floor(barWidth * 0.85))
  var totalW = numBars * barWidth + (numBars - 1) * gap
  var startX = Math.floor((w - totalW) / 2)

  // Dynamic Artwork Accent Color
  var acc = d.accent
  var ar = 250, ag = 60, ab = 120
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
    var bx = startX + i * (barWidth + gap)
    var energy = isPlaying ? (resampled[i] || 0) : 0.0

    // Apple spring physics: minimum resting pill height -> dynamic energetic expansion
    var minH = barWidth
    var maxH = h * 0.85
    var kickBoost = (i === 1 || i === 2) ? (beatDrop * (h * 0.30)) : 0
    var barH = Math.max(minH, minH + (energy * (maxH - minH)) + kickBoost)

    var by = midY - (barH / 2.0)
    var r = barWidth / 2.0

    // Apple Vibrant Fluid Gradient
    var grad = ctx.createLinearGradient(0, by, 0, by + barH)
    grad.addColorStop(0, "rgba(255, 255, 255, 0.98)")
    grad.addColorStop(0.35, "rgba(" + Math.min(255, ar + 45) + "," + Math.min(255, ag + 35) + ", 255, 0.95)")
    grad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.85)")

    ctx.fillStyle = grad
    ctx.beginPath()
    ctx.arc(bx + r, by + r, r, Math.PI, 0, false)
    ctx.lineTo(bx + barWidth, by + barH - r)
    ctx.arc(bx + r, by + barH - r, r, 0, Math.PI, false)
    ctx.closePath()
    ctx.fill()
  }
}
