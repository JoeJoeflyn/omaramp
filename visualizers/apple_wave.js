// Apple Sound Wave — Official Siri mathematical algorithm (globalAttenuation = (4/(4+x^4))^4)
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0

  var bass = H.bandAvg(bands, 0, 4)
  var mids = H.bandAvg(bands, 4, 12)
  var highs = H.bandAvg(bands, 12, 24)
  var beatDrop = d.beatDrop || 0

  // Amplitude directly driven by live audio energy (bass & kicks)
  var amp = isPlaying ? Math.min(h * 0.48, (h * 0.08) + bass * (h * 0.40) + beatDrop * 8.0) : 2.0
  var phase = frame * 0.075

  // 1. Apple Global Attenuation Formula: (4 / (4 + x^4))^4 on domain x in [-2, 2]
  function globalAttenuation(x) {
    var x2 = x * x
    var x4 = x2 * x2
    return Math.pow(4.0 / (4.0 + x4), 4.0)
  }

  // 2. iOS 9 / Apple Intelligence Multi-Chromatic Fluid Wave Blobs
  var curves = [
    { color: "53, 119, 246", alpha: 0.60, speed: 1.0,  freq: 1.2, desync: 0.0,  gain: 1.0 },
    { color: "236, 72, 153", alpha: 0.55, speed: -1.2, freq: 1.7, desync: 1.4,  gain: 0.85 + mids * 0.35 },
    { color: "18, 234, 146", alpha: 0.50, speed: 1.5,  freq: 2.2, desync: 2.6,  gain: 0.70 + highs * 0.45 }
  ]

  for (var c = 0; c < curves.length; c++) {
    var cv = curves[c]
    var curPhase = phase * cv.speed + cv.desync

    ctx.fillStyle = "rgba(" + cv.color + "," + cv.alpha + ")"
    ctx.beginPath()
    ctx.moveTo(0, midY)

    // Top curve
    for (var i = 0; i <= w; i += 2) {
      var xNorm = (i / w) * 4.0 - 2.0 // Range [-2, 2]
      var att = globalAttenuation(xNorm)
      var bIdx = Math.min(bands.length - 1, Math.floor((i / w) * bands.length))
      var bEnergy = isPlaying ? (bands[bIdx] || 0) : 0.05
      var disp = Math.sin(xNorm * cv.freq * Math.PI + curPhase) * (amp * cv.gain + bEnergy * 7.0) * att
      ctx.lineTo(i, midY - disp)
    }

    // Bottom curve
    for (var j = w; j >= 0; j -= 2) {
      var xNormB = (j / w) * 4.0 - 2.0
      var attB = globalAttenuation(xNormB)
      var bIdxB = Math.min(bands.length - 1, Math.floor((j / w) * bands.length))
      var bEnergyB = isPlaying ? (bands[bIdxB] || 0) : 0.05
      var dispB = Math.sin(xNormB * cv.freq * Math.PI + curPhase) * (amp * cv.gain + bEnergyB * 7.0) * attB
      ctx.lineTo(j, midY + dispB * 0.3)
    }

    ctx.closePath()
    ctx.fill()
  }

  // 3. Classic Attenuated Siri Sine Lines
  var classicLines = [
    { attPower: 1.0,  lineWidth: 2.0, color: "rgba(255, 255, 255, 0.95)", freq: 1.3, speed: 1.0 },
    { attPower: 2.0,  lineWidth: 1.2, color: "rgba(100, 220, 255, 0.70)", freq: 1.6, speed: -1.1 },
    { attPower: -2.0, lineWidth: 1.0, color: "rgba(255, 120, 220, 0.50)", freq: 2.0, speed: 1.4 }
  ]

  for (var cl = 0; cl < classicLines.length; cl++) {
    var line = classicLines[cl]
    ctx.lineWidth = line.lineWidth
    ctx.strokeStyle = line.color
    ctx.beginPath()

    for (var k = 0; k <= w; k += 2) {
      var xk = (k / w) * 4.0 - 2.0
      var attK = globalAttenuation(xk)
      var bIdxK = Math.min(bands.length - 1, Math.floor((k / w) * bands.length))
      var bEnergyK = isPlaying ? (bands[bIdxK] || 0) : 0.05
      var yDisp = Math.sin(xk * line.freq * Math.PI + phase * line.speed) * ((amp / Math.abs(line.attPower)) + bEnergyK * 6.0) * attK
      var yPos = midY - (line.attPower < 0 ? -yDisp : yDisp)
      if (k === 0) ctx.moveTo(k, yPos)
      else ctx.lineTo(k, yPos)
    }
    ctx.stroke()
  }
}
