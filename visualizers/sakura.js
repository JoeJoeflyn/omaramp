// Sakura — vis_sakura.go: falling cherry blossom petals
.pragma library

var shapes = [
  [[0,1],[1,0],[1,1],[1,2],[2,0],[2,1]],
  [[0,1],[1,0],[1,1],[1,2],[2,1],[2,2]],
  [[0,1],[0,2],[1,0],[1,1],[1,2],[2,1]],
  [[0,1],[1,0],[1,1],[2,0]],
  [[0,0],[1,0],[1,1],[2,1]],
  [[0,0],[0,1],[1,1],[2,1]],
  [[0,0],[1,1]],
  [[0,1],[1,0]],
  [[0,0],[0,1],[1,0]]
]

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count, S = d.S, frame = d.frame
  var total = 0
  for (var i = 0; i < count; i++) total += (bands[i] || 0)
  var avg = total / count
  var numPetals = 12 + Math.floor(avg * 16)
  for (var p = 0; p < numPetals; p++) {
    var seed = p * 104729 + 7919
    var shapeIdx = (seed * 4391) % shapes.length
    var shape = shapes[shapeIdx]
    var fallSpeed = shapeIdx >= 6 ? 2 : 1
    var baseX = seed % w
    var wrapH = h + 10
    var baseY = (seed * 3037) % wrapH
    var y = (baseY + frame * fallSpeed / 8) % wrapH - 5
    var swayPhase = (seed % 1000) / 1000.0 * 2 * Math.PI
    var sway = Math.sin(frame * 0.015 + swayPhase) * 3.0
    var x = baseX + sway
    for (var di = 0; di < shape.length; di++) {
      var dr = Math.floor(y + shape[di][0] * S / 2)
      var dc = Math.floor(x + shape[di][1] * S / 2)
      if (dr >= 0 && dr < h && dc >= 0 && dc < w) {
        ctx.fillStyle = "rgba(255, 180, 200, 0.7)"
        ctx.fillRect(dc, dr, S / 2, S / 2)
      }
    }
  }
}
