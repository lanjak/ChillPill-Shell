import Quickshell
import QtQuick
import "../components"
import ".."

Page {
    Heading { text: "PILL MODULES" }
    ModulesEditor {
        known: ["battery", "volume", "workspaces", "network", "clock", "brightness", "vpn", "notifications", "bluetooth", "weather", "audioVisualizer"]
        value: ConfigStore.cfg.pillModules === undefined ? [] : ConfigStore.cfg.pillModules
        onEdited: (v) => ConfigStore.set("pillModules", v)
      }
    Heading { text: "BEHAVIOUR" }
    ChoiceRow { label: "Monitor"; hint: "Show the Pill Bar on every monitor, or on one"; options: ["all"].concat(Quickshell.screens.map(s => s.name)); value: ConfigStore.get("pillMonitor", "all"); onEdited: (v) => ConfigStore.set("pillMonitor", v) }
    ToggleRow { label: "Hide in fullscreen"; hint: "Hide the Pill Bar on a monitor while its fullscreen app is focused"; value: ConfigStore.get("hidePillOnFullscreen", true); onEdited: (v) => ConfigStore.set("hidePillOnFullscreen", v) }
    ToggleRow { label: "Show pill on hover"; hint: "Auto hide the Pill Bar"; value: ConfigStore.get("pillOnHover", false); onEdited: (v) => ConfigStore.set("pillOnHover", v) }
    TextRow { label: "Clock format"; hint: "Qt format string, e.g. hh:mm (10:00) or h:mm AP (10:15 AM)"; fieldWidth: 160; value: ConfigStore.get("clockFormat", "hh:mm"); onEdited: (v) => ConfigStore.set("clockFormat", v) }
    NumRow { label: "Max workspaces"; from: 1; to: 20; value: ConfigStore.get("maxWorkspaces", 5); onEdited: (v) => ConfigStore.set("maxWorkspaces", v) }
    Heading { text: "PRIVACY" }
    ToggleRow { label: "Show sensitive info"; hint: "VPN module's information (City, IP Address etc.) in tooltip"; value: ConfigStore.get("showSensitiveInfo", true); onEdited: (v) => ConfigStore.set("showSensitiveInfo", v) }
}
