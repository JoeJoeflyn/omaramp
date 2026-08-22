// Sand — authentic ballistic particle physics sand simulation matching cliamp
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height
  var isPlaying = d.playing
  var s = d.state

  // Initialize particle pool and ground elevation map
  if (!s.sandParticles) {
    s.sandParticles = []
    s.groundBeds = new Float32Array(Math.floor(w / 4)).fill(0)
    s.sandRng = 0x5A4D5A4D
  }

  var particles = s.sandParticles
  var ground = s.groundBeds
  var numBins = ground.length
  var binW = w / numBins

  var rngVal = s.sandRng || 0x5A4D5A4D
  function rand01() {
    rngVal = (rngVal * 1103515245 + 12345) & 0x7fffffff
    return (rngVal >>> 16) / 32768.0
  }

  var numBands = bands.length > 0 ? bands.length : 16
  var bass = H.bandAvg(bands, 0, Math.max(1, Math.floor(numBands / 3)))
  var prevBass = s.prevBass || 0
  var delta = bass - prevBass
  s.prevBass = bass

  // 1. Spawning new sand particles from frequency bands
  if (isPlaying && bands.length > 0) {
    for (var b = 0; b < numBands; b++) {
      var level = bands[b] || 0
      if (level < 0.12) continue

      var spawnChance = level * 0.75
      if (rand01() < spawnChance && particles.length < 350) {
        var centreX = (b + 0.5) * (w / numBands)
        var sx = centreX + (rand01() - 0.5) * (w / numBands * 0.8)

        var tier = 1
        var color = "rgba(85, 255, 85, 0.95)"     // Green (treble)
        if (b < numBands / 3) {
          tier = 3
          color = "rgba(255, 85, 85, 0.95)"      // Red (bass)
        } else if (b < 2 * numBands / 3) {
          tier = 2
          color = "rgba(255, 255, 85, 0.95)"     // Yellow (mids)
        }

        particles.push({
          x: sx,
          y: 0,
          vx: (rand01() - 0.5) * 1.2,
          vy: 0.5 + rand01() * 1.0,
          color: color,
          size: 2.5,
          settled: false,
          life: 1.0
        })
      }
    }
  }

  // 2. Bass explosion & transient eruptions
  var isBassKick = delta > 0.06 && bass > 0.15
  if (isBassKick) {
    var kickForce = Math.min(1.4, delta * 4.0 + bass * 1.0)
    for (var i = 0; i < particles.length; i++) {
      var pt = particles[i]
      if (rand01() < 0.45 * kickForce) {
        pt.settled = false
        pt.vy = -(1.5 + rand01() * 3.5 * kickForce)
        pt.vx += (rand01() - 0.5) * 4.0 * kickForce
      }
    }
  }

  // 3. Update physics and render
  var gravity = 0.28
  var drag = 0.985
  var active = []

  for (var p = 0; p < particles.length; p++) {
    var pobj = particles[p]

    if (!pobj.settled) {
      pobj.vy += gravity
      pobj.vx *= drag
      pobj.x += pobj.vx
      pobj.y += pobj.vy

      // Check ground collision
      var bin = Math.floor(pobj.x / binW)
      bin = Math.max(0, Math.min(numBins - 1, bin))
      var groundY = h - 2 - ground[bin]

      if (pobj.y >= groundY) {
        pobj.y = groundY
        pobj.settled = true
        pobj.vy = 0
        pobj.vx = 0
        ground[bin] = Math.min(h * 0.45, ground[bin] + 0.4)
      }
    } else {
      // Settled sand decay
      pobj.life -= isPlaying ? 0.008 : 0.025
    }

    if (pobj.life > 0 && pobj.x >= 0 && pobj.x <= w && pobj.y <= h) {
      ctx.fillStyle = pobj.color
      ctx.fillRect(pobj.x, pobj.y, pobj.size, pobj.size)
      active.push(pobj)
    }
  }

  s.sandParticles = active

  // Slowly settle and drain ground heaps
  for (var g = 0; g < numBins; g++) {
    ground[g] = Math.max(0, ground[g] * 0.992 - 0.02)
  }

  s.sandRng = rngVal
}
