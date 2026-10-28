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
    spacing: 4 * Config.pillScale

    Text {
      text: String.fromCodePoint(0xf035b) // nf-md-memory
      color: root.value >= 90 ? Theme.danger : root.value >= 70 ? Theme.warnMed : Theme.fg
      font { family: Theme.nerdFontFamily; pixelSize: root.fontSize }
      Behavior on color { ColorAnimation { duration: SysStats.glide; easing.type: Easing.OutQuad } }
    }

    Text {
      text: Math.round(root.value) + "%"
      color: Theme.fg
      // fixed width so the pill does not twitch as the number changes
      Layout.preferredWidth: metrics.width
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
    onClicked: box.openSysmon("ram")
  }
}
