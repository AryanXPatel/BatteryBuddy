#Persistent
#SingleInstance, Force
SetTimer, CheckBattery, 5000         ; Every 5 seconds
SetTimer, ReminderCheck, 120000      ; Every 2 minutes (120000 ms)

Menu, Tray, NoStandard
Menu, Tray, Add, Mute 30 Minutes, Mute30
Menu, Tray, Add, Mute 1 Hour, Mute60
Menu, Tray, Add, Unmute Now, Unmute
Menu, Tray, Add
Menu, Tray, Add, Show Status, ShowCurrentStatus
Menu, Tray, Add, Exit, ExitScript
Menu, Tray, Tip, Battery Notifier
Menu, Tray, Icon, %A_ScriptDir%\icons\battery.ico

notifiedHigh := false
notifiedLow := false
lastPluggedState := -1
currentIcon := ""
reminderHigh := false
reminderLow := false
muteUntil := 0

CheckBattery:
    battery := GetBatteryInfo()
    global percent := battery[1]
    global plugged := battery[2]

    ; Icon handling
    greenIcon := A_ScriptDir "\icons\greenbattery.ico"
    redIcon := A_ScriptDir "\icons\redbattery.ico"
    newIcon := plugged ? greenIcon : redIcon

    if (currentIcon != newIcon && FileExist(newIcon)) {
        Menu, Tray, Icon, %newIcon%
        currentIcon := newIcon
    }

    ; Tooltip
    status := plugged ? "Charging" : "On Battery"
    Menu, Tray, Tip, % "Battery: " percent "%%  " status

    ; Plug/unplug notifications
    if (lastPluggedState != -1 && lastPluggedState != plugged) {
        if (plugged) {
            ShowToast("Charger Connected", "Charging started at " percent "%", newIcon)
        } else {
            ShowToast("Charger Disconnected", "Unplugged at " percent "%", newIcon)
        }
    }

    ; Initial reminder flags
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
        ShowToast("Reminder", "Battery still at " percent "% - unplug", A_ScriptDir "\icons\greenbattery.ico")
    }

    if (!plugged && percent <= 25 && reminderLow) {
        ShowToast("Reminder", "Battery still low at " percent "% - please plug in", A_ScriptDir "\icons\redbattery.ico")
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

Mute30:
    muteUntil := A_TickCount + 1800000 ; 30 minutes
    ShowToast("Muted", "Notifications paused for 30 minutes")
return

Mute60:
    muteUntil := A_TickCount + 3600000 ; 1 hour
    ShowToast("Muted", "Notifications paused for 1 hour")
return

Unmute:
    muteUntil := 0
    ShowToast("Unmuted", "Battery notifications resumed")
return

ShowCurrentStatus:
    battery := GetBatteryInfo()
    percent := battery[1]
    plugged := battery[2]
    status := plugged ? "Plugged In (Charging)" : "Unplugged (On Battery)"
    MsgBox, 64, Battery Status, Battery Level: %percent%`%`nCharger Status: %status%
return

ExitScript:
ExitApp
