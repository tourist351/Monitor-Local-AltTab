#Requires AutoHotkey v2.0
#SingleInstance Force

; Named mutex so an external watcher script can check "is this already
; running?" without any fragile window-title or PID matching.
DllCall("CreateMutex", "ptr", 0, "int", 0, "str", "Global\PerMonitorAltTab_Running")

; Self-exit the moment the second monitor disappears - this script manages
; its own lifecycle rather than relying on another script to kill it.
OnMessage(0x7E, CheckMonitorPresence)   ; WM_DISPLAYCHANGE
SetTimer(CheckMonitorPresence, 5000)    ; fallback poll in case the message is missed

CheckMonitorPresence(*) {
    if (MonitorGetCount() <= 1)
        ExitApp()
}

; ============================================================
;  Per-Monitor Alt+Tab
;  Alt+Tab / Alt+Shift+Tab cycles ONLY through windows on the
;  monitor your mouse cursor is currently sitting on.
; ============================================================

; Make this script per-monitor DPI aware. Without this, mouse/window
; coordinates can get reported in a scaled space that doesn't match
; MonitorGet's real pixel boundaries whenever your monitors use
; different display-scaling percentages, causing the wrong monitor
; to be detected intermittently.
DllCall("SetProcessDpiAwarenessContext", "ptr", -4, "int")  ; PER_MONITOR_AWARE_V2

CoordMode("Mouse", "Screen")
CoordMode("ToolTip", "Screen")

global switchList := []
global switchIndex := 0
global switchGui := 0
global isSwitching := false

; ---------- helpers ----------

GetMonitorAt(x, y) {
    monCount := MonitorGetCount()
    Loop monCount {
        MonitorGet(A_Index, &L, &T, &R, &B)
        if (x >= L && x < R && y >= T && y < B)
            return A_Index
    }
    return 1
}

GetWindowMonitor(hwnd) {
    try {
        WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
        cx := x + w // 2
        cy := y + h // 2
        return GetMonitorAt(cx, cy)
    } catch {
        return 0
    }
}

IsAltTabWindow(hwnd) {
    id := "ahk_id " hwnd
    title := ""
    try title := WinGetTitle(id)
    if (title = "")
        return false

    exStyle := 0
    try exStyle := WinGetExStyle(id)
    if (exStyle & 0x80)          ; WS_EX_TOOLWINDOW -> skip
        return false

    style := 0
    try style := WinGetStyle(id)
    if !(style & 0x10000000)     ; WS_VISIBLE required
        return false

    ; Skip cloaked windows (UWP apps on another virtual desktop, etc.)
    cloaked := 0
    DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "int", 14, "int*", &cloaked, "int", 4)
    if (cloaked)
        return false

    ; Skip owned popup windows that aren't real taskbar apps
    owner := DllCall("GetWindow", "ptr", hwnd, "uint", 4, "ptr")   ; GW_OWNER
    if (owner && !(exStyle & 0x40000))  ; WS_EX_APPWINDOW
        return false

    return true
}

BuildSwitchList() {
    MouseGetPos(&mx, &my)
    curMon := GetMonitorAt(mx, my)
    list := []
    for hwnd in WinGetList() {
        if !IsAltTabWindow(hwnd)
            continue
        if (GetWindowMonitor(hwnd) = curMon)
            list.Push(hwnd)
    }
    return list
}

ShowSwitchGui() {
    global switchGui, switchList, switchIndex

    if (switchGui)
        switchGui.Destroy()

    switchGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "Switcher")
    switchGui.BackColor := "222222"
    switchGui.SetFont("s11 cWhite", "Segoe UI")

    y := 10
    for i, hwnd in switchList {
        title := ""
        try title := WinGetTitle("ahk_id " hwnd)
        if (StrLen(title) > 60)
            title := SubStr(title, 1, 57) . "..."
        prefix := (i = switchIndex) ? "> " : "    "
        switchGui.Add("Text", "x10 y" y " w400", prefix . title)
        y += 24
    }

    MouseGetPos(&mx, &my)
    monIdx := GetMonitorAt(mx, my)
    MonitorGetWorkArea(monIdx, &L, &T, &R, &B)
    guiW := 420, guiH := y + 10
    posX := L + ((R - L) - guiW) // 2
    posY := T + ((B - T) - guiH) // 2

    switchGui.Show("x" posX " y" posY " w" guiW " h" guiH " NoActivate")
}

FinishSwitch() {
    global isSwitching, switchList, switchIndex, switchGui
    if !isSwitching
        return
    isSwitching := false

    if (switchGui) {
        switchGui.Destroy()
        switchGui := 0
    }

    if (switchIndex >= 1 && switchIndex <= switchList.Length) {
        hwnd := switchList[switchIndex]
        id := "ahk_id " hwnd
        if WinExist(id) {
            try {
                if WinGetMinMax(id) = -1
                    WinRestore(id)
            }
            WinActivate(id)
        }
    }
}

; ---------- hotkeys ----------

!Tab:: {
    global isSwitching, switchList, switchIndex
    if !isSwitching {
        switchList := BuildSwitchList()
        if (switchList.Length = 0)
            return
        isSwitching := true
        switchIndex := (switchList.Length > 1) ? 2 : 1
    } else {
        switchIndex += 1
        if (switchIndex > switchList.Length)
            switchIndex := 1
    }
    ShowSwitchGui()
}

!+Tab:: {
    global isSwitching, switchList, switchIndex
    if !isSwitching {
        switchList := BuildSwitchList()
        if (switchList.Length = 0)
            return
        isSwitching := true
        switchIndex := (switchList.Length > 1) ? switchList.Length : 1
    } else {
        switchIndex -= 1
        if (switchIndex < 1)
            switchIndex := switchList.Length
    }
    ShowSwitchGui()
}

~LAlt Up:: FinishSwitch()
~RAlt Up:: FinishSwitch()
