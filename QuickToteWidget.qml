import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import Qt5Compat.GraphicalEffects

PluginComponent {
    id: root
    layerNamespacePlugin: "quickTote"
    
    popoutWidth: 340
    popoutHeight: 0

    // Settings & State (Reactive bindings)
    property string downloadsPath: (pluginData && pluginData.downloadsPath) ? pluginData.downloadsPath : "~/Downloads"
    property string screenshotsPath: (pluginData && pluginData.screenshotsPath) ? pluginData.screenshotsPath : "~/Pictures/Screenshots"
    property int maxDownloads: (pluginData && pluginData.maxDownloads) ? pluginData.maxDownloads : 6
    property int maxScreenshots: (pluginData && pluginData.maxScreenshots) ? pluginData.maxScreenshots : 4
    
    property var pinnedFiles: (pluginData && pluginData.pinnedFiles) ? pluginData.pinnedFiles : []
    property var recentDownloads: []
    property var recentScreenshots: []
    
    property bool loading: dlScanner.running || ssScanner.running
    property string statusLabel: loading ? "Updating..." : (recentDownloads.length + recentScreenshots.length + pinnedModel.count) + " items ready"

    // --- Persistence & Reactivity Sync ---
    onPluginDataChanged: {
        if (!pluginData) return;
        
        root.downloadsPath = pluginData.downloadsPath || "~/Downloads";
        root.screenshotsPath = pluginData.screenshotsPath || "~/Pictures/Screenshots";
        root.maxDownloads = pluginData.maxDownloads || 6;
        root.maxScreenshots = pluginData.maxScreenshots || 4;
        
        if (pluginData.pinnedFiles !== undefined) {
            if (pluginData.pinnedFiles.length !== pinnedModel.count) {
                root.syncModel();
            }
            root.pinnedFiles = pluginData.pinnedFiles;
        }
        
        root.refresh();
    }

    onDownloadsPathChanged: refresh()
    onScreenshotsPathChanged: refresh()
    onMaxDownloadsChanged: refresh()
    onMaxScreenshotsChanged: refresh()

    function refresh() {
        dlScanner.running = false;
        ssScanner.running = false;
        dlScanner.running = true;
        ssScanner.running = true;
    }

    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // --- Adaptive "Smart Sort" Screenshot Logic ---
    readonly property int ssMaxAreaWidth: 316
    // Logic: 1-2 items = 1 row. 3-10 items = 2 rows, evenly distributed.
    readonly property int ssCols: {
        let count = recentScreenshots.length;
        if (count <= 2) return count;
        return Math.ceil(count / 2); // 3->2, 5->3, 10->5
    }

    property int ssWidth: {
        let count = recentScreenshots.length;
        if (count === 0) return 0;
        let spacing = (ssCols - 1) * Theme.spacingS;
        return (ssMaxAreaWidth - spacing) / ssCols;
    }
    // Large items for 1-2 images, more compact for grids
    property int ssHeight: recentScreenshots.length <= 2 ? Math.min(160, ssWidth * 0.625) : 72

    // --- ListModel Management ---
    ListModel { id: pinnedModel }

    Component.onCompleted: root.syncModel()
    
    function syncModel() {
        pinnedModel.clear();
        let current = root.pinnedFiles;
        for (let path of current) {
            pinnedModel.append({ "path": path });
        }
    }

    // --- Logic ---

    function getFileInfo(line) {
        let parts = line.split('|');
        if (parts.length < 2) return null;
        let path = parts[1];
        return {
            path: path,
            name: path.split('/').pop(),
            time: parseFloat(parts[0])
        };
    }

    Process {
        id: dlScanner
        running: false
        command: ["bash", "-c", `d="${root.downloadsPath}"; d=\${d/#\\~/$HOME}; [ -d "$d" ] && find "$d" -maxdepth 1 -type f -not -path '*/.*' -printf '%T@|%p\\n' | sort -rn | head -n ${root.maxDownloads}`]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split('\n').filter(l => l !== "");
                root.recentDownloads = lines.map(root.getFileInfo).filter(f => f !== null);
            }
        }
    }

    Process {
        id: ssScanner
        running: false
        command: ["bash", "-c", `d="${root.screenshotsPath}"; d=\${d/#\\~/$HOME}; [ -d "$d" ] && find "$d" -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \\) -printf '%T@|%p\\n' | sort -rn | head -n ${root.maxScreenshots}`]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split('\n').filter(l => l !== "");
                root.recentScreenshots = lines.map(root.getFileInfo).filter(f => f !== null);
            }
        }
    }

    function openFile(path) {
        Quickshell.execDetached(["xdg-open", path]);
        root.closePopout();
    }

    function togglePin(path) {
        let current = root.pinnedFiles ? Array.from(root.pinnedFiles) : [];
        let index = current.indexOf(path);
        
        if (index === -1) {
            current.push(path);
            pinnedModel.append({ "path": path });
        } else {
            current.splice(index, 1);
            for (let i = 0; i < pinnedModel.count; i++) {
                if (pinnedModel.get(i).path === path) {
                    pinnedModel.remove(i);
                    break;
                }
            }
        }
        
        root.pinnedFiles = current;
        pluginData.pinnedFiles = current;
    }

    function isPinned(path) {
        return root.pinnedFiles ? root.pinnedFiles.indexOf(path) !== -1 : false;
    }

    function isImage(path) {
        const ext = path.split('.').pop().toLowerCase();
        return ['png', 'jpg', 'jpeg', 'gif', 'webp'].includes(ext);
    }

    function getIcon(path) {
        let ext = path.split('.').pop().toLowerCase();
        switch(ext) {
            case 'png': case 'jpg': case 'jpeg': case 'gif': case 'webp': return "image_file";
            case 'mp4': case 'mkv': case 'mov': case 'avi': return "movie";
            case 'mp3': case 'wav': case 'flac': case 'ogg': return "audio_file";
            case 'pdf': return "picture_as_pdf";
            case 'zip': case 'tar': case 'gz': case '7z': case 'rar': return "archive";
            case 'txt': case 'md': case 'doc': case 'docx': case 'odt': return "description";
            case 'html': case 'css': case 'js': case 'json': case 'py': case 'sh': return "code";
            default: return "insert_drive_file";
        }
    }

    // --- Bar Pill ---

    horizontalBarPill: Component {
        DankIcon {
            name: "folder"; size: Theme.iconSize - 4; color: Theme.widgetIconColor || Theme.primary; anchors.verticalCenter: parent.verticalCenter
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "folder"; size: 20; color: Theme.widgetIconColor || Theme.primary; anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // --- Popout Content ---

    popoutContent: Component {
        PopoutComponent {
            id: popoutContainer
            headerText: "Quick Tote"
            detailsText: root.statusLabel
            showCloseButton: true
            
            Column {
                id: mainCol; width: parent.width; spacing: Theme.spacingM
                topPadding: Theme.spacingM; bottomPadding: Theme.spacingL

                // --- Header Card ---
                Item {
                    width: parent.width; height: 68
                    Rectangle {
                        anchors.fill: parent; radius: Theme.cornerRadius * 1.5
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) }
                            GradientStop { position: 1.0; color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08) }
                        }
                        border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                    }
                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                        Rectangle {
                            width: 38; height: 38; radius: 19; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                            DankIcon { name: "folder_shared"; size: 22; color: Theme.primary; anchors.centerIn: parent }
                        }
                        Column {
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: 1
                            StyledText { text: "Recent Documents"; font.bold: true; font.pixelSize: Theme.fontSizeLarge; color: Theme.surfaceText }
                            StyledText { text: "Quick access to your workspace"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                        DankIcon {
                            name: "cached"; size: 18; color: Theme.primary; opacity: 0.6; visible: root.loading
                            RotationAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: parent.visible }
                        }
                    }
                }

                // --- Pinned Files Section ---
                Column {
                    width: parent.width; spacing: Theme.spacingS
                    opacity: pinnedModel.count > 0 ? 1 : 0
                    height: pinnedModel.count > 0 ? (pinnedHead.height + (Math.ceil(pinnedModel.count / 2) * 52) + 24 + Theme.spacingS) : 0
                    visible: opacity > 0; clip: true
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Row {
                        id: pinnedHead; width: parent.width; spacing: Theme.spacingS
                        DankIcon { name: "push_pin"; size: 16; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Pinned files"; font.weight: Font.Bold; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceText }
                    }

                    StyledRect {
                        width: parent.width; height: (Math.ceil(pinnedModel.count / 2) * 52) + 24
                        radius: Theme.cornerRadius * 1.5; color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                        border.width: 1; border.color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.1)
                        
                        GridView {
                            id: pinnedGv; anchors.fill: parent; anchors.margins: 12
                            cellWidth: width / 2; cellHeight: 52; interactive: false
                            model: pinnedModel
                            add: Transition { 
                                NumberAnimation { property: "y"; from: 52; duration: 350; easing.type: Easing.OutBack } 
                                NumberAnimation { properties: "opacity,scale"; from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic } 
                            }
                            remove: Transition { 
                                NumberAnimation { property: "y"; to: 52; duration: 300; easing.type: Easing.InBack } 
                                NumberAnimation { properties: "opacity,scale"; to: 0; duration: 200 } 
                            }
                            displaced: Transition { NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutBack } }

                            delegate: Item {
                                width: pinnedGv.cellWidth; height: 50
                                property string filePath: model.path
                                property bool hovered: maPin.containsMouse || pinBtnMaGrid.containsMouse
                                MouseArea { id: maPin; anchors.fill: parent; hoverEnabled: true; onClicked: root.openFile(filePath); onPressed: (m) => pRipG.trigger(m.x, m.y) }
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 4; radius: Theme.cornerRadius
                                    color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, hovered ? 0.15 : 0.08)
                                    border.width: 1; border.color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, hovered ? 0.3 : 0.1)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Rectangle { anchors.fill: parent; radius: parent.radius; color: "white"; opacity: hovered ? 0.05 : 0; Behavior on opacity { NumberAnimation { duration: 150 } } }
                                }
                                DankRipple { id: pRipG; anchors.fill: parent; anchors.margins: 4; cornerRadius: Theme.cornerRadius; rippleColor: Theme.secondary }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 4; spacing: 8
                                    Rectangle {
                                        id: pinThumb; width: 28; height: 28; radius: 14; color: Theme.surfaceContainer
                                        Layout.alignment: Qt.AlignVCenter; layer.enabled: true
                                        layer.effect: OpacityMask { maskSource: Rectangle { width: 28; height: 28; radius: 14 } }
                                        Image { visible: root.isImage(filePath); anchors.fill: parent; source: "file://" + filePath; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                        DankIcon { visible: !root.isImage(filePath); anchors.centerIn: parent; name: root.getIcon(filePath); size: 12; color: Theme.secondary }
                                    }
                                    StyledText {
                                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                        text: filePath.split('/').pop(); font.pixelSize: Theme.fontSizeSmall - 1; color: Theme.surfaceText; elide: Text.ElideRight
                                    }
                                    Item {
                                        width: 40; height: 40; Layout.alignment: Qt.AlignVCenter
                                        DankIcon {
                                            anchors.centerIn: parent; name: "push_pin"; size: 14; color: Theme.secondary; opacity: 0.8
                                            scale: (hovered || root.isPinned(filePath)) ? (pinBtnMaGrid.pressed ? 0.8 : 1.2) : 0.0
                                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                        }
                                        MouseArea { id: pinBtnMaGrid; anchors.fill: parent; hoverEnabled: true; onClicked: root.togglePin(filePath) }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- Screen Captures Section (Smart Sort) ---
                Column {
                    width: parent.width; spacing: Theme.spacingS
                    opacity: root.recentScreenshots.length > 0 ? 1 : 0
                    height: root.recentScreenshots.length > 0 ? (ssHead.height + ssCont.height + Theme.spacingS * 2) : 0
                    visible: opacity > 0; clip: true
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Row {
                        id: ssHead; width: parent.width; spacing: Theme.spacingS
                        DankIcon { name: "screenshot_region"; size: 16; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Screen captures"; font.weight: Font.Bold; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceText }
                    }
                    StyledRect {
                        id: ssCont; width: parent.width; height: ssGrid.implicitHeight
                        radius: Theme.cornerRadius * 1.5; color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                        border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        Grid {
                            id: ssGrid; anchors.horizontalCenter: parent.horizontalCenter
                            columns: root.ssCols
                            spacing: Theme.spacingS; topPadding: 12; bottomPadding: 12
                            Repeater {
                                model: root.recentScreenshots
                                Item {
                                    id: ssDelegate; width: root.ssWidth; height: root.ssHeight
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    property bool hovered: maSS.containsMouse || ssPinMa.containsMouse
                                    MouseArea { id: maSS; anchors.fill: parent; hoverEnabled: true; onClicked: root.openFile(modelData.path); onPressed: (m) => ssRip.trigger(m.x, m.y) }
                                    Rectangle {
                                        id: thumbCont; anchors.fill: parent; radius: 12; color: Theme.surfaceContainer
                                        layer.enabled: true
                                        layer.effect: OpacityMask { maskSource: Rectangle { width: thumbCont.width; height: thumbCont.height; radius: 12 } }
                                        Image { anchors.fill: parent; source: "file://" + modelData.path; fillMode: Image.PreserveAspectCrop; asynchronous: true; mipmap: true }
                                        Rectangle { anchors.fill: parent; radius: 12; color: "black"; opacity: maSS.containsMouse ? 0.2 : 0; Behavior on opacity { NumberAnimation { duration: 150 } } }
                                        DankRipple { id: ssRip; anchors.fill: parent; cornerRadius: 12; rippleColor: Theme.primary }
                                    }
                                    Item {
                                        width: 32; height: 32; anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: -8; anchors.rightMargin: -8
                                        scale: (ssDelegate.hovered || root.isPinned(modelData.path)) ? 1.0 : 0.0
                                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                        Rectangle { anchors.centerIn: parent; width: 24; height: 24; radius: 12; color: root.isPinned(modelData.path) ? Theme.primary : Theme.surfaceContainer; border.width: 1; border.color: Theme.outline
                                            DankIcon { name: "push_pin"; size: 14; color: root.isPinned(modelData.path) ? "white" : Theme.surfaceText; anchors.centerIn: parent; rotation: root.isPinned(modelData.path) ? 0 : 45; Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutBack } } }
                                        }
                                        MouseArea { id: ssPinMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.togglePin(modelData.path) }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- Recent Downloads Section ---
                Column {
                    width: parent.width; spacing: Theme.spacingS
                    opacity: root.recentDownloads.length > 0 ? 1 : 0
                    height: root.recentDownloads.length > 0 ? (dlHead.height + dlCont.height + Theme.spacingS * 2) : 0
                    visible: opacity > 0; clip: true
                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Row {
                        id: dlHead; width: parent.width; spacing: Theme.spacingS
                        DankIcon { name: "download"; size: 16; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Recent downloads"; font.weight: Font.Bold; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceText }
                    }
                    StyledRect {
                        id: dlCont; width: parent.width; height: dlLv.contentHeight + 24
                        radius: Theme.cornerRadius * 1.5; color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                        border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                        ListView {
                            id: dlLv; anchors.fill: parent; anchors.margins: 12; spacing: 6
                            model: root.recentDownloads; interactive: false
                            add: Transition { 
                                NumberAnimation { property: "y"; from: 42; duration: 350; easing.type: Easing.OutBack } 
                                NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 250 } 
                            }
                            remove: Transition { 
                                NumberAnimation { property: "y"; to: 42; duration: 300; easing.type: Easing.InBack } 
                                NumberAnimation { properties: "opacity,scale"; to: 0; duration: 200 } 
                            }
                            displaced: Transition { NumberAnimation { properties: "y"; duration: 400; easing.type: Easing.OutBack } }
                            delegate: Item {
                                width: dlLv.width; height: 42
                                property bool hovered: maDL.containsMouse || dlPinMa.containsMouse
                                MouseArea { id: maDL; anchors.fill: parent; hoverEnabled: true; onClicked: root.openFile(modelData.path); onPressed: (m) => dlRip.trigger(m.x, m.y) }
                                Rectangle {
                                    anchors.fill: parent; radius: Theme.cornerRadius
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, hovered ? 0.15 : 0.08)
                                    border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, hovered ? 0.3 : 0.1)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Rectangle { anchors.fill: parent; radius: parent.radius; color: "white"; opacity: hovered ? 0.05 : 0; Behavior on opacity { NumberAnimation { duration: 150 } } }
                                }
                                DankRipple { id: dlRip; anchors.fill: parent; cornerRadius: Theme.cornerRadius; rippleColor: Theme.primary }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 0; spacing: Theme.spacingS
                                    Rectangle {
                                        id: dlThumb; width: 26; height: 26; radius: 13; color: Theme.surfaceContainer
                                        Layout.alignment: Qt.AlignVCenter; layer.enabled: true
                                        layer.effect: OpacityMask { maskSource: Rectangle { width: 26; height: 26; radius: 13 } }
                                        Image { visible: root.isImage(modelData.path); anchors.fill: parent; source: "file://" + modelData.path; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                        DankIcon { visible: !root.isImage(modelData.path); anchors.centerIn: parent; name: root.getIcon(modelData.path); size: 12; color: Theme.primary }
                                    }
                                    Column {
                                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                        StyledText { width: parent.width; text: modelData.name; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight }
                                        StyledText { width: parent.width; text: modelData.path; font.pixelSize: Theme.fontSizeSmall - 2; color: Theme.surfaceVariantText; opacity: 0.6; elide: Text.ElideMiddle }
                                    }
                                    Item {
                                        width: 40; height: 38; Layout.alignment: Qt.AlignVCenter
                                        DankIcon { 
                                            anchors.centerIn: parent; name: "push_pin"; size: 14; color: root.isPinned(modelData.path) ? Theme.primary : Theme.surfaceVariantText
                                            rotation: root.isPinned(modelData.path) ? 0 : 45
                                            scale: (hovered || root.isPinned(modelData.path)) ? (dlPinMa.pressed ? 0.8 : 1.2) : 0.0
                                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                            Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                        }
                                        MouseArea { id: dlPinMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.togglePin(modelData.path) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
