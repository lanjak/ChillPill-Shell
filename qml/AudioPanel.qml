import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// Audio devices, shown in place of the cc content (see shell.qml)
// Clicks on empty space fall through to the box, which closes the cc
Item {
  id: audioPanel

  property bool shown: false
  signal closeRequested()               // the host owns open state

  // Keys needs active focus
  focus: shown

  // height the box needs to show every row
  readonly property real contentHeight: sections.implicitHeight

  readonly property var nodes: Pipewire.nodes.values
  readonly property var sinks: nodes.filter(n => n.type === PwNodeType.AudioSink)
  readonly property var sources: nodes.filter(n => n.type === PwNodeType.AudioSource)

  // mute state of a node is only live while it is bound
  PwObjectTracker { objects: audioPanel.shown ? audioPanel.sinks.concat(audioPanel.sources) : [] }

  // sound cards from pactl: a sink or source is disabled by switching its
  // card to a profile without that direction (pavucontrol's "Off")
  property var cards: []

  Process {
    id: cardList
    command: ["pactl", "-f", "json", "list", "cards"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { audioPanel.cards = JSON.parse(this.text) } catch (e) { audioPanel.cards = [] }
      }
    }
  }

  Process {
    id: cardSet
    onExited: cardList.running = true
  }

  onShownChanged: if (shown) openPanel()
  // a Loader can build this already-open, and then shown never "changes"
  Component.onCompleted: if (shown) openPanel()
  // a card that changes profile adds or drops nodes
  onNodesChanged: if (shown) cardList.running = true

  function openPanel() {
    cardList.running = true
    // the Loader is asynchronous, so this can run before the panel is in a window
    Qt.callLater(() => audioPanel.forceActiveFocus())
  }

  function cardOf(node) {
    const id = node.properties ? node.properties["device.id"] : undefined
    if (id === undefined) return null
    return cards.find(c => String(c.properties["object.id"]) === String(id)) || null
  }

  // highest priority profile with `kind` ("sinks"/"sources") on or off,
  // keeping the other direction as it is now
  function profileFor(card, kind, on) {
    const other = kind === "sinks" ? "sources" : "sinks"
    const cur = card.profiles[card.active_profile] || {}
    const keepOther = (cur[other] || 0) > 0
    let best = "", bestPrio = -1
    for (const name in card.profiles) {
      const p = card.profiles[name]
      if (!p.available || name === "pro-audio") continue
      if ((p[kind] > 0) !== on || (p[other] > 0) !== keepOther) continue
      if (p.priority > bestPrio) { best = name; bestPrio = p.priority }
    }
    return best
  }

  function setCardDirection(card, kind, on) {
    if (!card || cardSet.running) return
    const profile = profileFor(card, kind, on)
    if (profile === "") return
    cardSet.command = ["pactl", "set-card-profile", card.name, profile]
    cardSet.running = true
  }

  // cards whose current profile has `kind` turned off, but that can turn it on
  function disabledCards(kind) {
    return cards.filter(c => {
      const cur = c.profiles[c.active_profile] || {}
      return (cur[kind] || 0) === 0 && profileFor(c, kind, true) !== ""
    })
  }

  Keys.onEscapePressed: closeRequested()

  // small glyph button inside a row
  component RowGlyph: Text {
    id: rg
    property color tone: Theme.fg4
    signal clicked

    color: rgMa.containsMouse ? Theme.fg : tone
    font { family: Theme.nerdFontFamily; pixelSize: 12 }
    Layout.preferredWidth: 18
    horizontalAlignment: Text.AlignHCenter
    scale: rgMa.pressed ? 0.85 : 1
    Behavior on color { ColorAnimation { duration: 100 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    MouseArea {
      id: rgMa
      anchors.fill: parent
      anchors.margins: -4
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: rg.clicked()
    }
  }

  // one device; a disabled card shows with only the power glyph to turn it back on
  component DeviceRow: Rectangle {
    id: dr
    property var node: null
    property var card: node ? audioPanel.cardOf(node) : null
    property bool isSource: false
    readonly property bool disabled: node === null
    readonly property bool isDefault: !disabled && node === (isSource ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink)
    readonly property bool muted: !disabled && node.ready && node.audio.muted

    width: parent ? parent.width : 0
    height: 24
    radius: 8
    color: dr.isDefault ? Theme.bg2 : (rowHover.hovered && !dr.disabled ? Theme.bg1 : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }

    HoverHandler { id: rowHover }
    MouseArea {
      anchors.fill: parent
      enabled: !dr.disabled
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (dr.isSource) Pipewire.preferredDefaultAudioSource = dr.node
        else Pipewire.preferredDefaultAudioSink = dr.node
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      spacing: 8

      RowGlyph {
        // nf-md-microphone(_off) / nf-md-volume_high / nf-md-volume_off
        text: String.fromCodePoint(dr.isSource ? (dr.muted ? 0xf036d : 0xf036c) : (dr.muted ? 0xf0581 : 0xf057e))
        tone: dr.disabled ? Theme.fg7 : dr.muted ? Theme.mutedFgSlider : dr.isDefault ? Theme.fg : Theme.fg4
        enabled: !dr.disabled
        onClicked: if (dr.node.ready) dr.node.audio.muted = !dr.node.audio.muted
      }

      Text {
        Layout.fillWidth: true
        text: dr.disabled ? (dr.card.properties["device.description"] || dr.card.name)
                          : (dr.node.nickname || dr.node.description || dr.node.name)
        color: dr.disabled ? Theme.fg6 : dr.isDefault ? Theme.fg : Theme.fg3
        elide: Text.ElideRight
        font { family: Theme.fontFamily; pixelSize: 10; weight: dr.isDefault ? 500 : 400 }
      }

      RowGlyph {
        visible: dr.card !== null
        text: "" // nf-fa-power_off
        tone: dr.disabled ? Theme.fg7 : Theme.fg5
        onClicked: audioPanel.setCardDirection(dr.card, dr.isSource ? "sources" : "sinks", dr.disabled)
      }
    }
  }

  // header tab + body, same shape as the cc notification stack
  component Section: Item {
    id: sec
    property string title: ""
    default property alias rows: body.data

    width: parent ? parent.width : 0
    implicitHeight: 20 + body.implicitHeight + 10

    Rectangle {
      id: tab
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width - 10
      height: 20
      topLeftRadius: 13
      topRightRadius: 13
      color: Theme.notifHeaderBg

      Text {
        text: sec.title
        color: Theme.fg2
        font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Rectangle {
      anchors.top: tab.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width - 10
      height: body.implicitHeight + 10
      bottomLeftRadius: 13
      bottomRightRadius: 13
      color: Theme.bgD
      border.width: 1
      border.color: Theme.bg3

      Column {
        id: body
        anchors.fill: parent
        anchors.margins: 5
        spacing: 2
      }
    }
  }

  Column {
    id: sections
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    spacing: 28
    opacity: audioPanel.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutExpo } }

    Section {
      title: "Output"
      Repeater {
        model: audioPanel.sinks
        delegate: DeviceRow { required property var modelData; node: modelData }
      }
      Repeater {
        model: audioPanel.disabledCards("sinks")
        delegate: DeviceRow { required property var modelData; card: modelData }
      }
    }

    Section {
      title: "Input"
      Repeater {
        model: audioPanel.sources
        delegate: DeviceRow { required property var modelData; node: modelData; isSource: true }
      }
      Repeater {
        model: audioPanel.disabledCards("sources")
        delegate: DeviceRow { required property var modelData; card: modelData; isSource: true }
      }
    }
  }
}
