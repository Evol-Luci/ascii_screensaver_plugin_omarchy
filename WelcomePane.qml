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

  property bool showThanks: false

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

  Text {
    Layout.fillWidth: true
    Layout.topMargin: Style.spacing.md
    text: "♥ a note from the dev"
    color: Color.accent
    font.family: Style.font.family
    font.pixelSize: Style.font.caption

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.showThanks = !root.showThanks
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.showThanks
    spacing: Style.spacing.sm

    Text {
      Layout.fillWidth: true
      text: "I grew up with screensavers — the flying toasters, the pipes, the mesmerizing 3D mazes that meant nothing was actually happening but you'd watch anyway. This started as an attempt to bring a little of that back, rebuilt in ASCII for an idle screen that still feels alive. The classic aquarium screensaver got a full reimagining here, and enough of it swam over into Terrarium that it ended up living there too. But I didn't want it to stop at nostalgia — the Marketplace is where this gets to grow past whatever I could dream up alone. Every animation you switch to started as someone's “what if this existed” — and I'm genuinely excited to see what people build next. If you've got an idea for something new, or your own spin on something old, the Marketplace repo is open. Submit it — I'd love to see it."
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.lg

      Text {
        text: "Star the plugin on GitHub"
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.underline: linkArea.containsMouse

        MouseArea {
          id: linkArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Qt.openUrlExternally("https://github.com/Evol-Luci/ascii_screensaver_plugin_omarchy")
        }
      }

      Text {
        text: "Browse & submit animations"
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.underline: submitLinkArea.containsMouse

        MouseArea {
          id: submitLinkArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Qt.openUrlExternally("https://github.com/Evol-Luci/ascii-screensaver-animations")
        }
      }
    }
  }

  Item { Layout.fillHeight: true }
}
