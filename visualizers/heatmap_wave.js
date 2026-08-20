// Heatmap Wave — Dynamic Thermal Intensity Energy-Color Mapped Scrubber
.pragma library
.import "helpers.js" as H

// Computes a blazing thermal gradient color from energy level (0.0 to 1.0)
function energyToHeatmapColor(val, alpha) {
  var v = Math.max(0.0, Math.min(1.0, val))
  var r = 0, g = 0, b = 0

  if (v < 0.25) {
    // Deep Indigo -> Electric Blue
    var t = v / 0.25
    r = Math.round(30 + t * 20)
    g = Math.round(50 + t * 130)
    b = Math.round(180 + t * 75)
  } else if (v < 0.50) {
    // Electric Blue -> Hot Magenta / Fuchsia
    var t = (v - 0.25) / 0.25
    r = Math.round(50 + t * 190)
    g = Math.round(180 - t * 140)
    b = Math.round(255 - t * 75)
  } else if (v < 0.75) {
    // Hot Magenta -> Neon Flame Orange
    var t = (v - 0.50) / 0.25
    r = 255
    g = Math.round(40 + t * 140)
    b = Math.round(180 - t * 160)
  } else {
    // Flame Orange -> Blazing Solar Gold / White-Hot Peak
    var t = (v - 0.75) / 0.25
    r = 255
    g = Math.round(180 + t * 75)
    b = Math.round(20 + t * 220)
  }

  return "rgba(" + r + "," + g + "," + b + "," + alpha.toFixed(2) + ")"
}

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height
  var isPlaying = d.playing
  var progress = d.progress !== undefined ? d.progress : (d.state ? d.state.progress || 0 : 0)
  var beatDrop = d.beatDrop || 0
  var midY = h / 2.0

  // 60 thermal intensity bars
  var numBars = 60
  var resampled = H.resampleBandsLinear(bands, numBars)

  var margin = 6
  var totalDrawW = w - margin * 2
  var gap = 1.8
  var barW = Math.max(2.0, (totalDrawW - (numBars - 1) * gap) / numBars)
  var actualW = numBars * barW + (numBars - 1) * gap
  var startX = margin + (totalDrawW - actualW) / 2.0
  var playheadX = startX + progress * actualW

  for (var i = 0; i < numBars; i++) {
    var bx = startX + i * (barW + gap)
    var barCenter = bx + barW / 2.0
    var isPlayed = barCenter <= playheadX

    // Track dynamic profile envelope
    var env = Math.sin((i / numBars) * Math.PI)
    var shapeVal = 0.16 + env * 0.48 + Math.sin(i * 0.75 + 0.3) * 0.14
    var energy = isPlaying ? (resampled[i] || 0) : 0.0
    var kick = (i >= 2 && i <= 14) ? (beatDrop * 0.26) : 0.0

    // Thermal energy intensity (0.0 to 1.0)
    var intensity = Math.min(1.0, shapeVal * 0.38 + energy * 0.62 + kick)
    var barH = Math.max(barW, intensity * (h * 0.86))
    var by = midY - (barH / 2.0)
    var r = Math.min(barW / 2.0, 1.5)

    if (isPlayed) {
      // ── Played: Thermal radiant gradient from top to bottom ──
      var grad = ctx.createLinearGradient(0, by, 0, by + barH)
      grad.addColorStop(0, energyToHeatmapColor(Math.min(1.0, intensity + 0.25), 0.98))
      grad.addColorStop(0.5, energyToHeatmapColor(intensity, 0.92))
      grad.addColorStop(1, energyToHeatmapColor(Math.max(0.0, intensity - 0.20), 0.85))
      ctx.fillStyle = grad
    } else {
      // ── Unplayed: Muted translucent thermal tint ──
      ctx.fillStyle = energyToHeatmapColor(intensity * 0.7, 0.24)
    }

    ctx.beginPath()
    H.roundedRect(ctx, bx, by, barW, barH, r)
    ctx.fill()
  }

  // ── Thermal Needle Marker ──
  if (isPlaying && actualW > 0) {
    var curX = Math.max(startX, Math.min(startX + actualW, playheadX))

    ctx.fillStyle = "#ffffff"
    ctx.fillRect(curX - 1, 3, 2, h - 6)

    // Glowing tip
    ctx.beginPath()
    ctx.arc(curX, 5, 2.5, 0, Math.PI * 2)
    ctx.fillStyle = "#ffcc00"
    ctx.fill()
  }
}
