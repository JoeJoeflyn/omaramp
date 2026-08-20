// Siri Wave — Genuinely audio-driven fluid multi-chromatic spectrum engine
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var rawWave = d.wave || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0
  var nBands = bands.length || 24

  // Real-time audio metrics
  var bass = H.bandAvg(bands, 0, 5)
  var mids = H.bandAvg(bands, 5, 14)
  var highs = H.bandAvg(bands, 14, 24)
  var totalEnergy = (bass * 0.5 + mids * 0.35 + highs * 0.15)
  var beatDrop = d.beatDrop || 0

  // Strictly collapse to 0 when paused or completely silent (No fake static motion)
  if (!isPlaying || totalEnergy < 0.005) {
    // Flat serene resting line
    ctx.strokeStyle = "rgba(255, 255, 255, 0.25)"
    ctx.lineWidth = 1.0
    ctx.beginPath()
    ctx.moveTo(0, midY)
    ctx.lineTo(w, midY)
    ctx.stroke()
    return
  }

  // Audio-coupled phase velocity: waves move faster during high-energy music
  var speedMult = 0.03 + (totalEnergy * 0.08)
  var phase = frame * speedMult

  // Apple Global Attenuation Formula: (4 / (4 + x^4))^4 for domain x in [-2, 2]
  function globalAttenuation(x) {
    var x2 = x * x
    var x4 = x2 * x2
    return Math.pow(4.0 / (4.0 + x4), 4.0)
  }

  // Frequency-coupled ribbons:
  // - Blue: Sub-bass & kicks
  // - Red/Magenta: Vocals & mid-range instrumentation
  // - Green: Highs, hi-hats, percussions
  var curves = [
    { r: 15,  g: 82,  b: 169, alpha: 0.55, freq: 1.0, speed: 1.0,  phaseOff: 0.0, startB: 0,  endB: 6,  power: bass * 1.4 + beatDrop * 0.5 },
    { r: 173, g: 57,  b: 76,  alpha: 0.55, freq: 1.8, speed: -1.3, phaseOff: 1.6, startB: 6,  endB: 15, power: mids * 1.3 },
    { r: 48,  g: 220, b: 155, alpha: 0.50, freq: 2.6, speed: 1.7,  phaseOff: 3.2, startB: 15, endB: 24, power: highs * 1.3 }
  ]

  // 1. Draw the 3 Audio-Sculpted Fluorescent Ribbons
  for (var c = 0; c < curves.length; c++) {
    var cv = curves[c]
    var curPhase = phase * cv.speed + cv.desync
    var amp = Math.min(h * 0.46, cv.power * (h * 0.65))
    if (amp < 1.0) continue

    var grad = ctx.createLinearGradient(0, midY - amp, 0, midY + amp * 0.6)
    grad.addColorStop(0, "rgba(" + cv.r + "," + cv.g + "," + cv.b + "," + cv.alpha + ")")
    grad.addColorStop(1, "rgba(" + cv.r + "," + cv.g + "," + cv.b + ", 0.03)")

    ctx.fillStyle = grad
    ctx.beginPath()
    ctx.moveTo(0, midY)

    // Top crest modulated by FFT band distribution
    for (var i = 0; i <= w; i += 2) {
      var xNorm = (i / w) * 4.0 - 2.0 // [-2, 2]
      var att = globalAttenuation(xNorm)
      var normIdx = (xNorm + 2.0) / 4.0 // [0, 1]
      var bIdx = Math.min(nBands - 1, Math.max(0, Math.floor(cv.startB + normIdx * (cv.endB - cv.startB))))
      var bVal = bands[bIdx] || 0.0

      // Acoustic wave displacement combines sine carrier with real FFT bin amplitude
      var waveVal = Math.sin(xNorm * cv.freq * Math.PI + curPhase)
      var disp = (waveVal * amp * (0.4 + bVal * 1.2)) * att
      ctx.lineTo(i, midY - disp)
    }

    // Bottom mirror curve
    for (var j = w; j >= 0; j -= 2) {
      var xNormB = (j / w) * 4.0 - 2.0
      var attB = globalAttenuation(xNormB)
      var normIdxB = (xNormB + 2.0) / 4.0
      var bIdxB = Math.min(nBands - 1, Math.max(0, Math.floor(cv.startB + normIdxB * (cv.endB - cv.startB))))
      var bValB = bands[bIdxB] || 0.0

      var waveValB = Math.sin(xNormB * cv.freq * Math.PI + curPhase)
      var dispB = (waveValB * amp * (0.3 + bValB * 0.8)) * attB
      ctx.lineTo(j, midY + dispB * 0.35)
    }

    ctx.closePath()
    ctx.fill()
  }

  // 2. Primary Luminous Support Crest Line (Directly displaced by raw audio waveform)
  var waveLen = rawWave.length
  ctx.strokeStyle = "rgba(255, 255, 255, 0.96)"
  ctx.lineWidth = 1.8
  ctx.beginPath()

  for (var k = 0; k <= w; k += 2) {
    var xk = (k / w) * 4.0 - 2.0
    var attK = globalAttenuation(xk)
    var bIdxK = Math.min(nBands - 1, Math.floor((k / w) * nBands))
    var bEnergyK = bands[bIdxK] || 0.0

    var rawSample = 0.0
    if (waveLen > 0) {
      var wIdx = Math.min(waveLen - 1, Math.floor((k / w) * waveLen))
      rawSample = rawWave[wIdx] || 0.0
    }

    // Blend harmonic carrier with live raw audio waveform sample
    var liveDisp = ((rawSample * (h * 0.38)) + Math.sin(xk * 1.35 * Math.PI + phase) * (bEnergyK * (h * 0.42))) * attK
    var yPrimary = midY - liveDisp

    if (k === 0) ctx.moveTo(k, yPrimary)
    else ctx.lineTo(k, yPrimary)
  }
  ctx.stroke()
}
