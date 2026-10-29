import QtQuick
import QtQuick.Layouts

RowLayout {
  Layout.alignment: Qt.AlignVCenter
  spacing: 2 * Config.pillScale
  layoutDirection: Qt.RightToLeft // icon after the text

  Text {
    text: "\uf0f3"
    font { family: Config.nerdFontFamily; pixelSize: 10 * box.dpi }
    color: notificationModule.notifications.length > 0 ? Theme.notifFg : Theme.notifFgOff
  }

  Text {
    text: notificationModule.notifications.length
    font { family: Config.textFontFamily; pixelSize: 10 * box.dpi }
    color: Theme.fg
  }

}
