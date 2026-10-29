import QtQuick
import QtQuick.Layouts

// download / upload rate; hover shows the last minute, click opens the interface list
Item {
  id: root
  property int fontSize: 10 * Config.pillScale
  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 5 * Config.pillScale

    Rate { rate: SysStats.rxShown; arrow: "↓"; font: metrics.font }
    Rate { rate: SysStats.txShown; arrow: "↑"; font: metrics.font; opacity: 0.6 }
  }

  // changed digits roll
  component Rate: Row {
    id: group
    property real rate: 0
    property string arrow: ""
    property font font
    Text { text: group.arrow; color: Theme.fg; font: group.font }
    RollingText { text: SysStats.formatRate(group.rate); value: group.rate; font: group.font }
  }

  TextMetrics {
    id: metrics
    font { family: Theme.fontFamily; pixelSize: root.fontSize; weight: 500 }
  }

  // consumes the press so the pill's own click (control center) does not fire
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: box.openSysmon("netSpeed")
  }
}
