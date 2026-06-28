import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services
import QtQuick.Effects
import QtQuick.Shapes

PluginComponent {
    id: root
    
    popoutWidth: 480
    popoutHeight: 0

    // --- Settings (Reliable PluginService Loading) ---
    property string _downloadsPath: PluginService.loadPluginData("quickTote", "downloadsPath", "")
    property string _screenshotsPath: PluginService.loadPluginData("quickTote", "screenshotsPath", "")
    
    // Robust fallbacks ensure valid paths even if settings are manually cleared or missing
    property string downloadsPath: {
        let p = _downloadsPath ? _downloadsPath.trim() : "";
        if (p === "") return "~/Downloads";
        return p;
    }
    property string screenshotsPath: {
        let p = _screenshotsPath ? _screenshotsPath.trim() : "";
        if (p === "") return "~/Pictures/Screenshots";
        return p;
    }
    
    property int maxDownloads: PluginService.loadPluginData("quickTote", "maxDownloads", 6)
    property int maxScreenshots: PluginService.loadPluginData("quickTote", "maxScreenshots", 6)
    property bool scanSubfolders: PluginService.loadPluginData("quickTote", "scanSubfolders", false)
    property bool scanScreenshotSubfolders: PluginService.loadPluginData("quickTote", "scanScreenshotSubfolders", false)
    
    // --- State Management ---
    property var pinnedFiles: []
    property var recentDownloads: []
    property var recentScreenshots: []
    
    property bool loading: (dlScanner && dlScanner.running) || (ssScanner && ssScanner.running)
    property string statusLabel: (loading ? "Updating..." : (recentDownloads.length + recentScreenshots.length + pinnedModel.count) + " items ready")

    // --- Persistence: Manual JSON Store ---
    // This bypasses the shell's volatile pluginData for pins, ensuring they are truly permanent.
    
    property string pinsFile: "~/.config/quickTote_pins.json"

    function savePins() {
        let jsonStr = JSON.stringify(root.pinnedFiles);
        // Ensure the directory exists before writing to prevent failure
        pinSaver.command = ["bash", "-c", "f=\"" + root.pinsFile + "\"; f=${f/#\\~/$HOME}; mkdir -p \"$(dirname \"$f\")\"; echo '" + jsonStr + "' > \"$f\""];
        pinSaver.running = true;
    }

    Process {
        id: pinSaver
        running: false
    }

    Process {
        id: pinLoader
        running: false
        command: ["bash", "-c", "f=\"" + root.pinsFile + "\"; f=${f/#\\~/$HOME}; [ -f \"$f\" ] && cat \"$f\" || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text.trim());
                    if (Array.isArray(data)) {
                        root.pinnedFiles = data;
                        root.syncModel();
                    }
                } catch(e) { console.log("QuickTote: No pins found yet or parse error"); }
            }
        }
    }

    // --- Reactivity (New DMS Standard) ---
    PluginGlobalVar { varName: "downloadsPath"; onValueChanged: { root._downloadsPath = value; root.refresh() } }
    PluginGlobalVar { varName: "screenshotsPath"; onValueChanged: { root._screenshotsPath = value; root.refresh() } }
    PluginGlobalVar { varName: "maxDownloads"; onValueChanged: { root.maxDownloads = value; root.refresh() } }
    PluginGlobalVar { varName: "maxScreenshots"; onValueChanged: { root.maxScreenshots = value; root.refresh() } }
    PluginGlobalVar { varName: "scanSubfolders"; onValueChanged: { root.scanSubfolders = value; root.refresh() } }
    PluginGlobalVar { varName: "scanScreenshotSubfolders"; onValueChanged: { root.scanScreenshotSubfolders = value; root.refresh() } }

    onPluginDataChanged: {
        if (!pluginData) return;
        // Fallback for older DMS versions
        root.refresh();
    }

    onDownloadsPathChanged: refresh()
    onScreenshotsPathChanged: refresh()
    onMaxDownloadsChanged: refresh()
    onMaxScreenshotsChanged: refresh()
    onScanSubfoldersChanged: refresh()
    onScanScreenshotSubfoldersChanged: refresh()

    function refresh() {
        if (dlScanner) dlScanner.running = false;
        if (ssScanner) ssScanner.running = false;
        if (dlScanner) dlScanner.running = true;
        if (ssScanner) ssScanner.running = true;
    }

    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // (Diagnostic mock timer removed — pipeline verified)

    // --- Adaptive "Smart Sort" Screenshot Logic ---
    readonly property int ssPadding: 12
    readonly property int ssCols: {
        let count = recentScreenshots.length;
        if (count <= 0) return 0;
        if (count <= 2) return count;
        return Math.ceil(count / 2);
    }

    property int ssWidth: 0
    property int ssHeight: 72

    // --- ListModel Management ---
    ListModel { id: pinnedModel }
    ListModel { id: downloadsModel }

    function syncDownloads() {
        let raw = root.recentDownloads;
        if (!raw) { downloadsModel.clear(); return; }
        
        // Identity-based sync for smooth ListView animations
        for(let i=0; i<downloadsModel.count; i++) downloadsModel.setProperty(i, "visited", false);
        
        for(let i=0; i<raw.length; i++) {
            let item = raw[i];
            let found = false;
            for(let j=0; j<downloadsModel.count; j++) {
                if(downloadsModel.get(j).path === item.path) {
                    downloadsModel.setProperty(j, "visited", true);
                    if (j !== i) downloadsModel.move(j, i, 1);
                    found = true;
                    break;
                }
            }
            if(!found) {
                downloadsModel.insert(i, {
                    "path": item.path,
                    "name": item.name,
                    "visited": true
                });
            }
        }
        
        for(let i=downloadsModel.count-1; i>=0; i--) {
            if(downloadsModel.get(i).visited === false) downloadsModel.remove(i);
        }
    }

    Component.onCompleted: {
        pinLoader.running = true; // Hard load pins from our custom disk file
        root.refresh();
    }
    
    function syncModel() {
        pinnedModel.clear();
        let current = root.pinnedFiles;
        if (!current) return;
        for (let path of current) {
            pinnedModel.append({ "path": path });
        }
    }

    // --- Logic ---

    function getFileInfo(line) {
        let path = line.trim();
        if (!path || path.length < 3) return null;

        // Strip timestamp if present
        if (path.indexOf('|') !== -1) {
            path = path.split('|')[1];
        }
        
        try {
            // Remove protocols
            path = path.replace(/^[a-z]+:\/\/\/?/i, "/"); // file:///home -> /home
            path = decodeURIComponent(path);
        } catch(e) {}
        
        // Final cleanup for XML/XBEL artifacts
        path = path.split('"')[0].split("'")[0].split("<")[0];

        if (!path || path.length < 2) return null;

        return {
            path: path,
            name: path.split('/').pop(),
            time: Date.now()
        };
    }

    Process {
        id: dlScanner
        running: false
        command: ["bash", "-c", `d="${root.downloadsPath}"; d=\${d/#\\~/$HOME}; [ -d "$d" ] && find "$d" ${root.scanSubfolders ? "" : "-maxdepth 1"} -type f -not -path '*/.*' -printf '%T@|%p\\n' | sort -rn | head -n ${root.maxDownloads}`]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split('\n').filter(l => l !== "");
                root.recentDownloads = lines.map(root.getFileInfo).filter(f => f !== null);
                root.syncDownloads();
            }
        }
    }

    Process {
        id: ssScanner
        running: false
        command: ["bash", "-c", `d="${root.screenshotsPath}"; d=\${d/#\\~/$HOME}; [ -d "$d" ] && find "$d" ${root.scanScreenshotSubfolders ? "" : "-maxdepth 1"} -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \\) -printf '%T@|%p\\n' | sort -rn | head -n ${root.maxScreenshots}`]
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

    // --- System Drag (works from layer shell via ripdrag/xdragon) ---
    // Qt's Drag.Automatic cannot initiate Wayland DnD from a layer shell surface.
    // We delegate to a native CLI tool that acts as a proper wl_data_source.
    function startSystemDrag(path) {
        fileDragger.running = false; // Reset the process object
        fileDragger.command = [
            "bash", "-c",
            "pkill -x ripdrag; pkill -x xdragon; pkill -x dragon; " +
            "f=" + JSON.stringify(path) + "; " +
            "if command -v ripdrag >/dev/null 2>&1; then ripdrag --and-exit --icons-only --icon-size 64 --content-width 90 --content-height 64 \"$f\"; " +
            "elif command -v xdragon >/dev/null 2>&1; then xdragon --and-exit --small \"$f\"; " +
            "elif command -v dragon >/dev/null 2>&1; then dragon --and-exit --small \"$f\"; fi"
        ];
        fileDragger.running = true;
    }

    Process {
        id: fileDragger
        running: false
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
        
        root.pinnedFiles = [...current];
        root.savePins(); // Manually push to disk
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
            headerText: ""
            detailsText: ""
            showCloseButton: false
            
            Component {
                id: sectionHeaderComponent
                RowLayout {
                    spacing: Theme.spacingXS
                    DankIcon { name: sectionIcon; size: 14; color: Theme.surfaceText }
                    StyledText { text: sectionTitle; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
                }
            }
            
            Column {
                id: mainCol; width: parent.width; spacing: Theme.spacingM
                topPadding: 0; bottomPadding: 2

                // --- Header Card ---
                StyledRect {
                    width: parent.width; height: 68
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    
                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: Theme.spacingM
                        Rectangle {
                            width: 38; height: 38; radius: height / 2; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
                            DankIcon { name: "folder_shared"; size: 22; color: Theme.primary; anchors.centerIn: parent }
                        }
                        Column {
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; spacing: Theme.spacingXXS
                            StyledText { text: "Recent Documents"; font.bold: true; font.pixelSize: Theme.fontSizeLarge; color: Theme.surfaceText }
                            Item {
                                width: statusText.implicitWidth; height: statusText.implicitHeight; clip: true
                                StyledText { 
                                    id: statusText
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.primary
                                    font.family: "Monospace"
                                    opacity: 0.8
                                    property string targetText: root.statusLabel
                                    Component.onCompleted: text = targetText
                                    onTargetTextChanged: { if (text !== targetText) flipAnim.restart(); }
                                    SequentialAnimation {
                                        id: flipAnim
                                        ParallelAnimation {
                                            NumberAnimation { target: statusText; property: "opacity"; to: 0; duration: 75 }
                                            NumberAnimation { target: statusText; property: "y"; to: 8; duration: 75; easing.type: Easing.InQuad }
                                        }
                                        PropertyAction { target: statusText; property: "text"; value: statusText.targetText }
                                        ParallelAnimation {
                                            NumberAnimation { target: statusText; property: "opacity"; to: 0.8; duration: 75 }
                                            NumberAnimation { target: statusText; property: "y"; to: 0; duration: 75; easing.type: Easing.OutQuad }
                                        }
                                    }
                                }
                            }
                        }
                        DankIcon {
                            id: loadingSpinner
                            name: "cached"; size: 18; color: Theme.primary; opacity: root.loading ? 0.6 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            RotationAnimation on rotation { 
                                from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: root.loading 
                                onRunningChanged: { if (!running) loadingSpinner.rotation = 0; }
                            }
                        }
                    }
                }



                // --- Pinned Files Section ---
                StyledRect {
                    id: pinnedCont
                    width: parent.width
                    opacity: pinnedModel.count > 0 ? 1 : 0
                    height: Math.max(0, pinnedModel.count > 0 ? (pinnedContentCol.implicitHeight + Theme.spacingM * 2) : 0)
                    visible: opacity > 0; clip: false
                    radius: Theme.cornerRadius; color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    
                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Column {
                        id: pinnedContentCol
                        anchors.fill: parent; anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Loader {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: Theme.spacingXS; anchors.rightMargin: Theme.spacingXS
                            width: Math.max(0, parent.width - Theme.spacingXS * 2)
                            asynchronous: true
                            property string sectionIcon: "push_pin"
                            property string sectionTitle: "Pinned Files"
                            sourceComponent: sectionHeaderComponent
                        }

                        GridView {
                            id: pinnedGv; width: Math.max(0, parent.width + Theme.spacingXS); height: Math.max(0, (Math.ceil(pinnedModel.count / 2) * cellHeight) - Theme.spacingXS)
                            Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            cellWidth: width / 2; cellHeight: 54; interactive: false
                            model: pinnedModel
                            populate: Transition { 
                                ParallelAnimation {
                                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                                    NumberAnimation { property: "scale"; from: 0.8; to: 1; duration: 150; easing.type: Easing.OutBack }
                                    NumberAnimation { property: "y"; from: -15; duration: 150; easing.type: Easing.OutBack }
                                }
                            }
                            add: Transition { 
                                ParallelAnimation {
                                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150 }
                                    NumberAnimation { property: "scale"; from: 0.8; to: 1; duration: 150; easing.type: Easing.OutBack }
                                    NumberAnimation { property: "y"; from: -15; duration: 150; easing.type: Easing.OutBack }
                                }
                            }
                            remove: Transition { 
                                ParallelAnimation {
                                    NumberAnimation { property: "opacity"; to: 0; duration: 150 }
                                    NumberAnimation { property: "scale"; to: 0.8; duration: 150; easing.type: Easing.InBack }
                                    NumberAnimation { property: "y"; to: -15; duration: 150; easing.type: Easing.InCubic }
                                }
                            }
                            displaced: Transition { NumberAnimation { properties: "x,y"; duration: 150; easing.type: Easing.OutBack } }

                            delegate: Item {
                                id: pinDelegate
                                property bool isFullWidth: (index === pinnedModel.count - 1 || index >= pinnedModel.count) && index % 2 === 0
                                width: Math.max(0, isFullWidth ? pinnedGv.width - Theme.spacingXS : pinnedGv.cellWidth - Theme.spacingXS)
                                height: 50
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                property string filePath: model.path
                                property bool hovered: maPin.containsMouse || pinBtnMaGrid.containsMouse
                                property bool isDragging: false

                                opacity: isDragging ? 0.45 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                MouseArea {
                                    id: maPin; anchors.fill: parent; hoverEnabled: true
                                    property real pressX: 0; property real pressY: 0
                                    property bool dragLaunched: false
                                    onPressed: (m) => { pressX = m.x; pressY = m.y; dragLaunched = false; pRipG.trigger(m.x, m.y) }
                                    onPositionChanged: (m) => {
                                        if (!dragLaunched && pressed) {
                                            let dx = m.x - pressX; let dy = m.y - pressY;
                                            if (Math.sqrt(dx*dx + dy*dy) > 12) {
                                                dragLaunched = true;
                                                pinDelegate.isDragging = true;
                                                root.startSystemDrag(filePath);
                                                root.closePopout();
                                            }
                                        }
                                    }
                                    onReleased: { pinDelegate.isDragging = false; dragLaunched = false; }
                                    onClicked: { if (!dragLaunched) root.openFile(filePath); }
                                }
                                Shape {
                                    id: pinBg
                                    anchors.fill: parent

                                    property real innerRadius: 6
                                    property real outerRadius: 12
                                    property bool isFirstRow: index < 2
                                    property bool isLastRow: index >= (pinnedModel.count - 1) - ((pinnedModel.count - 1) % 2)
                                    property bool isLeftCol: index % 2 === 0
                                    property bool isRightCol: index % 2 === 1 || (index === pinnedModel.count - 1 && index % 2 === 0)
                                    
                                    property real tlr: hovered ? (height / 2) : ((isFirstRow && isLeftCol) ? outerRadius : innerRadius)
                                    property real trr: hovered ? (height / 2) : ((isFirstRow && isRightCol) ? outerRadius : innerRadius)
                                    property real blr: hovered ? (height / 2) : ((isLastRow && isLeftCol) ? outerRadius : innerRadius)
                                    property real brr: hovered ? (height / 2) : ((isLastRow && isRightCol) ? outerRadius : innerRadius)

                                    property real tlrAnim: tlr; Behavior on tlrAnim { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                                    property real trrAnim: trr; Behavior on trrAnim { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                                    property real blrAnim: blr; Behavior on blrAnim { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                                    property real brrAnim: brr; Behavior on brrAnim { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }

                                    property color paintColor: hovered
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                            : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                                    
                                    property color paintBorder: hovered
                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                            : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)

                                    ShapePath {
                                        fillColor: pinBg.paintColor
                                        strokeColor: pinBg.paintBorder
                                        strokeWidth: 1
                                        
                                        startX: pinBg.tlrAnim; startY: 0
                                        PathLine { x: pinBg.width - pinBg.trrAnim; y: 0 }
                                        PathArc { x: pinBg.width; y: pinBg.trrAnim; radiusX: pinBg.trrAnim; radiusY: pinBg.trrAnim; direction: PathArc.Clockwise }
                                        PathLine { x: pinBg.width; y: pinBg.height - pinBg.brrAnim }
                                        PathArc { x: pinBg.width - pinBg.brrAnim; y: pinBg.height; radiusX: pinBg.brrAnim; radiusY: pinBg.brrAnim; direction: PathArc.Clockwise }
                                        PathLine { x: pinBg.blrAnim; y: pinBg.height }
                                        PathArc { x: 0; y: pinBg.height - pinBg.blrAnim; radiusX: pinBg.blrAnim; radiusY: pinBg.blrAnim; direction: PathArc.Clockwise }
                                        PathLine { x: 0; y: pinBg.tlrAnim }
                                        PathArc { x: pinBg.tlrAnim; y: 0; radiusX: pinBg.tlrAnim; radiusY: pinBg.tlrAnim; direction: PathArc.Clockwise }
                                    }
                                }
                                DankRipple { id: pRipG; anchors.fill: parent; cornerRadius: pinBg.tlrAnim; rippleColor: Theme.primary }
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: Theme.spacingS; anchors.rightMargin: Theme.spacingXS; spacing: Theme.spacingM
                                    Item {
                                        id: pinThumb; width: 28; height: 28
                                        Layout.alignment: Qt.AlignVCenter
                                        
                                        Rectangle { anchors.fill: parent; color: Theme.surfaceContainer; radius: height / 2 }
                                        
                                        Image {
                                            id: pinImgSrc
                                            visible: false
                                            anchors.fill: parent
                                            source: root.isImage(filePath) ? "file://" + filePath : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                        }
                                        
                                        Rectangle { id: pinMask; anchors.fill: parent; radius: height / 2; visible: false; layer.enabled: true }
                                        
                                        MultiEffect {
                                            anchors.fill: parent
                                            source: pinImgSrc
                                            maskEnabled: true
                                            maskSource: pinMask
                                            visible: root.isImage(filePath)
                                        }
                                        
                                        DankIcon { visible: !root.isImage(filePath); anchors.centerIn: parent; name: root.getIcon(filePath); size: 12; color: hovered ? Theme.primary : Theme.surfaceVariantText; Behavior on color { ColorAnimation { duration: 150 } } }
                                    }
                                    StyledText {
                                             Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                             text: filePath.split('/').pop(); font.pixelSize: Theme.fontSizeSmall - 1
                                             color: hovered ? Theme.surfaceText : Theme.surfaceVariantText
                                             elide: Text.ElideRight; wrapMode: Text.NoWrap; maximumLineCount: 1
                                             Behavior on color { ColorAnimation { duration: 150 } }
                                         }
                                         Item {
                                             width: 32; height: 32; Layout.alignment: Qt.AlignVCenter
                                             Rectangle {
                                                 id: pinBtnBg
                                                 anchors.centerIn: parent
                                                 width: 28; height: 28; radius: Theme.cornerRadius
                                                 color: pinBtnMaGrid.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04)
                                                 border.color: pinBtnMaGrid.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15)
                                                 border.width: pinBtnMaGrid.containsMouse ? 1 : 0
                                                 opacity: pinBtnMaGrid.containsMouse ? 1 : 0
                                                 scale: pinBtnMaGrid.pressed ? 0.9 : (pinBtnMaGrid.containsMouse ? 1.05 : 1.0)
                                                 Behavior on color { ColorAnimation { duration: 150 } }
                                                 Behavior on opacity { NumberAnimation { duration: 150 } }
                                                 Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                             }
                                             Item {
                                                 anchors.centerIn: parent
                                                 width: 14; height: 14
                                                 
                                                 DankIcon {
                                                     id: pushPinDot
                                                     anchors.centerIn: parent; name: "circle"
                                                     size: 14; color: Theme.withAlpha(Theme.surfaceVariantText, 0.5)
                                                     scale: (root.isPinned(filePath) && !pinBtnMaGrid.containsMouse) ? 0.4 : 0.0
                                                     opacity: scale > 0 ? 1 : 0
                                                     Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                                     Behavior on opacity { NumberAnimation { duration: 150 } }
                                                 }

                                                 DankIcon {
                                                     id: pushPinIcon
                                                     anchors.centerIn: parent; name: "push_pin"
                                                     size: 14; color: pinBtnMaGrid.containsMouse ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceVariantText, 0.7)
                                                     scale: (pinBtnMaGrid.containsMouse || (hovered && !root.isPinned(filePath))) ? (pinBtnMaGrid.pressed ? 0.8 : 1.0) : 0.0
                                                     rotation: (root.isPinned(filePath) || pinBtnMaGrid.containsMouse) ? 0 : 45
                                                     opacity: scale > 0 ? 1 : 0
                                                     Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                                     Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                                     Behavior on opacity { NumberAnimation { duration: 150 } }
                                                 }
                                             }
                                             DankRipple { id: pinBtnRip; anchors.fill: pinBtnBg; cornerRadius: Theme.cornerRadius; rippleColor: Theme.primary }
                                             MouseArea { 
                                                 id: pinBtnMaGrid; anchors.fill: parent; hoverEnabled: true; 
                                                 onPressed: (m) => pinBtnRip.trigger(m.x, m.y)
                                                 onClicked: root.togglePin(filePath) 
                                             }
                                         }
                                }
                            }
                        }
                    }
                }

                // --- Screen Captures Section ---
                StyledRect {
                    id: ssCont
                    width: parent.width
                    opacity: root.recentScreenshots.length > 0 ? 1 : 0
                    height: Math.max(0, root.recentScreenshots.length > 0 ? (ssContentCol.implicitHeight + Theme.spacingM * 2) : 0)
                    visible: opacity > 0; clip: true
                    radius: Theme.cornerRadius; color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    
                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Column {
                        id: ssContentCol
                        width: Math.max(0, parent.width - Theme.spacingM * 2)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        Loader {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: Theme.spacingXS; anchors.rightMargin: Theme.spacingXS
                            width: Math.max(0, parent.width - Theme.spacingXS * 2)
                            asynchronous: true
                            property string sectionIcon: "screenshot_region"
                            property string sectionTitle: "Screen Captures"
                            sourceComponent: sectionHeaderComponent
                        }

                        Flow {
                            id: ssGrid; width: parent.width
                            spacing: Theme.spacingXS
                            property int columns: root.ssCols

                            property int itemWidth: Math.max(0, width - (columns > 1 ? (columns - 1) * spacing : 0)) / Math.max(1, columns)
                            property int itemHeight: root.recentScreenshots.length <= 2 ? Math.min(160, itemWidth * 0.625) : 72

                            Repeater {
                                model: root.recentScreenshots
                                Item {
                                    id: ssDelegate
                                    property bool isOddLayout: root.recentScreenshots.length % 2 === 1 && root.recentScreenshots.length > 1
                                    property bool isSpan2: isOddLayout && index === 0
                                    
                                    width: isSpan2 ? (ssGrid.itemWidth * 2 + ssGrid.spacing) : ssGrid.itemWidth
                                    height: ssGrid.itemHeight
                                    property bool isDragging: false
                                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                    property bool hovered: maSS.containsMouse || ssPinMa.containsMouse

                                    // Dynamic Corner Logic
                                    property real innerRadius: 6
                                    property real outerRadius: 12
                                    
                                    property int virtualIndex: isOddLayout ? (index === 0 ? 0 : index + 1) : index
                                    
                                    property bool isFirstRow: virtualIndex < Math.max(1, ssGrid.columns)
                                    property bool isLastRow: {
                                        let totalVirtual = isOddLayout ? root.recentScreenshots.length + 1 : root.recentScreenshots.length;
                                        let cols = Math.max(1, ssGrid.columns);
                                        return virtualIndex >= (Math.floor((totalVirtual - 1) / cols) * cols);
                                    }
                                    property bool isLeftCol: virtualIndex % Math.max(1, ssGrid.columns) === 0
                                    property bool isRightCol: {
                                        let cols = Math.max(1, ssGrid.columns);
                                        let endVirtual = isSpan2 ? 1 : virtualIndex;
                                        let totalVirtual = isOddLayout ? root.recentScreenshots.length + 1 : root.recentScreenshots.length;
                                        return (endVirtual % cols) === (cols - 1) || virtualIndex === (totalVirtual - 1);
                                    }

                                    property real tlr: (hovered || root.isPinned(modelData.path)) ? (height / 2) : ((isFirstRow && isLeftCol) ? outerRadius : innerRadius)
                                    property real trr: (hovered || root.isPinned(modelData.path)) ? (height / 2) : ((isFirstRow && isRightCol) ? outerRadius : innerRadius)
                                    property real blr: (hovered || root.isPinned(modelData.path)) ? (height / 2) : ((isLastRow && isLeftCol) ? outerRadius : innerRadius)
                                    property real brr: (hovered || root.isPinned(modelData.path)) ? (height / 2) : ((isLastRow && isRightCol) ? outerRadius : innerRadius)
                                    
                                    property real tlrAnim: tlr; Behavior on tlrAnim { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                                    property real trrAnim: trr; Behavior on trrAnim { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                                    property real blrAnim: blr; Behavior on blrAnim { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                                    property real brrAnim: brr; Behavior on brrAnim { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }

                                    opacity: isDragging ? 0.45 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    MouseArea {
                                        id: maSS; anchors.fill: parent; hoverEnabled: true
                                        property real pressX: 0; property real pressY: 0
                                        property bool dragLaunched: false
                                        onPressed: (m) => { pressX = m.x; pressY = m.y; dragLaunched = false; ssRip.trigger(m.x, m.y) }
                                        onPositionChanged: (m) => {
                                            if (!dragLaunched && pressed) {
                                                let dx = m.x - pressX; let dy = m.y - pressY;
                                                if (Math.sqrt(dx*dx + dy*dy) > 12) {
                                                    dragLaunched = true;
                                                    ssDelegate.isDragging = true;
                                                    root.startSystemDrag(modelData.path);
                                                    root.closePopout();
                                                }
                                            }
                                        }
                                        onReleased: { ssDelegate.isDragging = false; dragLaunched = false; }
                                        onClicked: { if (!dragLaunched) root.openFile(modelData.path); }
                                    }

                                    // Mask for the Image
                                    Shape {
                                        id: ssMask
                                        anchors.fill: parent
                                        visible: false
                                        layer.enabled: true
                                        ShapePath {
                                            fillColor: "black"
                                            strokeColor: "transparent"
                                            
                                            startX: ssDelegate.tlrAnim; startY: 0
                                            PathLine { x: width - ssDelegate.trrAnim; y: 0 }
                                            PathArc { x: width; y: ssDelegate.trrAnim; radiusX: ssDelegate.trrAnim; radiusY: ssDelegate.trrAnim; direction: PathArc.Clockwise }
                                            PathLine { x: width; y: height - ssDelegate.brrAnim }
                                            PathArc { x: width - ssDelegate.brrAnim; y: height; radiusX: ssDelegate.brrAnim; radiusY: ssDelegate.brrAnim; direction: PathArc.Clockwise }
                                            PathLine { x: ssDelegate.blrAnim; y: height }
                                            PathArc { x: 0; y: height - ssDelegate.blrAnim; radiusX: ssDelegate.blrAnim; radiusY: ssDelegate.blrAnim; direction: PathArc.Clockwise }
                                            PathLine { x: 0; y: ssDelegate.tlrAnim }
                                            PathArc { x: ssDelegate.tlrAnim; y: 0; radiusX: ssDelegate.tlrAnim; radiusY: ssDelegate.tlrAnim; direction: PathArc.Clockwise }
                                        }
                                    }

                                    Item {
                                        id: thumbCont; anchors.fill: parent
                                        
                                        Item {
                                            id: thumbSrc
                                            anchors.fill: parent
                                            visible: false
                                            Rectangle { anchors.fill: parent; color: Theme.surfaceContainer }
                                            Image { anchors.fill: parent; source: "file://" + modelData.path; fillMode: Image.PreserveAspectCrop; asynchronous: true; mipmap: true }
                                            Rectangle { anchors.fill: parent; color: Theme.primary; opacity: root.isPinned(modelData.path) ? 0.18 : (maSS.containsMouse ? 0.1 : 0); Behavior on opacity { NumberAnimation { duration: 150 } } }
                                        }
                                        
                                        MultiEffect {
                                            anchors.fill: parent
                                            source: thumbSrc
                                            maskEnabled: true
                                            maskSource: ssMask
                                        }
                                    }
                                    
                                    // Border and Shadow
                                    Shape {
                                        id: ssBorder
                                        anchors.fill: parent
                                        property color borderColor: root.isPinned(modelData.path) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6) : (maSS.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15))
                                        
                                        ShapePath {
                                            fillColor: "transparent"
                                            strokeColor: ssBorder.borderColor
                                            strokeWidth: 1

                                            startX: ssDelegate.tlrAnim; startY: 0
                                            PathLine { x: width - ssDelegate.trrAnim; y: 0 }
                                            PathArc { x: width; y: ssDelegate.trrAnim; radiusX: ssDelegate.trrAnim; radiusY: ssDelegate.trrAnim; direction: PathArc.Clockwise }
                                            PathLine { x: width; y: height - ssDelegate.brrAnim }
                                            PathArc { x: width - ssDelegate.brrAnim; y: height; radiusX: ssDelegate.brrAnim; radiusY: ssDelegate.brrAnim; direction: PathArc.Clockwise }
                                            PathLine { x: ssDelegate.blrAnim; y: height }
                                            PathArc { x: 0; y: height - ssDelegate.blrAnim; radiusX: ssDelegate.blrAnim; radiusY: ssDelegate.blrAnim; direction: PathArc.Clockwise }
                                            PathLine { x: 0; y: ssDelegate.tlrAnim }
                                            PathArc { x: ssDelegate.tlrAnim; y: 0; radiusX: ssDelegate.tlrAnim; radiusY: ssDelegate.tlrAnim; direction: PathArc.Clockwise }
                                        }
                                    }

                                    DankRipple { id: ssRip; anchors.fill: parent; cornerRadius: ssDelegate.tlrAnim; rippleColor: Theme.primary }

                                    Item {
                                        width: 32; height: 32; anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: -6; anchors.rightMargin: -6
                                        scale: ssPinMa.pressed ? 0.9 : ((ssDelegate.hovered || root.isPinned(modelData.path)) ? 1.05 : 0.0)
                                        Behavior on scale { 
                                            SequentialAnimation {
                                                PauseAnimation { duration: 150 }
                                                NumberAnimation { duration: 150; easing.type: Easing.OutBack } 
                                            }
                                        }
                                        Rectangle { 
                                            id: ssPinBg
                                            anchors.centerIn: parent; width: 24; height: 24; radius: Theme.cornerRadius
                                            color: root.isPinned(modelData.path) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : (ssPinMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04))
                                            border.color: root.isPinned(modelData.path) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6) : (ssPinMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15))
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                        Item {
                                            anchors.centerIn: parent; width: 14; height: 14
                                            
                                            // Dot (Idle Pinned State)
                                            DankIcon {
                                                id: ssDotIcon
                                                anchors.centerIn: parent; name: "circle"
                                                size: 14; color: Theme.surfaceText
                                                opacity: (root.isPinned(modelData.path) && !ssPinMa.containsMouse) ? 1.0 : 0.0
                                                scale: opacity ? 0.6 : 0.0
                                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                            }

                                            // Pin (Hover or Pin Action)
                                            DankIcon { 
                                                id: ssPushIcon
                                                name: "push_pin"; size: 14; anchors.centerIn: parent
                                                color: root.isPinned(modelData.path) ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.8)
                                                opacity: (ssPinMa.containsMouse || !root.isPinned(modelData.path)) ? 1.0 : 0.0
                                                scale: opacity ? (ssPinMa.pressed ? 0.8 : 1.0) : 0.0
                                                rotation: (root.isPinned(modelData.path) || ssPinMa.containsMouse) ? 0 : 45
                                                
                                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                                Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutBack } } 
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }
                                        DankRipple { id: ssPinRip; anchors.fill: ssPinBg; cornerRadius: Theme.cornerRadius; rippleColor: Theme.primary }
                                        MouseArea { 
                                            id: ssPinMa; anchors.fill: parent; hoverEnabled: true; 
                                            onPressed: (m) => ssPinRip.trigger(m.x, m.y)
                                            onClicked: root.togglePin(modelData.path) 
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // --- Recent Downloads Section ---
                StyledRect {
                    id: dlCont
                    width: parent.width
                    opacity: root.recentDownloads.length > 0 ? 1 : 0
                    height: Math.max(0, root.recentDownloads.length > 0 ? (dlContentCol.implicitHeight + Theme.spacingM * 2) : 0)
                    visible: opacity > 0; clip: true
                    radius: Theme.cornerRadius; color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    
                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Column {
                        id: dlContentCol
                        width: Math.max(0, parent.width - Theme.spacingM * 2)
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        Loader {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: Theme.spacingXS; anchors.rightMargin: Theme.spacingXS
                            width: Math.max(0, parent.width - Theme.spacingXS * 2)
                            asynchronous: true
                            property string sectionIcon: "schedule"
                            property string sectionTitle: "Recent Downloads"
                            sourceComponent: sectionHeaderComponent
                        }

                        Column {
                            id: dlContainer; width: parent.width; spacing: Theme.spacingXS
                            Repeater {
                                model: root.recentDownloads
                                delegate: Item {
                                    id: dlDelegate; width: dlContainer.width; height: 42
                                    property bool hovered: maDL.containsMouse || dlPinMa.containsMouse
                                    property bool isDragging: false

                                    opacity: isDragging ? 0.45 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    MouseArea {
                                        id: maDL; anchors.fill: parent; hoverEnabled: true
                                        property real pressX: 0; property real pressY: 0
                                        property bool dragLaunched: false
                                        onPressed: (m) => { pressX = m.x; pressY = m.y; dragLaunched = false; dlRip.trigger(m.x, m.y) }
                                        onPositionChanged: (m) => {
                                            if (!dragLaunched && pressed) {
                                                let dx = m.x - pressX; let dy = m.y - pressY;
                                                if (Math.sqrt(dx*dx + dy*dy) > 12) {
                                                    dragLaunched = true;
                                                    dlDelegate.isDragging = true;
                                                    root.startSystemDrag(modelData.path);
                                                    root.closePopout();
                                                }
                                            }
                                        }
                                        onReleased: { dlDelegate.isDragging = false; dragLaunched = false; }
                                        onClicked: { if (!dragLaunched) root.openFile(modelData.path); }
                                    }
                                    Shape {
                                        id: dlBg
                                        anchors.fill: parent

                                        property real innerRadius: 6
                                        property real outerRadius: 12
                                        property bool isFirst: index === 0
                                        property bool isLast:  index === root.recentDownloads.length - 1
                                        
                                        property real tlr: (hovered || root.isPinned(modelData.path)) ? (height / 2) : (isFirst ? outerRadius : innerRadius)
                                        property real trr: (hovered || root.isPinned(modelData.path)) ? (height / 2) : (isFirst ? outerRadius : innerRadius)
                                        property real blr: (hovered || root.isPinned(modelData.path)) ? (height / 2) : (isLast ? outerRadius : innerRadius)
                                        property real brr: (hovered || root.isPinned(modelData.path)) ? (height / 2) : (isLast ? outerRadius : innerRadius)

                                        property real tlrAnim: tlr; Behavior on tlrAnim { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                                        property real trrAnim: trr; Behavior on trrAnim { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                                        property real blrAnim: blr; Behavior on blrAnim { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                                        property real brrAnim: brr; Behavior on brrAnim { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }

                                        property color paintColor: root.isPinned(modelData.path) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : (hovered
                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
                                                : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04))
                                        
                                        property color paintBorder: root.isPinned(modelData.path) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6) : (hovered
                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                                : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15))

                                        ShapePath {
                                            fillColor: dlBg.paintColor
                                            strokeColor: dlBg.paintBorder
                                            strokeWidth: 1
                                            
                                            startX: dlBg.tlrAnim; startY: 0
                                            PathLine { x: dlBg.width - dlBg.trrAnim; y: 0 }
                                            PathArc { x: dlBg.width; y: dlBg.trrAnim; radiusX: dlBg.trrAnim; radiusY: dlBg.trrAnim; direction: PathArc.Clockwise }
                                            PathLine { x: dlBg.width; y: dlBg.height - dlBg.brrAnim }
                                            PathArc { x: dlBg.width - dlBg.brrAnim; y: dlBg.height; radiusX: dlBg.brrAnim; radiusY: dlBg.brrAnim; direction: PathArc.Clockwise }
                                            PathLine { x: dlBg.blrAnim; y: dlBg.height }
                                            PathArc { x: 0; y: dlBg.height - dlBg.blrAnim; radiusX: dlBg.blrAnim; radiusY: dlBg.blrAnim; direction: PathArc.Clockwise }
                                            PathLine { x: 0; y: dlBg.tlrAnim }
                                            PathArc { x: dlBg.tlrAnim; y: 0; radiusX: dlBg.tlrAnim; radiusY: dlBg.tlrAnim; direction: PathArc.Clockwise }
                                        }


                                    }
                                    DankRipple { id: dlRip; anchors.fill: parent; cornerRadius: dlBg.tlrAnim; rippleColor: Theme.primary }
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: Theme.spacingS; anchors.rightMargin: Theme.spacingXS; spacing: Theme.spacingM
                                        Item {
                                            id: dlThumb; width: 26; height: 26
                                            Layout.alignment: Qt.AlignVCenter
                                            
                                            Rectangle { anchors.fill: parent; color: Theme.surfaceContainer; radius: height / 2 }
                                            
                                            Image {
                                                id: dlImgSrc
                                                visible: false
                                                anchors.fill: parent
                                                source: root.isImage(modelData.path) ? "file://" + modelData.path : ""
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                            }
                                            
                                            Rectangle { id: dlMask; anchors.fill: parent; radius: height / 2; visible: false; layer.enabled: true }
                                            
                                            MultiEffect {
                                                anchors.fill: parent
                                                source: dlImgSrc
                                                maskEnabled: true
                                                maskSource: dlMask
                                                visible: root.isImage(modelData.path)
                                            }
                                            
                                            DankIcon { visible: !root.isImage(modelData.path); anchors.centerIn: parent; name: root.getIcon(modelData.path); size: 12; color: hovered ? Theme.primary : Theme.surfaceVariantText; Behavior on color { ColorAnimation { duration: 150 } } }
                                        }
                                        Column {
                                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                            StyledText { 
                                             width: parent.width; text: modelData.name; font.pixelSize: Theme.fontSizeSmall - 1
                                             color: hovered ? Theme.surfaceText : Theme.surfaceVariantText
                                             elide: Text.ElideRight; wrapMode: Text.NoWrap; maximumLineCount: 1
                                             Behavior on color { ColorAnimation { duration: 150 } }
                                         }
                                        }
                                         Item {
                                             width: 32; height: 32; Layout.alignment: Qt.AlignVCenter
                                             Rectangle {
                                                 id: dlPinBtnBg
                                                 anchors.centerIn: parent
                                                 width: 28; height: 28; radius: Theme.cornerRadius
                                                 color: root.isPinned(modelData.path) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : (dlPinMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.04))
                                                 border.color: root.isPinned(modelData.path) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6) : (dlPinMa.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4) : Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.15))
                                                 border.width: (root.isPinned(modelData.path) || dlPinMa.containsMouse) ? 1 : 0
                                                 opacity: (root.isPinned(modelData.path) || dlPinMa.containsMouse) ? 1 : 0
                                                 scale: dlPinMa.pressed ? 0.9 : (dlPinMa.containsMouse ? 1.05 : 1.0)
                                                 Behavior on color { ColorAnimation { duration: 150 } }
                                                 Behavior on opacity { NumberAnimation { duration: 150 } }
                                                 Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                             }
                                             Item {
                                                 anchors.centerIn: parent
                                                 width: 14; height: 14

                                                 DankIcon {
                                                     id: dlPushPinDot
                                                     anchors.centerIn: parent; name: "circle"
                                                     size: 14; color: Theme.withAlpha(Theme.surfaceVariantText, 0.5)
                                                     scale: (root.isPinned(modelData.path) && !dlPinMa.containsMouse) ? 0.4 : 0.0
                                                     opacity: scale > 0 ? 1 : 0
                                                     Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                                     Behavior on opacity { NumberAnimation { duration: 150 } }
                                                 }

                                                 DankIcon {
                                                     id: dlPushPinIcon
                                                     anchors.centerIn: parent; name: "push_pin"
                                                     size: 14; color: dlPinMa.containsMouse ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceVariantText, 0.7)
                                                     rotation: (root.isPinned(modelData.path) || dlPinMa.containsMouse) ? 0 : 45
                                                     scale: (dlPinMa.containsMouse || (hovered && !root.isPinned(modelData.path))) ? (dlPinMa.pressed ? 0.8 : 1.0) : 0.0
                                                     opacity: scale > 0 ? 1 : 0
                                                     Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                                     Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                                     Behavior on opacity { NumberAnimation { duration: 150 } }
                                                 }
                                             }
                                             DankRipple { id: dlPinRip; anchors.fill: dlPinBtnBg; cornerRadius: Theme.cornerRadius; rippleColor: Theme.primary }
                                             MouseArea { 
                                                 id: dlPinMa; anchors.fill: parent; hoverEnabled: true; 
                                                 onPressed: (m) => dlPinRip.trigger(m.x, m.y)
                                                 onClicked: root.togglePin(modelData.path) 
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
    }


}
