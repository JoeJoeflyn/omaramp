// ClassicLED — vis_classic_led.go: Winamp 2.9 LED matrix with falling peak caps
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands, h = d.height, w = d.width, count = d.count
  var barW = 3, barGap = 1
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
  var rowPad = Math.max(0, w - bars * (barW + barGap) + barGap)
  for (var row = 0; row < h; row++) {
    var rfb = h - 1 - row
    var rowBottom = (h - 1 - row) / h
    for (var b = 0; b < bars; b++) {
      var lit = Math.floor(body[b] * h + 1e-6)
      var peakSeg = Math.floor(peak[b] * h + 1e-6)
      if (peakSeg >= h) peakSeg = h - 1
      var showPeak = peak[b] > body[b] + 0.5 / h && peakSeg >= lit
      var x = rowPad + b * (barW + barGap)
      if (rfb < lit) {
        ctx.fillStyle = H.specColor(rowBottom)
        ctx.fillRect(x, row, barW, 1)
      } else if (showPeak && rfb === peakSeg) {
        ctx.fillStyle = d.foreground
        ctx.fillRect(x, row, barW, 1)
      }
    }
  }
}
