import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property int panelWidth: 380
    property int maxPanelHeight: (panelRoot.screen?.height ?? 1080) - Appearance.sizes.hyprlandGapsOut * 4 - Appearance.sizes.baseBarHeight - 40

    PanelWindow {
        id: panelRoot
        visible: GlobalStates.controlPanelOpen

        function hide() {
            GlobalStates.controlPanelOpen = false
        }

        exclusiveZone: 0
        implicitWidth: screen?.width ?? 1920
        implicitHeight: screen?.height ?? 1080
        WlrLayershell.namespace: "quickshell:controlPanel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        color: "transparent"

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        CompositorFocusGrab {
            id: grab
            windows: [ panelRoot ]
            active: CompositorService.isHyprland && panelRoot.visible
            onCleared: () => {
                if (!active) panelRoot.hide()
            }
        }

        // Backdrop click to close
        MouseArea {
            id: backdropClickArea
            anchors.fill: parent
            onClicked: mouse => {
                const localPos = mapToItem(contentLoader, mouse.x, mouse.y)
                if (localPos.x < 0 || localPos.x > contentLoader.width
                        || localPos.y < 0 || localPos.y > contentLoader.height) {
                    panelRoot.hide()
                }
            }
        }

        Loader {
            id: contentLoader
            active: GlobalStates.controlPanelOpen || (Config?.options?.controlPanel?.keepLoaded ?? false)
            
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
                verticalCenterOffset: Config.options?.bar?.bottom ? -Appearance.sizes.baseBarHeight / 2 : Appearance.sizes.baseBarHeight / 2
            }
            
            width: root.panelWidth
            height: item?.implicitHeight ? Math.min(item.implicitHeight, root.maxPanelHeight) : root.maxPanelHeight

            // Slide + fade animation
            transform: Translate {
                y: GlobalStates.controlPanelOpen ? 0 : -20
                Behavior on y {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }
            opacity: GlobalStates.controlPanelOpen ? 1 : 0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            focus: GlobalStates.controlPanelOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    panelRoot.hide()
                }
            }

            sourceComponent: ControlPanelContent {
                screenWidth: panelRoot.screen?.width ?? 1920
                screenHeight: panelRoot.screen?.height ?? 1080
            }
        }
    }

    IpcHandler {
        target: "controlPanel"

        function toggle(): void {
            GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen
        }

        function close(): void {
            GlobalStates.controlPanelOpen = false
        }

        function open(): void {
            GlobalStates.controlPanelOpen = true
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: GlobalShortcut {
            name: "controlPanelToggle"
            description: "Toggles control panel on press"

            onPressed: {
                GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen
            }
        }
    }
}
