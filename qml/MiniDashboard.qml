import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// mini dashboard contents, loaded on demand by shell.qml
Item {
  id: root

  property var username: Quickshell.env("USER") || "IDK YOU"
  property string hostname: Quickshell.env("HOST") || ""

  signal toggleCalendar()
  signal toggleWeather()

  // hostname, fetched only when not already in the environment
  Process {
    id: hostnameProc
    command: ["sh", "-c", "cat /etc/hostname"]
    running: root.hostname === ""
    stdout: StdioCollector {
      onStreamFinished: {
        const name = this.text.trim()
        if (name !== "") root.hostname = name
        hostnameProc.running = false
      }
    }
  }

  RowLayout {
   // profile picture (display picture)
    ClippingRectangle {
      id: avatarClip
      width: avatarSize
      height: avatarSize
      radius: avatarSize / 2
      property string imgPath: Config.displayPicture ? "file://" + Config.displayPicture.replace("~", Quickshell.env("HOME")) : ""
      color: (imgPath === "" || avatarImg.status !== Image.Ready) ? Theme.bg5 : Theme.transparent
      layer.enabled: true
      layer.smooth: true
      layer.mipmap: true
      layer.textureSize: Qt.size(avatarSize, avatarSize)

      Image {
        id: avatarImg
        anchors.fill: parent
        source: avatarClip.imgPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        sourceSize: Qt.size(avatarSize, avatarSize)
      }
    }

    // uptime
    Process {
      id: uptimeProc
      command: ["sh", "-c", 'uptime -p']
      running: true
      stdout: StdioCollector {
        onStreamFinished: uptimeText.text = this.text
      }
    }

    // uptime refresh every 60 sec
    Timer {
      interval: 60000
      running: box.miniDashboard
      repeat: true
      triggeredOnStart: true
      onTriggered: {
        uptimeProc.running = false
        uptimeProc.running = true
      }
    }

    // username + uptime stacked
    ColumnLayout {
      spacing: 2
      Layout.alignment: Qt.AlignVCenter

      RowLayout {
        Text {
          text: username
          color: Theme.fg
          Layout.leftMargin: 10
          font { family: Theme.fontFamily; pixelSize: 14; weight: 600 }
        }

        Text {
          text: "(" + hostname + ")"
          color: Theme.fg5
          Layout.topMargin: 2
          font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
        }
      }

      Text {
        id: uptimeText
        color: Theme.fg4
        Layout.leftMargin: 10
        font { family: Theme.fontFamily; pixelSize: 8; weight: 400 }
      }
    }
  }

  // show battery in mini dashboard too, but no plug icon on desktops
  Battery {
    visible: box.hasBattery
    fontSize: 14
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: 8
    anchors.rightMargin: 12
  }

  // internet protocol information
  IpStatus {
    anchors.left: parent.left
    anchors.leftMargin: 5
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 42
  }

  // data usage status
  DataUsage {
    anchors.right: parent.right
    anchors.rightMargin: 4
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 42
  }

  // rectangle where poweroff, sleep etc. buttons placed
  Rectangle {
    color: Theme.bg2
    implicitWidth: 15
    implicitHeight: 30
    radius: 8

    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: 97

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      spacing: 8

      // lock
      Rectangle {
        width: buttonSize; height: buttonSize
        radius: buttonctlRadius; color: buttonBg
        Layout.alignment: Qt.AlignVCenter
        Text {
          anchors.centerIn: parent;
          text: ""
          color: lockHover.containsMouse ? buttonHoverBg : Theme.fg;
          font { family: Config.nerdFontFamily; pixelSize: 8 }
          Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
        }

        MouseArea {
          id: lockHover
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { lockProc.running = false; lockProc.running = true }
          hoverEnabled: true
        }

        Process { id: lockProc; command: ["bash", "-c", Config.screenLockAppCommand]; running: false }
      }

      // sleep
      Rectangle {
        width: buttonSize; height: buttonSize
        radius: buttonctlRadius; color: buttonBg
        Layout.alignment: Qt.AlignVCenter
        Text {
          anchors.centerIn: parent;
          text: "󰤄"
          color: sleepHover.containsMouse ? buttonHoverBg : Theme.fg;
          font { family: Config.nerdFontFamily; pixelSize: 9 }
          Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
        }

        MouseArea {
          id: sleepHover
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { sleepProc.running = false; sleepProc.running = true }
          hoverEnabled: true
        }
        Process { id: sleepProc; command: ["bash", "-c", "systemctl suspend"]; running: false }
      }

      Item { Layout.fillWidth: true }

      Datetime {
        id: dashboardDatetime
        dateFg: Theme.fg4
        onToggleCalendar: root.toggleCalendar()
      }

      Item { Layout.fillWidth: true }

      Weather {
        fg: Theme.fg4
        clickable: true
        onToggleWeather: root.toggleWeather()
      }

      Item { Layout.fillWidth: true }

      // reboot
      Rectangle {
        width: buttonSize; height: buttonSize
        radius: buttonctlRadius; color: buttonBg
        Layout.alignment: Qt.AlignVCenter
        Text {
          anchors.centerIn: parent;
          text: ""
          color: rebootHover.containsMouse ? buttonHoverBg : Theme.fg;
          font { family: Config.nerdFontFamily; pixelSize: 9 }
          Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
        }

        MouseArea {
          id: rebootHover
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (Config.confirmPowerActions) {
              box.powerMenuInitialAction = "reboot"
              box.miniDashboard = false
              box.powerMenu = true
            } else {
              rebootProc.running = false
              rebootProc.running = true
            }
          }
          hoverEnabled: true
        }
        Process { id: rebootProc; command: ["bash", "-c", "systemctl reboot"]; running: false }
      }

      // shutdown
      Rectangle {
        width: buttonSize; height: buttonSize
        radius: buttonctlRadius; color: buttonBg
        Layout.alignment: Qt.AlignVCenter
        Text {
          anchors.centerIn: parent;
          text: "󰐥"
          color: shutdownHover.containsMouse ? buttonHoverBg : Theme.fg;
          font { family: Config.nerdFontFamily; pixelSize: 12 }
          Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
        }

        MouseArea {
          id: shutdownHover
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (Config.confirmPowerActions) {
              box.powerMenuInitialAction = "shutdown"
              box.miniDashboard = false
              box.powerMenu = true
            } else {
              shutdownProc.running = false
              shutdownProc.running = true
            }
          }
          hoverEnabled: true
        }
        Process { id: shutdownProc; command: ["bash", "-c", "systemctl poweroff"]; running: false }
      }
    }
  }
}
