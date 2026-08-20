// Scrubber Wave — Full-size interactive waveform with live audio bounce & progress sweep
.pragma library
.import "helpers.js" as H

function render(ctx, d) {
  var bands = d.bands || []
  var w = d.width, h = d.height, frame = d.frame || 0
  var isPlaying = d.playing
  var midY = h / 2.0

  // 44 bold rounded waveform capsule bars
  var numBars = 44
  var resampled = H.resampleBandsLinear(bands, numBars)
  var beatDrop = d.beatDrop || 0
  var progress = d.progress !== undefined ? d.progress : (d.state ? d.state.progress || 0 : 0)

  // Layout spacing
  var gap = 3
  var barW = Math.max(3, Math.floor((w - (numBars - 1) * gap - 8) / numBars))
  var totalW = numBars * barW + (numBars - 1) * gap
  var startX = Math.floor((w - totalW) / 2)
  var playheadX = startX + progress * totalW

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

  // Draw 44 animated waveform bars
  for (var i = 0; i < numBars; i++) {
    var bx = startX + i * (barW + gap)
    var barCenter = bx + barW / 2.0
    var isPlayed = barCenter <= playheadX

    // Base waveform shape envelope (intro -> peaks -> chorus -> outro)
    var env = Math.sin((i / numBars) * Math.PI)
    var shapeVal = 0.20 + env * 0.40 + Math.sin(i * 0.8) * 0.15

    // Live audio energy modulation
    var energy = isPlaying ? (resampled[i] || 0) : 0.0
    var kick = (i >= 2 && i <= 10) ? (beatDrop * (h * 0.22)) : 0

    var minH = barW
    var maxH = h * 0.86
    var barH = Math.max(minH, (shapeVal * (h * 0.35)) + (energy * (maxH - minH) * 0.75) + kick)

    var by = midY - (barH / 2.0)
    var r = barW / 2.0

    if (isPlayed) {
      // Played: Luminous glowing accent gradient
      var grad = ctx.createLinearGradient(0, by, 0, by + barH)
      grad.addColorStop(0, "rgba(255, 255, 255, 0.95)")
      grad.addColorStop(0.35, "rgba(" + Math.min(255, ar + 45) + "," + Math.min(255, ag + 35) + ", 255, 0.95)")
      grad.addColorStop(1, "rgba(" + ar + "," + ag + "," + ab + ", 0.80)")
      ctx.fillStyle = grad
    } else {
      // Unplayed: Subtle translucent muted capsule
      ctx.fillStyle = "rgba(255, 255, 255, 0.22)"
    }

    // Draw smooth rounded capsule
    ctx.beginPath()
    ctx.arc(bx + r, by + r, r, Math.PI, 0, false)
    ctx.lineTo(bx + barW, by + barH - r)
    ctx.arc(bx + r, by + barH - r, r, 0, Math.PI, false)
    ctx.closePath()
    ctx.fill()
  }

  // Glowing Playhead Needle
  if (isPlaying && totalW > 0) {
    var curX = Math.max(startX, Math.min(startX + totalW, playheadX))
    ctx.fillStyle = "#ffffff"
    ctx.beginPath()
    ctx.rect(curX - 1, midY - h * 0.45, 2, h * 0.90)
    ctx.fill()
  }
}
