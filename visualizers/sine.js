// Sine — Pure Oscilloscope Harmonic Sine Wave (Clean, high-precision mathematical generator)
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0

  // 1. Audio Energy
  var bass = H.bandAvg(bands, 0, 4)
  var mids = H.bandAvg(bands, 4, 12)
  var highs = H.bandAvg(bands, 12, 24)
  var totalEnergy = bass * 0.5 + mids * 0.35 + highs * 0.15
  var beatDrop = d.beatDrop || 0

  // Serene flat line when quiet / paused
  if (!isPlaying || totalEnergy < 0.005) {
    ctx.strokeStyle = "rgba(255, 255, 255, 0.20)"
    ctx.lineWidth = 1.0
    ctx.beginPath()
    ctx.moveTo(0, midY)
    ctx.lineTo(w, midY)
    ctx.stroke()
    return
  }

  // Dynamic theme accent color
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

  // Safe amplitude ceiling (prevents all vertical cropping)
  var maxSafe = h * 0.36
  var speed = 0.04 + totalEnergy * 0.04
  var t = frame * speed

  // Edge windowing function (smooth taper to ends)
  function edgeWindow(x) {
    return Math.sin((x / w) * Math.PI)
  }

  // 2. Pure Dual-Harmonic Sine Wave (Distinct Oscilloscope Style)
  var fundamentalAmp = Math.min(maxSafe, (h * 0.08) + bass * (h * 0.26) + beatDrop * (h * 0.08))
  var harmonicAmp = Math.min(maxSafe * 0.6, (h * 0.04) + mids * (h * 0.18))

  // Soft Ambient Glow Underfill (Pure accent tone)
  ctx.beginPath()
  ctx.moveTo(0, midY)
  for (var x = 0; x <= w; x += 2) {
    var wF = edgeWindow(x)
    var rad = (x / w) * (2.0 * Math.PI) + t
    var yVal = midY - Math.sin(rad) * fundamentalAmp * wF
    ctx.lineTo(x, yVal)
  }
  ctx.lineTo(w, midY)
  ctx.closePath()
  ctx.fillStyle = "rgba(" + ar + "," + ag + "," + ab + ", 0.10)"
  ctx.fill()

  // Secondary Harmonic Trace (Sub-octave phosphor ghost)
  ctx.lineWidth = 1.2
  ctx.strokeStyle = "rgba(" + ar + "," + ag + "," + ab + ", 0.40)"
  ctx.beginPath()
  for (var x2 = 0; x2 <= w; x2 += 2) {
    var wF2 = edgeWindow(x2)
    var rad2 = (x2 / w) * (4.0 * Math.PI) - (t * 1.4)
    var yVal2 = midY - Math.sin(rad2) * harmonicAmp * wF2
    if (x2 === 0) ctx.moveTo(x2, yVal2)
    else ctx.lineTo(x2, yVal2)
  }
  ctx.stroke()

  // Primary Crisp Sine Trace (Pure mathematical curve in vivid accent + white core)
  ctx.lineWidth = 2.2
  ctx.strokeStyle = "rgba(" + ar + "," + ag + "," + ab + ", 0.95)"
  ctx.beginPath()
  for (var x3 = 0; x3 <= w; x3 += 2) {
    var wF3 = edgeWindow(x3)
    var rad3 = (x3 / w) * (2.0 * Math.PI) + t
    var yVal3 = midY - Math.sin(rad3) * fundamentalAmp * wF3
    if (x3 === 0) ctx.moveTo(x3, yVal3)
    else ctx.lineTo(x3, yVal3)
  }
  ctx.stroke()

  // Glowing Luminous Core Highlight
  ctx.lineWidth = 1.0
  ctx.strokeStyle = "rgba(255, 255, 255, 0.85)"
  ctx.beginPath()
  for (var x4 = 0; x4 <= w; x4 += 2) {
    var wF4 = edgeWindow(x4)
    var rad4 = (x4 / w) * (2.0 * Math.PI) + t
    var yVal4 = midY - Math.sin(rad4) * fundamentalAmp * wF4
    if (x4 === 0) ctx.moveTo(x4, yVal4)
    else ctx.lineTo(x4, yVal4)
  }
  ctx.stroke()
}
