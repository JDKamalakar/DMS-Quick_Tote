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

    // Settings & State
    property string downloadsPath: pluginData.downloadsPath || "~/Downloads"
    property string screenshotsPath: pluginData.screenshotsPath || "~/Pictures/Screenshots"
    property int maxDownloads: pluginData.maxDownloads || 6
    property int maxScreenshots: pluginData.maxScreenshots || 4
    
    property var pinnedFiles: pluginData.pinnedFiles || []
    property var recentDownloads: []
    property var recentScreenshots: []
    
    property bool loading: dlScanner.running || ssScanner.running
    property string statusLabel: loading ? "Scanning paths..." : (recentDownloads.length + recentScreenshots.length + pinnedFiles.length) + " items ready"

    // --- Instant Updates ---
    onPluginDataChanged: root.refresh()
    
    onDownloadsPathChanged: refresh()
    onScreenshotsPathChanged: refresh()
    onMaxDownloadsChanged: refresh()
    onMaxScreenshotsChanged: refresh()

    function refresh() {
        dlScanner.running = true;
        ssScanner.running = true;
    }

    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
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
        let current = root.pinnedFiles;
        let index = current.indexOf(path);
        if (index === -1) {
            current.push(path);
        } else {
            current.splice(index, 1);
        }
        root.pinnedFiles = current;
        pluginData.pinnedFiles = current;
    }

    function isPinned(path) {
        return root.pinnedFiles.indexOf(path) !== -1;
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

    // --- Bar Pill (Standard Icon-Only) ---

    horizontalBarPill: Component {
        DankIcon {
            name: "folder"
            size: Theme.iconSize - 4
            color: Theme.widgetIconColor || Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "folder"
            size: 20
            color: Theme.widgetIconColor || Theme.primary
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // --- Popout Content (GitHub Notifier Inspired) ---

    popoutContent: Component {
        PopoutComponent {
            id: popoutContainer
            headerText: "Quick Tote"
            detailsText: root.statusLabel
            showCloseButton: true
            
            Column {
                width: parent.width
                spacing: Theme.spacingM
                topPadding: Theme.spacingM
                bottomPadding: Theme.spacingL

                // --- Header Card (Premium Gradient) ---
                Item {
                    width: parent.width
                    height: 68
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.cornerRadius * 1.5
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) }
                            GradientStop { position: 1.0; color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08) }
                        }
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                    }

                    Row {
                        anchors.fill: parent; anchors.margins: Theme.spacingM
                        spacing: Theme.spacingM
                        
                        Rectangle {
                            width: 38; height: 38; radius: 19
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                            DankIcon { name: "folder_shared"; size: 22; color: Theme.primary; anchors.centerIn: parent }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            StyledText { text: "Recent Documents"; font.bold: true; font.pixelSize: Theme.fontSizeLarge; color: Theme.surfaceText }
                            StyledText { text: "Quick access to your workspace"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        DankIcon {
                            name: "cached"
                            size: 18
                            color: Theme.primary
                            opacity: 0.6
                            visible: root.loading
                            anchors.verticalCenter: parent.verticalCenter
                            RotationAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: parent.visible }
                        }
                    }
                }

                // --- Screen Captures Section (Flow Layout for Wrapping) ---
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.recentScreenshots.length > 0

                    Row {
                        width: parent.width; spacing: Theme.spacingS
                        Rectangle { width: 4; height: 16; radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Screen captures"; font.weight: Font.Bold; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceText }
                    }

                    StyledRect {
                        width: parent.width
                        height: ssFlow.implicitHeight + 24
                        radius: Theme.cornerRadius * 1.5
                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                        
                        Flow {
                            id: ssFlow
                            anchors.centerIn: parent
                            width: parent.width - 24
                            spacing: Theme.spacingM
                            padding: 12
                            
                            Repeater {
                                model: root.recentScreenshots
                                Item {
                                    width: 62; height: 62
                                    MouseArea {
                                        id: ssMa; anchors.fill: parent; hoverEnabled: true
                                        onClicked: root.openFile(modelData.path)
                                        onPressAndHold: root.togglePin(modelData.path)
                                    }
                                    Rectangle {
                                        anchors.fill: parent; radius: 31; clip: true; color: Theme.surfaceContainer
                                        Image { anchors.fill: parent; source: "file://" + modelData.path; fillMode: Image.PreserveAspectCrop; asynchronous: true; mipmap: true }
                                        Rectangle { anchors.fill: parent; radius: 31; color: "white"; opacity: ssMa.containsMouse ? 0.1 : 0; Behavior on opacity { NumberAnimation { duration: 150 } } }
                                    }
                                    DankIcon {
                                        visible: root.isPinned(modelData.path)
                                        name: "push_pin"; size: 12; color: Theme.secondary; anchors.top: parent.top; anchors.right: parent.right
                                    }
                                }
                            }
                        }
                    }
                }

                // --- Pinned Files Section ---
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.pinnedFiles.length > 0

                    Row {
                        width: parent.width; spacing: Theme.spacingS
                        Rectangle { width: 4; height: 16; radius: 2; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Pinned files"; font.weight: Font.Bold; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceText }
                    }

                    StyledRect {
                        width: parent.width
                        height: pinnedBox.implicitHeight + 24
                        radius: Theme.cornerRadius * 1.5
                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                        clip: true

                        Column {
                            id: pinnedBox
                            anchors.fill: parent; anchors.margins: 12
                            spacing: 4
                            Repeater {
                                model: root.pinnedFiles
                                Item {
                                    width: parent.width; height: 38
                                    property string filePath: modelData
                                    MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: root.openFile(filePath); onPressAndHold: root.togglePin(filePath); onPressed: (m) => pr.trigger(m.x, m.y) }
                                    Rectangle { anchors.fill: parent; radius: Theme.cornerRadius; color: pma.containsMouse ? Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08) : "transparent" }
                                    DankRipple { id: pr; anchors.fill: parent; cornerRadius: Theme.cornerRadius; rippleColor: Theme.secondary }
                                    Row {
                                        anchors.fill: parent; anchors.leftMargin: Theme.spacingS; anchors.rightMargin: Theme.spacingS; spacing: Theme.spacingS
                                        DankIcon { name: root.getIcon(filePath); size: 16; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
                                        Column {
                                            width: parent.width - 36; anchors.verticalCenter: parent.verticalCenter
                                            StyledText { width: parent.width; text: filePath.split('/').pop(); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight }
                                            StyledText { width: parent.width; text: filePath; font.pixelSize: Theme.fontSizeSmall - 2; color: Theme.surfaceVariantText; opacity: 0.6; elide: Text.ElideMiddle }
                                        }
                                        DankIcon { name: "push_pin"; size: 12; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- Recent Downloads Section ---
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: root.recentDownloads.length > 0

                    Row {
                        width: parent.width; spacing: Theme.spacingS
                        Rectangle { width: 4; height: 16; radius: 2; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Recent downloads"; font.weight: Font.Bold; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceText }
                    }

                    StyledRect {
                        width: parent.width
                        height: dlBox.implicitHeight + 24
                        radius: Theme.cornerRadius * 1.5
                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                        border.width: 1
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                        clip: true

                        Column {
                            id: dlBox
                            anchors.fill: parent; anchors.margins: 12
                            spacing: 4
                            Repeater {
                                model: root.recentDownloads
                                Item {
                                    width: parent.width; height: 38
                                    MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; onClicked: root.openFile(modelData.path); onPressAndHold: root.togglePin(modelData.path); onPressed: (m) => dr.trigger(m.x, m.y) }
                                    Rectangle { anchors.fill: parent; radius: Theme.cornerRadius; color: dma.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent" }
                                    DankRipple { id: dr; anchors.fill: parent; cornerRadius: Theme.cornerRadius; rippleColor: Theme.primary }
                                    Row {
                                        anchors.fill: parent; anchors.leftMargin: Theme.spacingS; anchors.rightMargin: Theme.spacingS; spacing: Theme.spacingS
                                        DankIcon { name: root.getIcon(modelData.path); size: 16; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                                        Column {
                                            width: parent.width - (root.isPinned(modelData.path) ? 36 : 24); anchors.verticalCenter: parent.verticalCenter
                                            StyledText { width: parent.width; text: modelData.name; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; elide: Text.ElideRight }
                                            StyledText { width: parent.width; text: modelData.path; font.pixelSize: Theme.fontSizeSmall - 2; color: Theme.surfaceVariantText; opacity: 0.6; elide: Text.ElideMiddle }
                                        }
                                        DankIcon { visible: root.isPinned(modelData.path); name: "push_pin"; size: 12; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
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
