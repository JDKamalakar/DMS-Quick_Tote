import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services
import Qt5Compat.GraphicalEffects

PluginComponent {
    id: root
    
    popoutWidth: 340
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

    onPluginDataChanged: {
        if (!pluginData) return;
        // Fallback for older DMS versions
        root.refresh();
    }

    onDownloadsPathChanged: refresh()
    onScreenshotsPathChanged: refresh()
    onMaxDownloadsChanged: refresh()
    onMaxScreenshotsChanged: refresh()

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
        command: ["bash", "-c", `d="${root.downloadsPath}"; d=\${d/#\\~/$HOME}; [ -d "$d" ] && find "$d" -maxdepth 1 -type f -not -path '*/.*' -printf '%T@|%p\\n' | sort -rn | head -n ${root.maxDownloads}`]
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
            
            Column {
                id: mainCol; width: parent.width; spacing: Theme.spacingM
                topPadding: 0; bottomPadding: Theme.spacingL

                // --- Header Card ---
                Item {
                    width: parent.width; height: 68
                    Rectangle {
                        anchors.fill: parent; radius: Theme.cornerRadius * 1.5
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) }
                            GradientStop { position: 1.0; color: Qt.rgba(Theme.secondary.r, Theme.secondary.g, Theme.secondary.b, 0.08) }
                        }
                        
                        layer.enabled: true
                        layer.effect: DropShadow {
                            transparentBorder: true
                            horizontalOffset: 0
                            verticalOffset: 3
                            radius: 12.0
                            samples: 24
                            color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
                        }
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
                            StyledText { 
                                text: root.statusLabel
                                font.pixelSize: Theme.fontSizeSmall - 1
                                color: Theme.primary
                                font.family: "Monospace"
                                opacity: 0.8
                            }
                        }
                        DankIcon {
                            name: "cached"; size: 18; color: Theme.primary; opacity: 0.6; visible: root.loading
                            RotationAnimation on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: parent.visible }
                        }
                    }
                }



                // --- Pinned Files Section ---
                StyledRect {
                    id: pinnedCont
                    width: parent.width
                    opacity: pinnedModel.count > 0 ? 1 : 0
                    height: pinnedModel.count > 0 ? (pinnedContentCol.implicitHeight + Theme.spacingM * 2) : 0
                    visible: opacity > 0; clip: true
                    radius: Theme.cornerRadius; color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 0; verticalOffset: 3
                        radius: 12.0; samples: 24
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
                    }

                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Column {
                        id: pinnedContentCol
                        anchors.fill: parent; anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: Theme.spacingXS; width: parent.width
                            DankIcon { name: "push_pin"; size: 14; color: Theme.secondary }
                            StyledText { text: "Pinned files"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
                        }

                        GridView {
                            id: pinnedGv; width: parent.width; height: (Math.ceil(pinnedModel.count / 2) * 52)
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
                                id: pinDelegate
                                width: pinnedGv.cellWidth; height: 50
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
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
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

                // --- Screen Captures Section ---
                StyledRect {
                    id: ssCont
                    width: parent.width
                    opacity: root.recentScreenshots.length > 0 ? 1 : 0
                    height: root.recentScreenshots.length > 0 ? (ssContentCol.implicitHeight + Theme.spacingM * 2) : 0
                    visible: opacity > 0; clip: true
                    radius: Theme.cornerRadius; color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 0; verticalOffset: 3
                        radius: 12.0; samples: 24
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
                    }

                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Column {
                        id: ssContentCol
                        width: parent.width - Theme.spacingM * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: Theme.spacingXS; width: parent.width
                            DankIcon { name: "screenshot_region"; size: 14; color: Theme.primary }
                            StyledText { text: "Screen captures"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
                        }

                        Grid {
                            id: ssGrid; width: parent.width
                            columns: root.ssCols
                            spacing: Theme.spacingS

                            property int itemWidth: (width - (columns > 1 ? (columns - 1) * spacing : 0)) / Math.max(1, columns)
                            property int itemHeight: root.recentScreenshots.length <= 2 ? Math.min(160, itemWidth * 0.625) : 72

                            Repeater {
                                model: root.recentScreenshots
                                Item {
                                    id: ssDelegate; width: ssGrid.itemWidth; height: ssGrid.itemHeight
                                    property bool isDragging: false
                                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    property bool hovered: maSS.containsMouse || ssPinMa.containsMouse

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
                                    Rectangle {
                                        id: thumbCont; anchors.fill: parent; radius: 12; color: Theme.surfaceContainer
                                        layer.enabled: true
                                        layer.effect: OpacityMask { maskSource: Rectangle { width: thumbCont.width; height: thumbCont.height; radius: 12 } }
                                        Image { anchors.fill: parent; source: "file://" + modelData.path; fillMode: Image.PreserveAspectCrop; asynchronous: true; mipmap: true }
                                        Rectangle { anchors.fill: parent; radius: 12; color: "black"; opacity: maSS.containsMouse ? 0.2 : 0; Behavior on opacity { NumberAnimation { duration: 150 } } }
                                        DankRipple { id: ssRip; anchors.fill: parent; cornerRadius: 12; rippleColor: Theme.primary }
                                    }
                                    Item {
                                        width: 32; height: 32; anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: -6; anchors.rightMargin: -6
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
                StyledRect {
                    id: dlCont
                    width: parent.width
                    opacity: root.recentDownloads.length > 0 ? 1 : 0
                    height: root.recentDownloads.length > 0 ? (dlContentCol.implicitHeight + Theme.spacingM * 2) : 0
                    visible: opacity > 0; clip: true
                    radius: Theme.cornerRadius; color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                    
                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 0; verticalOffset: 3
                        radius: 12.0; samples: 24
                        color: Theme.withAlpha(Theme.shadowColor || "#000000", 0.35)
                    }

                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Column {
                        id: dlContentCol
                        width: parent.width - Theme.spacingM * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 12; anchors.rightMargin: 12
                            spacing: Theme.spacingXS; width: parent.width
                            DankIcon { name: "download"; size: 14; color: Theme.primary }
                            StyledText { text: "Recent downloads"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
                        }

                        Column {
                            id: dlContainer; width: parent.width; spacing: 4
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
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Canvas {
                                            width: dlDelegate.width; height: dlDelegate.height
                                            onPaint: {
                                                var ctx = getContext("2d");
                                                ctx.clearRect(0, 0, width, height);
                                                let rTop = (index === 0) ? Theme.cornerRadius : 6;
                                                let rBot = (index === root.recentDownloads.length - 1) ? Theme.cornerRadius : 6;
                                                ctx.fillStyle = "black"; // Mask value
                                                ctx.beginPath();
                                                ctx.moveTo(rTop, 0); ctx.lineTo(width - rTop, 0); ctx.arcTo(width, 0, width, rTop, rTop);
                                                ctx.lineTo(width, height - rBot); ctx.arcTo(width, height, width - rBot, height, rBot);
                                                ctx.lineTo(rBot, height); ctx.arcTo(0, height, 0, height - rBot, rBot);
                                                ctx.lineTo(0, rTop); ctx.arcTo(0, 0, rTop, 0, rTop);
                                                ctx.closePath(); ctx.fill();
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: bgMain; anchors.fill: parent
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, hovered ? 0.15 : 0.08)
                                        border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, hovered ? 0.3 : 0.1)
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                        Rectangle { anchors.fill: parent; color: "white"; opacity: hovered ? 0.05 : 0; Behavior on opacity { NumberAnimation { duration: 150 } } }
                                    }
                                    DankRipple { id: dlRip; anchors.fill: parent; cornerRadius: 0; rippleColor: Theme.primary }
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: Theme.spacingS
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


}
