// Binary — cliamp vis_binary.go: streaming 0s and 1s, scroll speed ∝ energy
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, barW = d.barW, gap = d.gap, S = d.S, frame = d.frame
  ctx.fillStyle = "rgba(0, 0, 0, 0.2)"
  ctx.fillRect(0, 0, w, h)
  ctx.font = "8px monospace"
  var col = 0
  for (var b = 0; b < count; b++) {
    var energy = d.playing ? (bands[b] || 0) : 0
    var bx = b * (barW + gap)
    for (var xr = 0; xr < barW; xr += S, col++) {
      var speed = Math.max(1, 4 - Math.floor(energy * 3))
      var scroll = Math.floor(frame / speed)
      for (var y = 0; y < h; y += S) {
        var hv = H.scatterHash(b, y + scroll, col, 0)
        var oneProb = energy * 0.6 + 0.15
        var ch = hv < oneProb ? "1" : "0"
        if (ch === "1" && energy > 0.4) ctx.fillStyle = "#00ff66"
        else if (ch === "1" || energy > 0.3) ctx.fillStyle = "rgba(0, 200, 50, 0.6)"
        else ctx.fillStyle = "rgba(0, 100, 30, 0.3)"
        ctx.fillText(ch, bx + xr, y + S)
      }
    }
  }
}
