// Rain — cliamp vis_rain.go: bar columns with falling streaks
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, barW = d.barW, gap = d.gap, S = d.S, frame = d.frame
  var col = 0
  for (var rn = 0; rn < count; rn++) {
    var level = d.playing ? (bands[rn] || 0) : 0
    var rnx = rn * (barW + gap)
    for (var rcol = 0; rcol < barW; rcol += S, col++) {
      var seed = col * 7919 + 104729
      if (H.scatterHash(rn, 0, col, Math.floor(frame / 12)) > level * 1.6 + 0.1) continue
      var speed = 1 + (seed % 3)
      var dropLen = 2 + Math.floor((seed / 7) % 3)
      var cycle = h + dropLen + 3
      var offset = Math.floor((seed / 13) % cycle)
      var pos = (Math.floor(frame / speed) + offset) % cycle
      for (var rd = 0; rd < dropLen; rd++) {
        var row = pos - rd
        if (row < 0 || row >= h) continue
        if ((h - 1 - row) / h >= level) continue
        var alpha = rd === 0 ? 0.9 : rd === 1 ? 0.6 : 0.3
        ctx.fillStyle = "rgba(0, 200, 255, " + alpha + ")"
        ctx.fillRect(rnx + rcol, row, S, S)
      }
    }
  }
}
