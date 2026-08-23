// 3D Cyberpunk Audio Warp Tunnel — Infinite perspective wireframe with calibrated audio velocity
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var cx = w / 2.0, cy = h / 2.0

  var bass = H.bandAvg(bands, 0, 5)
  var mids = H.bandAvg(bands, 5, 14)
  var highs = H.bandAvg(bands, 14, 24)
  var totalEnergy = bass * 0.5 + mids * 0.35 + highs * 0.15
  var beatDrop = d.beatDrop || 0

  if (!isPlaying || totalEnergy < 0.005) {
    ctx.strokeStyle = "rgba(255, 255, 255, 0.15)"
    ctx.lineWidth = 1.0
    ctx.beginPath()
    ctx.arc(cx, cy, Math.min(w, h) * 0.20, 0, Math.PI * 2)
    ctx.stroke()
    return
  }

  var ar = (d.accent && d.accent.r !== undefined) ? d.accent.r : 0.0
  var ag = (d.accent && d.accent.g !== undefined) ? d.accent.g : 0.8
  var ab = (d.accent && d.accent.b !== undefined) ? d.accent.b : 1.0

  // Controlled musical tunnel velocity
  var speed = 0.006 + (totalEnergy * 0.012) + (beatDrop * 0.015)
  var ringCount = 8
  var numSides = 8
  var rotBase = frame * 0.005

  // 1. Draw Longitudinal Rails to Center Vanishing Point (Bounded safely inside box)
  ctx.lineWidth = 0.8
  ctx.strokeStyle = "rgba(" + Math.round(ar * 255) + "," + Math.round(ag * 255) + "," + Math.round(ab * 255) + ", 0.20)"

  for (var s = 0; s < numSides; s++) {
    var angle = rotBase + (s * (Math.PI * 2 / numSides))
    var outerX = cx + Math.cos(angle) * (w * 0.44)
    var outerY = cy + Math.sin(angle) * (h * 0.44)

    ctx.beginPath()
    ctx.moveTo(cx, cy)
    ctx.lineTo(outerX, outerY)
    ctx.stroke()
  }

  // 2. Draw Moving Concentric Perspective Rings
  for (var i = 0; i < ringCount; i++) {
    var z = ((i / ringCount) + (frame * speed)) % 1.0
    var scale = Math.pow(z, 2.0)
    if (scale < 0.03) continue

    var bandIndex = Math.min(bands.length - 1, Math.floor((1.0 - z) * (bands.length - 1)))
    var bVal = bands[bandIndex] || 0.0
    var ringAudioPulse = 1.0 + (bVal * 0.25) + (beatDrop * 0.20)

    var rx = (w * 0.42) * scale * ringAudioPulse
    var ry = (h * 0.42) * scale * ringAudioPulse
    var ringRot = rotBase + (1.0 - z) * 0.3

    var alpha = Math.min(1.0, scale * 1.4) * (0.35 + bVal * 0.45 + beatDrop * 0.20)
    var cr = Math.round(ar * 200 + (1.0 - z) * 55)
    var cg = Math.round(ag * 200 + highs * 55)
    var cb = Math.round(ab * 255)

    ctx.strokeStyle = "rgba(" + cr + "," + cg + "," + cb + "," + alpha.toFixed(2) + ")"
    ctx.lineWidth = Math.max(1.0, scale * 2.0)

    ctx.beginPath()
    for (var s = 0; s <= numSides; s++) {
      var a = ringRot + (s * (Math.PI * 2 / numSides))
      var px = cx + Math.cos(a) * rx
      var py = cy + Math.sin(a) * ry
      if (s === 0) ctx.moveTo(px, py)
      else ctx.lineTo(px, py)
    }
    ctx.stroke()
  }

  // 3. Central Event Horizon Core
  var coreR = Math.max(2.5, (h * 0.06) * (1.0 + bass * 0.6 + beatDrop * 0.4))
  var coreGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, coreR * 2.0)
  coreGrad.addColorStop(0, "rgba(255, 255, 255, " + (0.80 + beatDrop * 0.2).toFixed(2) + ")")
  coreGrad.addColorStop(0.4, "rgba(" + Math.round(ar * 255) + "," + Math.round(ag * 255) + "," + Math.round(ab * 255) + ", 0.5)")
  coreGrad.addColorStop(1, "rgba(0, 0, 0, 0)")

  ctx.fillStyle = coreGrad
  ctx.beginPath()
  ctx.arc(cx, cy, coreR * 2.0, 0, Math.PI * 2)
  ctx.fill()
}
