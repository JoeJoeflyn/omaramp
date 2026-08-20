// Apple Sound Wave — Apple Siri / Apple Music multi-chromatic fluid harmonic wave
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

  var t = frame * 0.045

  // 4 Apple Multichromatic Wave Ribbons (Magenta, Cyan, Violet, Amber)
  var waves = [
    {
      freq: 0.024, speed: 1.0, width: 2.8,
      gain: isPlaying ? (14.0 + bass * (h * 0.52) + beatDrop * 12.0) : 2.0,
      r: 236, g: 72, b: 153, a: 0.85 // Electric Pink/Magenta
    },
    {
      freq: 0.036, speed: -1.3, width: 2.2,
      gain: isPlaying ? (10.0 + mids * (h * 0.44)) : 1.5,
      r: 6, g: 182, b: 212, a: 0.80 // Cyan/Blue
    },
    {
      freq: 0.052, speed: 1.8, width: 1.8,
      gain: isPlaying ? (8.0 + highs * (h * 0.36)) : 1.2,
      r: 168, g: 85, b: 247, a: 0.75 // Violet
    },
    {
      freq: 0.068, speed: -2.1, width: 1.4,
      gain: isPlaying ? (6.0 + (bass + highs) * (h * 0.28)) : 1.0,
      r: 251, g: 191, b: 36, a: 0.70 // Amber/Yellow
    }
  ]

  for (var wi = 0; wi < waves.length; wi++) {
    var wv = waves[wi]
    ctx.beginPath()
    ctx.moveTo(0, midY)

    for (var x = 0; x <= w; x += 2) {
      var normX = (x / w) * 2.0 - 1.0
      // Apple Gaussian curve window
      var envelope = Math.exp(-normX * normX * 3.5)

      // Frequency mapping
      var bIdx = Math.min(nBands - 1, Math.floor((x / w) * nBands))
      var bEnergy = isPlaying ? (bands[bIdx] || 0) : 0.05

      var carrier = Math.sin(x * wv.freq + t * wv.speed)
      var displacement = (bEnergy * wv.gain + Math.sin(t * 1.5 + x * 0.01) * 3.0) * carrier
      var y = midY - displacement * envelope

      ctx.lineTo(x, y)
    }

    ctx.lineWidth = wv.width
    ctx.strokeStyle = "rgba(" + wv.r + "," + wv.g + "," + wv.b + "," + wv.a + ")"
    ctx.stroke()
  }

  // Apple center light core
  var coreAmp = (bass * 6.0) + (beatDrop * 8.0)
  if (isPlaying && coreAmp > 1.0) {
    var grad = ctx.createRadialGradient(w / 2, midY, 1, w / 2, midY, 20 + coreAmp * 2.5)
    grad.addColorStop(0, "rgba(255, 255, 255, " + Math.min(0.4, coreAmp * 0.05) + ")")
    grad.addColorStop(1, "rgba(255, 255, 255, 0)")
    ctx.fillStyle = grad
    ctx.fillRect(w / 2 - 40, midY - 20, 80, 40)
  }
}
