// Logo — vis_logo.go: pixel text "OMARAMP", energy-gated dots
.pragma library
.import "helpers.js" as H

// 5×7 pixel bitmaps for OMARAMP (bit 4 = leftmost pixel)
var glyphs = [
  [0x0E,0x11,0x11,0x11,0x11,0x11,0x0E], // O
  [0x11,0x1B,0x15,0x11,0x11,0x11,0x11], // M
  [0x0E,0x11,0x11,0x1F,0x11,0x11,0x11], // A
  [0x1E,0x11,0x11,0x1E,0x14,0x12,0x11], // R
  [0x0E,0x11,0x11,0x1F,0x11,0x11,0x11], // A
  [0x11,0x1B,0x15,0x11,0x11,0x11,0x11], // M
  [0x1E,0x11,0x11,0x1E,0x10,0x10,0x10]  // P
]
// Map 7 letters across 24 bands
var letterBand = [0, 3, 7, 10, 14, 18, 21]

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, frame = d.frame
  var lw = 5, lh = 7, gap = 2, nLetters = 7
  var totalW = nLetters * lw + (nLetters - 1) * gap
  var scaleX = Math.max(1, Math.floor(w / totalW))
  var scaleY = Math.max(1, Math.floor((h * 3 / 4) / lh))
  var renderedW = totalW * scaleX
  var renderedH = lh * scaleY
  var offX = Math.floor((w - renderedW) / 2)
  var baseOffY = Math.floor((h - renderedH) / 2)
  for (var li = 0; li < nLetters; li++) {
    var energy = bands[letterBand[li]] || 0
    var wave = Math.sin(frame * 0.06 + li * 0.9) * 1.5
    var bounce = Math.floor(energy * baseOffY * 0.3 + wave)
    var lx = offX + li * (lw + gap) * scaleX
    var ly = baseOffY - bounce
    for (var py = 0; py < lh; py++) {
      var row = glyphs[li][py]
      for (var px = 0; px < lw; px++) {
        if ((row & (1 << (lw - 1 - px))) === 0) continue
        var fill = energy * energy * 0.75 + 0.15
        for (var sy = 0; sy < scaleY; sy++) {
          for (var sx = 0; sx < scaleX; sx++) {
            var dx = lx + px * scaleX + sx
            var dy = ly + py * scaleY + sy
            if (dx < 0 || dx >= w || dy < 0 || dy >= h) continue
            if (H.scatterHash(li, py * scaleY + sy, px * scaleX + sx, frame) > fill) continue
            ctx.fillStyle = d.accent
            ctx.fillRect(dx, dy, 1, 1)
          }
        }
      }
    }
  }
}
