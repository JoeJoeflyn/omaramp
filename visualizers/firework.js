// Firework — vis_firework.go: deterministic bursts, trails, gravity, fade
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, S = 2, frame = d.frame
  var total = 0
  for (var i = 0; i < count; i++) total += (bands[i] || 0)
  var avg = total / count

  if (!d.playing || avg < 0.015) return

  var numBursts = 3 + Math.floor(avg * 11)
  var cycleLen = 48, launchLen = 10

  for (var i = 0; i < numBursts; i++) {
    // Seed changes each cycle — bursts stay put during a cycle
    var cycle = Math.floor((frame + i * 7) / cycleLen)
    var seed = (cycle * 104729 + i * 7919) & 0xFFFFFFFF

    // Stagger starts
    var offset = Math.floor(i * cycleLen / numBursts + (seed / 3) % 5)
    var localFrame = (frame + offset) % cycleLen

    // Burst center — spread across panel, upper portion
    var cx = (seed * 6271) % w
    var cy = ((seed * 4391) % Math.floor(h / 2)) + Math.floor(h / 8)
    var bandIdx = seed % count
    var energy = bands[bandIdx] || 0

    if (localFrame < launchLen) {
      // Rising trail from bottom to burst center
      var progress = localFrame / launchLen
      var trailY = h - 1 - Math.floor((h - 1 - cy) * progress)
      for (var dy = 0; dy < 4; dy++) {
        var ty = trailY + dy * 2
        if (ty >= 0 && ty < h) {
          ctx.fillStyle = H.specColor((h - 1 - ty) / h)
          ctx.fillRect(cx, ty, 2, 2)
        }
      }
    } else {
      // Burst expansion and fade
      var burstT = (localFrame - launchLen) / (cycleLen - launchLen)
      var maxRadius = Math.min((3.0 + energy * 8.0) * 3.0, h / 2)
      // Fast expansion then slow drift
      var radius = maxRadius * Math.min(burstT * 3.0, 1.0)
      // Gravity pulls particles down
      var gravity = burstT * burstT * 5.0 * 2
      // Particles fade out
      var fade = Math.max(0.0, 1.0 - burstT * 1.3)

      var numParticles = 18 + Math.floor(energy * 18)
      for (var p = 0; p < numParticles; p++) {
        var angle = p / numParticles * 2 * Math.PI
        var pSeed = seed + p * 2909
        var speed = 0.6 + (pSeed % 400) / 1000.0

        var px = cx + Math.cos(angle) * radius * speed
        var py = cy + Math.sin(angle) * radius * speed + gravity

        // Stochastic fade
        if (H.scatterHash(bandIdx, p, seed % 100, frame) > fade) continue

        if (px >= 0 && px < w && py >= 0 && py < h) {
          var normY = (h - 1 - py) / h
          ctx.fillStyle = H.specColor(normY)
          ctx.fillRect(Math.floor(px), Math.floor(py), 2, 2)
        }
      }
    }
  }
}
