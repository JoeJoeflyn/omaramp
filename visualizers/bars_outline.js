// BarsOutline — cliamp vis_bars_outline.go: top-edge outline only
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, barW = d.barW, gap = d.gap
  ctx.lineWidth = 2
  for (var i = 0; i < count; i++) {
    var level = d.playing ? (bands[i] || 0) : 0
    var barH = Math.round(level * h)
    var x = i * (barW + gap)
    if (barH > 0) {
      var y = h - barH
      ctx.strokeStyle = H.specColor(1 - y / h)
      ctx.beginPath()
      ctx.moveTo(x, y)
      ctx.lineTo(x + barW, y)
      ctx.stroke()
    }
  }
}
