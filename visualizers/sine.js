// Sine — Authentic Fourier Harmonic Sine Wave Engine
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0

  // 1. Live Frequency Band Energies
  var subBass = H.bandAvg(bands, 0, 3)
  var midBass = H.bandAvg(bands, 3, 6)
  var vocals  = H.bandAvg(bands, 6, 13)
  var treble  = H.bandAvg(bands, 13, 24)
  var totalEnergy = subBass * 0.4 + midBass * 0.3 + vocals * 0.2 + treble * 0.1
  var beatDrop = d.beatDrop || 0

  // Flat resting line when paused / silent
  if (!isPlaying || totalEnergy < 0.005) {
    ctx.strokeStyle = "rgba(255, 255, 255, 0.20)"
    ctx.lineWidth = 1.0
    ctx.beginPath()
    ctx.moveTo(0, midY)
    ctx.lineTo(w, midY)
    ctx.stroke()
    return
  }

  // Accent color extraction
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

  // Safe amplitude ceiling (prevents all vertical cropping)
  var maxSafe = h * 0.36
  var speed = 0.04 + totalEnergy * 0.04
  var t = frame * speed

  // Natural edge windowing function (Hanning window) so waves terminate smoothly at canvas borders
  function edgeWindow(x) {
    return Math.sin((x / w) * Math.PI)
  }

  // 2. Harmonic Sine Wave Definitions (Fourier series k = 1, 2, 3, 4)
  var harmonics = [
    // Fundamental (Bass / Kicks)
    {
      k: 1.0, speed: 1.0, phase: 0.0,
      amp: Math.min(maxSafe, (h * 0.06) + subBass * (h * 0.26) + beatDrop * (h * 0.08)),
      lineWidth: 2.4,
      stroke: "rgba(" + ar + "," + ag + "," + ab + ", 0.90)",
      fill: "rgba(" + ar + "," + ag + "," + ab + ", 0.12)"
    },
    // 2nd Harmonic (Low Mids / Rhythm)
    {
      k: 2.0, speed: -1.3, phase: 1.2,
      amp: Math.min(maxSafe * 0.85, (h * 0.05) + midBass * (h * 0.22)),
      lineWidth: 1.8,
      stroke: "rgba(" + Math.min(255, ar + 50) + "," + Math.min(255, ag + 30) + ", 255, 0.75)",
      fill: "rgba(" + Math.min(255, ar + 50) + "," + Math.min(255, ag + 30) + ", 255, 0.07)"
    },
    // 3rd Harmonic (Vocals / Guitars)
    {
      k: 3.2, speed: 1.6, phase: 2.5,
      amp: Math.min(maxSafe * 0.70, (h * 0.04) + vocals * (h * 0.18)),
      lineWidth: 1.4,
      stroke: "rgba(255, 180, 100, 0.70)",
      fill: "rgba(255, 180, 100, 0.05)"
    },
    // 4th Harmonic (Highs / Shimmer)
    {
      k: 4.8, speed: -2.0, phase: 3.8,
      amp: Math.min(maxSafe * 0.55, (h * 0.03) + treble * (h * 0.15)),
      lineWidth: 1.2,
      stroke: "rgba(100, 245, 200, 0.65)",
      fill: null
    }
  ]

  // Render individual harmonic waves with smooth gradient underfills
  for (var hIdx = 0; hIdx < harmonics.length; hIdx++) {
    var hm = harmonics[hIdx]
    var curT = t * hm.speed + hm.phase

    ctx.beginPath()
    ctx.moveTo(0, midY)

    for (var x = 0; x <= w; x += 2) {
      var wFactor = edgeWindow(x)
      var rad = (x / w) * (hm.k * 2.0 * Math.PI) + curT
      var y = midY - Math.sin(rad) * hm.amp * wFactor
      ctx.lineTo(x, y)
    }

    // Gradient underfill
    if (hm.fill) {
      ctx.lineTo(w, midY)
      ctx.closePath()
      ctx.fillStyle = hm.fill
      ctx.fill()
    }

    // Stroke pure sine curve
    ctx.beginPath()
    for (var x2 = 0; x2 <= w; x2 += 2) {
      var wFactor2 = edgeWindow(x2)
      var rad2 = (x2 / w) * (hm.k * 2.0 * Math.PI) + curT
      var y2 = midY - Math.sin(rad2) * hm.amp * wFactor2
      if (x2 === 0) ctx.moveTo(x2, y2)
      else ctx.lineTo(x2, y2)
    }
    ctx.lineWidth = hm.lineWidth
    ctx.strokeStyle = hm.stroke
    ctx.stroke()
  }

  // 3. Composite Superposition Wave (Glowing White Fourier Envelope)
  ctx.strokeStyle = "rgba(255, 255, 255, 0.95)"
  ctx.lineWidth = 2.0
  ctx.beginPath()

  for (var cx = 0; cx <= w; cx += 2) {
    var wFc = edgeWindow(cx)
    var compY = 0
    for (var k = 0; k < harmonics.length; k++) {
      var hItem = harmonics[k]
      var rAngle = (cx / w) * (hItem.k * 2.0 * Math.PI) + (t * hItem.speed + hItem.phase)
      compY += Math.sin(rAngle) * (hItem.amp * 0.45) * wFc
    }
    var finalY = midY - Math.min(maxSafe, compY)
    if (cx === 0) ctx.moveTo(cx, finalY)
    else ctx.lineTo(cx, finalY)
  }
  ctx.stroke()
}
