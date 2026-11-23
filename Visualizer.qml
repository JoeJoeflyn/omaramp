import QtQuick
import "visualizers/bars.js" as VisBars
import "visualizers/bars_dot.js" as VisBarsDot
import "visualizers/bars_outline.js" as VisBarsOutline
import "visualizers/bricks.js" as VisBricks
import "visualizers/columns.js" as VisColumns
import "visualizers/classic_led.js" as VisClassicLED
import "visualizers/peaks.js" as VisPeaks
import "visualizers/wave.js" as VisWave
import "visualizers/scope.js" as VisScope
import "visualizers/heartbeat.js" as VisHeartbeat
import "visualizers/retro.js" as VisRetro
import "visualizers/scatter.js" as VisScatter
import "visualizers/flame.js" as VisFlame
import "visualizers/pulse.js" as VisPulse
import "visualizers/matrix.js" as VisMatrix
import "visualizers/butterfly.js" as VisButterfly
import "visualizers/sakura.js" as VisSakura
import "visualizers/firework.js" as VisFirework
import "visualizers/bubbles.js" as VisBubbles
import "visualizers/rain.js" as VisRain
import "visualizers/terrain.js" as VisTerrain
import "visualizers/logo.js" as VisLogo
import "visualizers/firefly.js" as VisFirefly
import "visualizers/geyser.js" as VisGeyser
import "visualizers/mosaic.js" as VisMosaic
import "visualizers/sand.js" as VisSand
import "visualizers/stereo.js" as VisStereo
import "visualizers/ascii.js" as VisAscii
import "visualizers/sine.js" as VisSine
import "visualizers/siriwave.js" as VisSiriWave
import "visualizers/soundcloud_wave.js" as VisSoundCloudWave
import "visualizers/telegram_wave.js" as VisTelegramWave
import "visualizers/led_scrubber.js" as VisLEDScrubber
import "visualizers/heatmap_wave.js" as VisHeatmapWave
import "visualizers/osc_warp.js" as VisOscWarp
import "visualizers/crt_scanline.js" as VisCRTScanline
import "visualizers/cyber_tunnel.js" as VisCyberTunnel

