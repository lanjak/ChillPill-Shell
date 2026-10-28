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

    Text {
      text: "↓" + SysStats.formatRate(SysStats.rxRate)
      color: Theme.fg
      // fixed width so the pill does not twitch as the number changes
      Layout.preferredWidth: metrics.width
      horizontalAlignment: Text.AlignRight
      font: metrics.font
    }

    Text {
      text: "↑" + SysStats.formatRate(SysStats.txRate)
      color: Theme.fg
      opacity: 0.6
      Layout.preferredWidth: metrics.width
      horizontalAlignment: Text.AlignRight
      font: metrics.font
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
