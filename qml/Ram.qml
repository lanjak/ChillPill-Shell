import QtQuick
import QtQuick.Layouts

// memory usage; hover shows the last minute, click opens the process list
Item {
  id: root
  property int fontSize: 10 * Config.pillScale
  readonly property real value: SysStats.memPercentShown
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 2 * Config.pillScale
    layoutDirection: Qt.RightToLeft // icon after the text

    Text {
      text: String.fromCodePoint(0xf035b) // nf-md-memory
      color: root.value >= 90 ? Theme.danger : root.value >= 70 ? Theme.warnMed : Theme.fg
      font { family: Theme.nerdFontFamily; pixelSize: root.fontSize }
      Behavior on color { ColorAnimation { duration: 350; easing.type: Easing.OutQuad } }
    }

    // LOW / MED / HOT / MAX; changed letters roll
    RollingText {
      text: SysStats.level(root.value)
      value: root.value
      font: metrics.font
    }
  }

  TextMetrics {
    id: metrics
    text: "MAX"
    font { family: Theme.fontFamily; pixelSize: root.fontSize; weight: 500 }
  }

  // consumes the press so the pill's own click (control center) does not fire
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: box.openSysmon("ram")
  }
}
