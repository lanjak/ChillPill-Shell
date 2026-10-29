import Quickshell
import QtQuick
import QtQuick.Layouts
RowLayout {
  id: root
  property string fg: Theme.fg
  property int fontSize: 10 * Config.pillScale
  property var battery: box.battery
  property bool charging: box.charging
  property bool hasBattery: box.hasBattery
  spacing: 2 * Config.pillScale
  layoutDirection: Qt.RightToLeft // icon after the text

  // icon: battery on laptops, plug on desktops
  Text {
    text: box.batteryIcon
    color: hasBattery ? box.batteryIconColor : Theme.batteryOkFg

    font {
      family: Theme.nerdFontFamily
      pixelSize: hasBattery ? fontSize : fontSize + 2
    }
  }

  // percentage, only makes sense with a battery like laptop
  Text {
    visible: hasBattery
    text: box.batteryLevel + "%"
    color: fg

    font {
      family: Theme.fontFamily
      weight: 500
      pixelSize: fontSize
    }
  }
}
