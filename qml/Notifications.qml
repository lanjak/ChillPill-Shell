import QtQuick
import QtQuick.Layouts

RowLayout {
  Layout.alignment: Qt.AlignVCenter

  Text {
    text: "\uf0f3"
    font { family: Config.nerdFontFamily; pixelSize: 10 * box.dpi }
    color: notificationModule.notifications.length > 0 ? Theme.fg : Theme.fg6
  }

  Text {
    text: notificationModule.notifications.length
    font { family: Config.textFontFamily; pixelSize: 10 * box.dpi }
    color: notificationModule.notifications.length > 0 ? Theme.fg : Theme.fg6
  }

}
