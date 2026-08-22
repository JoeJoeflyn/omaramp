// Columns — exact 1:1 translation of bjarneo/cliamp vis_columns.go
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || [], h = d.height, w = d.width
  var playing = d.playing

  // More bands and higher column density with tighter gaps
  var bandCount = 16
  var smoothedBands = H.resampleBandsLinear(bands, bandCount)

  // 1. Compute per-band column counts (64 chars across panel width)
  var totalWidthChars = 64
  var gapCount = bandCount - 1
  var totalBandCols = totalWidthChars - gapCount
  var baseCols = Math.floor(totalBandCols / bandCount)
  var extraCols = totalBandCols % bandCount

  var bandCols = new Array(bandCount)
  for (var b = 0; b < bandCount; b++) {
    bandCols[b] = baseCols + (b < extraCols ? 1 : 0)
  }

  // 2. interpolateBandColumns across each band's sub-columns
  var totalCols = 0
  for (var i = 0; i < bandCount; i++) totalCols += bandCols[i]

  var cols = new Array(totalCols)
  var offset = 0
  for (var b2 = 0; b2 < bandCount; b2++) {
    var width = bandCols[b2]
    var level = playing ? (smoothedBands[b2] || 0) : 0
    var nextLevel = level
    if (b2 + 1 < bandCount && playing) {
      nextLevel = smoothedBands[b2 + 1] || 0
    }
    for (var c = 0; c < width; c++) {
      var t = width > 1 ? (c / width) : 0
      cols[offset + c] = level * (1 - t) + nextLevel * t
    }
    offset += width
  }

  // 3. Render grid layout on canvas matching cliamp fracBlock & specWrap
  var charW = w / totalWidthChars
  var rows = 14
  var rowH = h / rows

  for (var row = 0; row < rows; row++) {
    var rowBottom = (rows - 1 - row) / rows
    var rowTop = (rows - row) / rows
    var colOffset = 0
    var xChar = 0

    ctx.fillStyle = H.specColor(rowBottom)

    for (var b3 = 0; b3 < bandCount; b3++) {
      var wCols = bandCols[b3]
      for (var c2 = 0; c2 < wCols; c2++) {
        var colLevel = cols[colOffset + c2]
        var blockX = (xChar + c2) * charW
        var blockY = row * rowH

        if (colLevel >= rowTop) {
          // Full block
          ctx.fillRect(blockX, blockY, Math.ceil(charW), Math.ceil(rowH))
        } else if (colLevel > rowBottom) {
          // Fractional block
          var frac = (colLevel - rowBottom) / (rowTop - rowBottom)
          var fracH = frac * rowH
          ctx.fillRect(blockX, blockY + (rowH - fracH), Math.ceil(charW), Math.ceil(fracH))
        }
      }

      colOffset += wCols
      xChar += wCols + 1 // +1 for the inter-band space gap!
    }
  }
}
