// DAW Wave — Pro Audio Dual-Layer RMS (Body) + True Peak (Transients) full color visualizer
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var beatDrop = d.beatDrop || 0
  var midY = h / 2.0

  // 52 pro DAW audio columns
  var numBars = 52
  var resampled = H.resampleBandsLinear(bands, numBars)

  var margin = 6
  var totalDrawW = w - margin * 2
  var gap = 2.2
  var barW = Math.max(2.5, (totalDrawW - (numBars - 1) * gap) / numBars)
  var actualW = numBars * barW + (numBars - 1) * gap
  var startX = margin + (totalDrawW - actualW) / 2.0

  // Dynamic accent color
  var acc = d.accent
  var ar = 0, ag = 220, ab = 255 // Sleek cyan/electric DAW fallback
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

    // Base envelope
    var env = Math.sin((i / numBars) * Math.PI)
    var shapeVal = 0.15 + env * 0.45 + Math.sin(i * 0.85 + 0.5) * 0.12
    var energy = isPlaying ? (resampled[i] || 0) : 0.0
    var kick = (i >= 2 && i <= 14) ? (beatDrop * 0.22) : 0.0

    // Outer Peak height (transient spikes)
    var peakH = Math.max(barW, ((shapeVal * 0.40) + (energy * 0.65) + kick) * (h * 0.86))
    // Inner RMS height (sustained perceived body)
    var rmsH = Math.max(2.0, peakH * 0.58)

    var peakY = midY - (peakH / 2.0)
    var rmsY = midY - (rmsH / 2.0)
    var r = Math.min(barW / 2.0, 1.5)

    // ── Outer Peak (Luminous translucent shell) ──
    ctx.fillStyle = "rgba(" + Math.min(255, ar + 40) + "," + Math.min(255, ag + 30) + ", 255, 0.42)"
    ctx.beginPath()
    H.roundedRect(ctx, bx, peakY, barW, peakH, r)
    ctx.fill()

    // ── Inner RMS Core (Punchy solid gradient) ──
    var rmsGrad = ctx.createLinearGradient(0, rmsY, 0, rmsY + rmsH)
    rmsGrad.addColorStop(0, "rgba(255, 255, 255, 0.98)")
    rmsGrad.addColorStop(0.3, "rgba(" + ar + "," + ag + "," + ab + ", 0.95)")
    rmsGrad.addColorStop(1, "rgba(" + Math.round(ar * 0.7) + "," + Math.round(ag * 0.7) + "," + Math.round(ab * 0.7) + ", 0.90)")
    ctx.fillStyle = rmsGrad
    ctx.beginPath()
    H.roundedRect(ctx, bx + 0.4, rmsY, Math.max(1.8, barW - 0.8), rmsH, r)
    ctx.fill()
  }
}
