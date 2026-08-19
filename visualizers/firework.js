// Firework — vis_firework.go: deterministic bursts, trails, gravity, fade
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, S = d.S, frame = d.frame
  var total = 0
  for (var i = 0; i < count; i++) total += (bands[i] || 0)
  var avg = total / count
  var numBursts = 5 + Math.floor(avg * 9)
  var cycleLen = 48, launchLen = 10

  for (var i = 0; i < numBursts; i++) {
    // Seed changes each cycle (exact) — bursts stay put during a cycle
    var cycle = Math.floor((frame + i * 7) / cycleLen)
    var seed = (cycle * 104729 + i * 7919) & 0xFFFFFFFF

    // Stagger starts (exact)
    var offset = Math.floor(i * cycleLen / numBursts + (seed / 3) % 5)
    var localFrame = (frame + offset) % cycleLen

    // Burst center — spread across panel, upper portion (exact)
    var cx = (seed * 6271) % w
    var cy = ((seed * 4391) % Math.floor(h / 2)) + Math.floor(h / 8)
    var bandIdx = seed % count
    var energy = bands[bandIdx] || 0

    if (localFrame < launchLen) {
      // Rising trail from bottom to burst center (exact)
      var progress = localFrame / launchLen
      var trailY = h - 1 - Math.floor((h - 1 - cy) * progress)
      ctx.fillStyle = "rgba(255, 180, 50, 0.6)"
      for (var dy = 0; dy < 4; dy++) {
        var ty = trailY + dy * S
        if (ty >= 0 && ty < h) ctx.fillRect(cx, ty, S, S)
      }
    } else {
      // Burst expansion and fade (exact)
      var burstT = (localFrame - launchLen) / (cycleLen - launchLen)
      // Scale radius by S for pixel visibility, cap at h/2 so it fits the canvas
      // ponytail: uses dot units (3-11) on a 160×40 grid; our canvas is
      // 380×42px so we scale by S=4 → 12-44px, capped at h/2=21px
      var maxRadius = Math.min((3.0 + energy * 8.0) * S, h / 2)
      // Fast expansion then slow drift
      var radius = maxRadius * Math.min(burstT * 3.0, 1.0)
      // Gravity pulls particles down (exact: burstT² × 5, scaled by S)
      var gravity = burstT * burstT * 5.0 * S
      // Particles fade out (exact)
      var fade = Math.max(0.0, 1.0 - burstT * 1.3)

      var numParticles = 18 + Math.floor(energy * 18)
      for (var p = 0; p < numParticles; p++) {
        var angle = p / numParticles * 2 * Math.PI
        var pSeed = seed + p * 2909
        var speed = 0.6 + (pSeed % 400) / 1000.0

        var px = cx + Math.cos(angle) * radius * speed
        var py = cy + Math.sin(angle) * radius * speed + gravity

        // Stochastic fade (exact hash args)
        if (H.scatterHash(bandIdx, p, seed % 100, frame) > fade) continue

        if (px >= 0 && px < w && py >= 0 && py < h) {
          ctx.fillStyle = "rgba(255, 200, 50, " + fade + ")"
          ctx.fillRect(Math.floor(px), Math.floor(py), S, S)
        }
      }
    }
  }
}
