import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// A single card in the Marketplace tab for one available animation.
// `Color` has no "surface" role (that was a bug — it silently fell back to
// the QtQuick default of opaque white); every panel-like surface in this
// plugin instead tints the foreground color into the dark background,
// matching GeneralDetail.qml's snippet/input surfaces.
Rectangle {
  id: root

  property var entry: ({})
  property bool installed: false
  property bool installing: false

  signal installClicked()
  signal uninstallClicked()

  readonly property bool hovered: hoverHandler.hovered

  width: Style.space(260)
  height: cardColumn.implicitHeight + Style.spacing.lg * 2
  color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, root.hovered ? 0.09 : 0.06)
  border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, root.hovered ? 0.3 : 0.15)
  border.width: Style.normalBorderWidth
  radius: Style.cornerRadius

  HoverHandler { id: hoverHandler }

  ColumnLayout {
    id: cardColumn
    anchors {
      top: parent.top; left: parent.left; right: parent.right
      margins: Style.spacing.lg
    }
    spacing: Style.spacing.sm

    // Preview — animated so gifs actually play instead of sitting on
    // whatever their first frame happens to be (often a blank/black one
    // for these canvas animations). Falls back to a plain still for
    // single-frame previews.
    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(120)
      radius: Style.cornerRadius
      clip: true
      color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 1.0)
      border.color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15)
      border.width: Style.normalBorderWidth

      AnimatedImage {
        id: previewImage
        anchors.fill: parent
        source: root.entry.preview || ""
        fillMode: Image.PreserveAspectCrop
        cache: true
        visible: root.entry.preview && status === AnimatedImage.Ready
        playing: true
        asynchronous: true

        // Single-frame previews (a static png/webp, or a gif Qt decoded
        // as one frame) have nothing to "play" — land on a representative
        // mid-animation frame instead of whatever frame 0 happens to be.
        onStatusChanged: {
          if (status === AnimatedImage.Ready && frameCount > 1) {
            playing = true
          } else if (status === AnimatedImage.Ready) {
            currentFrame = Math.floor(frameCount / 2)
          }
        }
      }

      // Placeholder shown while the preview loads or when one isn't set.
      Text {
        anchors.centerIn: parent
        visible: !previewImage.visible
        text: (root.entry.name || root.entry.id || "?").charAt(0).toUpperCase()
        textFormat: Text.PlainText
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.displayLarge
        opacity: 0.4
      }

      // "Installed" badge, top-right corner of the preview.
      Rectangle {
        visible: root.installed
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Style.spacing.xs
        radius: Style.cornerRadius
        color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.75)
        implicitWidth: installedLabel.implicitWidth + Style.spacing.sm * 2
        implicitHeight: installedLabel.implicitHeight + Style.spacing.xxs * 2

        Text {
          id: installedLabel
          anchors.centerIn: parent
          text: "Installed"
          color: Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }

    Text {
      Layout.fillWidth: true
      text: root.entry.name || root.entry.id || ""
      textFormat: Text.PlainText
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      wrapMode: Text.WordWrap
    }

    Text {
      Layout.fillWidth: true
      visible: text !== ""
      text: root.entry.author || ""
      textFormat: Text.PlainText
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }

    Text {
      Layout.fillWidth: true
      visible: text !== ""
      text: root.entry.description || ""
      textFormat: Text.PlainText
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      maximumLineCount: 3
      elide: Text.ElideRight
    }

    Button {
      Layout.fillWidth: true
      text: root.installing ? "Installing…" : (root.installed ? "Uninstall" : "Install")
      enabled: !root.installing
      onClicked: root.installed ? root.uninstallClicked() : root.installClicked()
    }
  }
}
