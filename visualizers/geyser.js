// Geyser — vis_geyser.go: particle fountain with gravity
// cliamp dot grid 20×148 (Rows*4 × PanelWidth*2); canvas ~42×380px —
// keep original dot-unit velocities 1:1 (gravity/drag unchanged).
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, S = d.S, frame = d.frame
  var s = d.state
  if (s.geyserRng === undefined) { s.geyserRng = 0xFEED5EED; s.geyserParticles = []; s.geyserPrevBass = 0 }
  var rngVal = s.geyserRng
  var particles = s.geyserParticles
  function rng01() {
    rngVal = (rngVal * 1664525 + 1013904223) & 0xFFFFFFFF
    return ((rngVal >> 16) % 1000) / 1000.0
  }
  var bass = H.bandAvg(bands, 0, Math.max(1, Math.floor(count / 3)))
  var mid = H.bandAvg(bands, Math.floor(count / 3), Math.floor(2 * count / 3))
  var high = H.bandAvg(bands, Math.floor(2 * count / 3), count)
  var delta = bass - s.geyserPrevBass
  s.geyserPrevBass = bass
  var jetX = w / 2, jetSpread = Math.max(2, Math.floor(w / 16))

  function spawn(x, y, spread, vy) {
    var jx = x + Math.floor(rng01() * (2 * spread + 1)) - spread
    var vyJ = vy * (0.6 + rng01() * 0.5)
    var vxJ = (rng01() - 0.5) * (1.0 + vy * 0.4)
    var r = rng01()
    var tier = r < bass ? 3 : r < bass + mid ? 2 : 1
    particles.push({ x: jx, y: y, vx: vxJ, vy: -vyJ, tier: tier, life: 0 })
  }

  // Steady drizzle — spawn rate scales with overall loudness
  var steady = bass * 0.85 + mid * 0.25 + high * 0.08
  for (var i = 0; i < Math.floor(steady * 6); i++) spawn(jetX, h - 1, jetSpread, 1.5 + steady * 4.5)
  // Transient kick on bass rising edge
  if (delta > 0.06 && bass > 0.15) {
    var burst = 40 + Math.floor(delta * 180)
    for (var i2 = 0; i2 < burst; i2++) spawn(jetX, h - 1, jetSpread * 2, 4.5 + delta * 10.0 + bass * 4.0)
  }

  // Advance particles — same constants as cliamp (gravity 0.30, drag 0.992)
  var gravity = 0.30, drag = 0.992
  var live = []
  for (var p = 0; p < particles.length; p++) {
    var pt = particles[p]
    pt.vy += gravity
    pt.vx *= drag
    pt.x += pt.vx
    pt.y += pt.vy
    pt.life++
    var ix = Math.floor(pt.x), iy = Math.floor(pt.y)
    if (iy >= h || ix < 0 || ix >= w || pt.life > 200) continue
    if (iy < 0) iy = 0
    var colors = ["rgba(0,255,100,0.7)", "rgba(255,200,0,0.7)", "rgba(255,50,50,0.7)"]
    ctx.fillStyle = colors[Math.max(0, Math.min(2, pt.tier - 1))]
    ctx.fillRect(ix, iy, S, S)
    live.push(pt)
  }
  s.geyserParticles = live
  s.geyserRng = rngVal
}
