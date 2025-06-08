#Persistent
#SingleInstance, Force

; === Extract icons to temp directory ===
tempIconDir := A_Temp "\BatteryBuddyIcons"
FileCreateDir, %tempIconDir%
FileInstall, icons\greenbattery.ico, %tempIconDir%\greenbattery.ico, 1
FileInstall, icons\redbattery.ico, %tempIconDir%\redbattery.ico, 1
FileInstall, icons\bluebattery.ico, %tempIconDir%\bluebattery.ico, 1

greenIcon := tempIconDir "\greenbattery.ico"
redIcon := tempIconDir "\redbattery.ico"
neutralIcon := tempIconDir "\bluebattery.ico"

; === Tray menu setup ===
Menu, Tray, NoStandard
Menu, Tray, Add, Mute 30 Minutes, Mute30
Menu, Tray, Add, Mute 1 Hour, Mute60
Menu, Tray, Add, Unmute Now, Unmute
Menu, Tray, Add
Menu, Tray, Add, Run at Startup, AddStartup
Menu, Tray, Add, Remove from Startup, RemoveStartup
Menu, Tray, Add
Menu, Tray, Add, Show Status, ShowCurrentStatus
Menu, Tray, Add, Exit, ExitScript
Menu, Tray, Tip, Battery Notifier
Menu, Tray, Icon, %neutralIcon%

; Call this after your initial menu setup
UpdateTrayMenu()

; === Variables ===
notifiedHigh := false
notifiedLow := false
lastPluggedState := -1
currentIcon := ""
reminderHigh := false
reminderLow := false
muteUntil := 0

SetTimer, CheckBattery, 5000         ; 5 sec
SetTimer, ReminderCheck, 120000      ; 2 min

CheckBattery:
    battery := GetBatteryInfo()
    global percent := battery[1]
    global plugged := battery[2]

    ; Tray icon update
    newIcon := plugged ? greenIcon : redIcon
    if (currentIcon != newIcon && FileExist(newIcon)) {
        Menu, Tray, Icon, %newIcon%
        currentIcon := newIcon
    }

    ; Tooltip
    status := plugged ? "Charging" : "On Battery"
    Menu, Tray, Tip, % "Battery: " percent "%%  " status

    ; Plug/unplug toast
    if (lastPluggedState != -1 && lastPluggedState != plugged) {
        if (plugged) {
            ShowToast("Charger Connected", "Charging started at " percent "%", greenIcon)
        } else {
            ShowToast("Charger Disconnected", "Unplugged at " percent "%", redIcon)
        }
    }

    ; Battery level reminders
    currentTime := A_TickCount
    if (!plugged && percent <= 25 && !notifiedLow && currentTime > muteUntil) {
        ShowToast("Battery Low", "Please plug in to maintain health (" percent "%)", redIcon)
        notifiedLow := true
        reminderLow := true
    } else if (plugged && percent >= 80 && !notifiedHigh && currentTime > muteUntil) {
        ShowToast("Battery Full", "Battery at " percent "% - unplug for better lifespan", greenIcon)
        notifiedHigh := true
        reminderHigh := true
    } else if (percent > 25 && percent < 80) {
        notifiedHigh := false
        notifiedLow := false
        reminderHigh := false
        reminderLow := false
    }

    lastPluggedState := plugged
return

ReminderCheck:
    currentTime := A_TickCount
    if (currentTime < muteUntil)
        return

    if (plugged && percent >= 80 && reminderHigh) {
        ShowToast("Reminder", "Battery still at " percent "% - unplug", greenIcon)
    }

    if (!plugged && percent <= 25 && reminderLow) {
        ShowToast("Reminder", "Battery still low at " percent "% - please plug in", redIcon)
    }
return

GetBatteryInfo() {
    try {
        objWMIService := ComObjGet("winmgmts:\\.\root\cimv2")
        colItems := objWMIService.ExecQuery("Select * from Win32_Battery")
        for item in colItems {
            percent := item.EstimatedChargeRemaining
            status := item.BatteryStatus
            plugged := (status = 2)
            return [percent, plugged]
        }
    } catch e {
        return [0, false]
    }
    return [0, false]
}

ShowToast(title, message, iconFile := "") {
    if (iconFile = "" || !FileExist(iconFile)) {
        psCommand := "New-BurntToastNotification -Text '" title "', '" message "'"
    } else {
        psCommand := "New-BurntToastNotification -AppLogo '" iconFile "' -Text '" title "', '" message "'"
    }
    RunWait, % "powershell -NoProfile -WindowStyle Hidden -Command " . psCommand,, Hide
}

UpdateTrayMenu() {
    startupShortcut := A_Startup "\BatteryBuddy.lnk"
    isStartup := FileExist(startupShortcut)
    global muteUntil

    ; Enable or disable startup options
    if (isStartup) {
        Menu, Tray, Disable, Run at Startup
        Menu, Tray, Enable, Remove from Startup
    } else {
        Menu, Tray, Enable, Run at Startup
        Menu, Tray, Disable, Remove from Startup
    }

    ; Disable Unmute Now if not muted
    currentTime := A_TickCount
    if (muteUntil > currentTime) {
        Menu, Tray, Enable, Unmute Now
    } else {
        Menu, Tray, Disable, Unmute Now
    }
}

AddStartup:
{
    exePath := A_ScriptFullPath
    startupShortcut := A_Startup "\BatteryBuddy.lnk"
    FileCreateShortcut, %exePath%, %startupShortcut%
    ShowToast("Startup Enabled", "BatteryBuddy will run at login", neutralIcon)
    UpdateTrayMenu()
}
return

RemoveStartup:
{
    startupShortcut := A_Startup "\BatteryBuddy.lnk"
    FileDelete, %startupShortcut%
    ShowToast("Startup Removed", "BatteryBuddy will no longer auto-run", neutralIcon)
    UpdateTrayMenu()
}
return

Mute30:
    muteUntil := A_TickCount + 1800000
    ShowToast("Muted", "Notifications paused for 30 minutes", neutralIcon)
    UpdateTrayMenu()
return

Mute60:
    muteUntil := A_TickCount + 3600000
    ShowToast("Muted", "Notifications paused for 1 hour", neutralIcon)
    UpdateTrayMenu()
return

Unmute:
    muteUntil := 0
    ShowToast("Unmuted", "Battery notifications resumed", neutralIcon)
    UpdateTrayMenu()
return



ShowCurrentStatus:
    battery := GetBatteryInfo()
    percent := battery[1]
    plugged := battery[2]
    status := plugged ? "Plugged In (Charging)" : "Unplugged (On Battery)"
    ShowToast("Battery Status", "Battery Level: " percent "%nStatus: " status, neutralIcon)
return

ExitScript:
    FileRemoveDir, %tempIconDir%, 1
    ExitApp
