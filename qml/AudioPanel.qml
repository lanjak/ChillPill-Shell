import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

// Audio panel, shown inside the cc box (see shell.qml)
// Same structure as BluetoothPanel: Item + shown + closeRequested, host owns open state
Item {
  id: audioPanel

  property bool shown: false
  signal closeRequested()               // the host owns open state

  // Keys needs active focus
  focus: shown

  readonly property var nodes: Pipewire.nodes.values
  readonly property var sinks: nodes.filter(n => n.type === PwNodeType.AudioSink)
  readonly property var sources: nodes.filter(n => n.type === PwNodeType.AudioSource)
  // playback streams of applications
  readonly property var streams: nodes.filter(n => n.type === PwNodeType.AudioOutStream)

  // volume/mute of a node is only live while it is bound
  PwObjectTracker { objects: audioPanel.shown ? audioPanel.sinks.concat(audioPanel.sources, audioPanel.streams) : [] }

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

  function refreshCards() { cardList.running = true }

  onShownChanged: if (shown) openPanel()
  // a Loader can build this already-open, and then shown never "changes"
  Component.onCompleted: if (shown) openPanel()
  // a card that changes profile adds or drops nodes
  onNodesChanged: if (shown) refreshCards()

  function openPanel() {
    refreshCards()
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

  function nodeName(n) {
    return n.nickname || n.description || n.name
  }

  function streamName(n) {
    const p = n.properties || {}
    return p["application.name"] || n.description || n.name
  }

  // keep clicks off the cc below
  MouseArea { anchors.fill: parent; enabled: audioPanel.shown }

  Keys.onEscapePressed: closeRequested()

  // header button: panel fill, hover lift (same as BluetoothPanel)
  component HeaderButton: Rectangle {
    id: hb
    property string glyph: ""
    signal clicked

    implicitWidth: 25
    implicitHeight: 25
    radius: 15
    color: hbMa.containsMouse ? Theme.bg3 : Theme.bgD
    scale: hbMa.pressed ? 0.92 : (hbMa.containsMouse ? 1.03 : 1)

    Text {
      anchors.centerIn: parent
      text: hb.glyph
      color: hbMa.containsMouse ? Theme.fg : Theme.fg4
      font { family: Theme.nerdFontFamily; pixelSize: 12 }
    }

    MouseArea {
      id: hbMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: hb.clicked()
    }
  }

  // small round icon button for mute / disable
  component IconButton: Rectangle {
    id: ib
    property string glyph: ""
    property color tone: Theme.fg3
    property string tip: ""
    signal clicked

    implicitWidth: 24
    implicitHeight: 24
    radius: 12
    color: ibMa.containsMouse ? Theme.bg4 : "transparent"
    scale: ibMa.pressed ? 0.9 : 1
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
      anchors.centerIn: parent
      text: ib.glyph
      color: ib.tone
      font { family: Theme.nerdFontFamily; pixelSize: 13 }
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    MouseArea {
      id: ibMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: ib.clicked()
    }
  }

  component SectionLabel: Text {
    color: Theme.fg4
    topPadding: 6
    font { family: Theme.fontFamily; pixelSize: 10; weight: 500 }
  }

  // one sink or source: click selects it as default
  component DeviceRow: Rectangle {
    id: dr
    property var node
    property bool isSource: false
    readonly property bool isDefault: node === (isSource ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink)
    readonly property bool muted: node && node.ready && node.audio.muted
    readonly property var card: audioPanel.cardOf(node)

    width: parent ? parent.width : 0
    implicitHeight: 38
    radius: 14
    color: rowMa.containsMouse ? Theme.bg3 : Theme.rowBg
    Behavior on color { ColorAnimation { duration: 120 } }

    MouseArea {
      id: rowMa
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (dr.isSource) Pipewire.preferredDefaultAudioSource = dr.node
        else Pipewire.preferredDefaultAudioSink = dr.node
      }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 6
      spacing: 8

      Text {
        // nf-md-radiobox_marked / nf-md-radiobox_blank
        text: String.fromCodePoint(dr.isDefault ? 0xf043e : 0xf043d)
        color: dr.isDefault ? Theme.fg : Theme.fg5
        font { family: Theme.nerdFontFamily; pixelSize: 13 }
      }

      Text {
        Layout.fillWidth: true
        text: audioPanel.nodeName(dr.node)
        color: dr.muted ? Theme.fg4 : Theme.fg
        elide: Text.ElideRight
        font { family: Theme.fontFamily; pixelSize: 11; weight: dr.isDefault ? 500 : 300 }
      }

      IconButton {
        // nf-md-microphone(_off) / nf-md-volume_high / nf-md-volume_off
        glyph: String.fromCodePoint(dr.isSource ? (dr.muted ? 0xf036d : 0xf036c) : (dr.muted ? 0xf0581 : 0xf057e))
        tone: dr.muted ? Theme.mutedFgSlider : Theme.fg3
        onClicked: if (dr.node.ready) dr.node.audio.muted = !dr.node.audio.muted
      }

      IconButton {
        visible: dr.card !== null
        glyph: "" // nf-fa-power_off
        tone: Theme.fg4
        onClicked: audioPanel.setCardDirection(dr.card, dr.isSource ? "sources" : "sinks", false)
      }
    }
  }

  // a card with this direction turned off: power button turns it back on
  component DisabledRow: Rectangle {
    id: xr
    property var card
    property string kind: "sinks"

    width: parent ? parent.width : 0
    implicitHeight: 38
    radius: 14
    color: Theme.rowBg

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 6
      spacing: 8

      Text {
        text: String.fromCodePoint(0xf043d)
        color: Theme.fg7
        font { family: Theme.nerdFontFamily; pixelSize: 13 }
      }

      Text {
        Layout.fillWidth: true
        text: (xr.card.properties["device.description"] || xr.card.name) + "  · disabled"
        color: Theme.fg5
        elide: Text.ElideRight
        font { family: Theme.fontFamily; pixelSize: 11; weight: 300 }
      }

      IconButton {
        glyph: "" // nf-fa-power_off
        tone: Theme.fg7
        onClicked: audioPanel.setCardDirection(xr.card, xr.kind, true)
      }
    }
  }

  // thin bar slider like the cc volume slider, value 0-1
  component VolumeSlider: Item {
    id: vs
    property real value: 0
    signal moved(real value)

    implicitHeight: 4

    Rectangle {
      anchors.fill: parent
      radius: 4
      color: Theme.bg5

      Rectangle {
        width: parent.width * Math.min(vs.value, 1)
        height: parent.height
        radius: 4
        color: Theme.sliderBg
      }
    }

    MouseArea {
      anchors.fill: parent
      anchors.topMargin: -8
      anchors.bottomMargin: -8
      cursorShape: Qt.PointingHandCursor
      // horizontal drags must not scroll the list
      preventStealing: true
      onPressed: (mouse) => vs.moved(Math.max(0, Math.min(1, mouse.x / width)))
      onPositionChanged: (mouse) => { if (pressed) vs.moved(Math.max(0, Math.min(1, mouse.x / width))) }
    }
  }

  // one application stream: name, mute, volume slider
  component StreamRow: Rectangle {
    id: sr
    property var node
    readonly property bool ready: node && node.ready
    readonly property bool muted: ready && node.audio.muted
    readonly property real volume: ready ? node.audio.volume : 0

    width: parent ? parent.width : 0
    implicitHeight: 52
    radius: 14
    color: Theme.rowBg

    ColumnLayout {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 6
      anchors.topMargin: 5
      anchors.bottomMargin: 10
      spacing: 4

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          Layout.fillWidth: true
          text: audioPanel.streamName(sr.node)
          color: sr.muted ? Theme.fg4 : Theme.fg
          elide: Text.ElideRight
          font { family: Theme.fontFamily; pixelSize: 11 }
        }

        Text {
          text: sr.muted ? "muted" : Math.round(sr.volume * 100) + "%"
          color: Theme.fg3
          font { family: Theme.fontFamily; pixelSize: 10 }
        }

        IconButton {
          glyph: String.fromCodePoint(sr.muted ? 0xf0581 : 0xf057e)
          tone: sr.muted ? Theme.mutedFgSlider : Theme.fg3
          onClicked: if (sr.ready) sr.node.audio.muted = !sr.node.audio.muted
        }
      }

      VolumeSlider {
        Layout.fillWidth: true
        Layout.rightMargin: 8
        value: sr.volume
        opacity: sr.muted ? 0.5 : 1
        onMoved: (v) => { if (sr.ready) sr.node.audio.volume = v }
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: 8
    opacity: audioPanel.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }

    // header
    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      HeaderButton {
        glyph: "" // nf-fa-chevron_left
        onClicked: audioPanel.closeRequested()
      }

      Text {
        text: "Audio"
        color: Theme.fg
        font { family: Theme.fontFamily; pixelSize: 16 }
      }

      Item { Layout.fillWidth: true }
    }

    Flickable {
      Layout.fillWidth: true
      Layout.fillHeight: true
      contentHeight: sections.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: sections
        width: parent.width
        spacing: 5

        SectionLabel { text: "Output" }
        Repeater {
          model: audioPanel.sinks
          delegate: DeviceRow { required property var modelData; node: modelData }
        }
        Repeater {
          model: audioPanel.disabledCards("sinks")
          delegate: DisabledRow { required property var modelData; card: modelData; kind: "sinks" }
        }

        SectionLabel { text: "Input" }
        Repeater {
          model: audioPanel.sources
          delegate: DeviceRow { required property var modelData; node: modelData; isSource: true }
        }
        Repeater {
          model: audioPanel.disabledCards("sources")
          delegate: DisabledRow { required property var modelData; card: modelData; kind: "sources" }
        }

        SectionLabel { text: "Applications" }
        Text {
          visible: audioPanel.streams.length === 0
          text: "nothing is playing"
          color: Theme.fg5
          leftPadding: 12
          font { family: Theme.fontFamily; pixelSize: 10 }
        }
        Repeater {
          model: audioPanel.streams
          delegate: StreamRow { required property var modelData; node: modelData }
        }
      }
    }
  }
}
