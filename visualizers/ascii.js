// Ascii — exact cliamp vis_ascii.go: shade-block columns (█ ▓ ▒ ░)
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width
  var playing = d.playing

  // Authentic monospace character grid matching cliamp
  var charW = 10
  var charH = 11
  var numCols = Math.floor(w / charW)
  var numRows = Math.floor(h / charH)
  if (numCols < 1 || numRows < 1) return

  var cols = H.resampleBandsLinear(bands, numCols)

  ctx.save()
  ctx.font = "bold 10px monospace"
  ctx.textAlign = "center"
  ctx.textBaseline = "middle"

  for (var c = 0; c < numCols; c++) {
    var level = playing ? Math.min(1.0, Math.max(0.0, cols[c] || 0)) : 0.0
    var barHeight = level * numRows
    var cx = c * charW + charW / 2

    for (var r = 0; r < numRows; r++) {
      // r = 0 is bottom, r = numRows - 1 is top
      var cy = h - (r * charH + charH / 2)
      var normY = r / numRows

      // Color tier matching cliamp specColor
      if (normY >= 0.6) ctx.fillStyle = "rgba(255, 85, 85, 0.95)"     // Bright red
      else if (normY >= 0.3) ctx.fillStyle = "rgba(255, 255, 85, 0.95)" // Bright yellow
      else ctx.fillStyle = "rgba(85, 255, 85, 0.95)"                  // Bright green

      if (r < Math.floor(barHeight)) {
        // Full solid block
        ctx.fillText("█", cx, cy)
      } else if (r === Math.floor(barHeight) && level > 0.02) {
        // Fractional shade block at top
        var frac = barHeight - Math.floor(barHeight)
        var shade = "░"
        if (frac >= 0.66) shade = "▓"
        else if (frac >= 0.33) shade = "▒"
        else shade = "░"
        ctx.fillText(shade, cx, cy)
      }
    }
  }

  ctx.restore()
}
