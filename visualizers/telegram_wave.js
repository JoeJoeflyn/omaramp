// Telegram Wave — Full-width rounded capsule voice message waveform with full color fill
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var beatDrop = d.beatDrop || 0
  var midY = h / 2.0

  // 56 rounded capsule pills
  var numPills = 56
  var resampled = H.resampleBandsLinear(bands, numPills)

  var margin = 6
  var totalDrawW = w - margin * 2
  var gap = 2.4
  var pillW = Math.max(2.4, (totalDrawW - (numPills - 1) * gap) / numPills)
  var actualW = numPills * pillW + (numPills - 1) * gap
  var startX = margin + (totalDrawW - actualW) / 2.0

  // Dynamic accent color
  var acc = d.accent
  var ar = 0, ag = 210, ab = 150 // Elegant teal fallback
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

  // Draw 56 fully-filled vibrant micro-capsule pills
  for (var i = 0; i < numPills; i++) {
    var px = startX + i * (pillW + gap)

    // Dynamic amplitude profile envelope
    var env = Math.sin((i / numPills) * Math.PI)
    var shapeVal = 0.18 + env * 0.48 + Math.sin(i * 0.85 + 0.3) * 0.14
    var energy = isPlaying ? (resampled[i] || 0) : 0.0
    var kick = (i >= 2 && i <= 12) ? (beatDrop * 0.22) : 0.0

    var pillH = Math.max(pillW, ((shapeVal * 0.38) + (energy * 0.64) + kick) * (h * 0.86))
    var py = midY - (pillH / 2.0)
    var r = pillW / 2.0

    // Full radiant gradient fill with white luminous core
    var grad = ctx.createLinearGradient(0, py, 0, py + pillH)
    grad.addColorStop(0, "rgba(255, 255, 255, 0.98)")
    grad.addColorStop(0.25, "rgba(" + Math.min(255, ar + 50) + "," + Math.min(255, ag + 40) + ", 255, 0.95)")
    grad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.88)")
    ctx.fillStyle = grad

    ctx.beginPath()
    H.roundedRect(ctx, px, py, pillW, pillH, r)
    ctx.fill()
  }
}
