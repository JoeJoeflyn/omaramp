// Grounded Wave — Single-sided bottom baseline spectrum visualizer with full color fill
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var beatDrop = d.beatDrop || 0

  // 64 grounded bars anchored to bottom baseline
  var numBars = 64
  var resampled = H.resampleBandsLinear(bands, numBars)

  var margin = 6
  var totalDrawW = w - margin * 2
  var gap = 1.8
  var barW = Math.max(2.0, (totalDrawW - (numBars - 1) * gap) / numBars)
  var actualW = numBars * barW + (numBars - 1) * gap
  var startX = margin + (totalDrawW - actualW) / 2.0

  // Baseline floor line
  var baselineY = h - 6
  var maxH = baselineY - 4

  // Extract accent RGB
  var acc = d.accent
  var ar = 140, ag = 100, ab = 255 // Lavender/Violet fallback
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

  // Draw 64 fully-filled grounded bars
  for (var i = 0; i < numBars; i++) {
    var bx = startX + i * (barW + gap)

    // Track dynamic profile envelope
    var env = Math.sin((i / numBars) * Math.PI)
    var shapeVal = 0.15 + env * 0.48 + Math.sin(i * 0.7 + 0.4) * 0.12
    var energy = isPlaying ? (resampled[i] || 0) : 0.0
    var kick = (i >= 2 && i <= 14) ? (beatDrop * 0.22) : 0.0

    var barH = Math.max(3.0, (shapeVal * 0.38 + energy * 0.62 + kick) * maxH)
    var by = baselineY - barH
    var r = Math.min(barW / 2.0, 1.2)

    // Vertical gradient with brilliant white cap across all bars
    var grad = ctx.createLinearGradient(0, by, 0, baselineY)
    grad.addColorStop(0, "rgba(255, 255, 255, 0.98)")
    grad.addColorStop(0.25, "rgba(" + Math.min(255, ar + 45) + "," + Math.min(255, ag + 35) + ", 255, 0.95)")
    grad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.85)")
    ctx.fillStyle = grad

    ctx.beginPath()
    H.roundedRect(ctx, bx, by, barW, barH, r)
    ctx.fill()
  }

  // ── Baseline Floor Glow ──
  ctx.fillStyle = "rgba(255, 255, 255, 0.18)"
  ctx.fillRect(startX, baselineY + 1, actualW, 1)
}
