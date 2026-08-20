// Siri Wave — Authentic iOS 9 Fluorescent Multi-Chromatic Audio-Reactive Wave
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0
  var nBands = bands.length || 24

  // Real-time audio band averages
  var bass = H.bandAvg(bands, 0, 5)
  var mids = H.bandAvg(bands, 5, 14)
  var highs = H.bandAvg(bands, 14, 24)
  var totalEnergy = (bass * 0.5 + mids * 0.35 + highs * 0.15)
  var beatDrop = d.beatDrop || 0

  // When paused or completely silent, render a clean serene flat line
  if (!isPlaying || totalEnergy < 0.005) {
    ctx.strokeStyle = "rgba(255, 255, 255, 0.20)"
    ctx.lineWidth = 1.0
    ctx.beginPath()
    ctx.moveTo(0, midY)
    ctx.lineTo(w, midY)
    ctx.stroke()
    return
  }

  // Live audio speed modulation: phase accelerates on heavy beats
  var speed = 0.04 + totalEnergy * 0.08
  var phase = frame * speed

  // Apple Global Attenuation Formula: (4 / (4 + x^4))^4 for x in [-2, 2]
  function globalAttenuation(x) {
    var x2 = x * x
    var x4 = x2 * x2
    return Math.pow(4.0 / (4.0 + x4), 4.0)
  }

  // Tri-color fluorescent ribbons (iOS 9 definition)
  // Each color is mapped to its frequency domain (Blue: Bass, Red: Mids, Green: Highs)
  var curves = [
    { r: 15,  g: 82,  b: 169, alpha: 0.60, freq: 1.1, speed: 1.0,  phaseOff: 0.0, energy: bass * 1.5 + beatDrop * 0.6, startB: 0,  endB: 6 },
    { r: 173, g: 57,  b: 76,  alpha: 0.55, freq: 1.7, speed: -1.3, phaseOff: 1.5, energy: mids * 1.4,                 startB: 6,  endB: 15 },
    { r: 48,  g: 220, b: 155, alpha: 0.50, freq: 2.3, speed: 1.6,  phaseOff: 3.1, energy: highs * 1.4,                startB: 15, endB: 24 }
  ]

  // 1. Draw 3 Fluid Colored Waves
  for (var c = 0; c < curves.length; c++) {
    var cv = curves[c]
    var curPhase = phase * cv.speed + cv.phaseOff
    var waveAmp = Math.min(h * 0.44, (h * 0.06) + cv.energy * (h * 0.42))

    var grad = ctx.createLinearGradient(0, midY - waveAmp, 0, midY + waveAmp * 0.5)
    grad.addColorStop(0, "rgba(" + cv.r + "," + cv.g + "," + cv.b + "," + cv.alpha + ")")
    grad.addColorStop(1, "rgba(" + cv.r + "," + cv.g + "," + cv.b + ", 0.02)")

    ctx.fillStyle = grad
    ctx.beginPath()
    ctx.moveTo(0, midY)

    // Top curve
    for (var i = 0; i <= w; i += 2) {
      var xNorm = (i / w) * 4.0 - 2.0 // [-2, 2]
      var att = globalAttenuation(xNorm)
      var normIdx = (xNorm + 2.0) / 4.0
      var bIdx = Math.min(nBands - 1, Math.max(0, Math.floor(cv.startB + normIdx * (cv.endB - cv.startB))))
      var bVal = bands[bIdx] || 0.0

      var disp = Math.sin(xNorm * cv.freq * Math.PI + curPhase) * (waveAmp + bVal * (h * 0.15)) * att
      ctx.lineTo(i, midY - disp)
    }

    // Bottom curve
    for (var j = w; j >= 0; j -= 2) {
      var xNormB = (j / w) * 4.0 - 2.0
      var attB = globalAttenuation(xNormB)
      var normIdxB = (xNormB + 2.0) / 4.0
      var bIdxB = Math.min(nBands - 1, Math.max(0, Math.floor(cv.startB + normIdxB * (cv.endB - cv.startB))))
      var bValB = bands[bIdxB] || 0.0

      var dispB = Math.sin(xNormB * cv.freq * Math.PI + curPhase) * (waveAmp + bValB * (h * 0.15)) * attB
      ctx.lineTo(j, midY + dispB * 0.3)
    }

    ctx.closePath()
    ctx.fill()
  }

  // 2. Primary Luminous White Support Line (Apple Siri Crest)
  ctx.strokeStyle = "rgba(255, 255, 255, 0.96)"
  ctx.lineWidth = 2.0
  ctx.beginPath()

  var crestAmp = Math.min(h * 0.45, (h * 0.06) + (totalEnergy * (h * 0.40)) + beatDrop * 8.0)
  for (var k = 0; k <= w; k += 2) {
    var xk = (k / w) * 4.0 - 2.0
    var attK = globalAttenuation(xk)
    var bIdxK = Math.min(nBands - 1, Math.floor((k / w) * nBands))
    var bEnergyK = bands[bIdxK] || 0.0

    var yDisp = Math.sin(xk * 1.35 * Math.PI + phase) * (crestAmp + bEnergyK * (h * 0.18)) * attK
    var yPos = midY - yDisp

    if (k === 0) ctx.moveTo(k, yPos)
    else ctx.lineTo(k, yPos)
  }
  ctx.stroke()
}
