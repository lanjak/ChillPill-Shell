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

    // fixed width (padded rates), changed digits roll
    Row {
      Text { text: "↓"; color: Theme.fg; font: metrics.font }
      RollingText { text: SysStats.formatRate(SysStats.rxRate); value: SysStats.rxRate; font: metrics.font }
    }

    Row {
      opacity: 0.6
      Text { text: "↑"; color: Theme.fg; font: metrics.font }
      RollingText { text: SysStats.formatRate(SysStats.txRate); value: SysStats.txRate; font: metrics.font }
    }
  }

  TextMetrics {
    id: metrics
    text: "↓999K"
    font { family: Theme.fontFamily; pixelSize: root.fontSize; weight: 500 }
  }

  // consumes the press so the pill's own click (control center) does not fire
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: box.openSysmon("netSpeed")
  }
}
