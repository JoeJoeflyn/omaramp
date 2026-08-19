// Butterfly — vis_butterfly.go: mirrored Rorschach, vertical band mapping
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, w = d.width, h = d.height, count = d.count, frame = d.frame
  var cx = w / 2
  for (var y = 0; y < h; y++) {
    var bandF = y / Math.max(1, h - 1) * (count - 1)
    var bi = Math.floor(bandF)
    var frac = bandF - bi
    var energy = bi >= count - 1 ? (bands[count-1] || 0) :
                 (bands[bi] || 0) * (1 - frac) + (bands[bi+1] || 0) * frac
    var t = frame * 0.08 + y * 0.3
    var wobble = Math.sin(t) * 0.15
    var wingW = Math.floor(cx * (energy + wobble) * 0.9)
    for (var dx = 0; dx < wingW; dx++) {
      var norm = dx / Math.max(1, wingW)
      var thresh = (1.0 - norm * norm) * energy
      if (norm > 0.6) thresh *= 0.5 + 0.5 * Math.sin(frame * 0.1 + y * 0.5 + dx * 0.3)
      if (H.scatterHash(bi, y, dx, Math.floor(frame / 3)) < thresh) {
        ctx.fillStyle = "rgba(0, 229, 255, 0.7)"
        ctx.fillRect(cx + dx, y, 1, 1)
        ctx.fillRect(cx - 1 - dx, y, 1, 1)
      }
    }
    if (energy > 0.05) {
      ctx.fillStyle = d.accent
      ctx.fillRect(cx, y, 1, 1)
      if (cx > 0) ctx.fillRect(cx - 1, y, 1, 1)
    }
  }
}
