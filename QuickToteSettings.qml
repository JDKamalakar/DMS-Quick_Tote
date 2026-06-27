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
        StyledRect {
            id: sourceRect
            width: parent.width
            height: Math.max(0, sourcesGroup.implicitHeight + Theme.spacingM * 2)
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
            border.width: 1

            function loadValue() {
                dlPathField.loadValue();
                ssPathField.loadValue();
                scanSubToggle.loadValue();
                scanScreenshotSubToggle.loadValue();
            }

            Column {
                id: sourcesGroup
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Component {
                        id: settingHeaderComponent
                        RowLayout {
                            anchors.fill: parent
                            spacing: Theme.spacingM
                            DankIcon { name: settingIcon; size: 22; Layout.alignment: Qt.AlignVCenter; opacity: 0.8 }
                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: Theme.spacingXXS
                                StyledText { text: settingTitle; font.weight: Font.Medium; color: Theme.surfaceText; width: parent.width }
                                StyledText { text: settingDesc; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText; width: parent.width; wrapMode: Text.WordWrap }
                            }
                        }
                    }

                    Loader {
                        width: parent.width
                        asynchronous: true
                        sourceComponent: settingHeaderComponent
                        property string settingIcon: "download"
                        property string settingTitle: "Downloads Path"
                        property string settingDesc: "Directory to monitor for recent files."
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

                    Item { height: Theme.spacingXS }
                    RowLayout {
                        id: scanSubLabelRow
                        width: parent.width
                        spacing: Theme.spacingM
                        Loader {
                            Layout.fillWidth: true
                            asynchronous: true
                            sourceComponent: settingHeaderComponent
                            property string settingIcon: "account_tree"
                            property string settingTitle: "Scan Downloads Subdirectories"
                            property string settingDesc: "Search for files in all subdirectories of the downloads path."
                        }
                        DankToggle {
                            id: scanSubToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "scanSubfolders"
                            checked: false
                            
                            function loadValue() {
                                checked = mainSettingsCol.loadValue(settingKey, false);
                            }
                            Component.onCompleted: loadValue()
                            
                            onClicked: {
                                checked = !checked
                                mainSettingsCol.saveValue(settingKey, checked);
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    Loader {
                        width: parent.width
                        asynchronous: true
                        sourceComponent: settingHeaderComponent
                        property string settingIcon: "screenshot_region"
                        property string settingTitle: "Screenshots Path"
                        property string settingDesc: "Directory where screen captures are saved."
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

                    Item { height: Theme.spacingXS }
                    RowLayout {
                        id: scanScreenshotSubLabelRow
                        width: parent.width
                        spacing: Theme.spacingM
                        Loader {
                            Layout.fillWidth: true
                            asynchronous: true
                            sourceComponent: settingHeaderComponent
                            property string settingIcon: "account_tree"
                            property string settingTitle: "Scan Screenshot Subdirectories"
                            property string settingDesc: "Search for files in all subdirectories of the screenshots path."
                        }
                        DankToggle {
                            id: scanScreenshotSubToggle
                            Layout.alignment: Qt.AlignVCenter
                            property string settingKey: "scanScreenshotSubfolders"
                            checked: false
                            
                            function loadValue() {
                                checked = mainSettingsCol.loadValue(settingKey, false);
                            }
                            Component.onCompleted: loadValue()
                            
                            onClicked: {
                                checked = !checked
                                mainSettingsCol.saveValue(settingKey, checked);
                            }
                        }
                    }
                }
            }
        }



        // --- Performance & Limits ---
        StyledRect {
            id: limitRect
            width: parent.width
            height: Math.max(0, limitsGroup.implicitHeight + Theme.spacingM * 2)
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
            radius: Theme.cornerRadius
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
            border.width: 1

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
                        Loader {
                            Layout.fillWidth: true
                            asynchronous: true
                            sourceComponent: settingHeaderComponent
                            property string settingIcon: "list"
                            property string settingTitle: "Max Downloads"
                            property string settingDesc: "Number of recent downloads to display."
                        }
                        Rectangle {
                            id: dlResetBtn
                            width: 32; height: 32
                            radius: Theme.cornerRadius
                            Layout.alignment: Qt.AlignVCenter
                            color: dlResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                            border.color: dlResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                            border.width: 1
                            opacity: dlLimitSlider.value !== dlLimitSlider.defaultValue ? (dlResetMa.containsMouse ? 1.0 : 0.9) : 0.0
                            visible: opacity > 0
                            scale: dlResetMa.pressed ? 0.9 : (dlResetMa.containsMouse ? 1.05 : 1.0)
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

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
                                SequentialAnimation on rotation {
                                    running: dlResetMa.containsMouse; loops: Animation.Infinite
                                    NumberAnimation { to: 8; duration: 75 }
                                    NumberAnimation { to: -8; duration: 150 }
                                    NumberAnimation { to: 0; duration: 75 }
                                    onRunningChanged: { if (!running) dlResetIcon.rotation = 0; }
                                }
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
                        duration: 150
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
                        Loader {
                            Layout.fillWidth: true
                            asynchronous: true
                            sourceComponent: settingHeaderComponent
                            property string settingIcon: "photo_library"
                            property string settingTitle: "Max Screen Captures"
                            property string settingDesc: "Number of screen captures to show preview for."
                        }
                        Rectangle {
                            id: ssResetBtn
                            width: 32; height: 32
                            radius: Theme.cornerRadius
                            Layout.alignment: Qt.AlignVCenter
                            color: ssResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                            border.color: ssResetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                            border.width: 1
                            opacity: ssLimitSlider.value !== ssLimitSlider.defaultValue ? (ssResetMa.containsMouse ? 1.0 : 0.9) : 0.0
                            visible: opacity > 0
                            scale: ssResetMa.pressed ? 0.9 : (ssResetMa.containsMouse ? 1.05 : 1.0)
                            
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

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
                                SequentialAnimation on rotation {
                                    running: ssResetMa.containsMouse; loops: Animation.Infinite
                                    NumberAnimation { to: 8; duration: 75 }
                                    NumberAnimation { to: -8; duration: 150 }
                                    NumberAnimation { to: 0; duration: 75 }
                                    onRunningChanged: { if (!running) ssResetIcon.rotation = 0; }
                                }
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
                        duration: 150
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
