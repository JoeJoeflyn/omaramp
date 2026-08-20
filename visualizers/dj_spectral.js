// DJ Spectral Wave — Pioneer CDJ-3000 / Rekordbox 3-Band Frequency-Colored Waveform
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height
  var isPlaying = d.playing
  var progress = d.progress !== undefined ? d.progress : (d.state ? d.state.progress || 0 : 0)
  var beatDrop = d.beatDrop || 0
  var midY = h / 2.0

  // 48 high-definition DJ frequency columns
  var numBars = 48
  var margin = 6
  var totalDrawW = w - margin * 2
  var gap = 2.0
  var barW = Math.max(2.5, (totalDrawW - (numBars - 1) * gap) / numBars)
  var actualW = numBars * barW + (numBars - 1) * gap
  var startX = margin + (totalDrawW - actualW) / 2.0
  var playheadX = startX + progress * actualW

  // Compute live 3-band energy averages
  var lowAvg = H.bandAvg(bands, 0, 4)   // Bass / Kicks (20-250 Hz)
  var midAvg = H.bandAvg(bands, 4, 15)  // Vocals / Synths (250-4000 Hz)
  var highAvg = H.bandAvg(bands, 15, 24) // Hi-hats / Air (4000-20000 Hz)

  // Resample individual frequency bands across timeline
  var resampledAll = H.resampleBandsLinear(bands, numBars)

  for (var i = 0; i < numBars; i++) {
    var bx = startX + i * (barW + gap)
    var barCenter = bx + barW / 2.0
    var isPlayed = barCenter <= playheadX

    // Simulated track profile envelope
    var env = Math.sin((i / numBars) * Math.PI)
    var shapeVal = 0.20 + env * 0.45 + Math.sin(i * 0.9) * 0.12

    // Band energy weights per section of timeline
    var liveVal = isPlaying ? (resampledAll[i] || 0) : 0.0
    var kickBoost = (i % 6 < 2) ? beatDrop * 0.30 : 0.0

    // 3-Band Heights
    // 1. Lows (Sub/Bass): Blue / Deep Indigo
    var lowH = Math.max(3.0, (shapeVal * 0.35 + lowAvg * 0.55 + kickBoost) * (h * 0.82))
    // 2. Mids (Vocals/Lead): Amber / Neon Gold
    var midH = Math.max(2.0, (shapeVal * 0.28 + midAvg * 0.45 + liveVal * 0.25) * (h * 0.58))
    // 3. Highs (Transients): Crisp White / Ice Cyan
    var highH = Math.max(1.5, (shapeVal * 0.20 + highAvg * 0.40) * (h * 0.38))

    var r = Math.min(barW / 2.0, 2.0)

    // Opacity multiplier: Played = 1.0, Unplayed = 0.32
    var alphaMul = isPlayed ? 1.0 : 0.32

    // ── Tier 1: Lows (Outer Bass Spine - Electric Blue / Cyan) ──
    var lowY = midY - (lowH / 2.0)
    var lowGrad = ctx.createLinearGradient(0, lowY, 0, lowY + lowH)
    lowGrad.addColorStop(0, "rgba(0, 180, 255, " + (0.90 * alphaMul).toFixed(2) + ")")
    lowGrad.addColorStop(0.5, "rgba(20, 90, 255, " + (0.75 * alphaMul).toFixed(2) + ")")
    lowGrad.addColorStop(1, "rgba(0, 180, 255, " + (0.90 * alphaMul).toFixed(2) + ")")
    ctx.fillStyle = lowGrad
    ctx.beginPath()
    ctx.roundRect(bx, lowY, barW, lowH, r)
    ctx.fill()

    // ── Tier 2: Mids (Mid Body - Neon Amber / Orange) ──
    var midYPos = midY - (midH / 2.0)
    var midGrad = ctx.createLinearGradient(0, midYPos, 0, midYPos + midH)
    midGrad.addColorStop(0, "rgba(255, 180, 0, " + (0.95 * alphaMul).toFixed(2) + ")")
    midGrad.addColorStop(0.5, "rgba(255, 110, 20, " + (0.85 * alphaMul).toFixed(2) + ")")
    midGrad.addColorStop(1, "rgba(255, 180, 0, " + (0.95 * alphaMul).toFixed(2) + ")")
    ctx.fillStyle = midGrad
    ctx.beginPath()
    ctx.roundRect(bx, midYPos, barW, midH, r)
    ctx.fill()

    // ── Tier 3: Highs (Center Core - Pure White / Sparkle) ──
    var highY = midY - (highH / 2.0)
    ctx.fillStyle = "rgba(255, 255, 255, " + (0.95 * alphaMul).toFixed(2) + ")"
    ctx.beginPath()
    ctx.roundRect(bx + (barW > 3 ? 0.5 : 0), highY, Math.max(1.5, barW - 1), highH, r)
    ctx.fill()
  }

  // ── DJ Cue Cursor Line & Marker ──
  if (isPlaying && actualW > 0) {
    var curX = Math.max(startX, Math.min(startX + actualW, playheadX))

    // Vertical neon cue line
    ctx.fillStyle = "#ffffff"
    ctx.fillRect(curX - 1, 3, 2, h - 6)

    // Top cue triangle (pointing down)
    ctx.fillStyle = "#00e5ff"
    ctx.beginPath()
    ctx.moveTo(curX - 4, 3)
    ctx.lineTo(curX + 4, 3)
    ctx.lineTo(curX, 8)
    ctx.closePath()
    ctx.fill()

    // Bottom cue triangle (pointing up)
    ctx.beginPath()
    ctx.moveTo(curX - 4, h - 3)
    ctx.lineTo(curX + 4, h - 3)
    ctx.lineTo(curX, h - 8)
    ctx.closePath()
    ctx.fill()
  }
}
