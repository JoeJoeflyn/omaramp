// Oscilloscope 3D Warp — Time-domain raw audio waveform deforming a rotating 3D Mobius ribbon
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var wave = d.wave || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var cx = w / 2.0, cy = h / 2.0

  var bass = H.bandAvg(bands, 0, 5)
  var mids = H.bandAvg(bands, 5, 14)
  var highs = H.bandAvg(bands, 14, 24)
  var totalEnergy = bass * 0.5 + mids * 0.35 + highs * 0.15
  var beatDrop = d.beatDrop || 0

  if (!isPlaying || totalEnergy < 0.005) {
    ctx.strokeStyle = "rgba(255, 255, 255, 0.18)"
    ctx.lineWidth = 1.0
    ctx.beginPath()
    ctx.ellipse(cx, cy, w * 0.18, h * 0.18, 0, 0, Math.PI * 2)
    ctx.stroke()
    return
  }

  var ar = (d.accent && d.accent.r !== undefined) ? d.accent.r : 0.0
  var ag = (d.accent && d.accent.g !== undefined) ? d.accent.g : 0.8
  var ab = (d.accent && d.accent.b !== undefined) ? d.accent.b : 1.0

  var numNodes = 72
  // Gentle, musical rotation speed
  var rotX = frame * (0.006 + totalEnergy * 0.006)
  var rotY = frame * (0.010 + totalEnergy * 0.010)
  var waveLen = wave.length

  var vertices = []
  // Safe bounded radius that fits comfortably inside the HUD box
  var radiusX = (w * 0.28) * (0.85 + bass * 0.25 + beatDrop * 0.15)
  var radiusY = (h * 0.32) * (0.85 + bass * 0.20 + beatDrop * 0.15)
  var radiusZ = radiusX * 0.60

  // 1. Calculate 3D Parametric Mobius / Torus Vertices Deformed by Raw Waveform
  for (var i = 0; i <= numNodes; i++) {
    var u = (i / numNodes) * Math.PI * 2.0
    var waveVal = 0.0

    if (waveLen > 0) {
      var waveIdx = Math.floor((i / numNodes) * (waveLen - 1))
      waveVal = wave[waveIdx] || 0.0
    } else {
      var bIdx = Math.min(bands.length - 1, Math.floor((i / numNodes) * (bands.length - 1)))
      waveVal = (bands[bIdx] || 0.0) * Math.sin(u * 2.0 + frame * 0.04)
    }

    var p = 2, q = 3
    var r = 0.55 + 0.3 * Math.cos(q * u)
    var audioDisplacement = 1.0 + (waveVal * (0.35 + highs * 0.25 + beatDrop * 0.20))

    var rawX = r * Math.cos(p * u) * radiusX * audioDisplacement
    var rawY = r * Math.sin(p * u) * radiusY * audioDisplacement
    var rawZ = -Math.sin(q * u) * radiusZ * audioDisplacement

    // 3D Matrix Rotation
    var cosY = Math.cos(rotY), sinY = Math.sin(rotY)
    var x1 = rawX * cosY + rawZ * sinY
    var z1 = -rawX * sinY + rawZ * cosY

    var cosX = Math.cos(rotX), sinX = Math.sin(rotX)
    var y1 = rawY * cosX - z1 * sinX
    var z2 = rawY * sinX + z1 * cosX

    // 3D Perspective Projection
    var fov = 220.0
    var projZ = z2 + 260.0
    var projScale = fov / Math.max(10.0, projZ)
    var px = cx + x1 * projScale
    var py = cy + y1 * projScale

    vertices.push({ x: px, y: py, z: z2, wave: waveVal })
  }

  var cr = Math.round(ar * 255)
  var cg = Math.round(ag * 255)
  var cb = Math.round(ab * 255)

  // 2. Wide Neon Bloom Halo Pass
  ctx.lineWidth = 3.5
  ctx.strokeStyle = "rgba(" + cr + "," + cg + "," + cb + ", 0.20)"
  ctx.beginPath()
  for (var v = 0; v < vertices.length; v++) {
    if (v === 0) ctx.moveTo(vertices[v].x, vertices[v].y)
    else ctx.lineTo(vertices[v].x, vertices[v].y)
  }
  ctx.stroke()

  // 3. Crisp Core Laser Filament Pass
  ctx.lineWidth = 1.5
  for (var v = 0; v < vertices.length - 1; v++) {
    var v0 = vertices[v]
    var v1 = vertices[v + 1]
    var zNorm = (v0.z + radiusZ) / (radiusZ * 2.0)
    var audioEnergy = Math.abs(v0.wave)

    var alpha = Math.min(1.0, 0.40 + zNorm * 0.35 + audioEnergy * 0.40 + beatDrop * 0.15)
    ctx.strokeStyle = "rgba(" + Math.min(255, cr + 40) + "," + Math.min(255, cg + 40) + "," + Math.min(255, cb + 40) + "," + alpha.toFixed(2) + ")"

    ctx.beginPath()
    ctx.moveTo(v0.x, v0.y)
    ctx.lineTo(v1.x, v1.y)
    ctx.stroke()

    // White-Hot Energy Beads on Waveform Peaks
    if (audioEnergy > 0.35 || beatDrop > 0.40) {
      ctx.fillStyle = "rgba(255, 255, 255, " + (alpha * 0.90).toFixed(2) + ")"
      ctx.beginPath()
      ctx.arc(v0.x, v0.y, 1.6 + audioEnergy * 1.8, 0, Math.PI * 2)
      ctx.fill()
    }
  }
}
