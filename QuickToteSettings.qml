import QtQuick
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "quickTote"

    Column {
        width: parent.width
        spacing: Theme.spacingL

        // --- Header Section ---
        Column {
            width: parent.width
            spacing: Theme.spacingXS
            
            StyledText {
                width: parent.width
                text: "Quick Tote"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: "ChromeOS-inspired 'Tote' for quick access to your recent downloads and screen captures."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }

        // --- Paths & Sources ---
        Rectangle {
            width: parent.width
            height: sourcesGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                for (var i = 0; i < sourcesGroup.children.length; i++) {
                    var row = sourcesGroup.children[i];
                    for (var j = 0; j < row.children.length; j++) {
                        if (row.children[j].loadValue) row.children[j].loadValue();
                    }
                }
            }

            Column {
                id: sourcesGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "download"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM
                            spacing: Theme.spacingXXS
                            StyledText { text: "Downloads Path"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Directory to monitor for recent files."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }

                    StringSetting {
                        width: parent.width
                        settingKey: "downloadsPath"
                        label: ""
                        description: ""
                        placeholder: "~/Downloads"
                        defaultValue: "~/Downloads"
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "screenshot_region"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM
                            spacing: Theme.spacingXXS
                            StyledText { text: "Screenshots Path"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Directory where screen captures are saved."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }

                    StringSetting {
                        width: parent.width
                        settingKey: "screenshotsPath"
                        label: ""
                        description: ""
                        placeholder: "~/Pictures/Screenshots"
                        defaultValue: "~/Pictures/Screenshots"
                    }
                }
            }
        }

        // --- Performance & Limits ---
        Rectangle {
            width: parent.width
            height: limitsGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            function loadValue() {
                for (var i = 0; i < limitsGroup.children.length; i++) {
                    var row = limitsGroup.children[i];
                    for (var j = 0; j < row.children.length; j++) {
                        if (row.children[j].loadValue) row.children[j].loadValue();
                    }
                }
            }

            Column {
                id: limitsGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "list"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM
                            spacing: Theme.spacingXXS
                            StyledText { text: "Max Downloads"; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Number of recent downloads to display."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }

                    SliderSetting {
                        width: parent.width
                        settingKey: "maxDownloads"
                        label: ""
                        description: ""
                        defaultValue: 6
                        minimum: 1
                        maximum: 20
                        unit: "files"
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "photo_library"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM
                            spacing: Theme.spacingXXS
                            StyledText { text: "Max Screenshots"; font.weight: Font.Bold; color: Theme.surfaceText }
                            StyledText { text: "Number of screen captures to show preview for."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                    }

                    SliderSetting {
                        width: parent.width
                        settingKey: "maxScreenshots"
                        label: ""
                        description: ""
                        defaultValue: 4
                        minimum: 1
                        maximum: 8
                        unit: "files"
                    }
                }
            }
        }
    }
}
