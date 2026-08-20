// Sine — Multi-frequency Harmonic Sine Ribbon Visualizer
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

  var acc = d.accent
  var ar = 100, ag = 170, ab = 255
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

  var t = frame * 0.04
  var waves = [
    { freq: 0.015, speed: 1.0, amp: isPlaying ? (4.0 + bass * (h * 0.40)) : 2.0, col: "rgba(" + ar + "," + ag + "," + ab + ", 0.85)", width: 2.2 },
    { freq: 0.028, speed: -1.4, amp: isPlaying ? (3.0 + mids * (h * 0.32)) : 1.5, col: "rgba(" + Math.min(255, ar + 40) + "," + Math.min(255, ag + 30) + ", 255, 0.70)", width: 1.8 },
    { freq: 0.045, speed: 2.0, amp: isPlaying ? (2.0 + highs * (h * 0.24)) : 1.0, col: "rgba(255, 225, 130, 0.60)", width: 1.4 }
  ]

  for (var wi = 0; wi < waves.length; wi++) {
    var wv = waves[wi]
    ctx.beginPath()
    ctx.lineWidth = wv.width
    ctx.strokeStyle = wv.col

    for (var x = 0; x <= w; x += 3) {
      // Gaussian window to taper wave gracefully at left and right borders
      var normX = (x / w) * 2.0 - 1.0
      var envelope = Math.exp(-normX * normX * 3.0)
      var y = midY + Math.sin(x * wv.freq + t * wv.speed) * wv.amp * envelope
      if (x === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.stroke()
  }
}
