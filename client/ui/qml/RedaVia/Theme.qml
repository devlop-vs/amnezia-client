pragma Singleton
import QtQuick 2.15

QtObject {
    readonly property color background: "#071224"
    readonly property color cardBackground: "#111e35"
    readonly property color cardBackgroundAlt: "#17243e"
    readonly property color borderColor: "#293a55"
    readonly property color primaryGreen: "#35e76f"
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#94a3b8"
    readonly property color textMuted: "#cbd5e1"
    readonly property color textPlaceholder: "#64748b"
    readonly property color textSubtle: "#7f8ba2"
    readonly property color textLabel: "#dce4f2"
    readonly property color textBody: "#b3bed2"
    readonly property color accentYellow: "#ffd21e"
    readonly property color accentBlue: "#2f6bff"
    readonly property color accentBlueDark: "#1a4eb5"
    readonly property color dangerRed: "#ff5353"
    readonly property color connectedGlow: "#163e2a"
    readonly property color connectedInner: "#175934"
    readonly property color planetBlue: "#1e4eea"
    readonly property color planetHighlight: "#2140a4"
    readonly property color chartLine: "#26364f"

    readonly property int screenWidth: 393
    readonly property int screenHeight: 852
    readonly property int screenRadius: 28
    readonly property int cardRadius: 22
    readonly property int buttonRadius: 18
    readonly property int inputRadius: 16
    readonly property int smallRadius: 13
    readonly property int pillRadius: 18
    readonly property int tabBarY: 800

    readonly property string fontFamily: "Inter"
}
