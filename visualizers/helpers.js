// Shared helpers for all visualizers — ported from cliamp's visualizer.go
.pragma library

// cliamp scatterHash — deterministic per-dot hash for stable particle patterns
function scatterHash(band, row, col, frame) {
  var f = Math.floor((frame + row * 3 + col) / 3)
  var h = (band * 7919 + row * 6271 + col * 3037 + f * 104729) & 0xFFFFFFFF
  h ^= Math.floor(h / 65536)
  h = (h * 0x45d9f3b) & 0xFFFFFFFF
  h ^= Math.floor(h / 65536)
  return (h % 10000) / 10000.0
}

// cliamp sampleBandLinear — linear interpolation between band values
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

// cliamp resampleBandsLinear — resample bands to N columns
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

// cliamp bandAvg — mean of bands[lo:hi]
function bandAvg(b, lo, hi) {
  if (lo < 0) lo = 0
  if (hi > b.length) hi = b.length
  if (hi <= lo) return 0
  var s = 0
  for (var i = lo; i < hi; i++) s += b[i]
  return s / (hi - lo)
}

// cliamp specWrap: 3 discrete color tiers (green/yellow/red at 0.3/0.6)
// SpectrumLow = bright green, SpectrumMid = bright yellow, SpectrumHigh = bright red
function specColor(norm) {
  if (norm >= 0.6) return "rgba(255, 85, 85, 0.9)"   // bright red
  if (norm >= 0.3) return "rgba(255, 255, 85, 0.9)"  // bright yellow
  return "rgba(85, 255, 85, 0.9)"                    // bright green
}

// LCG RNG — cliamp uses 64-bit constants that JS doubles can't handle precisely.
// 32-bit Numerical Recipes LCG produces equivalent deterministic pseudo-randomness.
function lcgRng(state) {
  state.v = (state.v * 1664525 + 1013904223) & 0xFFFFFFFF
  return state.v
}

// Extract [0,1) float from upper bits of an LCG state (use >>16, not >>33)
function lcgRand01(state) {
  lcgRng(state)
  return ((state.v >> 16) % 1000) / 1000.0
}
