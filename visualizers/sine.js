// Sine — Physical Acoustic Standing Wave (Vibrating String / Harmonic Resonance)
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
  var totalEnergy = bass * 0.5 + mids * 0.35 + highs * 0.15
  var beatDrop = d.beatDrop || 0

  // Serene flat line when quiet / paused
  if (!isPlaying || totalEnergy < 0.005) {
    ctx.strokeStyle = "rgba(255, 255, 255, 0.20)"
    ctx.lineWidth = 1.0
    ctx.beginPath()
    ctx.moveTo(0, midY)
    ctx.lineTo(w, midY)
    ctx.stroke()
    return
  }

  // Dynamic theme accent color
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

  var maxSafe = h * 0.38
  var t = frame * 0.08

  // Standing Wave Harmonic Series: y(x,t) = sum( A_n * sin(n * pi * x / w) * cos(omega_n * t) )
  // This physically vibrates and resonates vertically in place like a real acoustic string/membrane!
  var harmonics = [
    { n: 1, omega: 1.0, amp: Math.min(maxSafe, (h * 0.06) + bass * (h * 0.26) + beatDrop * (h * 0.08)) },
    { n: 2, omega: 1.8, amp: Math.min(maxSafe * 0.75, (h * 0.04) + mids * (h * 0.20)) },
    { n: 3, omega: 2.7, amp: Math.min(maxSafe * 0.55, (h * 0.03) + highs * (h * 0.16)) },
    { n: 4, omega: 3.9, amp: Math.min(maxSafe * 0.35, (h * 0.02) + highs * (h * 0.10)) }
  ]

  // 1. Draw Phosphor Ambient Glow Underfill
  ctx.beginPath()
  ctx.moveTo(0, midY)
  for (var x = 0; x <= w; x += 2) {
    var xNorm = x / w
    var yDisp = 0
    for (var k = 0; k < harmonics.length; k++) {
      var hItem = harmonics[k]
      yDisp += hItem.amp * Math.sin(hItem.n * Math.PI * xNorm) * Math.cos(hItem.omega * t)
    }
    ctx.lineTo(x, midY - yDisp)
  }
  ctx.lineTo(w, midY)
  ctx.closePath()
  ctx.fillStyle = "rgba(" + ar + "," + ag + "," + ab + ", 0.12)"
  ctx.fill()

  // 2. Secondary Harmonic String (Upper Octave Vibration)
  ctx.lineWidth = 1.2
  ctx.strokeStyle = "rgba(" + ar + "," + ag + "," + ab + ", 0.45)"
  ctx.beginPath()
  for (var x2 = 0; x2 <= w; x2 += 2) {
    var xN2 = x2 / w
    var y2 = harmonics[1].amp * Math.sin(2.0 * Math.PI * xN2) * Math.cos(1.8 * t) +
             harmonics[2].amp * Math.sin(3.0 * Math.PI * xN2) * Math.cos(2.7 * t)
    var yPos2 = midY - y2
    if (x2 === 0) ctx.moveTo(x2, yPos2)
    else ctx.lineTo(x2, yPos2)
  }
  ctx.stroke()

  // 3. Primary Resonating String (Composite Standing Wave)
  ctx.lineWidth = 2.2
  ctx.strokeStyle = "rgba(" + ar + "," + ag + "," + ab + ", 0.95)"
  ctx.beginPath()
  for (var x3 = 0; x3 <= w; x3 += 2) {
    var xN3 = x3 / w
    var y3 = 0
    for (var m = 0; m < harmonics.length; m++) {
      var hm = harmonics[m]
      y3 += hm.amp * Math.sin(hm.n * Math.PI * xN3) * Math.cos(hm.omega * t)
    }
    var yPos3 = midY - y3
    if (x3 === 0) ctx.moveTo(x3, yPos3)
    else ctx.lineTo(x3, yPos3)
  }
  ctx.stroke()

  // 4. Glowing White Centerline Trace
  ctx.lineWidth = 1.0
  ctx.strokeStyle = "rgba(255, 255, 255, 0.90)"
  ctx.beginPath()
  for (var x4 = 0; x4 <= w; x4 += 2) {
    var xN4 = x4 / w
    var y4 = 0
    for (var p = 0; p < harmonics.length; p++) {
      var hp = harmonics[p]
      y4 += hp.amp * Math.sin(hp.n * Math.PI * xN4) * Math.cos(hp.omega * t)
    }
    var yPos4 = midY - y4
    if (x4 === 0) ctx.moveTo(x4, yPos4)
    else ctx.lineTo(x4, yPos4)
  }
  ctx.stroke()
}
