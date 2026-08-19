// Terrain — cliamp vis_terrain.go: scrolling buffer, new data enters right
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, frame = d.frame
  var s = d.state
  if (!s.terrainBuf || s.terrainBuf.length !== w) s.terrainBuf = new Array(w).fill(0.1)
  var buf = s.terrainBuf

  // Scroll left
  for (var x = 0; x < w - 1; x++) buf[x] = buf[x + 1]

  // New averaged spectrum value enters from right
  var avg = 0
  for (var i = 0; i < count; i++) avg += (bands[i] || 0)
  avg /= count
  var noise = H.scatterHash(0, 0, w - 1, Math.floor(frame / 3)) * 0.15
  buf[w - 1] = Math.max(0.03, avg + noise - 0.05)

  // Render filled terrain
  for (var x2 = 0; x2 < w; x2++) {
    var ty = h - 1 - Math.floor(buf[x2] * (h - 1))
    var norm = (h - ty) / h
    ctx.fillStyle = H.specColor(norm)
    for (var y = ty; y < h; y++) ctx.fillRect(x2, y, 1, 1)
  }
}
