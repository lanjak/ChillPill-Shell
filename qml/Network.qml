import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root

  spacing: 4 * Config.paddingScale

  property string iconFg: Theme.netFg
  property string disconIconFg: Theme.netFgOff

  readonly property bool wifiEnabled: Networking.wifiEnabled
  property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
  property var active: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null

  property var tetherDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected)
  readonly property bool tethered: tetherDevice !== undefined
  // usb tethering shows up as a wired device named usb0 / enp0s20u1 etc.
  readonly property bool usbTether: tethered && /^usb|u[0-9]/.test(tetherDevice.name)

  readonly property real signal: active ? active.signalStrength * 100 : 0

  readonly property string icon: {
    if (root.tethered) return String.fromCodePoint(root.usbTether ? 0xf287 : 0xf0200) // nf-fa-usb / nf-md-ethernet
    if (!Networking.wifiEnabled) return String.fromCodePoint(0xf092d)
    if (!active) return String.fromCodePoint(0xf092d)
    let s = signal / 100
    let tier = s >= 0.75 ? 4
             : s >= 0.50 ? 3
             : s >= 0.25 ? 2
             : 1
    return String.fromCodePoint(0xf091f + (tier - 1) * 3)
  }

  function toggleWifi() {
    Networking.wifiEnabled = !Networking.wifiEnabled
  }

  Text {
    text: root.icon
    color: root.tethered ? root.iconFg : (Networking.wifiEnabled ? iconFg : disconIconFg)

    font {
      family: Theme.nerdFontFamily
      pixelSize: 10 * Config.pillScale
    }
  }

  Text {
      text: {
          if (root.tethered) return root.usbTether ? "USB" : "LAN"
          if (!Networking.wifiEnabled) return "off"
          if (!root.active) return "N/A"
          return root.active.name
      }
      color: Theme.fg
      font { family: Theme.fontFamily; pixelSize: 10 * Config.pillScale; weight: 500 }
      elide: Text.ElideRight
      Layout.maximumWidth: 90 * Config.pillScale
  }
}
