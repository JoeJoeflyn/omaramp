// Siri Wave — Silky smooth, uncropped Apple fluid wave with acoustic energy modulation
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0

  // 1. Audio Energy (Smooth Low-Pass Averages)
  var bass = H.bandAvg(bands, 0, 5)
  var mids = H.bandAvg(bands, 5, 14)
  var highs = H.bandAvg(bands, 14, 24)
  var totalEnergy = bass * 0.5 + mids * 0.35 + highs * 0.15
  var beatDrop = d.beatDrop || 0

  // If paused or completely silent, draw a clean resting flat line
  if (!isPlaying || totalEnergy < 0.005) {
    ctx.strokeStyle = "rgba(255, 255, 255, 0.20)"
    ctx.lineWidth = 1.0
    ctx.beginPath()
    ctx.moveTo(0, midY)
    ctx.lineTo(w, midY)
    ctx.stroke()
    return
  }

  // 2. Safe Peak Amplitude Envelope (Guarantees NO cropping/clipping on top or bottom)
  var maxSafeAmp = h * 0.36
  var bassAmp = Math.min(maxSafeAmp, (h * 0.08) + (bass * (h * 0.24)) + (beatDrop * (h * 0.08)))
  var midsAmp = Math.min(maxSafeAmp * 0.9, (h * 0.06) + (mids * (h * 0.22)))
  var highsAmp = Math.min(maxSafeAmp * 0.8, (h * 0.05) + (highs * (h * 0.20)))

  // Smooth, non-chaotic phase travel modulated by music tempo
  var speed = 0.035 + (totalEnergy * 0.035)
  var phase = frame * speed

  // Apple Global Attenuation Formula: (4 / (4 + x^4))^4 on x in [-2, 2]
  function globalAttenuation(x) {
    var x2 = x * x
    var x4 = x2 * x2
    return Math.pow(4.0 / (4.0 + x4), 4.0)
  }

  // 3. Tri-Color Fluorescent Ribbons (Pure Harmonic Sine Curves with Zero Jagged Noise)
  var ribbons = [
    { r: 15,  g: 82,  b: 169, alpha: 0.55, freq: 1.15, speed: 1.0,  phaseOff: 0.0, amp: bassAmp },
    { r: 173, g: 57,  b: 76,  alpha: 0.50, freq: 1.65, speed: -1.2, phaseOff: 1.4, amp: midsAmp },
    { r: 48,  g: 220, b: 155, alpha: 0.45, freq: 2.15, speed: 1.5,  phaseOff: 2.8, amp: highsAmp }
  ]

  // Render 3 fluid harmonic color curves
  for (var c = 0; c < ribbons.length; c++) {
    var rb = ribbons[c]
    var curPhase = phase * rb.speed + rb.phaseOff

    var grad = ctx.createLinearGradient(0, midY - rb.amp, 0, midY + rb.amp * 0.5)
    grad.addColorStop(0, "rgba(" + rb.r + "," + rb.g + "," + rb.b + "," + rb.alpha + ")")
    grad.addColorStop(1, "rgba(" + rb.r + "," + rb.g + "," + rb.b + ", 0.02)")

    ctx.fillStyle = grad
    ctx.beginPath()
    ctx.moveTo(0, midY)

    // Top smooth curve
    for (var i = 0; i <= w; i += 2) {
      var xNorm = (i / w) * 4.0 - 2.0 // Domain [-2, 2]
      var att = globalAttenuation(xNorm)
      var disp = Math.sin(xNorm * rb.freq * Math.PI + curPhase) * rb.amp * att
      ctx.lineTo(i, midY - disp)
    }

    // Bottom mirror curve (subtle reflection)
    for (var j = w; j >= 0; j -= 2) {
      var xNormB = (j / w) * 4.0 - 2.0
      var attB = globalAttenuation(xNormB)
      var dispB = Math.sin(xNormB * rb.freq * Math.PI + curPhase) * (rb.amp * 0.28) * attB
      ctx.lineTo(j, midY + dispB)
    }

    ctx.closePath()
    ctx.fill()
  }

  // 4. Primary Luminous White Support Line (Apple Siri Crest)
  ctx.strokeStyle = "rgba(255, 255, 255, 0.95)"
  ctx.lineWidth = 2.0
  ctx.beginPath()

  var crestAmp = Math.min(maxSafeAmp, (h * 0.08) + (totalEnergy * (h * 0.25)) + (beatDrop * (h * 0.06)))
  for (var k = 0; k <= w; k += 2) {
    var xk = (k / w) * 4.0 - 2.0
    var attK = globalAttenuation(xk)
    var yDisp = Math.sin(xk * 1.35 * Math.PI + phase) * crestAmp * attK
    var yPos = midY - yDisp

    if (k === 0) ctx.moveTo(k, yPos)
    else ctx.lineTo(k, yPos)
  }
  ctx.stroke()
}
