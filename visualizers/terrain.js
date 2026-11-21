// Terrain — vis_terrain.go: scrolling buffer, new data enters right
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
  buf[w - 1] = d.playing ? Math.max(0.02, avg + noise - 0.05) : Math.max(0.0, buf[w - 1] * 0.9 - 0.01)

  // Render filled terrain (green valleys, yellow slopes, red peaks).
  // One path per colour band: a rect per pixel cost thousands of calls a frame.
  var edges = [0, Math.floor(h - 1 - 0.6 * h) + 1, Math.floor(h - 1 - 0.3 * h) + 1, h]
  var norms = [0.6, 0.3, 0]
  for (var t = 0; t < 3; t++) {
    ctx.fillStyle = H.specColor(norms[t])
    ctx.beginPath()
    for (var x2 = 0; x2 < w; x2++) {
      var top = Math.max(edges[t], h - 1 - Math.floor(buf[x2] * (h - 1)))
      if (top < edges[t + 1]) ctx.rect(x2, top, 1, edges[t + 1] - top)
    }
    ctx.fill()
  }
}
