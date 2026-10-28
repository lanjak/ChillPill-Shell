pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// cpu / ram / network samples for the cpu, ram and netSpeed pill modules.
// A singleton is only built on first use, so nothing polls unless one of those
// modules is in pillModules; each /proc file is only read when its module is.
Singleton {
  id: root

  readonly property int interval: 2000
  // one minute of samples for the hover graph, plus two that sit past its
  // left edge, so the oldest point slides out instead of vanishing on screen
  readonly property int graphSlots: 60000 / interval
  readonly property int historyLength: graphSlots + 2

  readonly property var modules: Config.pillModules || []
  readonly property bool wantCpu: modules.includes("cpu")
  readonly property bool wantRam: modules.includes("ram")
  readonly property bool wantNet: modules.includes("netSpeed")

  property real cpuPercent: 0
  property var cpuHistory: []

  property real memTotalKb: 0
  property real memUsedKb: 0
  readonly property real memPercent: memTotalKb > 0 ? memUsedKb / memTotalKb * 100 : 0
  property var memHistory: []

  // bytes per second, all physical interfaces summed
  property real rxRate: 0
  property real txRate: 0
  property var rxHistory: []
  property var txHistory: []
  // [{ name, rx, tx }] per-interface rates, busiest first
  property var interfaces: []

  function push(list, v) {
    const next = list.length >= historyLength ? list.slice(1 - historyLength) : list.slice()
    next.push(v)
    return next
  }

  // short rate: " 12B" "340K" "1.2M", in bits or bytes (netSpeedUnit);
  // padded to 4 characters so the text keeps one width as the value changes
  function formatRate(bytesPerSec) {
    const bits = Config.netSpeedUnit === "bits"
    const step = bits ? 1000 : 1024
    let v = bits ? bytesPerSec * 8 : bytesPerSec
    const units = ["B", "K", "M", "G", "T"]
    let i = 0
    // roll over at 1000 so the text never grows past 4 characters
    while (v >= 999.5 && i < units.length - 1) { v /= step; i++ }
    return String((i > 0 && v < 9.95 ? v.toFixed(1) : Math.round(v)) + units[i]).padStart(4)
  }

  // memory size, padded to 5 characters ("1024M", "12.3G") so it keeps one width
  function formatKb(kb) {
    const s = kb >= 1048576 ? (kb / 1048576).toFixed(1) + "G"
            : kb >= 1024 ? Math.round(kb / 1024) + "M"
            : Math.round(kb) + "K"
    return s.padStart(5)
  }

  // percentage padded to one width: "  5%" / "100%", or "  0.5%" / "100.0%" with decimals
  function formatPercent(v, decimals) {
    const d = decimals || 0
    return (v.toFixed(d) + "%").padStart(d ? 6 : 4)
  }

  property var lastCpu: null
  property var lastNet: null
  property real lastNetAt: 0

  FileView {
    id: statFile
    path: "/proc/stat"
    onLoaded: {
      // cpu  user nice system idle iowait irq softirq steal
      const f = text().split("\n", 1)[0].trim().split(/\s+/).slice(1, 9).map(Number)
      const idle = f[3] + f[4]
      const total = f.reduce((a, b) => a + b, 0)
      if (root.lastCpu) {
        const dt = total - root.lastCpu.total
        root.cpuPercent = dt > 0 ? Math.max(0, Math.min(100, (1 - (idle - root.lastCpu.idle) / dt) * 100)) : 0
        root.cpuHistory = root.push(root.cpuHistory, root.cpuPercent)
      }
      root.lastCpu = { idle: idle, total: total }
    }
  }

  FileView {
    id: memFile
    path: "/proc/meminfo"
    onLoaded: {
      const m = text().match(/MemTotal:\s+(\d+)[\s\S]*MemAvailable:\s+(\d+)/)
      if (!m) return
      root.memTotalKb = Number(m[1])
      root.memUsedKb = root.memTotalKb - Number(m[2])
      root.memHistory = root.push(root.memHistory, root.memPercent)
    }
  }

  FileView {
    id: netFile
    path: "/proc/net/dev"
    onLoaded: {
      const now = Date.now()
      const counters = {}
      for (const line of text().split("\n").slice(2)) {
        const [name, rest] = line.split(":")
        if (!rest) continue
        const iface = name.trim()
        // loopback and virtual links would count the same traffic twice
        if (/^(lo|veth|docker|br-|virbr|vnet|tap)/.test(iface)) continue
        const f = rest.trim().split(/\s+/)
        counters[iface] = { rx: Number(f[0]), tx: Number(f[8]) }
      }
      if (root.lastNet) {
        const sec = (now - root.lastNetAt) / 1000
        const list = []
        let rx = 0, tx = 0
        for (const iface in counters) {
          const prev = root.lastNet[iface]
          if (!prev) continue
          // a counter that went backwards was reset (interface re-created)
          const r = Math.max(0, counters[iface].rx - prev.rx) / sec
          const t = Math.max(0, counters[iface].tx - prev.tx) / sec
          rx += r; tx += t
          list.push({ name: iface, rx: r, tx: t })
        }
        list.sort((a, b) => (b.rx + b.tx) - (a.rx + a.tx))
        root.rxRate = rx
        root.txRate = tx
        root.interfaces = list
        root.rxHistory = root.push(root.rxHistory, rx)
        root.txHistory = root.push(root.txHistory, tx)
      }
      root.lastNet = counters
      root.lastNetAt = now
    }
  }

  Timer {
    interval: root.interval
    running: root.wantCpu || root.wantRam || root.wantNet
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (root.wantCpu) statFile.reload()
      if (root.wantRam) memFile.reload()
      if (root.wantNet) netFile.reload()
    }
  }
}
