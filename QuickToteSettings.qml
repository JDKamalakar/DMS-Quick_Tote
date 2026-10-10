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

    readonly property real outerR: Theme.cornerRadius || 12
    readonly property real innerR: 4

    function loadValue(key, def) {
        if (typeof PluginService !== "undefined" && PluginService && PluginService.loadPluginData) {
            return PluginService.loadPluginData(root.pluginId, key, def);
        }
        return def;
    }

    function saveValue(key, val) {
        if (typeof PluginService !== "undefined" && PluginService && PluginService.savePluginData) {
            PluginService.savePluginData(root.pluginId, key, val);
            if (PluginService.setGlobalVar) {
                PluginService.setGlobalVar(root.pluginId, key, val);
            }
        }
    }

    Connections {
        target: PluginService
        ignoreUnknownSignals: true
        function onPluginDataChanged(pId) {
            if (pId === root.pluginId) {
                rootWrapper.loadValue();
            }
        }
        function onGlobalVarChanged(pId, varName) {
            if (pId === root.pluginId) {
                rootWrapper.loadValue();
            }
        }
    }

    // -------------------------------------------------------------------------
    // REUSABLE COMPONENTS (Matching DMS Full Screen Power Menu Style)
    // -------------------------------------------------------------------------

    component SectionHeader: Row {
        property string title: ""
        property string iconName: ""

        spacing: Theme.spacingXS
        leftPadding: Theme.spacingM

        DankIcon {
            name: iconName
            size: 16
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: title
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    component SettingsSliderItem: Rectangle {
        id: sliderCard
        width: parent.width
        implicitHeight: sliderInnerCol.implicitHeight + Theme.spacingM * 2
        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
        border.width: 1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

        property string iconName: ""
        property string title: ""
        property string description: ""
        property string settingKey: ""
        property int defaultValue: 0
        property int minimumValue: 1
        property int maximumValue: 20
        property string unit: " files"
        property bool sliderEnabled: true

        property bool isFirst: false
        property bool isLast: false
        property bool isSingle: false

        topLeftRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        topRightRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        bottomLeftRadius: (isLast || isSingle) ? root.outerR : root.innerR
        bottomRightRadius: (isLast || isSingle) ? root.outerR : root.innerR

        function loadValue() {
            slider.loadValue();
        }

        Column {
            id: sliderInnerCol
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    Layout.alignment: Qt.AlignVCenter

                    DankIcon {
                        name: sliderCard.iconName
                        size: 18
                        color: Theme.primary
                        anchors.centerIn: parent
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    StyledText {
                        text: sliderCard.title
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: sliderCard.description
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    id: resetBtn
                    width: 32
                    height: 32
                    radius: 16
                    Layout.alignment: Qt.AlignVCenter
                    color: resetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                    border.color: resetMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                    border.width: 1
                    opacity: slider.value !== sliderCard.defaultValue ? (resetMa.containsMouse ? 1.0 : 0.9) : 0.0
                    visible: opacity > 0
                    scale: resetMa.pressed ? 0.9 : (resetMa.containsMouse ? 1.05 : 1.0)

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    DankRipple { 
                        id: resetRip
                        anchors.fill: parent
                        cornerRadius: parent.radius
                        rippleColor: Theme.primary 
                    }

                    DankIcon {
                        id: resetIcon
                        name: "restart_alt"
                        size: 16
                        anchors.centerIn: parent
                        color: resetMa.containsMouse ? Theme.primary : Theme.surfaceVariantText
                        SequentialAnimation on rotation {
                            running: resetMa.containsMouse; loops: Animation.Infinite
                            NumberAnimation { to: 8; duration: 75 }
                            NumberAnimation { to: -8; duration: 150 }
                            NumberAnimation { to: 0; duration: 75 }
                            onRunningChanged: { if (!running) resetIcon.rotation = 0; }
                        }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: resetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: slider.value !== sliderCard.defaultValue && sliderCard.sliderEnabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            resetAnim.restart();
                            root.saveValue(sliderCard.settingKey, sliderCard.defaultValue);
                        }
                        onPressed: (m) => resetRip.trigger(m.x, m.y)
                    }
                }

                NumberAnimation {
                    id: resetAnim
                    target: slider
                    property: "value"
                    to: sliderCard.defaultValue
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                DankSlider {
                    id: slider
                    property string settingKey: sliderCard.settingKey
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    minimum: sliderCard.minimumValue
                    maximum: sliderCard.maximumValue
                    step: 1
                    unit: sliderCard.unit
                    wheelEnabled: false
                    enabled: sliderCard.sliderEnabled

                    function loadValue() {
                        if (root)
                            value = root.loadValue(settingKey, sliderCard.defaultValue);
                    }
                    Component.onCompleted: loadValue()
                    onSliderValueChanged: newValue => {
                        value = newValue;
                        root.saveValue(settingKey, newValue);
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => { wheel.accepted = true; }
                    }
                }

                Rectangle {
                    id: smallBox
                    width: 64
                    height: 32
                    color: Theme.surfaceContainerHigh
                    radius: height / 2
                    border.color: textInput.activeFocus ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter
                    opacity: sliderCard.sliderEnabled ? 1.0 : 0.4

                    TextInput {
                        id: textInput
                        anchors.fill: parent
                        anchors.margins: 4
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        enabled: sliderCard.sliderEnabled
                        text: activeFocus ? slider.value.toString() : (slider.value + (sliderCard.unit ? sliderCard.unit : ""))
                        selectByMouse: true

                        onEditingFinished: {
                            var cleanText = text.replace(/[^0-9.-]/g, "").trim();
                            var parsed = parseInt(cleanText, 10);
                            if (!isNaN(parsed)) {
                                var clamped = Math.max(sliderCard.minimumValue, Math.min(sliderCard.maximumValue, parsed));
                                slider.value = clamped;
                                root.saveValue(sliderCard.settingKey, clamped);
                            }
                            textInput.focus = false;
                        }

                        onAccepted: {
                            editingFinished();
                        }
                    }
                }
            }
        }
    }

    component SettingsToggleItem: Rectangle {
        id: toggleCard
        width: parent.width
        height: 56
        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
        border.width: 1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

        property string iconName: ""
        property string title: ""
        property string description: ""
        property string settingKey: ""
        property bool defaultValue: false

        property bool isFirst: false
        property bool isLast: false
        property bool isSingle: false

        property alias checked: toggle.checked

        topLeftRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        topRightRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        bottomLeftRadius: (isLast || isSingle) ? root.outerR : root.innerR
        bottomRightRadius: (isLast || isSingle) ? root.outerR : root.innerR

        function loadValue() {
            if (root) {
                var loaded = root.loadValue(settingKey, defaultValue);
                checked = loaded === true || loaded === "true";
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingM

            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: toggle.checked ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.5)
                Layout.alignment: Qt.AlignVCenter
                Behavior on color { ColorAnimation { duration: 150 } }

                DankIcon {
                    name: toggleCard.iconName
                    size: 18
                    color: toggle.checked ? Theme.primary : Theme.surfaceVariantText
                    anchors.centerIn: parent
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                StyledText {
                    text: toggleCard.title
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
                StyledText {
                    text: toggleCard.description
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            DankToggle {
                id: toggle
                Layout.alignment: Qt.AlignVCenter
                Component.onCompleted: toggleCard.loadValue()
                onToggled: function (newChecked) {
                    root.saveValue(toggleCard.settingKey, newChecked);
                }
            }
        }
    }

    component PathFieldItem: Rectangle {
        id: pathCard
        width: parent.width
        implicitHeight: pathCol.implicitHeight + Theme.spacingM * 2
        color: Theme.withAlpha(Theme.surfaceContainerHigh, 0.5)
        border.width: 1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)

        property string iconName: ""
        property string title: ""
        property string description: ""
        property string settingKey: ""
        property string defaultValue: ""

        property bool isFirst: false
        property bool isLast: false
        property bool isSingle: false

        topLeftRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        topRightRadius: (isFirst || isSingle) ? root.outerR : root.innerR
        bottomLeftRadius: (isLast || isSingle) ? root.outerR : root.innerR
        bottomRightRadius: (isLast || isSingle) ? root.outerR : root.innerR

        function loadValue() {
            textField.loadValue();
        }

        Column {
            id: pathCol
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    Layout.alignment: Qt.AlignVCenter

                    DankIcon {
                        name: pathCard.iconName
                        size: 18
                        color: Theme.primary
                        anchors.centerIn: parent
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    StyledText {
                        text: pathCard.title
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                    StyledText {
                        text: pathCard.description
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            DankTextField {
                id: textField
                property string settingKey: pathCard.settingKey
                width: parent.width
                placeholderText: pathCard.defaultValue
                text: pathCard.defaultValue
                function loadValue() {
                    if (root)
                        text = root.loadValue(settingKey, pathCard.defaultValue);
                }
                Component.onCompleted: loadValue()
                onEditingFinished: root.saveValue(settingKey, text)
            }
        }
    }

    // -------------------------------------------------------------------------
    // SETTINGS UI
    // -------------------------------------------------------------------------

    Column {
        id: rootWrapper
        width: parent.width
        spacing: Theme.spacingL

        function loadValue() {
            var groups = [directoriesGroup, displayLimitsGroup];
            for (var g = 0; g < groups.length; g++) {
                var group = groups[g];
                for (var i = 0; i < group.children.length; i++) {
                    var item = group.children[i];
                    if (item && item.loadValue)
                        item.loadValue();
                }
            }
        }

        // ---------------------------------------------------------------------
        // 1. DIRECTORY SOURCES & MONITORING
        // ---------------------------------------------------------------------
        Column {
            width: parent.width
            spacing: Theme.spacingS

            SectionHeader {
                title: "Directory Sources & Monitoring"
                iconName: "folder_open"
            }

            Column {
                id: directoriesGroup
                width: parent.width
                spacing: 2

                PathFieldItem {
                    iconName: "download"
                    title: "Downloads Path"
                    description: "Directory to monitor for recent files"
                    settingKey: "downloadsPath"
                    defaultValue: "~/Downloads"
                    isFirst: true
                }

                SettingsToggleItem {
                    iconName: "account_tree"
                    title: "Scan Downloads Subdirectories"
                    description: "Search for files in all subdirectories of the downloads path"
                    settingKey: "scanSubfolders"
                    defaultValue: false
                }

                PathFieldItem {
                    iconName: "screenshot_region"
                    title: "Screenshots Path"
                    description: "Directory where screen captures are saved"
                    settingKey: "screenshotsPath"
                    defaultValue: "~/Pictures/Screenshots"
                }

                SettingsToggleItem {
                    iconName: "account_tree"
                    title: "Scan Screenshot Subdirectories"
                    description: "Search for files in all subdirectories of the screenshots path"
                    settingKey: "scanScreenshotSubfolders"
                    defaultValue: false
                    isLast: true
                }
            }
        }

        // ---------------------------------------------------------------------
        // 2. DISPLAY & STORAGE LIMITS
        // ---------------------------------------------------------------------
        Column {
            width: parent.width
            spacing: Theme.spacingS

            SectionHeader {
                title: "Display & Storage Limits"
                iconName: "tune"
            }

            Column {
                id: displayLimitsGroup
                width: parent.width
                spacing: 2

                SettingsSliderItem {
                    iconName: "list"
                    title: "Max Downloads"
                    description: "Number of recent downloads to display in list"
                    settingKey: "maxDownloads"
                    defaultValue: 6
                    minimumValue: 1
                    maximumValue: 20
                    unit: " files"
                    isFirst: true
                }

                SettingsSliderItem {
                    iconName: "photo_library"
                    title: "Max Screen Captures"
                    description: "Number of screenshot previews to show in grid"
                    settingKey: "maxScreenshots"
                    defaultValue: 6
                    minimumValue: 1
                    maximumValue: 10
                    unit: " files"
                    isLast: true
                }
            }
        }
    }
}
