// Scatter — vis_scatter.go: density = bands² × gravity bias
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, barW = d.barW, gap = d.gap, S = d.S
  for (var sp = 0; sp < count; sp++) {
    var val = d.playing ? (bands[sp] || 0) : 0
    var spX = sp * (barW + gap)
    for (var sy = 0; sy < h; sy += S) {
      for (var sx = 0; sx < barW; sx += S) {
        var gravity = 0.5 + 0.5 * (h - sy) / h
        var threshold = val * val * gravity
        if (H.scatterHash(sp, Math.floor(sy / S), Math.floor(sx / S), d.frame) < threshold) {
          ctx.fillStyle = "rgba(0, 229, 255, " + (0.4 + val * 0.6) + ")"
          ctx.fillRect(spX + sx, sy, S, S)
        }
      }
    }
  }
}
