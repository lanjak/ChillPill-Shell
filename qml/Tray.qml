import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts

// StatusNotifierItem tray icons: left click activates, middle click is the
// secondary action, right click (or left on menu-only items) opens the menu
RowLayout {
  id: root
  property int iconSize: 14 * Config.pillScale
  spacing: 6 * Config.paddingScale

  Repeater {
    model: SystemTray.items

    delegate: IconImage {
      id: trayIcon
      required property SystemTrayItem modelData
      // passive items ask to be hidden until they need attention
      visible: modelData.status !== Status.Passive
      source: modelData.icon
      implicitSize: root.iconSize
      Layout.alignment: Qt.AlignVCenter

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
          const item = trayIcon.modelData
          if (mouse.button === Qt.MiddleButton) {
            item.secondaryActivate()
          } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
            if (!item.hasMenu) return
            const p = trayIcon.mapToItem(null, 0, trayIcon.height)
            item.display(trayIcon.QsWindow.window, p.x, p.y)
          } else {
            item.activate()
          }
        }
        onWheel: (wheel) => trayIcon.modelData.scroll(wheel.angleDelta.y, false)
      }
    }
  }
}
