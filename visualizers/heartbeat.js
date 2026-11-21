// Heartbeat — Hospital ECG monitor with sweeping phosphor trace & bass QRS pulse
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var wave = d.wave || [], w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0
  var s = d.state

  // Initialize rolling ECG buffer
  if (!s.ecgBuffer || s.ecgBuffer.length !== w || s.ecgHeight !== h) {
    s.ecgBuffer = new Array(w).fill(midY)
    s.ecgHeight = h
    s.ecgHead = 0
    s.ecgLastFrame = -1
    s.ecgBeatFrame = -20
  }

  // A short QRS-like shape follows the onset, not the phase of a free-running sine.
  if (isPlaying && frame !== s.ecgLastFrame) {
    s.ecgLastFrame = frame
    if (d.beatDrop === 1) s.ecgBeatFrame = frame
    var age = frame - s.ecgBeatFrame
    var pulse = [0.12, -0.18, 0.95, -0.36, 0.05, 0.20, 0.10][age] || 0
    var rawSample = wave[Math.floor(wave.length / 3)] || 0
    var sampleVal = midY - (pulse * 0.33 + rawSample * 0.10) * h
    var speed = Math.max(1, Math.round(w / 52))
    for (var sp = 0; sp < speed; sp++) {
      s.ecgBuffer[s.ecgHead] = sampleVal
      s.ecgHead = (s.ecgHead + 1) % w
    }
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
    var distAhead = (x - head + bufLen) % bufLen
    if (distAhead < Math.min(8, Math.floor(w / 4))) { started = false; continue } // erase head margin

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
  var tip = (head - 1 + bufLen) % bufLen
  ctx.fillStyle = "#ffffff"
  ctx.beginPath()
  ctx.arc(tip, s.ecgBuffer[tip], 2.5, 0, Math.PI * 2)
  ctx.fill()
}
