// Sand — cliamp vis_sand.go: falling-sand cellular automaton
// ponytail: cliamp's grid is ~160 dot-rows; our canvas is 42px. Scale physics
// by rows/160 so explosions peak at ~50% height like cliamp, not 193%.
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, S = d.S, frame = d.frame
  // 2px rows → 2×2 grains (visible), fall in 21 frames
  var rows = Math.floor(h / 2), cols = Math.floor(w / 2)
  // Scale physics to match cliamp's 160-row grid proportions
  var physScale = rows / 160.0
  var s = d.state
  if (s.sandRng === undefined) { s.sandRng = 0x5A4D5A4D; s.sandPrevBass = 0; s.sandParticles = []; s.sandExplosionTTL = 0 }
  if (!s.sandGrid || s.sandRows !== rows || s.sandCols !== cols) {
    s.sandGrid = new Array(rows * cols).fill(0)
    s.sandRows = rows; s.sandCols = cols
  }
  var grid = s.sandGrid
  var rngVal = s.sandRng
  function rand01() {
    rngVal = (rngVal * 1664525 + 1013904223) & 0xFFFFFFFF
    return ((rngVal >> 16) % 1000) / 1000.0
  }

  var bass = H.bandAvg(bands, 0, Math.max(1, Math.floor(count / 3)))
  var delta = bass - s.sandPrevBass
  s.sandPrevBass = bass

  // EXPLOSION PHASE: suspend normal sim, animate ballistic particles
  if (s.sandExplosionTTL > 0 || s.sandParticles.length > 0) {
    tickExplosion(grid, rows, cols, s.sandParticles, physScale)
    s.sandExplosionTTL = Math.max(0, s.sandExplosionTTL - 1)
    if (s.sandParticles.length === 0) s.sandExplosionTTL = 0
    renderGrid(ctx, grid, rows, cols)
    s.sandRng = rngVal
    return
  }

  // Spawn grains — probability ∝ band level, at column proportional to band index
  for (var b = 0; b < count; b++) {
    var level = bands[b] || 0
    if (level < 0.10) continue
    if (rand01() > level * 0.85) continue
    var centre = (b * 2 + 1) * cols / (2 * count)
    var spread = Math.max(1, Math.floor(cols / (count * 2)))
    var x = centre + Math.floor(rand01() * (2 * spread)) - spread
    x = Math.max(0, Math.min(cols - 1, x))
    var tier = b < count / 3 ? 3 : b < 2 * count / 3 ? 2 : 1
    if (grid[x] === 0) grid[x] = tier
  }

  // Bass transient bump
  if (delta > 0.06 && bass > 0.15) {
    var fill = 0
    for (var gi = 0; gi < grid.length; gi++) if (grid[gi] !== 0) fill++
    if (fill / grid.length > 0.30) {
      startExplosion(grid, rows, cols, s.sandParticles, rand01, physScale)
      s.sandExplosionTTL = 80
      renderGrid(ctx, grid, rows, cols)
      s.sandRng = rngVal
      return
    }
    var strength = Math.min(1.4, delta * 3.5 + bass * 0.8)
    for (var y = 0; y < rows; y++) {
      var df = y / Math.max(1, rows - 1)
      var liftProb = Math.min(0.95, strength * (0.30 + 0.70 * df))
      var liftMax = 2 + Math.floor(strength * 7.0 * (0.4 + 0.6 * df))
      var jitterR = 1 + Math.floor(strength * 5.0)
      for (var x2 = 0; x2 < cols; x2++) {
        var g = grid[y * cols + x2]
        if (g === 0 || rand01() > liftProb) continue
        var lift = 1 + Math.floor(rand01() * liftMax)
        var jit = Math.floor(rand01() * (2 * jitterR + 1)) - jitterR
        var ny = Math.max(0, y - lift), nx = Math.max(0, Math.min(cols - 1, x2 + jit))
        if (grid[ny * cols + nx] === 0) { grid[ny * cols + nx] = g; grid[y * cols + x2] = 0 }
      }
    }
  }

  // Sustained rumble
  if (bass > 0.30) {
    var rumble = Math.min(0.6, (bass - 0.30) * 1.8)
    var minY = Math.floor(rows / 2)
    for (var y2 = minY; y2 < rows; y2++) {
      var df2 = (y2 - minY) / Math.max(1, rows - 1 - minY)
      var prob = rumble * (0.15 + 0.55 * df2)
      for (var x3 = 0; x3 < cols; x3++) {
        var g2 = grid[y2 * cols + x3]
        if (g2 === 0 || rand01() > prob) continue
        var lift2 = 1 + Math.floor(rand01() * 2.0)
        var jit2 = Math.floor(rand01() * 5) - 2
        var ny2 = Math.max(0, y2 - lift2), nx2 = Math.max(0, Math.min(cols - 1, x3 + jit2))
        if (grid[ny2 * cols + nx2] === 0) { grid[ny2 * cols + nx2] = g2; grid[y2 * cols + x3] = 0 }
      }
    }
  }

  // Falling pass (bottom-up, alternating L/R for natural pile slopes)
  for (var y3 = rows - 2; y3 >= 0; y3--) {
    var leftFirst = (frame % 2) === 0
    for (var xi = leftFirst ? 0 : cols - 1; leftFirst ? xi < cols : xi >= 0; xi += leftFirst ? 1 : -1) {
      var g3 = grid[y3 * cols + xi]
      if (g3 === 0) continue
      if (grid[(y3 + 1) * cols + xi] === 0) { grid[(y3 + 1) * cols + xi] = g3; grid[y3 * cols + xi] = 0; continue }
      var d1 = rand01() < 0.5 ? -1 : 1, d2 = -d1
      for (var dx = 0; dx < 2; dx++) {
        var ddx = dx === 0 ? d1 : d2
        var nx3 = xi + ddx
        if (nx3 < 0 || nx3 >= cols) continue
        if (grid[(y3 + 1) * cols + nx3] === 0) { grid[(y3 + 1) * cols + nx3] = g3; grid[y3 * cols + xi] = 0; break }
      }
    }
  }

  // Floor drain
  for (var x4 = 0; x4 < cols; x4++) {
    if (grid[(rows - 1) * cols + x4] !== 0 && rand01() < 0.04) grid[(rows - 1) * cols + x4] = 0
  }

  renderGrid(ctx, grid, rows, cols)
  s.sandRng = rngVal
}

