// Bubbles — cliamp vis_bubbles.go: rising hollow rings, per-dot pop fade
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, S = d.S, frame = d.frame
  var avg = 0
  for (var i = 0; i < count; i++) avg += (bands[i] || 0)
  avg /= count
  for (var i = 0; i < 18; i++) {
    var seed = i * 104729 + 7919
    var r = (1.5 + (seed % 100) / 100.0 * 2.5) * S
    var speedDiv = 3 + Math.floor(r / S)
    var wrap = Math.floor(h + r * 2 + 8 * S)
    var baseY = (seed * 3037) % wrap
    var y = Math.floor(wrap - 1 - ((baseY + Math.floor(frame / speedDiv)) % wrap) - r - 2 * S)
    var baseX = seed % w
    var swayPhase = (seed % 1000) / 1000.0 * 2 * Math.PI
    var swayAmp = (1.5 + avg * 2.5) * S
    var sway = Math.sin(frame * 0.03 + swayPhase) * swayAmp
    var x = Math.floor(baseX + sway)
    // Pop fade near top
    var popZone = Math.floor(r + 3 * S)
    var popFade = y < popZone ? Math.max(0, y / popZone) : 1.0
    // Dot-by-dot hollow ring
    var inner = r - 0.9 * S
    var bbox = Math.floor(r) + 1
    for (var dy = -bbox; dy <= bbox; dy++) {
      for (var dx = -bbox; dx <= bbox; dx++) {
        var dist = Math.sqrt(dx * dx + dy * dy)
        if (dist > r || dist < inner) continue
        if (popFade < 1.0 && H.scatterHash(i, dy, dx, 0) > popFade) continue
        var gx = x + dx, gy = y + dy
        if (gx >= 0 && gx < w && gy >= 0 && gy < h) {
          ctx.fillStyle = "rgba(0, 229, 255, 0.6)"
          ctx.fillRect(gx, gy, 1, 1)
        }
      }
    }
    // Specular highlight
    if (r >= 2 * S && popFade > 0.5) {
      var hx = Math.floor(x - r * 0.45), hy = Math.floor(y - r * 0.45)
      ctx.fillStyle = "rgba(255, 255, 255, 0.7)"
      ctx.fillRect(hx, hy, 1, 1)
      ctx.fillRect(hx + 1, hy, 1, 1)
      ctx.fillRect(hx, hy + 1, 1, 1)
    }
  }
}
