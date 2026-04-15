import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: root
    pluginId: "quickTote"

    Column {
        id: mainSettingsCol
        width: parent.width
        spacing: Theme.spacingL

        function loadValue(key, def) {
            return PluginService.loadPluginData(root.pluginId, key, def);
        }

        function saveValue(key, val) {
            PluginService.savePluginData(root.pluginId, key, val);
            PluginService.setGlobalVar(root.pluginId, key, val);
        }

        function loadValueInternal() {
            sourceRect.loadValue();
            limitRect.loadValue();
        }
        
        Component.onCompleted: loadValueInternal()
        Rectangle {
            id: sourceRect
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
                            text = mainSettingsCol.loadValue(settingKey, defaultValue);
                        }
                        Component.onCompleted: loadValue()
                        onEditingFinished: {
                            mainSettingsCol.saveValue(settingKey, text);
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
                            text = mainSettingsCol.loadValue(settingKey, defaultValue);
                        }
                        Component.onCompleted: loadValue()
                        onEditingFinished: {
                            mainSettingsCol.saveValue(settingKey, text);
                        }
                    }
                }
            }
        }



        // --- Performance & Limits ---
        Rectangle {
            id: limitRect
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

                    RowLayout {
                        id: dlLabelRow
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "list"; size: 22; Layout.alignment: Qt.AlignVCenter; opacity: 0.8 }
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.spacingXXS
                            StyledText { text: "Max Downloads"; width: parent.width; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Number of recent downloads to display."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                        Rectangle {
                            id: dlResetBtn
                            width: 32; height: 32
                            radius: Theme.cornerRadius
                            Layout.alignment: Qt.AlignVCenter
                            color: dlResetMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.color: dlResetMa.containsMouse ? Theme.primary : Theme.outline
                            border.width: 1
                            opacity: dlLimitSlider.value !== dlLimitSlider.defaultValue ? (dlResetMa.containsMouse ? 1.0 : 0.9) : 0.0
                            visible: opacity > 0
                            scale: dlResetMa.containsMouse ? 1.1 : 1.0
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                            DankRipple { 
                                id: dlRip
                                anchors.fill: parent
                                cornerRadius: parent.radius
                                rippleColor: Theme.primary 
                            }

                            DankIcon {
                                id: dlResetIcon
                                name: "restart_alt"
                                size: 18
                                anchors.centerIn: parent
                                color: dlResetMa.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                rotation: dlResetMa.containsMouse ? 90 : 0
                                Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: dlResetMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    dlResetAnim.restart();
                                    mainSettingsCol.saveValue(dlLimitSlider.settingKey, dlLimitSlider.defaultValue);
                                }
                                onPressed: (m) => dlRip.trigger(m.x, m.y)
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
                            value = mainSettingsCol.loadValue(settingKey, defaultValue);
                        }
                        Component.onCompleted: loadValue()
                        onSliderValueChanged: newValue => {
                            value = newValue;
                            mainSettingsCol.saveValue(settingKey, newValue);
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    RowLayout {
                        id: ssLabelRow
                        width: parent.width
                        spacing: Theme.spacingM
                        DankIcon { name: "photo_library"; size: 22; Layout.alignment: Qt.AlignVCenter; opacity: 0.8 }
                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Theme.spacingXXS
                            StyledText { text: "Max Screenshots"; width: parent.width; font.weight: Font.Medium; color: Theme.surfaceText }
                            StyledText { text: "Number of screen captures to show preview for."; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                        }
                        Rectangle {
                            id: ssResetBtn
                            width: 32; height: 32
                            radius: Theme.cornerRadius
                            Layout.alignment: Qt.AlignVCenter
                            color: ssResetMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.color: ssResetMa.containsMouse ? Theme.primary : Theme.outline
                            border.width: 1
                            opacity: ssLimitSlider.value !== ssLimitSlider.defaultValue ? (ssResetMa.containsMouse ? 1.0 : 0.9) : 0.0
                            visible: opacity > 0
                            scale: ssResetMa.containsMouse ? 1.1 : 1.0
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                            DankRipple { 
                                id: ssRip
                                anchors.fill: parent
                                cornerRadius: parent.radius
                                rippleColor: Theme.primary 
                            }

                            DankIcon {
                                id: ssResetIcon
                                name: "restart_alt"
                                size: 18
                                anchors.centerIn: parent
                                color: ssResetMa.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                rotation: ssResetMa.containsMouse ? 90 : 0
                                Behavior on rotation { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: ssResetMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ssResetAnim.restart();
                                    mainSettingsCol.saveValue(ssLimitSlider.settingKey, ssLimitSlider.defaultValue);
                                }
                                onPressed: (m) => ssRip.trigger(m.x, m.y)
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
                            value = mainSettingsCol.loadValue(settingKey, defaultValue);
                        }
                        Component.onCompleted: loadValue()
                        onSliderValueChanged: newValue => {
                            value = newValue;
                            mainSettingsCol.saveValue(settingKey, newValue);
                        }
                    }
                }
            }
        }
    }
}
