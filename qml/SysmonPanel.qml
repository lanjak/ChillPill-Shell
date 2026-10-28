import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// cpu / ram / netSpeed pill module panel: the last minute as a graph, then the
// busiest processes (cpu, ram) or interfaces (netSpeed), refreshed every second
Item {
  id: panel

  property string kind: "cpu" // cpu | ram | netSpeed
  signal closeRequested

  readonly property bool isNet: kind === "netSpeed"
  readonly property int rowCount: 7

  focus: true
  Keys.onEscapePressed: panel.closeRequested()
  Component.onCompleted: {
    forceActiveFocus()
    if (isNet) netRows.onInterfacesChanged()
  }

  // fixed rows updated in place, so values and bars animate instead of rebuilding
  ListModel { id: rows }

  function fill(list) {
    const top = Math.max(1e-9, ...list.map(r => r.value))
    for (let i = 0; i < list.length; i++) {
      const r = { name: list[i].name, text: list[i].text, value: list[i].value, share: list[i].value / top }
      if (i < rows.count) rows.set(i, r)
      else rows.append(r)
    }
    if (rows.count > list.length) rows.remove(list.length, rows.count - list.length)
  }

  // network rows come from SysStats, no extra process
  Connections {
    id: netRows
    target: SysStats
    enabled: panel.isNet
    function onInterfacesChanged() {
      panel.fill(SysStats.interfaces.slice(0, panel.rowCount).map(i => ({
        name: i.name,
        value: i.rx + i.tx,
        text: "↓" + SysStats.formatRate(i.rx) + "  ↑" + SysStats.formatRate(i.tx)
      })))
    }
  }

  // one long-lived top streams a frame every second while the panel is open
  property var frame: []
  property bool inTable: false

  function parseMem(s) {
    const unit = { m: 1024, g: 1048576, t: 1073741824 }[s.slice(-1)]
    return unit ? parseFloat(s) * unit : Number(s)
  }

  Process {
    running: !panel.isNet
    command: ["top", "-b", "-d", String(SysStats.interval / 1000), "-w", "512", "-o", panel.kind === "ram" ? "RES" : "%CPU"]
    // no toprc: a user's saved field layout would break the column parsing
    environment: ({ "HOME": "/nonexistent", "XDG_CONFIG_HOME": "/nonexistent" })
    stdout: SplitParser {
      onRead: (line) => {
        if (line.startsWith("top -")) { panel.inTable = false; panel.frame = []; return }
        if (!panel.inTable) { panel.inTable = line.trim().startsWith("PID"); return }
        if (panel.frame.length >= panel.rowCount) return
        // PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND
        const f = line.trim().split(/\s+/)
        if (f.length < 12) return
        const cpu = Number(f[8])
        const res = panel.parseMem(f[5])
        panel.frame.push(panel.kind === "ram"
          ? { name: f.slice(11).join(" "), value: res, text: SysStats.formatKb(res) }
          : { name: f.slice(11).join(" "), value: cpu, text: SysStats.formatPercent(cpu, 1) })
        if (panel.frame.length === panel.rowCount) panel.fill(panel.frame)
      }
    }
  }

  readonly property string title: kind === "ram" ? "Memory" : isNet ? "Network" : "CPU"
  readonly property string headline: kind === "ram"
    ? SysStats.formatKb(SysStats.memUsedKb) + " / " + SysStats.formatKb(SysStats.memTotalKb)
    : isNet ? "↓" + SysStats.formatRate(SysStats.rxRate) + "  ↑" + SysStats.formatRate(SysStats.txRate)
    : SysStats.formatPercent(SysStats.cpuPercent)

  // short staggered rise on open
  property real reveal: 0
  NumberAnimation on reveal { from: 0; to: 1; duration: 420; easing.type: Easing.OutExpo }
  function stage(i) { return Math.max(0, Math.min(1, panel.reveal * 4 - i * 0.5)) }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 6
    spacing: 8

    RowLayout {
      Layout.fillWidth: true
      opacity: panel.stage(0)
      transform: Translate { y: (1 - panel.stage(0)) * 8 }

      Text {
        text: panel.title
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 16 }
      }
      Item { Layout.fillWidth: true }
      RollingText {
        text: panel.headline
        value: panel.kind === "ram" ? SysStats.memUsedKb : panel.isNet ? SysStats.rxRate : SysStats.cpuPercent
        color: Theme.fg3
        font { family: Theme.fontFamily; pixelSize: 13 }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 64
      radius: 12
      color: Theme.bg2
      opacity: panel.stage(1)
      transform: Translate { y: (1 - panel.stage(1)) * 8 }

      SysGraph {
        anchors.fill: parent
        anchors.margins: 8
        values: panel.kind === "ram" ? SysStats.memHistory : panel.isNet ? SysStats.rxHistory : SysStats.cpuHistory
        values2: panel.isNet ? SysStats.txHistory : []
        maxValue: panel.isNet ? 0 : 100
      }
    }

    Column {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 2

      Text {
        visible: rows.count === 0
        width: parent.width
        topPadding: 20
        horizontalAlignment: Text.AlignHCenter
        text: panel.isNet ? "No traffic yet" : "Loading…"
        color: Theme.fg5
        font { family: Theme.fontFamily; pixelSize: 11 }
      }

      Repeater {
        model: rows

        delegate: Item {
          id: rowItem
          required property int index
          required property string name
          required property string text
          required property real value
          required property real share
          width: parent.width
          height: 21
          opacity: panel.stage(2 + index * 0.4)
          transform: Translate { y: (1 - panel.stage(2 + rowItem.index * 0.4)) * 6 }

          // usage bar behind the row, relative to the busiest entry
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            radius: 7
            width: parent.width * rowItem.share
            // an idle entry gets no bar instead of a rounded stub
            visible: width >= radius * 2
            color: Theme.bg3
            // the visualizer's feel: OutQuad across the whole gap to the next frame
            Behavior on width { NumberAnimation { duration: SysStats.interval; easing.type: Easing.OutQuad } }
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: valueText.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: rowItem.name
            elide: Text.ElideRight
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 11 }
          }

          RollingText {
            id: valueText
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: rowItem.text
            value: rowItem.value
            color: Theme.fg3
            font { family: Theme.fontFamily; pixelSize: 11 }
          }
        }
      }
    }
  }
}
