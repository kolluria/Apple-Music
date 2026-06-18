-- switch-output.applescript: Switch system audio output via Control Center.
-- Requires Terminal to have Accessibility permission.
-- Usage: osascript switch-output.applescript "Device Name"
on run argv
    set targetDevice to item 1 of argv
    set maxRetries to 10

    tell application "System Events"
        tell process "Control Center"
            -- Open the Sound section of Control Center
            click menu bar item "Sound" of menu bar 1
            delay 0.8

            set soundWindow to window "Control Center"
            set found to false

            repeat maxRetries times
                try
                    set allCheckboxes to checkboxes of scroll area 1 of group 1 of soundWindow
                    repeat with cb in allCheckboxes
                        if title of cb is targetDevice then
                            click cb
                            set found to true
                            exit repeat
                        end if
                    end repeat
                end try
                if found then exit repeat
                delay 0.3
            end repeat

            -- Close Control Center regardless of outcome
            key code 53
        end tell
    end tell

    if not found then
        error "Device not found in Control Center: " & targetDevice
    end if
end run
