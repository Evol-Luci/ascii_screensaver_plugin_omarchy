import QtQuick
import QtQuick.Layouts
import qs.Commons

// Shown in the detail pane until something is picked from the sidebar.
ColumnLayout {
  id: root

  property int animationCount: 0
  property int enabledCount: 0
  property int marketplaceCount: 0
  property string mode: "random"

  spacing: Style.spacing.lg

  Text {
    Layout.fillWidth: true
    text: "ASCII Screensaver"
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.heading
    wrapMode: Text.WordWrap
  }

  Text {
    Layout.fillWidth: true
    text: root.mode === "single"
      ? "Playing one chosen animation every time the screensaver starts."
      : "Picking a random animation each time the screensaver starts, weighted by the values you set."
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  Text {
    Layout.fillWidth: true
    text: root.animationCount + " animations installed, " + root.enabledCount + " enabled."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  Text {
    Layout.fillWidth: true
    text: root.marketplaceCount + " from the Marketplace, "
      + (root.animationCount - root.marketplaceCount) + " built-in."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Text {
    Layout.fillWidth: true
    text: "Choose General on the left to set how long the screen waits before the screensaver and the lock appear, or pick any animation to tune how it looks. Changes save as you make them."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  Item { Layout.fillHeight: true }
}
