// Sine — Live FFT-Displaced Multi-Harmonic Sine Wave Ribbon
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

  var t = frame * 0.05

  // 3 Harmonic Ribbons directly driven by real audio FFT bands + Beat Drop Energy
  var ribbons = [
    {
      freq: 0.022, speed: 1.0, width: 2.5,
      gain: isPlaying ? (12.0 + bass * (h * 0.45) + beatDrop * 10.0) : 1.0,
      col: "rgba(" + ar + "," + ag + "," + ab + ", 0.90)",
      fillCol: "rgba(" + ar + "," + ag + "," + ab + ", 0.12)"
    },
    {
      freq: 0.038, speed: -1.4, width: 1.8,
      gain: isPlaying ? (8.0 + mids * (h * 0.38)) : 1.0,
      col: "rgba(" + Math.min(255, ar + 50) + "," + Math.min(255, ag + 40) + ", 255, 0.75)",
      fillCol: "rgba(" + Math.min(255, ar + 50) + "," + Math.min(255, ag + 40) + ", 255, 0.08)"
    },
    {
      freq: 0.055, speed: 2.2, width: 1.4,
      gain: isPlaying ? (6.0 + highs * (h * 0.30)) : 0.8,
      col: "rgba(255, 230, 140, 0.65)",
      fillCol: "rgba(255, 230, 140, 0.05)"
    }
  ]

  for (var ri = 0; ri < ribbons.length; ri++) {
    var rb = ribbons[ri]
    ctx.beginPath()
    ctx.moveTo(0, midY)

    for (var x = 0; x <= w; x += 2) {
      // Map x position directly to actual frequency band (Left = Bass, Right = Highs)
      var bIdx = Math.min(nBands - 1, Math.floor((x / w) * nBands))
      var bandEnergy = isPlaying ? (bands[bIdx] || 0) : 0.05

      // Natural edge windowing
      var normX = (x / w) * 2.0 - 1.0
      var windowEdge = Math.max(0.0, 1.0 - Math.pow(Math.abs(normX), 3.0))

      // Sinusoidal carrier + direct audio FFT displacement
      var carrier = Math.sin(x * rb.freq + t * rb.speed)
      var audioDisplacement = (bandEnergy * rb.gain) * carrier
      var y = midY - audioDisplacement * windowEdge

      ctx.lineTo(x, y)
    }

    ctx.lineWidth = rb.width
    ctx.strokeStyle = rb.col
    ctx.stroke()
  }

  // Draw subtle center baseline
  ctx.lineWidth = 1.0
  ctx.strokeStyle = "rgba(255, 255, 255, 0.12)"
  ctx.beginPath()
  ctx.moveTo(0, midY)
  ctx.lineTo(w, midY)
  ctx.stroke()
}
