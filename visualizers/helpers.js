// Shared helpers for all visualizers — ported from  visualizer.go
.pragma library

// scatterHash — deterministic per-dot hash for stable particle patterns
function scatterHash(band, row, col, frame) {
  var f = Math.floor((frame + row * 3 + col) / 3)
  var h = (band * 7919 + row * 6271 + col * 3037 + f * 104729) | 0
  h = Math.imul(h ^ (h >>> 16), 0x45d9f3b)
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296
}

// Integrate speed over new audio frames; an amplitude change must not
// rephase the entire elapsed animation, and a repaint is not a new frame.
function advancePhase(state, key, frame, speed) {
  var phase = state[key]
  if (!phase) phase = state[key] = { frame: frame, value: 0 }
  if (frame > phase.frame) phase.value += speed * Math.min(3, frame - phase.frame)
  phase.frame = frame
  return phase.value
}

// sampleBandLinear — linear interpolation between band values
function sampleBandLinear(bands, pos) {
  if (bands.length === 0) return 0
  if (bands.length === 1) return bands[0]
  if (pos <= 0) return bands[0]
  var last = bands.length - 1
  if (pos >= last) return bands[last]
  var idx = Math.floor(pos)
  var frac = pos - idx
  return bands[idx] * (1 - frac) + bands[idx + 1] * frac
}

// resampleBandsLinear — resample bands to N columns
function resampleBandsLinear(bands, totalCols) {
  if (totalCols <= 0 || bands.length === 0) return []
  if (bands.length === totalCols) return bands.slice()
  var out = new Array(totalCols)
  if (totalCols === 1) {
    out[0] = sampleBandLinear(bands, (bands.length - 1) / 2)
    return out
  }
  var last = bands.length - 1
  for (var col = 0; col < totalCols; col++) {
    var pos = col / (totalCols - 1) * last
    out[col] = sampleBandLinear(bands, pos)
  }
  return out
}

// bandAvg — mean of bands[lo:hi]
function bandAvg(b, lo, hi) {
  if (lo < 0) lo = 0
  if (hi > b.length) hi = b.length
  if (hi <= lo) return 0
  var s = 0
  for (var i = lo; i < hi; i++) s += b[i]
  return s / (hi - lo)
}

// Keep the full frequency range on small canvases by drawing fewer columns,
// rather than laying out the same number and losing the ends to clipping.
function fitColumns(width, desired, minWidth, spacing) {
  var margin = Math.min(6, width * 0.08)
  var room = width - margin * 2
  var count = Math.max(1, Math.min(desired, Math.floor((room + spacing) / (minWidth + spacing))))
  return { count: count, gap: spacing, left: margin, width: (room - (count - 1) * spacing) / count }
}

// specWrap: 3 discrete color tiers (green/yellow/red at 0.3/0.6)
// SpectrumLow = bright green, SpectrumMid = bright yellow, SpectrumHigh = bright red
function specColor(norm) {
  if (norm >= 0.6) return "rgba(255, 85, 85, 0.9)"   // bright red
  if (norm >= 0.3) return "rgba(255, 255, 85, 0.9)"  // bright yellow
  return "rgba(85, 255, 85, 0.9)"                    // bright green
}

// Universal rounded rectangle path compatible with all Qt Quick Canvas versions
function roundedRect(ctx, x, y, w, h, r) {
  if (w <= 0 || h <= 0) return
  if (r <= 0) {
    ctx.rect(x, y, w, h)
    return
  }
  var radius = Math.min(r, w / 2.0, h / 2.0)
  ctx.moveTo(x + radius, y)
  ctx.lineTo(x + w - radius, y)
  ctx.arcTo(x + w, y, x + w, y + radius, radius)
  ctx.lineTo(x + w, y + h - radius)
  ctx.arcTo(x + w, y + h, x + w - radius, y + h, radius)
  ctx.lineTo(x + radius, y + h)
  ctx.arcTo(x, y + h, x, y + h - radius, radius)
  ctx.lineTo(x, y + radius)
  ctx.arcTo(x, y, x + radius, y, radius)
}
