// Sand — Organic desert sand dunes with flowing acoustic wind & grain ripples
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var s = d.state

  // Initialize particle & dune state
  if (!s.sandDuneParticles) {
    s.sandDuneParticles = []
    for (var i = 0; i < 36; i++) {
      s.sandDuneParticles.push({
        x: Math.random() * w,
        y: Math.random() * h,
        vx: 0.8 + Math.random() * 1.5,
        vy: -0.2 + Math.random() * 0.4,
        size: 1 + Math.random() * 1.5,
        alpha: 0.3 + Math.random() * 0.6
      })
    }
  }

  // Smooth spectrum frequencies
  var numBands = 12
  var resampled = H.resampleBandsLinear(bands, numBands)
  var bass = H.bandAvg(resampled, 0, 3)
  var mids = H.bandAvg(resampled, 3, 7)
  var highs = H.bandAvg(resampled, 7, 12)
  var beatDrop = d.beatDrop || 0

  // Adaptive Theme Accent Colors
  var acc = d.accent
  var ar = 215, ag = 175, ab = 110 // Default warm desert sand
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

  var t = frame * 0.025

  // 1. Dune Layer 1 (Far Background - Deep Bass Horizon)
  var grad1 = ctx.createLinearGradient(0, h * 0.3, 0, h)
  grad1.addColorStop(0, "rgba(" + Math.round(ar * 0.5 + 50) + "," + Math.round(ag * 0.4 + 40) + "," + Math.round(ab * 0.3 + 30) + ", 0.45)")
  grad1.addColorStop(1, "rgba(" + Math.round(ar * 0.3 + 30) + "," + Math.round(ag * 0.25 + 25) + "," + Math.round(ab * 0.2 + 20) + ", 0.75)")

  ctx.beginPath()
  ctx.moveTo(0, h)
  var pts1 = 12
  for (var i1 = 0; i1 <= pts1; i1++) {
    var px1 = (i1 / pts1) * w
    var bIdx1 = Math.floor((i1 / pts1) * 4)
    var bVal1 = (resampled[bIdx1] || 0) * (isPlaying ? 1.0 : 0.1)
    var py1 = h * 0.65 - (bVal1 * h * 0.42) - Math.sin(t * 0.8 + i1 * 0.6) * 4.0 - (beatDrop * 6.0)
    if (i1 === 0) ctx.lineTo(px1, py1)
    else {
      var prevX1 = ((i1 - 1) / pts1) * w
      var cpx1 = (prevX1 + px1) / 2
      ctx.quadraticCurveTo(prevX1, py1, px1, py1)
    }
  }
  ctx.lineTo(w, h)
  ctx.closePath()
  ctx.fillStyle = grad1
  ctx.fill()

  // 2. Dune Layer 2 (Mid Ground - Vocals & Melodic Ridge)
  var grad2 = ctx.createLinearGradient(0, h * 0.4, 0, h)
  grad2.addColorStop(0, "rgba(" + Math.round(ar * 0.8 + 60) + "," + Math.round(ag * 0.7 + 50) + "," + Math.round(ab * 0.5 + 40) + ", 0.75)")
  grad2.addColorStop(1, "rgba(" + Math.round(ar * 0.45 + 35) + "," + Math.round(ag * 0.4 + 30) + "," + Math.round(ab * 0.3 + 25) + ", 0.90)")

  ctx.beginPath()
  ctx.moveTo(0, h)
  var pts2 = 14
  for (var i2 = 0; i2 <= pts2; i2++) {
    var px2 = (i2 / pts2) * w
    var bIdx2 = Math.min(11, 2 + Math.floor((i2 / pts2) * 6))
    var bVal2 = (resampled[bIdx2] || 0) * (isPlaying ? 1.0 : 0.1)
    var py2 = h * 0.75 - (bVal2 * h * 0.48) - Math.sin(t * 1.2 + i2 * 0.8 + 1.2) * 5.0 - (mids * 5.0)
    if (i2 === 0) ctx.lineTo(px2, py2)
    else {
      var prevX2 = ((i2 - 1) / pts2) * w
      ctx.quadraticCurveTo((prevX2 + px2) / 2, py2, px2, py2)
    }
  }
  ctx.lineTo(w, h)
  ctx.closePath()
  ctx.fillStyle = grad2
  ctx.fill()

  // 3. Dune Layer 3 (Foreground - Crisp Treble Ripple Crest)
  var grad3 = ctx.createLinearGradient(0, h * 0.5, 0, h)
  grad3.addColorStop(0, "rgba(" + Math.min(255, ar + 30) + "," + Math.min(255, ag + 25) + "," + Math.min(255, ab + 20) + ", 0.95)")
  grad3.addColorStop(1, "rgba(" + Math.round(ar * 0.65 + 40) + "," + Math.round(ag * 0.55 + 35) + "," + Math.round(ab * 0.45 + 30) + ", 0.98)")

  ctx.beginPath()
  ctx.moveTo(0, h)
  var pts3 = 16
  for (var i3 = 0; i3 <= pts3; i3++) {
    var px3 = (i3 / pts3) * w
    var bIdx3 = Math.min(11, Math.floor((i3 / pts3) * 12))
    var bVal3 = (resampled[bIdx3] || 0) * (isPlaying ? 1.0 : 0.1)
    var ripple = Math.sin(t * 2.0 + i3 * 1.2) * (2.0 + highs * 6.0)
    var py3 = h * 0.86 - (bVal3 * h * 0.38) - ripple
    if (i3 === 0) ctx.lineTo(px3, py3)
    else {
      var prevX3 = ((i3 - 1) / pts3) * w
      ctx.quadraticCurveTo((prevX3 + px3) / 2, py3, px3, py3)
    }
  }
  ctx.lineTo(w, h)
  ctx.closePath()
  ctx.fillStyle = grad3
  ctx.fill()

  // 4. Dune Crest Highlight Line
  ctx.lineWidth = 1.0
  ctx.strokeStyle = "rgba(255, 245, 200, 0.4)"
  ctx.stroke()

  // 5. Drifting Wind Sand Particles
  var windSpeed = 1.0 + (bass + mids) * 3.5
  for (var p = 0; p < s.sandDuneParticles.length; p++) {
    var pt = s.sandDuneParticles[p]
    if (isPlaying) {
      pt.x += pt.vx * windSpeed
      pt.y += pt.vy * (1.0 + highs * 2.0) + Math.sin(t * 3.0 + p) * 0.4
    } else {
      pt.x += pt.vx * 0.3
    }

    if (pt.x > w) { pt.x = -5; pt.y = h * 0.3 + Math.random() * (h * 0.6) }
    if (pt.y < h * 0.2) pt.y = h * 0.8
    if (pt.y > h) pt.y = h * 0.4

    ctx.fillStyle = "rgba(255, 235, 175, " + pt.alpha + ")"
    ctx.fillRect(pt.x, pt.y, pt.size, pt.size)
  }
}
