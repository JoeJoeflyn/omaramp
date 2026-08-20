// Sand — falling-sand cellular automaton with dynamic audio streams & dune physics
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var h = d.height, w = d.width, frame = d.frame || 0
  var rows = Math.max(12, Math.floor(h / 2))
  var cols = Math.max(20, Math.floor(w / 2))
  var s = d.state

  if (s.sandRng === undefined) {
    s.sandRng = 0x5A4D5A4D
    s.sandPrevBass = 0
    s.sandGrid = new Array(rows * cols).fill(0)
    s.sandRows = rows
    s.sandCols = cols
  }

  if (!s.sandGrid || s.sandRows !== rows || s.sandCols !== cols) {
    s.sandGrid = new Array(rows * cols).fill(0)
    s.sandRows = rows
    s.sandCols = cols
  }

  var grid = s.sandGrid
  var rngVal = s.sandRng
  function rand01() {
    rngVal = (rngVal * 1664525 + 1013904223) & 0xFFFFFFFF
    return ((rngVal >>> 16) % 1000) / 1000.0
  }

  var numBands = Math.min(16, bands.length || 10)
  var resampled = H.resampleBandsLinear(bands, numBands)
  var bass = H.bandAvg(resampled, 0, Math.max(1, Math.floor(numBands / 3)))
  var delta = bass - (s.sandPrevBass || 0)
  s.sandPrevBass = bass

  // 1. Spawn Grains — Pour continuous sand streams from top based on frequency energy
  if (d.playing) {
    for (var b = 0; b < numBands; b++) {
      var lvl = resampled[b] || 0
      if (lvl < 0.05) continue
      var spawnCount = Math.floor(lvl * 3.2)
      if (rand01() < (lvl * 3.2 - spawnCount)) spawnCount++

      var centreX = Math.floor((b + 0.5) * (cols / numBands))
      var spread = Math.max(1, Math.floor(cols / (numBands * 2.5)))

      for (var sc = 0; sc < spawnCount; sc++) {
        var sx = centreX + Math.floor(rand01() * (2 * spread + 1)) - spread
        if (sx >= 0 && sx < cols) {
          var tier = b < numBands / 3 ? 3 : (b < (2 * numBands) / 3 ? 2 : 1)
          if (grid[sx] === 0) grid[sx] = tier
          else if (grid[cols + sx] === 0) grid[cols + sx] = tier
        }
      }
    }
  }

  // 2. Bass Kick / Beat Drop Eruption (vibrate and scatter dunes upward)
  var isBeatDrop = (d.beatDrop && d.beatDrop > 0.4) || (delta > 0.08 && bass > 0.20)
  if (isBeatDrop) {
    var kickPower = Math.min(1.0, (delta * 4.0) + (d.beatDrop || 0) * 0.5)
    var liftRows = 1 + Math.floor(kickPower * 5)
    for (var yk = 2; yk < rows; yk++) {
      var depthFactor = yk / rows
      var popChance = kickPower * (0.25 + 0.65 * depthFactor)
      for (var xk = 0; xk < cols; xk++) {
        var gVal = grid[yk * cols + xk]
        if (gVal === 0) continue
        if (rand01() < popChance) {
          var popY = Math.max(0, yk - Math.floor(1 + rand01() * liftRows))
          var popX = Math.max(0, Math.min(cols - 1, xk + Math.floor(rand01() * 5) - 2))
          if (grid[popY * cols + popX] === 0) {
            grid[popY * cols + popX] = gVal
            grid[yk * cols + xk] = 0
          }
        }
      }
    }
  }

  // 3. Falling Sand Simulation (Cellular Automaton Physics)
  var leftToRight = (frame % 2) === 0
  for (var y = rows - 2; y >= 0; y--) {
    var startX = leftToRight ? 0 : cols - 1
    var endX = leftToRight ? cols : -1
    var stepX = leftToRight ? 1 : -1

    for (var x = startX; x !== endX; x += stepX) {
      var grain = grid[y * cols + x]
      if (grain === 0) continue

      var below = (y + 1) * cols + x
      // 1. Direct fall straight down
      if (grid[below] === 0) {
        grid[below] = grain
        grid[y * cols + x] = 0
        continue
      }

      // 2. Slide diagonally down-left or down-right
      var dirA = rand01() < 0.5 ? -1 : 1
      var dirB = -dirA

      var nxA = x + dirA
      if (nxA >= 0 && nxA < cols && grid[(y + 1) * cols + nxA] === 0) {
        grid[(y + 1) * cols + nxA] = grain
        grid[y * cols + x] = 0
      } else {
        var nxB = x + dirB
        if (nxB >= 0 && nxB < cols && grid[(y + 1) * cols + nxB] === 0) {
          grid[(y + 1) * cols + nxB] = grain
          grid[y * cols + x] = 0
        }
      }
    }
  }

  // 4. Floor Drainage
  var drainRate = d.playing ? 0.05 : 0.15
  for (var xd = 0; xd < cols; xd++) {
    var btmIdx = (rows - 1) * cols + xd
    if (grid[btmIdx] !== 0 && rand01() < drainRate) {
      grid[btmIdx] = 0
    }
  }

  // 5. Render Sand Grains with Dynamic Glowing Palette
  var accent = d.accent || Qt.rgba(0.27, 0.33, 0.59, 1.0)
  var col1 = Qt.rgba(accent.r, accent.g, accent.b, 0.75)
  var col2 = Qt.rgba(Math.min(1.0, accent.r * 1.2 + 0.1), Math.min(1.0, accent.g * 1.1 + 0.1), Math.min(1.0, accent.b * 1.2 + 0.1), 0.9)
  var col3 = Qt.rgba(1.0, 0.82, 0.38, 0.95)

  for (var ry = 0; ry < rows; ry++) {
    for (var rx = 0; rx < cols; rx++) {
      var gTier = grid[ry * cols + rx]
      if (gTier === 0) continue

      if (gTier === 1) ctx.fillStyle = col1
      else if (gTier === 2) ctx.fillStyle = col2
      else ctx.fillStyle = col3

      ctx.fillRect(rx * 2, ry * 2, 2, 2)
    }
  }

  s.sandRng = rngVal
}
