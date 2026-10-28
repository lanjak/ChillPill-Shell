import QtQuick
import QtQuick.Layouts

// cpu usage; hover shows the last minute, click opens the process list
Item {
  id: root
  property int fontSize: 10 * Config.pillScale
  readonly property real value: SysStats.cpuShown
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 4 * Config.pillScale

    Text {
      text: String.fromCodePoint(0xf0ee0) // nf-md-cpu_64_bit
      color: root.value >= 90 ? Theme.danger : root.value >= 70 ? Theme.warnMed : Theme.fg
      font { family: Theme.nerdFontFamily; pixelSize: root.fontSize }
      Behavior on color { ColorAnimation { duration: 350; easing.type: Easing.OutQuad } }
    }

    // fixed width (padded text), changed digits roll
    RollingText {
      text: SysStats.formatPercent(root.value)
      value: root.value
      font: metrics.font
    }
  }

  TextMetrics {
    id: metrics
    text: "100%"
    font { family: Theme.fontFamily; pixelSize: root.fontSize; weight: 500 }
  }

  // consumes the press so the pill's own click (control center) does not fire
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: box.openSysmon("cpu")
  }
}
