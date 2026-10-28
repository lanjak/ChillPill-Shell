import QtQuick

// filled line graph of the last minute of SysStats samples; values2 draws a
// second series on the same scale (network upload)
Canvas {
  id: graph

  property var values: []
  property var values2: []
  property color color: Theme.fg
  property color color2: Theme.netFg
  // 0 scales to the biggest sample (network), percentages pass 100
  property real maxValue: 0
  // SysStats.graphSlots / .interval; literals so the tooltip does not build SysStats on its own
  property int slots: 60
  property int sampleInterval: 1000

  // like the audio visualizer, motion spans the whole gap to the next sample
  // so the graph never stops between them: the line slides one slot left at
  // constant speed, and the vertical scale eases (OutQuad) to a new peak
  property real shift: 0
  NumberAnimation on shift {
    id: scroll
    running: false
    from: 1; to: 0
    duration: graph.sampleInterval
  }

  readonly property real targetTop: maxValue > 0 ? maxValue : Math.max(1, ...values, ...values2)
  property real scaleTop: targetTop
  Behavior on scaleTop {
    enabled: graph.visible
    NumberAnimation { duration: graph.sampleInterval; easing.type: Easing.OutQuad }
  }

  onValuesChanged: {
    if (visible && values.length > 1) scroll.restart()
    requestPaint()
  }
  onShiftChanged: requestPaint()
  onScaleTopChanged: requestPaint()
  onValues2Changed: requestPaint()
  onColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  function series(ctx, list, c) {
    if (list.length < 2) return
    const step = width / (slots - 1)
    // the newest point enters from one slot past the right edge
    const x1 = width + shift * step
    const x0 = x1 - (list.length - 1) * step
    const y = v => height - 1 - Math.min(v / scaleTop, 1) * (height - 2)
    ctx.beginPath()
    ctx.moveTo(x0, y(list[0]))
    for (let i = 1; i < list.length; i++) ctx.lineTo(x0 + i * step, y(list[i]))
    ctx.strokeStyle = c
    ctx.lineWidth = 1.5
    ctx.lineJoin = "round"
    ctx.stroke()
    ctx.lineTo(x1, height)
    ctx.lineTo(x0, height)
    ctx.closePath()
    ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.15)
    ctx.fill()
  }

  onPaint: {
    const ctx = getContext("2d")
    ctx.reset()
    series(ctx, values, color)
    series(ctx, values2, color2)
  }
}
