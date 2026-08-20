// SoundCloud Wave — Ultra-thin high-density asymmetrical waveform with full vibrant color fill
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var beatDrop = d.beatDrop || 0

  // 84 ultra-thin vertical bars
  var numBars = 84
  var resampled = H.resampleBandsLinear(bands, numBars)

  // Layout geometry
  var margin = 6
  var totalDrawW = w - margin * 2
  var gap = 1.4
  var barW = Math.max(1.2, (totalDrawW - (numBars - 1) * gap) / numBars)
  var actualW = numBars * barW + (numBars - 1) * gap
  var startX = margin + (totalDrawW - actualW) / 2.0

  // Baseline at 66% down
  var baselineY = h * 0.66
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

  // Draw 84 fully-filled vibrant waveform bars
  for (var i = 0; i < numBars; i++) {
    var bx = startX + i * (barW + gap)

    // Dynamic wave envelope
    var env = Math.sin((i / numBars) * Math.PI)
    var shapeVal = 0.16 + env * 0.48 + Math.sin(i * 0.55 + 0.2) * 0.12 + Math.sin(i * 1.3) * 0.08
    var energy = isPlaying ? (resampled[i] || 0) : 0.0
    var kick = (i >= 3 && i <= 20) ? (beatDrop * 0.22) : 0.0

    // Top peak height
    var topNorm = Math.min(1.0, shapeVal * 0.38 + energy * 0.65 + kick)
    var topH = Math.max(3.0, topNorm * maxTopH)

    // Bottom reflection height (~28% of top peak)
    var botH = Math.max(1.5, topH * 0.28)

    var topY = baselineY - topH
    var botY = baselineY + 1.2 // 1.2px horizon slit
    var r = Math.min(barW / 2.0, 0.8)

    // ── Full Vibrant Top Bar Gradient ──
    var topGrad = ctx.createLinearGradient(0, topY, 0, baselineY)
    topGrad.addColorStop(0, "rgba(255, 255, 255, 0.98)")
    topGrad.addColorStop(0.20, "rgba(" + Math.min(255, ar + 50) + "," + Math.min(255, ag + 40) + ", 255, 0.95)")
    topGrad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.88)")
    ctx.fillStyle = topGrad
    ctx.beginPath()
    H.roundedRect(ctx, bx, topY, barW, topH, r)
    ctx.fill()

    // ── Full Vibrant Bottom Reflection ──
    var botGrad = ctx.createLinearGradient(0, botY, 0, botY + botH)
    botGrad.addColorStop(0, "rgba(" + ar + "," + ag + "," + ab + ", 0.55)")
    botGrad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.15)")
    ctx.fillStyle = botGrad
    ctx.beginPath()
    H.roundedRect(ctx, bx, botY, barW, botH, r)
    ctx.fill()
  }
}