function renderGrid(ctx, grid, rows, cols) {
  var colors = [null, "rgba(0,255,100,0.8)", "rgba(255,200,0,0.8)", "rgba(255,50,50,0.8)"]
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      var g = grid[y * cols + x]
      if (g === 0) continue
      ctx.fillStyle = colors[g]
      ctx.fillRect(x * 2, y * 2, 2, 2)
    }
  }
}

function startExplosion(grid, rows, cols, particles, rand01, physScale) {
  particles.length = 0
  for (var y = 0; y < rows; y++) {
    var df = y / Math.max(1, rows - 1)
    for (var x = 0; x < cols; x++) {
      var g = grid[y * cols + x]
      if (g === 0) continue
      grid[y * cols + x] = 0
      // Scale velocities by physScale so apex matches cliamp's ~50% of height
      particles.push({
        x: x, y: y,
        vx: (rand01() - 0.5) * 8.0 * physScale,
        vy: -(2.0 + rand01() * 5.0 + df * 2.0) * physScale,
        tier: g
      })
    }
  }
}

function tickExplosion(grid, rows, cols, particles, physScale) {
  var gravity = 0.50 * physScale, drag = 0.985
  for (var i = 0; i < grid.length; i++) grid[i] = 0
  var live = []
  for (var p = 0; p < particles.length; p++) {
    var pt = particles[p]
    pt.vy += gravity
    pt.vx *= drag
    pt.x += pt.vx
    pt.y += pt.vy
    var ix = Math.floor(pt.x), iy = Math.floor(pt.y)
    if (iy < 0 || iy >= rows || ix < 0 || ix >= cols) continue
    grid[iy * cols + ix] = pt.tier
    live.push(pt)
  }
  particles.length = 0
  for (var i2 = 0; i2 < live.length; i2++) particles.push(live[i2])
}
