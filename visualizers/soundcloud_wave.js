// SoundCloud Wave — Asymmetrical top-heavy waveform with subtle bottom reflection & progress split
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height
  var isPlaying = d.playing
  var progress = d.progress !== undefined ? d.progress : (d.state ? d.state.progress || 0 : 0)
  var beatDrop = d.beatDrop || 0

  // 52 crisp vertical bars with asymmetrical reflection
  var numBars = 52
  var resampled = H.resampleBandsLinear(bands, numBars)

  // Layout geometry
  var margin = 6
  var totalDrawW = w - margin * 2
  var gap = 2.0
  var barW = Math.max(2.0, (totalDrawW - (numBars - 1) * gap) / numBars)
  var actualW = numBars * barW + (numBars - 1) * gap
  var startX = margin + (totalDrawW - actualW) / 2.0
  var playheadX = startX + progress * actualW

  // Baseline positioned at 66% down (leaving ~66% for top peaks, ~34% for reflection)
  var baselineY = h * 0.64
  var maxTopH = baselineY - 4
  var maxBotH = (h - baselineY) - 4

  // Extract accent RGB
  var acc = d.accent
  var ar = 255, ag = 119, ab = 0 // Signature SoundCloud orange fallback
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

  // Draw 52 asymmetrical waveform bars
  for (var i = 0; i < numBars; i++) {
    var bx = startX + i * (barW + gap)
    var barCenter = bx + barW / 2.0
    var isPlayed = barCenter <= playheadX

    // Track dynamic profile envelope
    var env = Math.sin((i / numBars) * Math.PI)
    var shapeVal = 0.18 + env * 0.46 + Math.sin(i * 0.75 + 0.4) * 0.14
    var energy = isPlaying ? (resampled[i] || 0) : 0.0
    var kick = (i >= 2 && i <= 12) ? (beatDrop * 0.22) : 0.0

    // Top peak height
    var topNorm = Math.min(1.0, shapeVal * 0.40 + energy * 0.65 + kick)
    var topH = Math.max(3.0, topNorm * maxTopH)

    // Bottom reflection height (~32% of top peak)
    var botH = Math.max(2.0, topH * 0.32)

    var topY = baselineY - topH
    var botY = baselineY + 1.5 // 1.5px horizon slit
    var r = Math.min(barW / 2.0, 1.5)

    if (isPlayed) {
      // ── Played Top Bar: Radiant glowing accent gradient with white-hot tip ──
      var topGrad = ctx.createLinearGradient(0, topY, 0, baselineY)
      topGrad.addColorStop(0, "rgba(255, 255, 255, 0.98)")
      topGrad.addColorStop(0.25, "rgba(" + Math.min(255, ar + 50) + "," + Math.min(255, ag + 40) + ", 255, 0.95)")
      topGrad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.85)")
      ctx.fillStyle = topGrad
      ctx.beginPath()
      H.roundedRect(ctx, bx, topY, barW, topH, r)
      ctx.fill()

      // ── Played Bottom Reflection: Muted accent with shadow falloff ──
      var botGrad = ctx.createLinearGradient(0, botY, 0, botY + botH)
      botGrad.addColorStop(0, "rgba(" + ar + "," + ag + "," + ab + ", 0.55)")
      botGrad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.15)")
      ctx.fillStyle = botGrad
      ctx.beginPath()
      H.roundedRect(ctx, bx, botY, barW, botH, r)
      ctx.fill()
    } else {
      // ── Unplayed Top Bar: Clean translucent white ──
      ctx.fillStyle = "rgba(255, 255, 255, 0.28)"
      ctx.beginPath()
      H.roundedRect(ctx, bx, topY, barW, topH, r)
      ctx.fill()

      // ── Unplayed Bottom Reflection: Deep translucent dim ──
      ctx.fillStyle = "rgba(255, 255, 255, 0.10)"
      ctx.beginPath()
      H.roundedRect(ctx, bx, botY, barW, botH, r)
      ctx.fill()
    }
  }

  // ── Crisp Playhead Needle ──
  if (isPlaying && actualW > 0) {
    var curX = Math.max(startX, Math.min(startX + actualW, playheadX))

    // Vertical line spanning top peak to reflection
    ctx.fillStyle = "#ffffff"
    ctx.fillRect(curX - 1, 4, 2, h - 8)

    // Glowing tip at top of playhead
    ctx.beginPath()
    ctx.arc(curX, 5, 2.5, 0, Math.PI * 2)
    ctx.fillStyle = "#ffffff"
    ctx.fill()
  }
}