Item {
  id: root
  required property var p
  property bool compact: false
  property var drawState: ({})

  property real beatDropPulse: 0.0
  property real _bassAvg: 0.0
  property double _lastDropTime: 0
  property real shaderTime: 0

  function updateBeatDrop() {
    var subBass = Math.max(p.visBands[1], p.visBands[2], p.visBands[3], p.visBands[4], p.visBands[5])
    var delta = subBass - _bassAvg
    _bassAvg = _bassAvg * 0.85 + subBass * 0.15
    var now = Date.now()
    shaderTime += 0.025 + subBass * 0.026 + beatDropPulse * 0.02
    if (subBass > 0.40 && delta > 0.15 && (now - _lastDropTime) > 260) {
      beatDropPulse = 1.0
      _lastDropTime = now
    } else {
      beatDropPulse = Math.max(0.0, beatDropPulse * 0.88 - 0.02)
    }
  }

  readonly property var _renderers: ({
    "bars": VisBars.render, "bars_dot": VisBarsDot.render, "bars_outline": VisBarsOutline.render,
    "bricks": VisBricks.render, "columns": VisColumns.render, "classic_led": VisClassicLED.render,
    "peaks": VisPeaks.render, "wave": VisWave.render, "scope": VisScope.render,
    "heartbeat": VisHeartbeat.render, "retro": VisRetro.render, "scatter": VisScatter.render,
    "flame": VisFlame.render, "pulse": VisPulse.render, "matrix": VisMatrix.render,
    "butterfly": VisButterfly.render, "sakura": VisSakura.render,
    "firework": VisFirework.render, "bubbles": VisBubbles.render, "rain": VisRain.render,
    "terrain": VisTerrain.render, "logo": VisLogo.render, "firefly": VisFirefly.render,
    "geyser": VisGeyser.render, "mosaic": VisMosaic.render, "sand": VisSand.render,
    "stereo": VisStereo.render, "ascii": VisAscii.render, "sine": VisSine.render,
    "siriwave": VisSiriWave.render, "soundcloud_wave": VisSoundCloudWave.render,
    "telegram_wave": VisTelegramWave.render,
    "led_scrubber": VisLEDScrubber.render, "heatmap_wave": VisHeatmapWave.render,
    "osc_warp": VisOscWarp.render, "crt_scanline": VisCRTScanline.render,
    "cyber_tunnel": VisCyberTunnel.render
  })

  function requestPaint() { if (visible && visCanvas && visCanvas.visible) visCanvas.requestPaint() }

  Connections {
    target: p
    function onVisModeChanged() { root.drawState = ({}); root.requestPaint() }
    function onVisFrameChanged() { if (root.visible) { root.updateBeatDrop(); root.requestPaint() } }
    function onVisActiveChanged() {
      if (!p.visActive) {
        root.drawState = ({})
        root._bassAvg = 0
        root._lastDropTime = 0
        root.beatDropPulse = 0
      }
    }
  }

  onVisibleChanged: if (visible) requestPaint()

  ShaderEffect {
    id: gpuShader
    anchors.fill: parent
    visible: p.visMode.indexOf("glsl_") === 0

    readonly property real u_time: root.shaderTime
    readonly property real u_aspect: width / Math.max(1, height)
    readonly property real u_bass: {
      if (!p || !p.visBands || p.visBands.length < 4) return 0.0
      var s = 0; for (var i = 0; i < 4; i++) s += (p.visBands[i] || 0)
      return s / 4.0
    }
    readonly property real u_mids: {
      if (!p || !p.visBands || p.visBands.length < 14) return 0.0
      var s = 0; for (var i = 4; i < 14; i++) s += (p.visBands[i] || 0)
      return s / 10.0
    }
    readonly property real u_highs: {
      if (!p || !p.visBands || p.visBands.length < 24) return 0.0
      var s = 0; for (var i = 14; i < 24; i++) s += (p.visBands[i] || 0)
      return s / 10.0
    }
    readonly property real u_beat: root.beatDropPulse
    readonly property vector3d u_accent: Qt.vector3d(p.dynamicAccent.r, p.dynamicAccent.g, p.dynamicAccent.b)

    fragmentShader: p.visMode.indexOf("glsl_") === 0 ? ("shaders/" + p.visMode + ".frag.qsb") : "shaders/glsl_plasma.frag.qsb"
  }

  Canvas {
    id: visCanvas
    anchors.fill: parent
    visible: p.visMode.indexOf("glsl_") !== 0

    onPaint: {
      var ctx = getContext("2d")
      // Draw icon art in logical units so fixed-size strokes and particles still fit.
      var scale = root.compact ? Math.max(1, 48 / Math.max(1, height)) : 1
      var w = Math.floor(width * scale), h = Math.floor(height * scale)
      if (w < 1 || h < 1) return
      ctx.setTransform(1, 0, 0, 1, 0, 0)
      ctx.clearRect(0, 0, width, height)
      ctx.scale(1 / scale, 1 / scale)

      // ── Animated Nebula Plasma Background ──
      if (!root.compact && p.visActive) {
        var ar = p.dynamicAccent.r, ag = p.dynamicAccent.g, ab = p.dynamicAccent.b
        var t = p.visFrame * 0.02
        var beat = root.beatDropPulse
        var bass = 0
        if (p.visBands && p.visBands.length > 4) {
          for (var bi = 0; bi < 5; bi++) bass += (p.visBands[bi] || 0)
          bass /= 5.0
        }

        // Paint 5 drifting nebula blobs at different positions
        var blobs = [
          { cx: 0.15, cy: 0.35, rx: 0.30, ry: 0.70, r: ar, g: ag * 0.4, b: ab, drift: 1.0 },
          { cx: 0.85, cy: 0.60, rx: 0.28, ry: 0.65, r: ab * 0.8, g: ar * 0.5, b: ag, drift: -0.7 },
          { cx: 0.50, cy: 0.50, rx: 0.35, ry: 0.80, r: Math.min(1, ar + 0.2), g: Math.min(1, ag + 0.15), b: Math.min(1, ab + 0.2), drift: 1.3 },
          { cx: 0.30, cy: 0.70, rx: 0.22, ry: 0.55, r: ag * 0.6, g: ab * 0.7, b: ar * 0.9, drift: -1.1 },
          { cx: 0.72, cy: 0.30, rx: 0.25, ry: 0.60, r: ab * 0.5, g: ar * 0.8, b: Math.min(1, ag + 0.3), drift: 0.9 }
        ]

        for (var i = 0; i < blobs.length; i++) {
          var bl = blobs[i]
          // Drift position with time
          var bx = (bl.cx + Math.sin(t * bl.drift + i * 1.5) * 0.12) * w
          var by = (bl.cy + Math.cos(t * bl.drift * 0.8 + i * 2.0) * 0.15) * h
          var radiusX = bl.rx * w * (1.0 + bass * 0.4 + beat * 0.3)
          var radiusY = bl.ry * h * (1.0 + bass * 0.3 + beat * 0.2)
          var radius = Math.max(radiusX, radiusY)

          var grad = ctx.createRadialGradient(bx, by, 0, bx, by, radius)
          var alpha = bass * 0.15 + beat * 0.10
          grad.addColorStop(0, "rgba(" + Math.round(bl.r * 255) + "," + Math.round(bl.g * 255) + "," + Math.round(bl.b * 255) + "," + alpha.toFixed(2) + ")")
          grad.addColorStop(0.6, "rgba(" + Math.round(bl.r * 180) + "," + Math.round(bl.g * 120) + "," + Math.round(bl.b * 180) + "," + (alpha * 0.35).toFixed(2) + ")")
          grad.addColorStop(1, "rgba(0,0,0,0)")

          ctx.fillStyle = grad
          ctx.fillRect(0, 0, w, h)
        }
      }

      // ── Visualizer on top ──
      var count = 24
      var gap = Math.max(0, Math.min(3, Math.floor((w - count) / (count - 1))))
      var barW = (w - (count - 1) * gap) / count
      var fn = root._renderers[p.visMode]
      if (!fn) return
      ctx.save()
      try {
        fn(ctx, {
          bands: p.visBands, wave: p.visWave, lr: p.visLR, frame: p.visFrame,
          playing: p.visActive, width: w, height: h, S: 2,
          count: count, barW: barW, gap: gap, x0: 0,
          accent: p.dynamicAccent, foreground: p.foreground, dim: p.dim,
          beatDrop: root.beatDropPulse, progress: p.progress,
          state: root.drawState
        })
      } finally { ctx.restore() }
    }
  }
}
