-- album-art.applescript: Save current track artwork to a given directory.
-- Usage: osascript album-art.applescript /path/to/output/dir
on run argv
    set outputDir to item 1 of argv
    set imgFormat to ".jpg"
    set rawData to missing value

    tell application "Music"
        try
            if player state is not stopped then
                tell artwork 1 of current track
                    if format is JPEG picture then
                        set imgFormat to ".jpg"
                    else
                        set imgFormat to ".png"
                    end if
                end tell
                set rawData to (get raw data of artwork 1 of current track)
            end if
        on error
            return
        end try
    end tell

    if rawData is missing value then return

    set newPath to (outputDir & "/tmp" & imgFormat)
    try
        set fileRef to (open for access (POSIX file newPath) with write permission)
        set eof of fileRef to 0
        write rawData to fileRef
        close access fileRef
    on error m number n
        try
            close access fileRef
        end try
    end try
end run
