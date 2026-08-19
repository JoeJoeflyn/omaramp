// Mosaic — vis_mosaic.go: static heatmap of flickering tiles
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count
  var cellW = 4, cellGap = 2
  var numTiles = Math.floor((w + cellGap) / (cellW + cellGap))
  var numRows = Math.floor(h / 4)
  var s = d.state
  if (!s.mosaicCells || s.mosaicRows !== numRows || s.mosaicTiles !== numTiles) {
    s.mosaicRows = numRows
    s.mosaicTiles = numTiles
    s.mosaicCells = new Array(numRows * numTiles)
    var rngVal = 0xC1AB1A10
    for (var r = 0; r < numRows; r++) {
      var baseBand = numRows > 1 ? Math.floor((numRows - 1 - r) * (count - 1) / (numRows - 1)) : Math.floor(count / 2)
      for (var c = 0; c < numTiles; c++) {
        rngVal = (rngVal * 1664525 + 1013904223) & 0xFFFFFFFF
        var jitter = ((rngVal >> 16) % 5) - 2
        var band = Math.max(0, Math.min(count - 1, baseBand + jitter))
        rngVal = (rngVal * 1664525 + 1013904223) & 0xFFFFFFFF
        var th = 0.04 + ((rngVal >> 16) % 1000) / 1000.0 * 0.74
        s.mosaicCells[r * numTiles + c] = { bandIdx: band, threshold: th, value: 0 }
      }
    }
  }
  var cells = s.mosaicCells

  for (var i = 0; i < cells.length; i++) {
    var c = cells[i]
    var level = bands[c.bandIdx] || 0
    if (level > c.threshold) {
      var ignited = Math.min(1.05, level)
      if (ignited > c.value) c.value = ignited
    }
    c.value *= 0.88
    if (c.value < 0.001) c.value = 0
  }

  for (var r2 = 0; r2 < numRows; r2++) {
    for (var c2 = 0; c2 < numTiles; c2++) {
      var cell = cells[r2 * numTiles + c2]
      var v = cell.value
      if (v < 0.05) continue
      var x = c2 * (cellW + cellGap)
      var y = r2 * 4
      var color, alpha
      if (v >= 0.85) { color = "rgba(255,50,50,"; alpha = v }
      else if (v >= 0.65) { color = "rgba(255,200,0,"; alpha = v }
      else if (v >= 0.45) { color = "rgba(0,255,100,"; alpha = v }
      else if (v >= 0.28) { color = "rgba(0,200,80,"; alpha = v * 0.7 }
      else { color = "rgba(0,150,60,"; alpha = v * 0.4 }
      ctx.fillStyle = color + Math.min(0.9, alpha) + ")"
      ctx.fillRect(x, y, cellW, 3)
    }
  }
}
