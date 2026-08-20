// Voice Pill Wave — Telegram & WhatsApp style high-density rounded micro-capsules
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height
  var isPlaying = d.playing
  var progress = d.progress !== undefined ? d.progress : (d.state ? d.state.progress || 0 : 0)
  var beatDrop = d.beatDrop || 0
  var midY = h / 2.0

  // 64 high-density micro-pills
  var numPills = 64
  var resampled = H.resampleBandsLinear(bands, numPills)

  var margin = 6
  var totalDrawW = w - margin * 2
  var gap = 2.0
  var pillW = Math.max(2.0, (totalDrawW - (numPills - 1) * gap) / numPills)
  var actualW = numPills * pillW + (numPills - 1) * gap
  var startX = margin + (totalDrawW - actualW) / 2.0
  var playheadX = startX + progress * actualW

  // Dynamic accent color
  var acc = d.accent
  var ar = 0, ag = 200, ab = 140 // Elegant emerald/cyan fallback
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

  // Draw 64 micro-capsule pills
  for (var i = 0; i < numPills; i++) {
    var px = startX + i * (pillW + gap)
    var pillCenter = px + pillW / 2.0
    var isPlayed = pillCenter <= playheadX

    // Dynamic voice message amplitude contour
    var env = Math.sin((i / numPills) * Math.PI)
    var shapeVal = 0.15 + env * 0.50 + Math.sin(i * 0.85 + 0.3) * 0.15
    var energy = isPlaying ? (resampled[i] || 0) : 0.0
    var kick = (i >= 2 && i <= 10) ? (beatDrop * 0.20) : 0.0

    var pillH = Math.max(pillW, ((shapeVal * 0.40) + (energy * 0.60) + kick) * (h * 0.84))
    var py = midY - (pillH / 2.0)
    var r = pillW / 2.0

    if (isPlayed) {
      // ── Played: Smooth vibrant gradient with luminous core ──
      var grad = ctx.createLinearGradient(0, py, 0, py + pillH)
      grad.addColorStop(0, "rgba(255, 255, 255, 0.96)")
      grad.addColorStop(0.3, "rgba(" + Math.min(255, ar + 45) + "," + Math.min(255, ag + 35) + ", 255, 0.95)")
      grad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.85)")
      ctx.fillStyle = grad
    } else {
      // ── Unplayed: Clean translucent capsule ──
      ctx.fillStyle = "rgba(255, 255, 255, 0.24)"
    }

    ctx.beginPath()
    ctx.roundRect(px, py, pillW, pillH, r)
    ctx.fill()
  }

  // ── Sleek Playhead Micro-Marker ──
  if (isPlaying && actualW > 0) {
    var curX = Math.max(startX, Math.min(startX + actualW, playheadX))

    // Delicate vertical needle
    ctx.fillStyle = "#ffffff"
    ctx.fillRect(curX - 0.75, midY - h * 0.42, 1.5, h * 0.84)

    // Center circular pearl
    ctx.beginPath()
    ctx.arc(curX, midY, 3.0, 0, Math.PI * 2)
    ctx.fillStyle = "#ffffff"
    ctx.fill()

    ctx.beginPath()
    ctx.arc(curX, midY, 1.5, 0, Math.PI * 2)
    ctx.fillStyle = "rgba(" + ar + "," + ag + "," + ab + ", 1.0)"
    ctx.fill()
  }
}
