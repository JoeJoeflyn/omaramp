// Checks that need no shell: every visualizer draws on a fake canvas, the three lists of
// visualizer ids agree, and the track list lights up the right row.
// Run: node tests/check.js
const fs = require('fs'), path = require('path'), assert = require('assert')
const root = path.join(__dirname, '..'), dir = path.join(root, 'visualizers')
const read = f => fs.readFileSync(path.join(root, f), 'utf8')

// The visualizers are QML JS libraries; strip the two QML-only lines to run them here
function load(name) {
  const src = read('visualizers/' + name + '.js')
    .replace(/^\.pragma library.*$/m, '').replace(/^\.import "helpers\.js" as H.*$/m, '')
  const names = [...src.matchAll(/^function (\w+)\(/gm)].map(m => m[1])
  return new Function('H', src + '\n;return {' + names.join(',') + '}')(name === 'helpers' ? null : load('helpers'))
}

// A canvas that counts calls and remembers which pixels fillRect touched
function mock(w, h) {
  const grid = new Uint8Array(w * h), calls = {}, points = []
  const grad = { addColorStop(offset, color) { assert(offset >= 0 && offset <= 1); assert(!/NaN|Infinity/.test(color)) } }
  const arities = { fillRect: 4, createLinearGradient: 4, createRadialGradient: 6, ellipse: 4, arc: 5, arcTo: 5,
    beginPath: 0, closePath: 0, stroke: 0, fill: 0, save: 0, restore: 0, rect: 4, moveTo: 2, lineTo: 2,
    quadraticCurveTo: 4, fillText: 3 }
  let depth = 0
  const base = {
    fillRect(x, y, rw, rh) {
      for (let yy = Math.max(0, Math.floor(y)); yy < Math.min(h, Math.ceil(y + rh)); yy++)
        for (let xx = Math.max(0, Math.floor(x)); xx < Math.min(w, Math.ceil(x + rw)); xx++) grid[yy * w + xx] = 1
    },
    createLinearGradient: () => grad, createRadialGradient: () => grad,
  }
  const ctx = new Proxy(base, {
    get: (o, k) => (...args) => {
      assert(k in arities && args.length === arities[k], 'invalid Qt Canvas call: ' + String(k) + ' (' + args.length + ' args)')
      assert(args.slice(k === 'fillText' ? 1 : 0).every(Number.isFinite), 'non-finite number in ' + k)
      if (k === 'arc') assert(args[2] >= 0, 'negative radius')
      if (k === 'moveTo' || k === 'lineTo') points.push(args)
      if (k === 'save') depth++
      if (k === 'restore') assert(depth-- > 0, 'restore without save')
      calls[k] = (calls[k] || 0) + 1
      return o[k]?.(...args)
    },
    set: (o, k, v) => { assert(!/NaN|Infinity/.test(String(v)), 'invalid ' + k); o[k] = v; return true },
  })
  return { ctx, grid, calls, points, check: () => assert.strictEqual(depth, 0), lit: () => grid.reduce((a, b) => a + b, 0) }
}

const W = 326, H = 46
function frame(i, state) {
  const bands = [], wave = []
  for (let b = 0; b < 24; b++) bands.push(Math.min(1, 0.55 * Math.exp(-b / 9) + 0.35 * Math.abs(Math.sin(i * 0.31 + b * 0.7))))
  for (let s = 0; s < 128; s++) wave.push(0.6 * Math.sin(s * 0.3 + i))
  return { bands, wave, lr: [0.5, 0.02], frame: i, playing: true, width: W, height: H, S: 2, count: 24, barW: 10, gap: 3, x0: 8,
    accent: { r: 0.5, g: 0.6, b: 0.9 }, foreground: '#fff', dim: '#888', beatDrop: i % 20 === 0 ? 1 : 0, progress: 0.3, state }
}
function run(name, frames, each) {
  const v = load(name), state = {}
  let m
  for (let i = 0; i < frames; i++) {
    const d = frame(i, state)
    if (each) each(d)
    m = mock(d.width, d.height)
    v.render(m.ctx, d)
    m.check()
  }
  return { m, state }
}

// 1. every style renders, and the panel, the player and the picker list the same styles
const files = fs.readdirSync(dir).filter(f => f.endsWith('.js') && f !== 'helpers.js').map(f => f.slice(0, -3)).sort()
for (const name of files) {
  try {
    run(name, 60)
    run(name, 20, d => {
      d.width = d.frame < 5 ? 326 : d.frame < 15 ? 55 : 1
      d.height = d.frame < 5 ? 46 : d.frame < 15 ? 21 : 1
      d.gap = Math.max(0, Math.min(3, Math.floor((d.width - d.count) / (d.count - 1))))
      d.barW = (d.width - (d.count - 1) * d.gap) / d.count
      d.x0 = 0
      d.playing = d.frame % 3 !== 0
      if (d.frame % 3 !== 1) { d.bands.fill(0); d.wave = []; d.lr.fill(0) }
      else d.bands.fill(1)
    })
  } catch (e) { throw new Error(name + ': ' + e.message, { cause: e }) }
}
const ids = (text, re) => [...text.matchAll(re)].map(m => m[1]).sort()
const panel = ids(read('Panel.qml').match(/property var visModes: \[(.*)\]/)[1], /"(\w+)"/g)
const picker = ids(read('VisPicker.qml'), /\{ id: "(\w+)", name:/g)
const renderers = ids(read('Player.qml').match(/_renderers: \(\{([\s\S]*?)\}\)/)[1], /"(\w+)":/g)
const shaders = fs.readdirSync(path.join(root, 'shaders')).filter(f => f.endsWith('.qsb')).map(f => f.replace('.frag.qsb', '')).sort()
assert.deepStrictEqual(renderers, files)
assert.deepStrictEqual(panel, [...files, ...shaders].sort())
assert.deepStrictEqual(picker, panel)

// 2. the fixed styles keep behaving
{ // geyser sprays evenly to both sides
  let n = 0, vx = 0, left = 0
  const v = load('geyser'), state = {}
  for (let i = 0; i < 400; i++) {
    v.render(mock(W, H).ctx, frame(i, state))
    for (const p of state.geyserParticles) if (p.life === 1) { n++; vx += p.vx; if (p.x < W / 2) left++ }
  }
  assert(Math.abs(vx / n) < 0.15 && Math.abs(left / n - 0.5) < 0.08, 'geyser leans: ' + vx / n + ' ' + left / n)
}
{ // flame rises straight above its source
  const { state } = run('flame', 200, d => { d.bands = d.bands.map((_, b) => b === 11 || b === 12 ? 1 : 0) })
  const cols = Math.floor(W / 4), centre = r => { let s = 0, w = 0; for (let c = 0; c < cols; c++) { const h = state.flameHeat[r * cols + c]; s += h * c; w += h } return s / w }
  assert(Math.abs(centre(12) - centre(0)) < 4, 'flame drifts')
}
assert(run('mosaic', 1).state.mosaicCells.every(c => c.threshold >= 0.04), 'mosaic tile without a threshold')
{ // bars dot has gaps, and the bars sit in the middle
  const bars = run('bars', 8).m, dots = run('bars_dot', 8).m
  assert(dots.lit() < bars.lit() * 0.4, 'bars_dot is solid')
  let min = W, max = -1
  bars.grid.forEach((on, i) => { if (on) { min = Math.min(min, i % W); max = Math.max(max, i % W) } })
  assert(Math.abs(min - (W - 1 - max)) <= 1, 'bars off centre')
}
{ // stereo: each meter follows its own channel
  const { m } = run('stereo', 1), row = y => { let n = 0; for (let x = 0; x < W; x++) n += m.grid[y * W + x]; return n }
  assert(row(10) > row(34) + 100 && row(34) > 0, 'stereo meters do not follow L/R')
}

{ // Bound the wave columns and warp projection, and never multiply old time by new speed.
  const { advancePhase } = load('helpers'), state = {}
  assert.strictEqual(advancePhase(state, 'phase', 8000, 0.01), 0)
  assert.strictEqual(advancePhase(state, 'phase', 8001, 0.2), 0.2)
  assert.strictEqual(advancePhase(state, 'phase', 8001, 0.8), 0.2)
  for (const name of ['telegram_wave', 'soundcloud_wave', 'heatmap_wave', 'led_scrubber']) {
    const { m } = run(name, 1, d => { d.width = 55; d.height = 21; d.bands.fill(1) })
    assert(m.points.every(([x,y]) => x >= 0 && x <= 55 && y >= 0 && y <= 21), name + ' clips at narrow width')
  }
  const warp = load('osc_warp'), warpState = {}
  for (let n = 0; n < 400; n++) {
    const d = frame(n, warpState), m = mock(W, H)
    d.bands.fill(1); d.wave = d.wave.map(v => v / 0.6); d.beatDrop = 1
    warp.render(m.ctx, d)
    assert(m.points.every(([x,y]) => x >= 0 && x <= W && y >= 0 && y <= H), 'warp clips at ' + n)
  }
}
{ // Freshness uses capture time, not changes in the values (steady audio still advances).
  const source = read('Panel.qml').match(/function updateSpectrumData\([\s\S]*?\n  \}/)[0]
  const now = 10000, root = { opened: true, isPlaying: true, _spectrumSince: now - 300, _lastSpectrumAt: 0, visFrame: 0 }
  const receive = new Function('root', 'Date', source + '; return updateSpectrumData')(root, { now: () => now })
  const frame = t => JSON.stringify({ captured_at: t, bands: Array(24).fill(0.4), wave: [-2, 1.5], lr: [0.4, 0] })
  receive(frame(now - 500)); assert.strictEqual(root.visFrame, 0)
  receive(frame(now - 20)); receive(frame(now - 20)); receive(frame(now - 1))
  assert.strictEqual(root.visFrame, 2)
  assert.deepStrictEqual(root.visWave, [-1, 1])
  root.isPlaying = false
  receive(frame(now)); assert.strictEqual(root.visFrame, 2)
}

{ // Only local file URIs are drops; decode exactly once and skip malformed entries individually.
  const src = read('BarWidget.qml').match(/function droppedPaths\([\s\S]*?\n  \}/)[0]
  const paths = new Function(src + '; return droppedPaths')()
  assert.deepStrictEqual(paths(['file:///music/bad%FF', 'file:///music/%00', 'https://example.com/file.mp3',
    'file://otherhost/remote.mp3', 'file:///music/%E2%99%AB%20%231%25.wav', 'file://localhost/music/%2520.flac']),
    ['/music/♫ #1%.wav', '/music/%20.flac'])
}

// 3. which row is "the one playing" (the function lives in TrackList.qml)
const fn = read('TrackList.qml').match(/function isTrackCurrent\([\s\S]*?\n  \}\n/)[0]
const current = (p, ...item) => new Function('p', fn + '; return isTrackCurrent')(p)(...item)
const yt = id => 'https://www.youtube.com/watch?v=' + id
const playing = { currentTrack: 'Toxicity', currentArtist: 'System Of A Down', currentUrl: yt('iywaBOMvYLI') }
assert(current(playing, yt('iywaBOMvYLI'), 'Toxicity', 'System Of A Down'))
assert(current(playing, 'https://youtu.be/iywaBOMvYLI', 'other title', ''))                 // same video, other link form
assert(!current(playing, yt('aaaaaaaaaaa'), 'Toxicity', 'System Of A Down'))               // same name, other video
assert(!current({ ...playing, currentUrl: '/music/a/Toxicity.mp3' }, '/music/b/Toxicity.mp3', 'Toxicity', 'System Of A Down'))
assert(current(playing, 'Toxicity System Of A Down', 'Toxicity', 'System Of A Down'))      // imported row without a link
assert(!current(playing, 'Aerials System Of A Down', 'Aerials', 'System Of A Down'))
assert(!current({ currentTrack: 'No track loaded', currentArtist: '', currentUrl: '' }, yt('iywaBOMvYLI'), 'Toxicity', ''))

console.log('ok: ' + files.length + ' canvas styles + ' + shaders.length + ' shaders, row matching')
