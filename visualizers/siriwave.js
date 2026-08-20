// Siri Wave (iOS 9 Fluorescent Wave) — High-polish multi-layer fluid engine
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0
  var nBands = bands.length || 24

  var bass = H.bandAvg(bands, 0, 4)
  var mids = H.bandAvg(bands, 4, 12)
  var highs = H.bandAvg(bands, 12, 24)
  var beatDrop = d.beatDrop || 0

  // Dynamic amplitude with Apple critically-damped spring response
  var targetAmp = isPlaying ? Math.min(h * 0.44, (h * 0.08) + (bass * (h * 0.38)) + (beatDrop * 10.0)) : 1.8
  var baseAmp = targetAmp
  var phase = frame * 0.065

  // Apple Global Attenuation Formula: (4 / (4 + x^4))^4 for domain x in [-2, 2]
  function globalAttenuation(x) {
    var x2 = x * x
    var x4 = x2 * x2
    return Math.pow(4.0 / (4.0 + x4), 4.0)
  }

  // 1. Fluid Multi-Layer Color Curves (Official iOS 9 Fluorescent Tri-Color Harmony)
  // Each color has 2-3 layered sub-waves with harmonic phase & frequency offsets
  var layers = [
    // --- Blue Layer (Deep electric blue foundation) ---
    { r: 15,  g: 82,  b: 169, alpha: 0.40, freq: 1.1, speed: 1.0,  phaseOff: 0.0, gain: 1.00, energy: bass },
    { r: 35,  g: 110, b: 210, alpha: 0.30, freq: 1.5, speed: 0.8,  phaseOff: 1.8, gain: 0.75, energy: bass },

    // --- Red / Magenta Layer (Vibrant mid-harmonic energy) ---
    { r: 173, g: 57,  b: 76,  alpha: 0.42, freq: 1.6, speed: -1.2, phaseOff: 1.2, gain: 0.85, energy: mids },
    { r: 215, g: 45,  b: 105, alpha: 0.28, freq: 2.1, speed: -0.9, phaseOff: 3.0, gain: 0.65, energy: mids },

    // --- Emerald Green Layer (Luminous high-frequency shimmer) ---
    { r: 48,  g: 220, b: 155, alpha: 0.38, freq: 2.0, speed: 1.4,  phaseOff: 2.4, gain: 0.70, energy: highs },
    { r: 80,  g: 245, b: 180, alpha: 0.25, freq: 2.6, speed: 1.1,  phaseOff: 4.2, gain: 0.50, energy: highs }
  ]

  // Render fluid colored wave shapes
  for (var c = 0; c < layers.length; c++) {
    var ly = layers[c]
    var curPhase = phase * ly.speed + ly.phaseOff
    var waveScale = baseAmp * ly.gain + (isPlaying ? ly.energy * (h * 0.18) : 0)

    // Fluid vertical gradient fill
    var grad = ctx.createLinearGradient(0, midY - waveScale, 0, midY + waveScale * 0.5)
    grad.addColorStop(0, "rgba(" + ly.r + "," + ly.g + "," + ly.b + "," + ly.alpha + ")")
    grad.addColorStop(1, "rgba(" + ly.r + "," + ly.g + "," + ly.b + ", 0.02)")

    ctx.fillStyle = grad
    ctx.beginPath()
    ctx.moveTo(0, midY)

    // Top curve
    var step = 2
    for (var i = 0; i <= w; i += step) {
      var xNorm = (i / w) * 4.0 - 2.0 // Map to [-2, 2]
      var att = globalAttenuation(xNorm)
      var bIdx = Math.min(nBands - 1, Math.floor((i / w) * nBands))
      var bEnergy = isPlaying ? (bands[bIdx] || 0) : 0.01
      var disp = Math.sin(xNorm * ly.freq * Math.PI + curPhase) * (waveScale + bEnergy * 6.0) * att
      ctx.lineTo(i, midY - disp)
    }

    // Bottom curve
    for (var j = w; j >= 0; j -= step) {
      var xNormB = (j / w) * 4.0 - 2.0
      var attB = globalAttenuation(xNormB)
      var bIdxB = Math.min(nBands - 1, Math.floor((j / w) * nBands))
      var bEnergyB = isPlaying ? (bands[bIdxB] || 0) : 0.01
      var dispB = Math.sin(xNormB * ly.freq * Math.PI + curPhase) * (waveScale + bEnergyB * 6.0) * attB
      ctx.lineTo(j, midY + dispB * 0.28)
    }

    ctx.closePath()
    ctx.fill()
  }

  // 2. Secondary Glowing Cyan/Magenta Accent Line
  ctx.strokeStyle = "rgba(100, 220, 255, 0.40)"
  ctx.lineWidth = 1.2
  ctx.beginPath()
  for (var k2 = 0; k2 <= w; k2 += 2) {
    var xk2 = (k2 / w) * 4.0 - 2.0
    var attK2 = globalAttenuation(xk2)
    var bIdxK2 = Math.min(nBands - 1, Math.floor((k2 / w) * nBands))
    var bEnergyK2 = isPlaying ? (bands[bIdxK2] || 0) : 0.01
    var ySub = midY - Math.sin(xk2 * 1.8 * Math.PI + phase * 1.2 + 0.5) * (baseAmp * 0.85 + bEnergyK2 * 6.0) * attK2
    if (k2 === 0) ctx.moveTo(k2, ySub)
    else ctx.lineTo(k2, ySub)
  }
  ctx.stroke()

  // 3. Primary White Glowing Support Line (The signature Apple Siri Crest)
  ctx.strokeStyle = "rgba(255, 255, 255, 0.96)"
  ctx.lineWidth = 2.0
  ctx.beginPath()

  for (var k = 0; k <= w; k += 2) {
    var xk = (k / w) * 4.0 - 2.0
    var attK = globalAttenuation(xk)
    var bIdxK = Math.min(nBands - 1, Math.floor((k / w) * nBands))
    var bEnergyK = isPlaying ? (bands[bIdxK] || 0) : 0.01
    var yPrimary = midY - Math.sin(xk * 1.35 * Math.PI + phase * 1.0) * (baseAmp * 1.08 + bEnergyK * 7.5) * attK
    if (k === 0) ctx.moveTo(k, yPrimary)
    else ctx.lineTo(k, yPrimary)
  }
  ctx.stroke()
}
