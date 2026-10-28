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
  // nothing to show: PillBarModules hides the module so it leaves no gap
  readonly property bool empty: !SystemTray.items.values.some(i => i.status !== Status.Passive)

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
        hoverEnabled: true
        // per-icon tooltip through the shared popup (TooltipPopup's "tray" case);
        // callLater so it runs after PillBarModules' module-wide hover handler
        onEntered: Qt.callLater(() => {
          const item = trayIcon.modelData
          box.customTooltipText = item.tooltipTitle || item.title || item.id
          box.tooltipX = trayIcon.mapToGlobal(trayIcon.width / 2, 0).x
          box.tooltipVisible = box.customTooltipText !== ""
        })
        onClicked: (mouse) => {
          const item = trayIcon.modelData
          if (mouse.button === Qt.MiddleButton) {
            item.secondaryActivate()
          } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
            if (!item.hasMenu) {
              // XEmbed icons (Wine apps, through xembedsniproxy) have no menu,
              // the app draws its own once asked over D-Bus
              if (mouse.button === Qt.RightButton) {
                // global position under the icon, so the menu opens below the pill
                const p = trayIcon.mapToItem(null, 0, trayIcon.height)
                const sc = trayIcon.QsWindow.window.screen
                Quickshell.execDetached(["sh", "/usr/share/chillpill-shell/scripts/tray-context-menu.sh", item.id,
                  String(Math.round(sc.x + p.x)), String(Math.round(sc.y + Config.pillTopMargin + p.y + 4))])
              }
              return
            }
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
