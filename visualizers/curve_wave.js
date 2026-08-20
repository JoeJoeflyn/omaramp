// Curve Wave — Smooth Bézier organic waveform (BezierCurveDrawer style)
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0

  var numPoints = 48
  var resampled = H.resampleBandsLinear(bands, numPoints)
  var beatDrop = d.beatDrop || 0
  var progress = d.progress !== undefined ? d.progress : 0

  // Dynamic accent color
  var acc = d.accent
  var ar = 100, ag = 180, ab = 255
  if (acc) {
    if (typeof acc === "string" && acc.charAt(0) === "#" && acc.length === 7) {
      ar = parseInt(acc.substr(1, 2), 16)
      ag = parseInt(acc.substr(3, 2), 16)
      ab = parseInt(acc.substr(5, 2), 16)
    } else if (acc.r !== undefined && acc.g !== undefined && acc.b !== undefined) {
      ar = Math.round(acc.r <= 1.0 ? acc.r * 255 : acc.r)
      ag = Math.round(acc.g <= 1.0 ? acc.g * 255 : acc.g)
      ab = Math.round(acc.b <= 1.0 ? acc.b * 255 : acc.b)
    }
  }

  var margin = 6
  var drawW = w - margin * 2
  var playheadX = margin + progress * drawW

  // Build smooth height data points
  var points = [] // { x, topY, botY }
  for (var i = 0; i < numPoints; i++) {
    var x = margin + (i / (numPoints - 1)) * drawW
    var env = Math.sin((i / numPoints) * Math.PI)
    var shape = 0.12 + env * 0.50 + Math.sin(i * 0.6 + 0.8) * 0.10
    var energy = isPlaying ? (resampled[i] || 0) : 0.0
    var kick = (i >= 2 && i <= 12) ? (beatDrop * (h * 0.16)) : 0
    var halfH = Math.min(h * 0.44, Math.max(1, (shape * (h * 0.28)) + (energy * (h * 0.50)) + kick))
    points.push({ x: x, topY: midY - halfH, botY: midY + halfH * 0.80 })
  }

  // Draw smooth Bézier curve path through points
  function bezierPath(pts, yKey) {
    if (pts.length < 2) return
    ctx.moveTo(pts[0].x, pts[0][yKey])
    for (var j = 0; j < pts.length - 1; j++) {
      var p0 = pts[j], p1 = pts[j + 1]
      var cpx = (p0.x + p1.x) / 2
      ctx.bezierCurveTo(cpx, p0[yKey], cpx, p1[yKey], p1.x, p1[yKey])
    }
  }

  // Helper: draw clipped Bézier fill
  function drawCurveFill(clipLeft, clipRight, fillStyle) {
    ctx.save()
    ctx.beginPath()
    ctx.rect(clipLeft, 0, clipRight - clipLeft, h)
    ctx.clip()

    ctx.beginPath()
    // Top Bézier curve
    bezierPath(points, "topY")
    // Bottom Bézier curve (reverse)
    for (var k = points.length - 1; k >= 0; k--) {
      var p = points[k]
      if (k === points.length - 1) {
        ctx.lineTo(p.x, p.botY)
      } else {
        var pNext = points[k + 1]
        var cpx2 = (p.x + pNext.x) / 2
        ctx.bezierCurveTo(cpx2, pNext.botY, cpx2, p.botY, p.x, p.botY)
      }
    }
    ctx.closePath()
    ctx.fillStyle = fillStyle
    ctx.fill()
    ctx.restore()
  }

  // Played portion: vibrant accent gradient fill
  var playedGrad = ctx.createLinearGradient(0, midY - h * 0.4, 0, midY + h * 0.35)
  playedGrad.addColorStop(0, "rgba(255, 255, 255, 0.92)")
  playedGrad.addColorStop(0.35, "rgba(" + Math.min(255, ar + 35) + "," + Math.min(255, ag + 25) + ", 255, 0.88)")
  playedGrad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.72)")
  drawCurveFill(margin, playheadX, playedGrad)

  // Unplayed portion: muted translucent
  drawCurveFill(playheadX, margin + drawW, "rgba(255, 255, 255, 0.16)")

  // Stroke outline on top for definition
  ctx.beginPath()
  bezierPath(points, "topY")
  ctx.strokeStyle = "rgba(255, 255, 255, 0.40)"
  ctx.lineWidth = 1.0
  ctx.stroke()

  // Playhead needle
  if (isPlaying && drawW > 0) {
    ctx.fillStyle = "#ffffff"
    ctx.fillRect(playheadX - 1, midY - h * 0.44, 2, h * 0.88)
  }
}
