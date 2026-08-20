// LED Scrubber — Retro Digital Hardware Segmented LED Matrix Scrubber
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height
  var isPlaying = d.playing
  var progress = d.progress !== undefined ? d.progress : (d.state ? d.state.progress || 0 : 0)
  var beatDrop = d.beatDrop || 0
  var midY = h / 2.0

  // 44 segmented LED columns
  var numCols = 44
  var resampled = H.resampleBandsLinear(bands, numCols)

  var margin = 6
  var totalDrawW = w - margin * 2
  var gap = 2.5
  var colW = Math.max(2.5, (totalDrawW - (numCols - 1) * gap) / numCols)
  var actualW = numCols * colW + (numCols - 1) * gap
  var startX = margin + (totalDrawW - actualW) / 2.0
  var playheadX = startX + progress * actualW

  // LED block metrics (11 vertical segments per column)
  var numSegs = 11
  var segH = 2.4
  var segGap = 1.4
  var totalMatrixH = numSegs * segH + (numSegs - 1) * segGap
  var matrixStartY = midY - (totalMatrixH / 2.0)

  // Segment colors (from center outwards: neon cyan/green -> yellow -> hot red/magenta)
  var segColors = [
    "rgba(255, 60, 90, 0.95)",   // Outer top (Peak Red)
    "rgba(255, 140, 30, 0.95)",  // High (Orange)
    "rgba(255, 220, 40, 0.95)",  // Mid-high (Yellow)
    "rgba(80, 240, 160, 0.95)",  // Mid (Green)
    "rgba(0, 210, 255, 0.95)",   // Low-mid (Cyan)
    "rgba(0, 240, 255, 1.00)",   // Center core (Electric Cyan)
    "rgba(0, 210, 255, 0.95)",   // Low-mid
    "rgba(80, 240, 160, 0.95)",  // Mid
    "rgba(255, 220, 40, 0.95)",  // Mid-high
    "rgba(255, 140, 30, 0.95)",  // High
    "rgba(255, 60, 90, 0.95)"    // Outer bottom (Peak Red)
  ]

  for (var col = 0; col < numCols; col++) {
    var cx = startX + col * (colW + gap)
    var colCenter = cx + colW / 2.0
    var isPlayed = colCenter <= playheadX

    // Track dynamic profile envelope
    var env = Math.sin((col / numCols) * Math.PI)
    var shapeVal = 0.20 + env * 0.45 + Math.sin(col * 0.8) * 0.15
    var energy = isPlaying ? (resampled[col] || 0) : 0.0
    var kick = (col >= 2 && col <= 12) ? (beatDrop * 0.25) : 0.0

    // Number of active illuminated segments (1 to 5 outward from center)
    var norm = Math.min(1.0, shapeVal * 0.40 + energy * 0.65 + kick)
    var activeRadius = Math.max(1, Math.round(norm * 5))

    var centerIdx = Math.floor(numSegs / 2) // 5

    for (var s = 0; s < numSegs; s++) {
      var sy = matrixStartY + s * (segH + segGap)
      var distFromCenter = Math.abs(s - centerIdx)
      var isLit = distFromCenter <= activeRadius

      if (isLit) {
        if (isPlayed) {
          // ── Played & Lit: Vivid glowing LED block ──
          ctx.fillStyle = segColors[s]
        } else {
          // ── Unplayed & Lit: Dim illuminated LED ──
          ctx.fillStyle = "rgba(255, 255, 255, 0.35)"
        }
      } else {
        // ── Unlit: Dark unlit LED matrix cell silhouette ──
        ctx.fillStyle = isPlayed ? "rgba(255, 255, 255, 0.08)" : "rgba(255, 255, 255, 0.04)"
      }

      ctx.beginPath()
      H.roundedRect(ctx, cx, sy, colW, segH, 0.8)
      ctx.fill()
    }
  }

  // ── Digital Cursor Playhead ──
  if (isPlaying && actualW > 0) {
    var curX = Math.max(startX, Math.min(startX + actualW, playheadX))

    ctx.fillStyle = "#ffffff"
    ctx.fillRect(curX - 1, matrixStartY - 2, 2, totalMatrixH + 4)

    // Glowing top & bottom LED dots
    ctx.beginPath()
    ctx.arc(curX, matrixStartY - 2, 2.0, 0, Math.PI * 2)
    ctx.arc(curX, matrixStartY + totalMatrixH + 2, 2.0, 0, Math.PI * 2)
    ctx.fillStyle = "#00ffff"
    ctx.fill()
  }
}
