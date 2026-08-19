// Columns — vis_columns.go: many thin interpolated columns
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count
  // Interpolate bands across full width for dense columns
  var colW = 2, colGap = 1
  var totalCols = Math.floor(w / (colW + colGap))
  var cols = H.resampleBandsLinear(bands, totalCols)
  for (var c = 0; c < totalCols; c++) {
    var level = d.playing ? (cols[c] || 0) : 0
    var barH = Math.round(level * h)
    var x = c * (colW + colGap)
    for (var y = 0; y < barH; y++) {
      ctx.fillStyle = H.specColor(1 - y / h)
      ctx.fillRect(x, h - 1 - y, colW, 1)
    }
  }
}
