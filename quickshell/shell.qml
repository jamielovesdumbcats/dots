import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

PanelWindow {
    id: root

    // Theme
    property color colRosewater: "#f2d5cf"
    property color colFlamingo: "#eebebe"
    property color colPink: "#f4b8e4"
    property color colMauve: "#ca9ee6"
    property color colRed: "#e78284"
    property color colMaroon: "#ea999c"
    property color colPeach: "#ef9f76"
    property color colYellow: "#e5c890"
    property color colGreen: "#a6d189"
    property color colTeal: "#81c8be"
    property color colSky: "#99d1db"
    property color colSapphire: "#85c1dc"
    property color colBlue: "#8caaee"
    property color colLavender: "#babbf1"
    property color colText: "#c6d0f5"
    property color colSubtext1: "#b5bfe2"
    property color colSubtext0: "#a5adce"
    property color colOverlay2: "#949cbb"
    property color colOverlay1: "#838ba7"
    property color colOverlay0: "#737994"
    property color colSurface2: "#626880"
    property color colSurface1: "#51576d"
    property color colSurface0: "#414559"
    property color colBase: "#303446"
    property color colMantle: "#292c3c"
    property color colCrust: "#232634"
    property string fontFamily: "3270 Nerd Font"
    property int fontSize: 14

    // System data
    property int cpuUsage: 0
    property int memUsage: 0
    property int roundedBattery: Math.round(UPower.displayDevice.percentage * 100)
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0

    // Processes and timers here...
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var p = data.trim().split(/\s+/)
                var idle = parseInt(p[4]) + parseInt(p[5])
                var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0)
                if (lastCpuTotal > 0) {
                    cpuUsage = Math.round(100 * (1 - (idle - lastCpuIdle) / (total - lastCpuTotal)))
                }
                lastCpuTotal = total
                lastCpuIdle = idle
            }
        }
        Component.onCompleted: running = true
    }


    Process {
        id: memProc
        command: ["sh", "-c", "free -g"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var p = data.trim().split(/\s+/)
                if (p[0] === 'Mem:'){
                    var total = p[1];
                    var used = p[6];
                    memUsage = parseInt(100 - (used / total) * 100)
                }
            }
        }
        Component.onCompleted: running = true
    }

    Timer {
        interval: 2000        // Every 2 seconds
        running: true         // Start immediately
        repeat: true          // Keep going forever
        onTriggered: cpuProc.running = true
    }

    Timer {
        interval: 2000        // Every 2 seconds
        running: true         // Start immediately
        repeat: true          // Keep going forever
        onTriggered: memProc.running = true
    }

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 24
    color: root.colBase

    RowLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8


        Item { Layout.fillWidth: true }

        // CPU
        Text {
            text: "CPU: " + cpuUsage + "%"
            color: root.colLavender
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
        }

        Rectangle { width: 1; height: 16; color: root.colCrust }

        // Memory
        Text {
            text: "Mem: " + memUsage + "%"
            color: root.colRosewater
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
        }

        Rectangle { width: 1; height: 16; color: root.colCrust }

        Text {
            text: "Battery: " + roundedBattery + "%"
            color: root.colRosewater
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
        }

        // Clock
        Text {
            id: clock
            color: root.colMauve
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
            text: Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
            }
        }
    }
}