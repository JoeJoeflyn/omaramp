// Heartbeat — Hospital ECG monitor with sweeping phosphor trace & bass QRS pulse
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var wave = d.wave || [], w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0
  var s = d.state

  // Initialize rolling ECG buffer
  if (!s.ecgBuffer || s.ecgBuffer.length !== Math.floor(w)) {
    s.ecgBuffer = new Array(Math.floor(w)).fill(midY)
    s.ecgHead = 0
  }

  var bands = d.bands || []
  var bass = H.bandAvg(bands, 0, 4)
  var beatDrop = d.beatDrop || 0
  var n = wave.length

  // Calculate current pulse sample
  var sampleVal = 0
  if (isPlaying && n > 0) {
    var rawSample = wave[Math.floor((frame * 4) % n)] || 0
    // Inject QRS cardiac spike when bass/kick hits
    var qrs = (beatDrop > 0.3 || bass > 0.45) ? Math.sin(frame * 0.8) * (h * 0.42) : 0
    sampleVal = midY - (rawSample * (h * 0.30)) - qrs
  } else {
    sampleVal = midY
  }

  // Advance sweep head smoothly across monitor (2.0 px per frame = ~1.5s sweep)
  var speed = 2
  for (var sp = 0; sp < speed; sp++) {
    s.ecgBuffer[s.ecgHead] = sampleVal
    s.ecgHead = (s.ecgHead + 1) % s.ecgBuffer.length
  }

  // 1. Draw subtle grid / dashed baseline
  ctx.strokeStyle = "rgba(0, 255, 120, 0.15)"
  ctx.lineWidth = 1
  ctx.beginPath()
  for (var gx = 0; gx < w; gx += 12) {
    ctx.moveTo(gx, midY)
    ctx.lineTo(gx + 6, midY)
  }
  ctx.stroke()

  // 2. Draw Phosphor ECG Trace with fade trail behind sweep head
  var bufLen = s.ecgBuffer.length
  var head = s.ecgHead

  ctx.lineWidth = 2.0
  ctx.beginPath()
  var started = false

  for (var x = 0; x < bufLen; x++) {
    // Gap right ahead of the sweep head
    var distBehind = (head - x + bufLen) % bufLen
    if (distBehind < 8) continue // erase head margin

    var alpha = Math.max(0.15, 1.0 - (distBehind / bufLen) * 0.85)
    var y = s.ecgBuffer[x]

    if (!started) {
      ctx.moveTo(x, y)
      started = true
    } else {
      ctx.lineTo(x, y)
    }
  }

  ctx.strokeStyle = "#00ff88"
  ctx.stroke()

  // 3. Glowing Sweep Cursor / Beam Head
  var headY = s.ecgBuffer[head] || midY
  ctx.fillStyle = "#ffffff"
  ctx.beginPath()
  ctx.arc(head, headY, 2.5, 0, Math.PI * 2)
  ctx.fill()
}
