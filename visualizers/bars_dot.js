// BarsDot — vis_bars_dot.go: Braille dot-pattern bars (fill all dots, no skip)
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, barW = d.barW, gap = d.gap, S = d.S
  // : each terminal cell = 4×2 Braille grid. We map to 2×2 pixel dots.
  // Fill ALL dots where dotY < level (no stochastic skip — the dot grid IS the texture)
  for (var i = 0; i < count; i++) {
    var level = d.playing ? (bands[i] || 0) : 0
    var x = d.x0 + i * (barW + gap)
    // 4px pitch: at 2px the 2x2 dots touched and this drew plain bars
    for (var sy = 0; sy < h; sy += 4) {
      var dotY = (h - 1 - sy) / h
      if (dotY >= level) continue
      for (var sx = 0; sx < barW; sx += 4) {
        ctx.fillStyle = H.specColor(dotY)
        ctx.fillRect(x + sx, sy, 2, 2)
      }
    }
  }
}
