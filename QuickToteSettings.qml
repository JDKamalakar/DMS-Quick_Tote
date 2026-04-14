import QtQuick
import QtQuick.Layouts
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
                dlPathField.loadValue();
                ssPathField.loadValue();
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

                    DankTextField {
                        id: dlPathField
                        property string settingKey: "downloadsPath"
                        property string defaultValue: "~/Downloads"
                        width: parent.width
                        placeholderText: defaultValue
                        
                        function loadValue() {
                            text = root.loadValue ? root.loadValue(settingKey, defaultValue) : defaultValue;
                        }
                        Component.onCompleted: loadValue()
                        onEditingFinished: {
                            root.saveValue(settingKey, text);
                        }
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

                    DankTextField {
                        id: ssPathField
                        property string settingKey: "screenshotsPath"
                        property string defaultValue: "~/Pictures/Screenshots"
                        width: parent.width
                        placeholderText: defaultValue

                        function loadValue() {
                            text = root.loadValue ? root.loadValue(settingKey, defaultValue) : defaultValue;
                        }
                        Component.onCompleted: loadValue()
                        onEditingFinished: {
                            root.saveValue(settingKey, text);
                        }
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
                dlLimitSlider.loadValue();
                ssLimitSlider.loadValue();
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
                        id: dlLabelRow
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "list"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - 22 - Theme.spacingM * 2
                            spacing: Theme.spacingXXS
                            StyledText { text: "Max Downloads"; width: parent.width; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Number of recent downloads to display."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                        DankIcon {
                            name: "restart_alt"
                            size: 22
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: dlLimitSlider.value !== dlLimitSlider.defaultValue ? 0.8 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    dlResetAnim.restart();
                                    root.saveValue(dlLimitSlider.settingKey, dlLimitSlider.defaultValue);
                                }
                            }
                        }
                    }

                    NumberAnimation {
                        id: dlResetAnim
                        target: dlLimitSlider
                        property: "value"
                        to: dlLimitSlider.defaultValue
                        duration: 300
                        easing.type: Easing.OutCubic
                    }

                    DankSlider {
                        id: dlLimitSlider
                        property int defaultValue: 6
                        property string settingKey: "maxDownloads"
                        width: parent.width
                        minimum: 1
                        maximum: 20
                        step: 1
                        unit: " files"
                        
                        function loadValue() {
                            value = root.loadValue ? root.loadValue(settingKey, defaultValue) : defaultValue;
                        }
                        Component.onCompleted: loadValue()
                        onSliderValueChanged: newValue => {
                            value = newValue;
                            root.saveValue(settingKey, newValue);
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Row {
                        id: ssLabelRow
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "photo_library"; size: 22; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
                        Column {
                            width: parent.width - 22 - 22 - Theme.spacingM * 2
                            spacing: Theme.spacingXXS
                            StyledText { text: "Max Screenshots"; width: parent.width; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Number of screen captures to show preview for."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                        DankIcon {
                            name: "restart_alt"
                            size: 22
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: ssLimitSlider.value !== ssLimitSlider.defaultValue ? 0.8 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ssResetAnim.restart();
                                    root.saveValue(ssLimitSlider.settingKey, ssLimitSlider.defaultValue);
                                }
                            }
                        }
                    }

                    NumberAnimation {
                        id: ssResetAnim
                        target: ssLimitSlider
                        property: "value"
                        to: ssLimitSlider.defaultValue
                        duration: 300
                        easing.type: Easing.OutCubic
                    }

                    DankSlider {
                        id: ssLimitSlider
                        property int defaultValue: 6
                        property string settingKey: "maxScreenshots"
                        width: parent.width
                        minimum: 1
                        maximum: 10
                        step: 1
                        unit: " files"

                        function loadValue() {
                            value = root.loadValue ? root.loadValue(settingKey, defaultValue) : defaultValue;
                        }
                        Component.onCompleted: loadValue()
                        onSliderValueChanged: newValue => {
                            value = newValue;
                            root.saveValue(settingKey, newValue);
                        }
                    }
                }
            }
        }
    }
}
