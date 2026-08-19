// Matrix — cliamp vis_matrix.go: per-column streams, scatterHash gate
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, barW = d.barW, gap = d.gap, S = d.S, frame = d.frame
  ctx.fillStyle = "rgba(0, 0, 0, 0.15)"
  ctx.fillRect(0, 0, w, h)
  var col = 0
  for (var mc = 0; mc < count; mc++) {
    var energy = d.playing ? (bands[mc] || 0) : 0
    var mxBase = mc * (barW + gap)
    for (var mr = 0; mr < barW; mr += S, col++) {
      var seed = col * 7919 + 104729
      if (H.scatterHash(mc, 0, col, Math.floor(frame / 20)) > energy * 1.5 + 0.1) continue
      var speed = 2 + (seed % 3)
      var trailLen = 3 + Math.floor((seed / 7) % 3)
      var cycle = h + trailLen + 4
      var offset = Math.floor((seed / 13) % cycle)
      var pos = (Math.floor(frame / speed) + offset) % cycle
      for (var md = 0; md <= trailLen; md++) {
        var row = pos - md
        if (row < 0 || row >= h) continue
        if (md === 0) ctx.fillStyle = "#aaffaa"
        else if (md <= 2) ctx.fillStyle = "rgba(0, 255, 70, 0.8)"
        else ctx.fillStyle = "rgba(0, 180, 50, 0.4)"
        ctx.fillRect(mxBase + mr, row, S, S)
      }
    }
  }
}
