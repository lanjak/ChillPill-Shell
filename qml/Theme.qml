pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "./Config.qml"

Singleton {
    id: themeRoot

    // ---- active theme -------------------------------------------------------
    // user override set by Theme.applyTheme("name"); falls back to
    // Config.theme (config.jsonc) when empty. presets live at
    // ~/.cache/chillpill-shell/<theme>.json
    property string theme: ""                  // user override (current session)
    readonly property string configTheme: Config.theme
    property string activeTheme: theme !== "" ? theme : configTheme
    // presets live in their own subdir so cache jsons (events, usage stats...)
    // don't show up as theme cards
    property string cacheDir: Quickshell.env("HOME") + "/.cache/chillpill-shell"
    property string themeDir: cacheDir + "/themes"
    property string themeFile: activeTheme ? themeDir + "/" + activeTheme + ".json" : ""
    property var themePreset: {}
    property bool themeLoaded: false

    // available presets (scanned from the theme dir)
    property var themeNames: []

    // discover presets on startup and whenever the pill asks for them
    Process {
        id: themeScanProc
        command: ["sh", "-c",
            "ls -1 \"" + themeRoot.themeDir + "\"/*.json 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\\.json$//' || true"]
        running: false
        stdout: StdioCollector {
            // the whole listing arrives at once; a SplitParser would fire per
            // line and leave only the last name in the list
            onStreamFinished: {
                themeRoot.themeNames = this.text.trim().split("\n")
                    .map(n => n.trim())
                    .filter(n => n !== "")
            }
        }
    }

    function scanThemes() {
        if (themeDir !== "") themeScanProc.running = true
    }

    // persist the chosen theme to config.jsonc (survives restart)
    Process {
        id: themeSaveProc
        command: ["sh", "-c", ""]
        running: false
    }

    function applyTheme(name) {
        theme = name
        // installed layout first, source tree fallback for dev runs
        const localScript = Qt.resolvedUrl("../scripts/set_theme.py").toString().replace("file://", "")
        themeSaveProc.command = ["sh", "-c",
            "python3 /usr/share/chillpill-shell/scripts/set_theme.py " + JSON.stringify(name) + " 2>/dev/null" +
            " || python3 " + JSON.stringify(localScript) + " " + JSON.stringify(name) + " 2>/dev/null || true"]
        themeSaveProc.running = true
        themeLoadTimer.start()
    }

    Component.onCompleted: {
        scanThemes()
        themeLoadTimer.start()
    }

    FileView {
        id: themeFileView
        path: themeFile
        preload: true
        watchChanges: true
        onLoaded: themeRoot.applyPreset()
        onFileChanged: themeRoot.applyPreset()
        onLoadFailed: {
            // no preset file (default theme or typo'd name): fall back to defaults
            themeRoot.themePreset = {}
            themeRoot.themeLoaded = activeTheme !== ""
        }
    }

    // read the loaded preset file into the theme properties
    // (a plain FileView has no adapter, so data() is raw bytes: parse the text)
    function applyPreset() {
        if (activeTheme === "") {
            themePreset = {}
            themeLoaded = false
            return
        }
        try {
            themePreset = JSON.parse(themeFileView.text())
        } catch (e) {
            console.warn("theme preset parse failed:", activeTheme, e)
            themePreset = {}
        }
        themeLoaded = true
    }

    // initial load (FileView reads async, so retry once the file is in memory)
    Timer {
        id: themeLoadTimer
        interval: 120
        repeat: false
        onTriggered: themeRoot.applyPreset()
    }

    onActiveThemeChanged: {
        themeRoot.themePreset = {}
        themeRoot.themeLoaded = false
        if (activeTheme) {
            scanThemes()
            themeLoadTimer.start()
        }
    }

    // read a theme preset color, falling back to the built-in default when the
    // preset does not define it (or no theme is active)
    function themeColor(key, def) {
        const v = themePreset && typeof themePreset === "object" ? themePreset[key] : undefined
        return v === undefined || v === null || v === "" ? def : v
    }

    readonly property bool isLight: !!themePreset && themePreset.variant === "light"
    function chipHover(c) {
        const col = Qt.color(c)
        if (!isLight) return Qt.lighter(col, 1.2)
        return Qt.rgba(col.r + (1 - col.r) * 0.3, col.g + (1 - col.g) * 0.3, col.b + (1 - col.b) * 0.3, 1)
    }

    // more darker (descending)
    property string bg: themeColor("bg", "#111111")
    property string bg1: themeColor("bg1", "#141414")
    property string bg2: themeColor("bg2", "#191919")
    property string bg3: themeColor("bg3", "#242424")
    property string bg4: themeColor("bg4", "#292929")
    property string bg5: themeColor("bg5", "#323232")
    property string bg6: themeColor("bg6", "#363636")
    property string bg7: themeColor("bg7", "#404040")
    property string bg8: themeColor("bg8", "#444444")
    property string bg9: themeColor("bg9", "#505050")

    property string bgD: themeColor("bgD", "#0b0b0b")
    property string bgD1: themeColor("bgD1", "#101010")

    // more darker (ascending)
    property string fg: themeColor("fg", "#dadada")
    property string fg1: themeColor("fg1", "#e7e7e7")
    property string fg2: themeColor("fg2", "#dfdfdf")
    property string fg3: themeColor("fg3", "#c4c4c4")
    property string fg4: themeColor("fg4", "#9e9e9e")
    property string fg5: themeColor("fg5", "#777777")
    property string fg6: themeColor("fg6", "#6a6a6a")
    property string fg7: themeColor("fg7", "#484848")
    property string fg8: themeColor("fg8", "#313131")
    property string fgL: themeColor("fgL", "#e9e9e9")

    // CC sliders
    property string sliderBg: themeColor("sliderBg", "#c9c9c9")

    property string fg3D: themeColor("fg3D", "#a7a7a7")
    property string fg4D: themeColor("fg4D", "#c5c4c4") // d == darker

    property string borderBg: themeColor("borderBg", "#6a6a6a")
    property string borderBg1: themeColor("borderBg1", "#484848")
    property string borderBg2: themeColor("borderBg2", "#323232")
    property string borderBg3: themeColor("borderBg3", "#282828")
    property string borderBg4: themeColor("borderBg4", "#242424")
    property string borderBgFocus: themeColor("borderBgFocus", "#555555")
    property string borderBgFocus1: themeColor("borderBgFocus1", "#4f4f4f")

    // focus bg
    property string focusBg: themeColor("focusBg", "#252525")
    property string focusBg1: themeColor("focusBg1", "#2e2e2e")
    property string focusBgD: themeColor("focusBgD", "#222222")
    property string focusBgL: themeColor("focusBgL", "#353535") // L == lighter

    property string focusFg: themeColor("focusFg", "#d1d1d1")
    property string focusFg1: themeColor("focusFg1", "#bcbcbc")
    property string focusFg2: themeColor("focusFg2", "#a8a8a8")

    property string fontFamily: Config.textFontFamily
    property string nerdFontFamily: Config.nerdFontFamily

    // base literals (alpha overlays, never themed)
    property string white: "#ffffff"
    property string black: "#000000"
    property string transparent: "#00000000"

    // shadows and scrims (black alphas, work on any theme)
    property string shadowSoft: "#7a000000"
    property string shadowPill: "#b0000000"
    property string fadeBottom: "#cc000000"

    // semantic status
    property string ok: themeColor("ok", "#4bd25c") // battery good, success
    property string okShell: themeColor("okShell", "#46e03b") // shell exit 0
    property string warnMed: themeColor("warnMed", "#eecc47") // battery medium
    property string danger: themeColor("danger", "#e22323") // battery low, error, shutdown confirm
    property string mutedFg: themeColor("mutedFg", "#fb2a2a") // volume pill muted icon
    property string mutedFgSlider: themeColor("mutedFgSlider", "#fd2222") // cc slider muted icon
    property string fgMuted: themeColor("fgMuted", "#8a8a8a")

    // connectivity
    property string netFg: themeColor("netFg", "#6791dc") // network / bluetooth pill icon
    property string netFgOff: themeColor("netFgOff", "#9ea9bd") // disconnected icon
    property string netConnected: themeColor("netConnected", "#4175c5")
    property string netConnectedFg: themeColor("netConnectedFg", "#c9d7ef")
    property string netFail: themeColor("netFail", "#e94545")
    property string netBtn: themeColor("netBtn", "#3874d7")
    property string netBtnHover: themeColor("netBtnHover", "#3065be")
    property string btDeviceOff: themeColor("btDeviceOff", "#949494")
    property string vpnFg: themeColor("vpnFg", "#48cc47") // vpn pill icon
    property string vpnOkFg: themeColor("vpnOkFg", "#64d667") // ip status vpn glyph
    property string ipFg: themeColor("ipFg", "#6496dd") // ip status glyph

    // control center
    property string ccActiveBg: themeColor("ccActiveBg", "#181d23") // wifi / bluetooth button active
    property string ccActiveBg2: themeColor("ccActiveBg2", "#20232a") // timer button active
    property string ccDndBg: themeColor("ccDndBg", "#262626")
    property string ccActiveFg: themeColor("ccActiveFg", "#4888ef")
    property string ccDndFg: themeColor("ccDndFg", "#fff9eb")
    property string timerFg: themeColor("timerFg", "#5892f3") // timer osd icon
    property string burstFg: themeColor("burstFg", "#ff922b")
    property string timerRunningFg: themeColor("timerRunningFg", "#4490ee")
    property var burstPalette: themeColor("burstPalette", ["#ffd43b", "#ff6b6b", "#4490ee", "#b197fc", "#f783ac", "#63e6be"])

    // power actions
    property string powerLock: themeColor("powerLock", "#628ae2")
    property string powerSleep: themeColor("powerSleep", "#9d6fff")
    property string powerLogout: themeColor("powerLogout", "#f4a232")
    property string powerRestart: themeColor("powerRestart", "#ff6b35")
    property string powerShutdown: themeColor("powerShutdown", "#d62828")
    property string powerLogoutPending: themeColor("powerLogoutPending", "#ea9d34")
    property string powerRestartConfirm: themeColor("powerRestartConfirm", "#ff6c25")
    property string powerLogoutConfirm: themeColor("powerLogoutConfirm", "#e07e20")

    // weather (icons are monochrome by default; fog stays dimmer)
    property string weatherText: themeColor("weatherText", "#ecebeb")
    property string weatherCondition: themeColor("weatherCondition", "#7e7e7e")
    property string weatherTemp: themeColor("weatherTemp", "#a0a0a0")
    property string weatherDay: themeColor("weatherDay", "#6e6e6e")
    property string weatherFeels: themeColor("weatherFeels", fg)
    property string weatherHumidity: themeColor("weatherHumidity", fg)
    property string weatherWind: themeColor("weatherWind", fg)
    property string weatherSunrise: themeColor("weatherSunrise", fg)
    property string weatherSunset: themeColor("weatherSunset", fg)
    property string weatherClear: themeColor("weatherClear", fg)
    property string weatherCloudy: themeColor("weatherCloudy", fg)
    property string weatherRain: themeColor("weatherRain", fg)
    property string weatherThunder: themeColor("weatherThunder", fg)
    property string weatherSnow: themeColor("weatherSnow", fg)
    property string weatherFog: fgMuted

    // widgets
    property string notificationFg: themeColor("notificationFg", "#9b9b9b")
    property string notifFg: themeColor("notifFg", "#d8ad5c")
    property string dateFg: themeColor("dateFg", "#9d9d9d")
    property string todayFg: themeColor("todayFg", "#ec3737")
    property string calendarBg: themeColor("calendarBg", "#1c1c1c")
    property string osdBarBg: themeColor("osdBarBg", "#333333")
    property string scrollIdle: themeColor("scrollIdle", "#3a3a3a")
    property string scrollHover: themeColor("scrollHover", "#6f6f6f")
    property string scrollPressed: themeColor("scrollPressed", "#888888")
    property string wsActiveBg: themeColor("wsActiveBg", "#4d5258")
    property string wsInactiveBg: themeColor("wsInactiveBg", "#393c41")
    property string wsActiveFg: themeColor("wsActiveFg", "#dae0ea")
    property string wsInactiveFg: themeColor("wsInactiveFg", "#c4c4c4")
    property string rowBg: themeColor("rowBg", "#171717")
    property string heroBg: themeColor("heroBg", "#191919")
    property string toggleOffBg: themeColor("toggleOffBg", "#242424")
    property string notifHeaderBg: themeColor("notifHeaderBg", "#242424")
    property string clearAllBg: themeColor("clearAllBg", "#141414")
    property string clearAllBgHover: themeColor("clearAllBgHover", "#111111")

    property string warning: themeColor("warning", "#fac94a")
    property string deleting: themeColor("deleting", "#e32626")

    property string accent: themeColor("accent", "#979797")
    property string coverArtGlowShadow: themeColor("coverArtGlowShadow", "#80aae6")

    property int fontSizeBase: 13
    property int fontSize: Math.round(fontSizeBase * Config.pillScale)
}
