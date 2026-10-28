import QtQuick

// fixed-width text whose changed characters roll in, like an odometer;
// characters that stay the same do not move. Pad text to a fixed length.
Row {
  id: root

  property string text: ""
  property font font
  property color color: Theme.fg
  // the number behind the text: a rise rolls digits up, a fall rolls them down
  property real value: 0
  property int duration: 300

  property bool up: true
  property real previous: value
  onValueChanged: {
    up = value >= previous
    previous = value
  }

  TextMetrics { id: cellMetrics; font: root.font; text: "0" }

  Repeater {
    model: root.text.length

    delegate: Item {
      id: cell
      required property int index
      readonly property string ch: root.text.charAt(index)
      property string current: ""
      property string leaving: ""

      width: cellMetrics.advanceWidth
      height: cellMetrics.height
      clip: true

      Component.onCompleted: current = ch
      onChChanged: {
        leaving = current
        current = ch
        // after the value handler, so root.up holds this change's direction
        Qt.callLater(roll.restart)
      }

      Text {
        id: outText
        width: cell.width
        horizontalAlignment: Text.AlignHCenter
        text: cell.leaving
        opacity: 0
        color: root.color
        font: root.font
      }

      Text {
        id: inText
        width: cell.width
        horizontalAlignment: Text.AlignHCenter
        text: cell.current
        color: root.color
        font: root.font
      }

      ParallelAnimation {
        id: roll
        NumberAnimation { target: inText; property: "y"; from: (root.up ? 1 : -1) * cell.height; to: 0; duration: root.duration; easing.type: Easing.OutQuint }
        NumberAnimation { target: outText; property: "y"; from: 0; to: (root.up ? -1 : 1) * cell.height; duration: root.duration; easing.type: Easing.OutQuint }
        NumberAnimation { target: inText; property: "opacity"; from: 0; to: 1; duration: root.duration; easing.type: Easing.OutQuad }
        NumberAnimation { target: outText; property: "opacity"; from: 1; to: 0; duration: root.duration; easing.type: Easing.OutQuad }
      }
    }
  }
}
