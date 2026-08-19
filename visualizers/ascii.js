// Ascii — cliamp vis_ascii.go: shade-block columns (█ ▓ ▒ ░)
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count
  var colW = 2, colGap = 1
  var totalCols = Math.floor(w / (colW + colGap))
  var cols = H.resampleBandsLinear(bands, totalCols)
  for (var c = 0; c < totalCols; c++) {
    var level = d.playing ? (cols[c] || 0) : 0
    var x = c * (colW + colGap)
    var barH = level * h
    for (var y = 0; y < h; y++) {
      var rowBottom = (h - 1 - y) / h
      var rowTop = (h - y) / h
      var fill = 0
      if (level >= rowTop) fill = 1.0
      else if (level > rowBottom) fill = (level - rowBottom) / (rowTop - rowBottom)
      if (fill > 0) {
        var alpha = fill >= 0.75 ? 0.9 : fill >= 0.5 ? 0.6 : fill >= 0.25 ? 0.35 : 0.15
        ctx.fillStyle = "rgba(0, 229, 255, " + alpha + ")"
        ctx.fillRect(x, y, colW, 1)
      }
    }
  }
}
