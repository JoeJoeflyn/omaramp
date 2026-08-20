// Bars — vis_bars.go: smooth fractional blocks
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, barW = d.barW, gap = d.gap
  for (var i = 0; i < count; i++) {
    var level = d.playing ? (bands[i] || 0) : 0
    var barH = Math.round(level * h)
    var x = i * (barW + gap)
    for (var y = 0; y < barH; y++) {
      var rowNorm = y / h
      ctx.fillStyle = H.specColor(rowNorm)
      ctx.fillRect(x, h - 1 - y, barW, 1)
    }
  }
}
