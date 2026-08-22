// ClassicLED — exact Winamp 2.9 LED matrix with discrete blocks & falling peak caps
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width
  var barW = 6, barGap = 2
  var bars = Math.max(1, Math.floor((w + barGap) / (barW + barGap)))
  var levels = H.resampleBandsLinear(bands, bars)
  var s = d.state

  if (!s.ledBody || s.ledBody.length !== bars) {
    s.ledBody = new Array(bars).fill(0)
    s.ledPeak = new Array(bars).fill(0)
    s.ledHold = new Array(bars).fill(0)
  }

  var body = s.ledBody, peak = s.ledPeak, hold = s.ledHold
  var dt = 1 / 30, riseRate = 60.0, fallRate = 16.0, peakHoldT = 0.45, peakFall = 0.55

  for (var i = 0; i < bars; i++) {
    var target = d.playing ? (levels[i] || 0) : 0
    var rate = target > body[i] ? riseRate : fallRate
    body[i] += (target - body[i]) * (1 - Math.exp(-rate * dt))
    if (body[i] >= peak[i]) { peak[i] = body[i]; hold[i] = peakHoldT }
    else if (hold[i] > 0) hold[i] = Math.max(0, hold[i] - dt)
    else peak[i] = Math.max(body[i], peak[i] - peakFall * dt)
  }

  var segH = 3, segGap = 1
  var numSegs = Math.floor(h / (segH + segGap))
  var totalRenderW = bars * (barW + barGap) - barGap
  var startX = Math.max(0, Math.floor((w - totalRenderW) / 2))

  for (var b = 0; b < bars; b++) {
    var x = startX + b * (barW + barGap)
    var litSegs = Math.floor(body[b] * numSegs)
    var peakSeg = Math.min(numSegs - 1, Math.floor(peak[b] * numSegs))

    for (var seg = 0; seg < numSegs; seg++) {
      var y = h - (seg + 1) * (segH + segGap)
      var norm = seg / numSegs

      if (seg < litSegs) {
        ctx.fillStyle = H.specColor(norm)
        ctx.fillRect(x, y, barW, segH)
      } else if (seg === peakSeg && peak[b] > body[b] + 0.05) {
        ctx.fillStyle = "#ffffff"
        ctx.fillRect(x, y, barW, segH)
      }
    }
  }
}
