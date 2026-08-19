// Firefly — vis_firefly.go: meadow at dusk with drifting fireflies
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, S = d.S, frame = d.frame
  var bass = H.bandAvg(bands, 0, Math.max(1, Math.floor(count / 3)))
  var high = H.bandAvg(bands, Math.floor(2 * count / 3), count)
  var wind = bass * 1.5
  var numFlies = 26

  // Grass silhouette at bottom
  ctx.fillStyle = "rgba(0, 80, 20, 0.6)"
  for (var x = 0; x < w; x += 2) {
    var gh = 1 + Math.floor(2.5 + 1.5 * Math.sin(x * 0.41) + 1.0 * Math.sin(x * 0.17 + 2.3))
    gh = Math.max(1, Math.min(h / 3, gh * 2))
    ctx.fillRect(x, h - gh, 2, gh)
  }

  // Fireflies
  for (var i = 0; i < numFlies; i++) {
    var seed = i * 2246822519 + 11
    var fx = 0.012 + (seed % 17) / 3500.0
    var fy = 0.018 + ((seed >> 4) % 19) / 2900.0
    var phx = (seed % 1000) / 1000.0 * 2 * Math.PI
    var phy = ((seed >> 8) % 1000) / 1000.0 * 2 * Math.PI
    var t = frame
    var baseX = w / 2 + Math.cos(t * fx + phx) * (w - 6) * 0.45
    var baseY = (h - 4) * 0.5 + Math.sin(t * fy + phy) * (h - 6) * 0.4
    var x = Math.floor(baseX + wind * Math.sin(t * 0.02 + phx))
    var y = Math.floor(baseY)
    if (x < 0 || x >= w || y < 0 || y >= h - 1) continue
    // Skip if in grass
    var gh2 = 1 + Math.floor(2.5 + 1.5 * Math.sin(x * 0.41) + 1.0 * Math.sin(x * 0.17 + 2.3))
    if (y > h - gh2 * 2) continue
    // Blink
    var blink = Math.sin(t * 0.18 + i * 1.31) * 0.5
    var on = blink + 0.5 + high * 0.4 > 0.55
    if (on) {
      ctx.fillStyle = "rgba(255, 255, 100, 0.9)"
      ctx.fillRect(x, y, 2, 2)
      // Glow halo
      ctx.fillStyle = "rgba(255, 255, 100, 0.3)"
      ctx.fillRect(x - 2, y, 2, 2)
      ctx.fillRect(x + 2, y, 2, 2)
      ctx.fillRect(x, y - 2, 2, 2)
      ctx.fillRect(x, y + 2, 2, 2)
    } else {
      ctx.fillStyle = "rgba(200, 200, 50, 0.2)"
      ctx.fillRect(x, y, 2, 2)
    }
  }
}
