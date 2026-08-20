// SiriWave (iOS 9) — The fluorescent multi-chromatic fluid wave introduced in iOS 9 (siriwavejs)
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

  // Amplitude driven by audio energy (rests gently when idle)
  var baseAmp = isPlaying ? Math.min(h * 0.46, (h * 0.06) + (bass * (h * 0.40)) + (beatDrop * 8.0)) : 1.5
  var phase = frame * 0.08

  // Official iOS 9 global attenuation function: (4 / (4 + x^4))^4 on x in [-2, 2]
  function globalAttenuation(x) {
    var x2 = x * x
    var x4 = x2 * x2
    return Math.pow(4.0 / (4.0 + x4), 4.0)
  }

  // Official iOS 9 SiriWave color definitions
  var curves = [
    { color: "15, 82, 169",   speed: 1.0,  freq: 1.2, desync: 0.0,  gain: 1.0 },                 // Blue
    { color: "173, 57, 76",   speed: -1.2, freq: 1.7, desync: 1.5,  gain: 0.85 + mids * 0.35 },  // Red/Pink
    { color: "48, 220, 155",  speed: 1.5,  freq: 2.1, desync: 2.8,  gain: 0.70 + highs * 0.45 }  // Green
  ]

  // 1. Draw iOS 9 Fluorescent Colored Wave Shapes
  for (var c = 0; c < curves.length; c++) {
    var cv = curves[c]
    var curPhase = phase * cv.speed + cv.desync

    ctx.fillStyle = "rgba(" + cv.color + ", 0.55)"
    ctx.beginPath()
    ctx.moveTo(0, midY)

    // Top wave curve
    for (var i = 0; i <= w; i += 2) {
      var xNorm = (i / w) * 4.0 - 2.0 // Domain [-2, 2]
      var att = globalAttenuation(xNorm)
      var bIdx = Math.min(nBands - 1, Math.floor((i / w) * nBands))
      var bEnergy = isPlaying ? (bands[bIdx] || 0) : 0.02
      var disp = Math.sin(xNorm * cv.freq * Math.PI + curPhase) * (baseAmp * cv.gain + bEnergy * 6.0) * att
      ctx.lineTo(i, midY - disp)
    }

    // Bottom mirror wave curve
    for (var j = w; j >= 0; j -= 2) {
      var xNormB = (j / w) * 4.0 - 2.0
      var attB = globalAttenuation(xNormB)
      var bIdxB = Math.min(nBands - 1, Math.floor((j / w) * nBands))
      var bEnergyB = isPlaying ? (bands[bIdxB] || 0) : 0.02
      var dispB = Math.sin(xNormB * cv.freq * Math.PI + curPhase) * (baseAmp * cv.gain + bEnergyB * 6.0) * attB
      ctx.lineTo(j, midY + dispB * 0.25)
    }

    ctx.closePath()
    ctx.fill()
  }

  // 2. White Primary Support Line ({ color: "255, 255, 255", supportLine: true })
  ctx.strokeStyle = "rgba(255, 255, 255, 0.95)"
  ctx.lineWidth = 1.8
  ctx.beginPath()
  ctx.moveTo(0, midY)

  for (var k = 0; k <= w; k += 2) {
    var xk = (k / w) * 4.0 - 2.0
    var attK = globalAttenuation(xk)
    var bIdxK = Math.min(nBands - 1, Math.floor((k / w) * nBands))
    var bEnergyK = isPlaying ? (bands[bIdxK] || 0) : 0.02
    var yPrimary = midY - Math.sin(xk * 1.5 * Math.PI + phase) * (baseAmp * 1.05 + bEnergyK * 7.0) * attK
    ctx.lineTo(k, yPrimary)
  }
  ctx.stroke()
}
