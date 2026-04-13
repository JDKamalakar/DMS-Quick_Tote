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
                text: "Quick access to your recent files and screenshots. Inspired by ChromeOS Tote."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }
        }

        // --- File Paths ---
        Rectangle {
            width: parent.width
            height: pathsGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            Column {
                id: pathsGroup
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
                            StyledText {
                                text: "Downloads Path"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Folder to watch for recent downloads."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
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
                            StyledText {
                                text: "Screenshots Path"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Folder where screenshots are saved."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
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

        // --- View Options ---
        Rectangle {
            width: parent.width
            height: viewGroup.implicitHeight + Theme.spacingM * 2
            color: Theme.surfaceContainer
            radius: Theme.cornerRadius
            border.color: Theme.outline
            border.width: 1
            opacity: 0.8

            Column {
                id: viewGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "format_list_numbered"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM
                            spacing: Theme.spacingXXS
                            StyledText {
                                text: "Max Downloads"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Max number of recent downloads to show."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
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
                        leftIcon: ""
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "grid_view"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - Theme.spacingM
                            spacing: Theme.spacingXXS
                            StyledText {
                                text: "Max Screenshots"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: "Max number of screenshot previews to show."
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                width: parent.width
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    SliderSetting {
                        width: parent.width
                        settingKey: "maxScreenshots"
                        label: ""
                        description: ""
                        defaultValue: 3
                        minimum: 1
                        maximum: 8
                        unit: "files"
                        leftIcon: ""
                    }
                }
            }
        }
    }
}
