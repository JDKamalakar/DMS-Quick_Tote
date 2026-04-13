import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    layerNamespacePlugin: "quickTote"
    
    popoutWidth: 340
    popoutHeight: 0

    // Settings & State
    property var pinnedFiles: pluginData.pinnedFiles || []
    property var recentDownloads: []
    property var recentScreenshots: []
    
    property bool loading: dlScanner.running || ssScanner.running
    property string statusLabel: loading ? "Scanning..." : (recentDownloads.length + recentScreenshots.length + pinnedFiles.length) + " items ready."

    function refresh() {
        dlScanner.running = true;
        ssScanner.running = true;
    }

    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // --- Logic ---

    Process {
        id: dlScanner
        running: false
        command: ["bash", "-c", `find "$HOME/Downloads" -maxdepth 1 -type f -printf '%f\\n' | head -n 5`]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split('\n').filter(l => l !== "");
                root.recentDownloads = lines;
            }
        }
    }

    Process {
        id: ssScanner
        running: false
        command: ["bash", "-c", `find "$HOME/Pictures/Screenshots" -maxdepth 1 -type f -printf '%f\\n' | head -n 5`]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split('\n').filter(l => l !== "");
                root.recentScreenshots = lines;
            }
        }
    }

    // --- Bar Pill (Icon Only) ---

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

    // --- Popout Content (Using User Standard) ---

    popoutContent: Component {
        PopoutComponent {
            id: popoutContainer
            headerText: "Quick Tote"
            detailsText: root.statusLabel
            showCloseButton: true
            
            // Minimal test content to check visibility
            Column {
                width: parent.width
                spacing: Theme.spacingM
                topPadding: Theme.spacingM
                
                StyledText {
                    text: "Files found in Downloads: " + root.recentDownloads.join(", ")
                    visible: root.recentDownloads.length > 0
                    width: parent.width
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    text: "No files found yet."
                    visible: root.recentDownloads.length === 0 && !root.loading
                    font.italic: true
                    opacity: 0.6
                }
                
                DankButton {
                    width: parent.width
                    height: 40
                    visible: !root.loading
                    onClicked: root.refresh()
                    StyledText { anchors.centerIn: parent; text: "Manual Scan" }
                }
            }
        }
    }
}
