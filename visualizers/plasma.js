// Liquid Silk Plasma — Calibrated harmonic fluid field with edge attenuation and audio-reactive pacing
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0

  // 1. Acoustic Frequency Extraction
  var subBass = H.bandAvg(bands, 0, 4)
  var bass = H.bandAvg(bands, 0, 7)
  var mids = H.bandAvg(bands, 7, 16)
  var highs = H.bandAvg(bands, 16, 24)
  var totalEnergy = bass * 0.50 + mids * 0.35 + highs * 0.15
  var beatDrop = d.beatDrop || 0

  // Resting state when paused or quiet
  if (!isPlaying || totalEnergy < 0.005) {
    ctx.strokeStyle = "rgba(255, 255, 255, 0.15)"
    ctx.lineWidth = 1.0
    ctx.beginPath()
    ctx.moveTo(0, midY)
    ctx.lineTo(w, midY)
    ctx.stroke()
    return
  }

  var ar = (d.accent && d.accent.r !== undefined) ? d.accent.r : 0.0
  var ag = (d.accent && d.accent.g !== undefined) ? d.accent.g : 0.8
  var ab = (d.accent && d.accent.b !== undefined) ? d.accent.b : 1.0

  // 2. Controlled Acoustic Pacing (Calm, organic motion that speeds up on energy bursts)
  var speed = 0.010 + (totalEnergy * 0.018) + (beatDrop * 0.015)
  var phase = frame * speed

  // Safe vertical envelope so it never clips top or bottom borders
  var maxSafeAmp = h * 0.38
  var bassAmp = Math.min(maxSafeAmp, (h * 0.08) + (bass * (h * 0.22)) + (beatDrop * (h * 0.08)))
  var midsAmp = Math.min(maxSafeAmp * 0.9, (h * 0.06) + (mids * (h * 0.20)))
  var highsAmp = Math.min(maxSafeAmp * 0.8, (h * 0.05) + (highs * (h * 0.18)))

  // Smooth edge attenuation formula so waves taper gracefully to 0 at left and right edges
  function edgeAtt(xNorm) {
    var d = (xNorm - 0.5) * 2.0 // [-1, 1]
    var d2 = d * d
    return Math.max(0.0, 1.0 - d2 * d2)
  }

  // 3. Fluid Harmonic Silk Layers
  var layers = [
    { amp: bassAmp,  freq: 1.2, speed: 1.0,  phaseOff: 0.0, r: ar, g: ag * 0.6, b: ab, alpha: 0.55 },
    { amp: midsAmp,  freq: 1.8, speed: -0.9, phaseOff: 1.6, r: ab * 0.8, g: ar * 0.5, b: ag, alpha: 0.50 },
    { amp: highsAmp, freq: 2.4, speed: 1.3,  phaseOff: 3.2, r: Math.min(1, ar + 0.2), g: Math.min(1, ag + 0.2), b: Math.min(1, ab + 0.2), alpha: 0.45 }
  ]

  for (var l = 0; l < layers.length; l++) {
    var ly = layers[l]
    var curPhase = phase * ly.speed + ly.phaseOff

    var cr = Math.round(ly.r * 255)
    var cg = Math.round(ly.g * 255)
    var cb = Math.round(ly.b * 255)
    var a = (ly.alpha * (0.6 + totalEnergy * 0.4 + beatDrop * 0.2))

    // Under-fill gradient with smooth fade
    ctx.beginPath()
    ctx.moveTo(0, midY)

    for (var x = 0; x <= w; x += 2) {
      var xNorm = x / w
      var att = edgeAtt(xNorm)

      // Frequency band lookup across X
      var bIdx = Math.min(bands.length - 1, Math.floor(xNorm * (bands.length - 1)))
      var bVal = bands[bIdx] || 0.0

      // Trigonometric harmonic wave
      var s1 = Math.sin(xNorm * Math.PI * 2.0 * ly.freq + curPhase)
      var s2 = Math.sin(xNorm * Math.PI * 4.0 * ly.freq - curPhase * 0.6) * 0.3
      var waveVal = (s1 + s2) * (ly.amp * (0.6 + bVal * 0.6)) * att

      var y = midY - waveVal
      ctx.lineTo(x, y)
    }

    ctx.lineTo(w, midY)
    ctx.closePath()

    var grad = ctx.createLinearGradient(0, midY - ly.amp, 0, midY + ly.amp * 0.6)
    grad.addColorStop(0, "rgba(" + cr + "," + cg + "," + cb + "," + (a * 0.50).toFixed(2) + ")")
    grad.addColorStop(0.6, "rgba(" + cr + "," + cg + "," + cb + "," + (a * 0.15).toFixed(2) + ")")
    grad.addColorStop(1, "rgba(0, 0, 0, 0)")

    ctx.fillStyle = grad
    ctx.fill()

    // Glowing Silk Surface Line
    ctx.beginPath()
    for (var x2 = 0; x2 <= w; x2 += 2) {
      var xNorm2 = x2 / w
      var att2 = edgeAtt(xNorm2)
      var bIdx2 = Math.min(bands.length - 1, Math.floor(xNorm2 * (bands.length - 1)))
      var bVal2 = bands[bIdx2] || 0.0

      var s1b = Math.sin(xNorm2 * Math.PI * 2.0 * ly.freq + curPhase)
      var s2b = Math.sin(xNorm2 * Math.PI * 4.0 * ly.freq - curPhase * 0.6) * 0.3
      var waveVal2 = (s1b + s2b) * (ly.amp * (0.6 + bVal2 * 0.6)) * att2
      var y2 = midY - waveVal2

      if (x2 === 0) ctx.moveTo(x2, y2)
      else ctx.lineTo(x2, y2)
    }

    ctx.strokeStyle = "rgba(" + Math.min(255, cr + 70) + "," + Math.min(255, cg + 70) + "," + Math.min(255, cb + 70) + "," + (a * 0.95).toFixed(2) + ")"
    ctx.lineWidth = l === 0 ? 2.0 : 1.3
    ctx.stroke()
  }
}
