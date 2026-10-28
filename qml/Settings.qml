import QtQuick

// opens the config app, the tap is handled in PillBarModules.qml
Text {
  text: String.fromCodePoint(0xf0493) // nf-md-cog
  color: Theme.fg
  font {
    family: Theme.nerdFontFamily
    pixelSize: 12 * Config.pillScale
  }
}
