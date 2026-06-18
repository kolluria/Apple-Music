#!/bin/zsh

SCRIPT_DIR="${0:A:h}"
ART_DIR="${TMPDIR:-/tmp}/am-art"

_need() {
    # _need CMD [brew-formula]  — abort with install hint if CMD is missing
    local cmd="$1" pkg="${2:-$1}"
    if ! command -v "$cmd" &>/dev/null; then
        print -u2 "Required: $cmd  →  brew install $pkg"
        return 1
    fi
}

# Run at startup to verify the full dep set (used by `am check`)
_check_deps() {
    local ok=true
    _need fzf            || ok=false
    _need SwitchAudioSource switchaudio-osx || ok=false
    command -v viu &>/dev/null \
        || print "Optional: viu  →  brew install viu  (needed for album art in np)"
    $ok
}

# ---------------------------------------------------------------------------
# np — Now Playing TUI
# ---------------------------------------------------------------------------
np() {
    local text_mode=false
    [[ "$1" == "-t" ]] && text_mode=true

    mkdir -p "$ART_DIR"

    local init=1 help=false
    local cyan magenta nocolor
    cyan=$(printf '\e[00;36m')
    magenta=$(printf '\033[01;35m')
    nocolor=$(printf '\033[0m')
    local keybindings="
Keybindings:
  p   Play / Pause          f   Forward one track
  b   Backward one track    >   Fast forward
  <   Rewind                R   Resume normal playback
  +   Volume +5%            -   Volume -5%
  s   Toggle shuffle        r   Toggle song repeat
  o   Switch audio output   q   Quit np
  Q   Quit np + Music.app   ?   Show / hide keybindings"

    local vol shuffle repeat duration arr curr currMin currSec
    local name artist record end endMin endSec art input
    local volIcon shuffleIcon repeatIcon volLevel
    local volBars volBG volDisp progressBars progBG prog percentRemain

    while :; do
        vol=$(osascript -e 'tell application "Music" to get sound volume')
        shuffle=$(osascript -e 'tell application "Music" to get shuffle enabled')
        repeat=$(osascript -e 'tell application "Music" to get song repeat')
        duration=$(osascript -e 'tell application "Music" to get {player position} & {duration} of current track')
        arr=(`echo "${duration}"`)
        curr=$(cut -d . -f 1 <<< "${arr[-2]}")
        currMin=$(( curr / 60 ))
        currSec=$(( curr % 60 ))
        [[ ${#currMin} -eq 1 ]] && currMin="0$currMin"
        [[ ${#currSec} -eq 1 ]] && currSec="0$currSec"

        if (( curr < 2 || init == 1 )); then
            init=0
            name=$(osascript -e 'tell application "Music" to get name of current track')
            name=${name:0:50}
            artist=$(osascript -e 'tell application "Music" to get artist of current track')
            artist=${artist:0:50}
            record=$(osascript -e 'tell application "Music" to get album of current track')
            record=${record:0:50}
            end=$(cut -d . -f 1 <<< "${arr[-1]}")
            endMin=$(( end / 60 ))
            endSec=$(( end % 60 ))
            [[ ${#endMin} -eq 1 ]] && endMin="0$endMin"
            [[ ${#endSec} -eq 1 ]] && endSec="0$endSec"

            if ! $text_mode; then
                rm -f "$ART_DIR/tmp.png" "$ART_DIR/tmp.jpg"
                osascript "$SCRIPT_DIR/album-art.applescript" "$ART_DIR" 2>/dev/null
                art=""
                if [[ -f "$ART_DIR/tmp.png" ]]; then
                    art=$(viu -b "$ART_DIR/tmp.png" -w 31 -h 14 2>/dev/null)
                elif [[ -f "$ART_DIR/tmp.jpg" ]]; then
                    art=$(viu -b "$ART_DIR/tmp.jpg" -w 31 -h 14 2>/dev/null)
                fi
            fi
        fi

        if [[ $vol -eq 0 ]]; then volIcon='🔇'; else volIcon='🔊'; fi
        volLevel=$(( vol / 12 ))
        if [[ "$shuffle" == "false" ]]; then shuffleIcon='➡️ '; else shuffleIcon='🔀'; fi
        case "$repeat" in
            off) repeatIcon='↪️ ' ;;
            one) repeatIcon='🔂' ;;
            *)   repeatIcon='🔁' ;;
        esac

        volBars='▁▂▃▄▅▆▇'
        volBG=${volBars:$volLevel}
        volDisp=${volBars:0:$volLevel}

        progressBars='▇▇▇▇▇▇▇▇▇'
        percentRemain=$(( end > 0 ? (curr * 100) / end / 10 : 0 ))
        (( percentRemain > 9 )) && percentRemain=9
        progBG=${progressBars:$percentRemain}
        prog=${progressBars:0:$percentRemain}

        clear
        if $text_mode; then
            paste <(printf '%s\n' "$name" "$artist - $record" \
                "$shuffleIcon $repeatIcon $currMin:$currSec ${cyan}${prog}${nocolor}${progBG} $endMin:$endSec" \
                "$volIcon ${magenta}${volDisp}${nocolor}${volBG}")
        else
            paste <(printf %s "$art") <(printf %s "") <(printf %s "") <(printf %s "") \
                <(printf '%s\n' "$name" "$artist - $record" \
                "$shuffleIcon $repeatIcon $currMin:$currSec ${cyan}${prog}${nocolor}${progBG} $endMin:$endSec" \
                "$volIcon ${magenta}${volDisp}${nocolor}${volBG}")
        fi

        [[ "$help" == "true" ]] && printf '%s\n' "$keybindings"

        input=$(/bin/bash -c "read -n 1 -t 1 input; echo \$input | xargs")
        case "$input" in
            *s*) [[ "$shuffle" == "true" ]] \
                    && osascript -e 'tell application "Music" to set shuffle enabled to false' \
                    || osascript -e 'tell application "Music" to set shuffle enabled to true' ;;
            *r*) case "$repeat" in
                    off) osascript -e 'tell application "Music" to set song repeat to all' ;;
                    all) osascript -e 'tell application "Music" to set song repeat to one' ;;
                    *)   osascript -e 'tell application "Music" to set song repeat to off' ;;
                 esac ;;
            *+*)  osascript -e 'tell application "Music" to set sound volume to sound volume + 5' ;;
            *-*)  osascript -e 'tell application "Music" to set sound volume to sound volume - 5' ;;
            *\>*) osascript -e 'tell application "Music" to fast forward' ;;
            *\<*) osascript -e 'tell application "Music" to rewind' ;;
            *R*)  osascript -e 'tell application "Music" to resume' ;;
            *f*)  osascript -e 'tell application "Music" to play next track' ;;
            *b*)  osascript -e 'tell application "Music" to back track' ;;
            *p*)  osascript -e 'tell application "Music" to playpause' ;;
            *o*)  output ;;
            *q*)  clear; return 0 ;;
            *Q*)  killall Music; clear; return 0 ;;
            *\?*) [[ "$help" == "true" ]] && help='false' || help='true' ;;
        esac

        read -sk 1 -t 0.001 2>/dev/null || true
    done
}

# Collect deduplicated track names from Library + Liked Music (covers local + streaming)
_all_track_names() {
    {
        osascript -e 'tell application "Music" to get name of every track' 2>/dev/null
        osascript -e 'tell application "Music" to get name of every track of playlist "Liked Music"' 2>/dev/null
    } | tr ',' '\n' | sed 's/^ //' | sort | awk '!seen[$0]++'
}

# ---------------------------------------------------------------------------
# list — enumerate library items
# ---------------------------------------------------------------------------
list() {
    local usage="Usage: list [-grouping] [name]

  -s                    List all songs.
  -r                    List all albums.
  -r PATTERN            List all songs in album PATTERN.
  -a                    List all artists.
  -a PATTERN            List all songs by artist PATTERN.
  -p                    List all playlists.
  -p PATTERN            List all songs in playlist PATTERN.
  -g                    List all genres.
  -g PATTERN            List all songs in genre PATTERN."

    if [[ "$#" -eq 0 ]]; then printf '%s\n' "$usage"; return; fi

    local flag="$1"; shift
    case "$flag" in
        -p)
            if [[ "$#" -eq 0 ]]; then
                osascript -e 'tell application "Music" to get name of playlists' \
                    | tr ',' '\n' | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
            else
                osascript -e 'on run args' \
                    -e 'tell application "Music" to get name of every track of playlist (item 1 of args)' \
                    -e 'end' "$@" | tr ',' '\n' | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
            fi ;;
        -s)
            if [[ "$#" -eq 0 ]]; then
                _all_track_names | /usr/bin/pr -t -a -3
            else
                printf '%s\n' "$usage"
            fi ;;
        -r)
            if [[ "$#" -eq 0 ]]; then
                osascript -e 'tell application "Music" to get album of every track' \
                    | tr ',' '\n' | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
            else
                osascript -e 'on run args' \
                    -e 'tell application "Music" to get name of every track whose album is (item 1 of args)' \
                    -e 'end' "$@" | tr ',' '\n' | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
            fi ;;
        -a)
            if [[ "$#" -eq 0 ]]; then
                osascript -e 'tell application "Music" to get artist of every track' \
                    | tr ',' '\n' | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
            else
                osascript -e 'on run args' \
                    -e 'tell application "Music" to get name of every track whose artist is (item 1 of args)' \
                    -e 'end' "$@" | tr ',' '\n' | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
            fi ;;
        -g)
            if [[ "$#" -eq 0 ]]; then
                osascript -e 'tell application "Music" to get genre of every track' \
                    | tr ',' '\n' | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
            else
                osascript -e 'on run args' \
                    -e 'tell application "Music" to get name of every track whose genre is (item 1 of args)' \
                    -e 'end' "$@" | tr ',' '\n' | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
            fi ;;
        *) printf '%s\n' "$usage" ;;
    esac
}

# ---------------------------------------------------------------------------
# play — fuzzy-find and begin playback
# ---------------------------------------------------------------------------
play() {
    local usage="Usage: play [-grouping] [name] [-S]

  -s                    Fzf for a song and begin playback.
  -s PATTERN            Play the song PATTERN.
  -r                    Fzf for an album and begin playback.
  -r PATTERN            Play from album PATTERN.
  -a                    Fzf for an artist and begin playback.
  -a PATTERN            Play from artist PATTERN.
  -p                    Fzf for a playlist and begin playback.
  -p PATTERN            Play from playlist PATTERN.
  -g                    Fzf for a genre and begin playback.
  -g PATTERN            Play from genre PATTERN.
  -l                    Play your entire library.

  -S                    Enable shuffle before playback."

    if [[ "$#" -eq 0 ]]; then printf '%s\n' "$usage"; return; fi
    _need fzf || return 1

    local shuffle_on=false newargs=()
    for a in "$@"; do [[ "$a" == "-S" ]] && shuffle_on=true || newargs+=("$a"); done
    set -- "${newargs[@]}"

    $shuffle_on && osascript -e 'tell application "Music" to set shuffle enabled to true'

    local flag="$1"; shift
    local _tp='am_temp'

    _play_from_filter() {
        # $1 = AppleScript filter clause; remaining = osascript argv
        # Searches both "Library" (local) and "Liked Music" (streaming saves)
        local clause="$1"; shift
        osascript \
            -e 'on run argv' \
            -e 'tell application "Music"' \
            -e "if (exists playlist \"$_tp\") then delete playlist \"$_tp\"" \
            -e "set name of (make new playlist) to \"$_tp\"" \
            -e "set theseTracks to {}" \
            -e 'try' \
            -e "  set theseTracks to theseTracks & (every track of playlist \"Library\" ${clause})" \
            -e 'end try' \
            -e 'try' \
            -e "  set theseTracks to theseTracks & (every track of playlist \"Liked Music\" ${clause})" \
            -e 'end try' \
            -e 'if theseTracks is {} then return' \
            -e 'repeat with t in theseTracks' \
            -e "duplicate t to playlist \"$_tp\"" \
            -e 'end repeat' \
            -e "play playlist \"$_tp\"" \
            -e 'end tell' \
            -e 'end' "$@"
    }

    case "$flag" in
        -p)
            local playlist
            if [[ "$#" -eq 0 ]]; then
                playlist=$(osascript -e 'tell application "Music" to get name of playlists' \
                    | tr ',' '\n' | sed 's/^ //' | fzf --prompt="Playlist > " --height=20)
                [[ -z "$playlist" ]] && { unfunction _play_from_filter; return 0; }
                set -- "$playlist"
            fi
            osascript -e 'on run argv
                tell application "Music" to play playlist (item 1 of argv)
            end' "$@" ;;
        -s)
            local song
            if [[ "$#" -eq 0 ]]; then
                song=$(_all_track_names | fzf --prompt="Song > " --height=20)
                [[ -z "$song" ]] && { unfunction _play_from_filter; return 0; }
                set -- "$song"
            fi
            osascript -e 'on run argv' \
                -e 'set targetName to item 1 of argv' \
                -e 'tell application "Music"' \
                -e '  set res to (tracks whose name is targetName)' \
                -e '  if res is {} then' \
                -e '    repeat with pl in playlists' \
                -e '      try' \
                -e '        set res to (tracks of pl whose name is targetName)' \
                -e '        if res is not {} then exit repeat' \
                -e '      end try' \
                -e '    end repeat' \
                -e '  end if' \
                -e '  if res is not {} then play (item 1 of res)' \
                -e 'end tell' \
                -e 'end' "$@" ;;
        -r)
            local record
            if [[ "$#" -eq 0 ]]; then
                record=$(osascript -e 'tell application "Music" to get album of every track' \
                    | tr ',' '\n' | sort | awk '!seen[$0]++' | sed 's/^ //' | fzf --prompt="Album > " --height=20)
                [[ -z "$record" ]] && { unfunction _play_from_filter; return 0; }
                set -- "$record"
            fi
            _play_from_filter 'whose album is (item 1 of argv)' "$@" ;;
        -a)
            local artist
            if [[ "$#" -eq 0 ]]; then
                artist=$(osascript -e 'tell application "Music" to get artist of every track' \
                    | tr ',' '\n' | sort | awk '!seen[$0]++' | sed 's/^ //' | fzf --prompt="Artist > " --height=20)
                [[ -z "$artist" ]] && { unfunction _play_from_filter; return 0; }
                set -- "$artist"
            fi
            _play_from_filter 'whose artist is (item 1 of argv)' "$@" ;;
        -g)
            local genre
            if [[ "$#" -eq 0 ]]; then
                genre=$(osascript -e 'tell application "Music" to get genre of every track' \
                    | tr ',' '\n' | sort | awk '!seen[$0]++' | sed 's/^ //' | fzf --prompt="Genre > " --height=20)
                [[ -z "$genre" ]] && { unfunction _play_from_filter; return 0; }
                set -- "$genre"
            fi
            _play_from_filter 'whose genre is (item 1 of argv)' "$@" ;;
        -l)
            osascript -e 'tell application "Music" to play playlist "Library"' ;;
        *) printf '%s\n' "$usage" ;;
    esac

    unfunction _play_from_filter
}

# ---------------------------------------------------------------------------
# add — add the currently playing track to a user playlist
# ---------------------------------------------------------------------------
add() {
    local usage="Usage: add [PLAYLIST | --new PLAYLIST]

  (no args)             Fzf-pick a user playlist and add the current track.
  PLAYLIST              Add current track directly to PLAYLIST (must exist).
  --new PLAYLIST        Create PLAYLIST if needed, then add current track."

    local target new_playlist=false
    case "${1:-}" in
        --new)
            [[ -z "$2" ]] && { printf '%s\n' "$usage"; return 1; }
            new_playlist=true
            target="$2" ;;
        ""|-h|--help)
            [[ "${1:-}" == "" ]] && { _need fzf || return 1
                target=$(osascript -e 'tell application "Music" to get name of user playlists' \
                    2>/dev/null | tr ',' '\n' | sed 's/^ //' | sort \
                    | fzf --prompt="Add to playlist > " --height=20)
                [[ -z "$target" ]] && return 0
            } || { printf '%s\n' "$usage"; return 0; } ;;
        *)
            target="$*" ;;
    esac

    # Capture current track info before any AppleScript that might change state
    local track_name artist_name
    track_name=$(osascript -e 'tell application "Music" to get name of current track' 2>/dev/null)
    artist_name=$(osascript -e 'tell application "Music" to get artist of current track' 2>/dev/null)

    if [[ -z "$track_name" ]]; then
        print -u2 "No track currently playing."; return 1
    fi

    # Library-first workflow: streaming URL tracks can't be duplicated directly to
    # user playlists; they must be added to the Library source first, then re-found
    # by name+artist and duplicated to the target playlist.
    local result
    result=$(osascript -e 'on run argv' \
        -e 'set trackName  to item 1 of argv' \
        -e 'set artistName to item 2 of argv' \
        -e 'set targetPl   to item 3 of argv' \
        -e 'set makeNew    to item 4 of argv' \
        -e 'tell application "Music"' \
        -e '  -- Create playlist if requested' \
        -e '  if makeNew is "true" and not (exists user playlist targetPl) then' \
        -e '    set name of (make new playlist) to targetPl' \
        -e '  end if' \
        -e '  if not (exists user playlist targetPl) then' \
        -e '    return "error: playlist not found: " & targetPl' \
        -e '  end if' \
        -e '  -- Add to library (no-op if already there; use library playlist 1, not source "Library")' \
        -e '  try' \
        -e '    duplicate current track to library playlist 1' \
        -e '  end try' \
        -e '  delay 4' \
        -e '  -- Re-find by name + artist in the library' \
        -e '  set found to (every track of library playlist 1 whose name is trackName and artist is artistName)' \
        -e '  if found is {} then' \
        -e '    return "error: track not found in library after add: " & trackName' \
        -e '  end if' \
        -e '  duplicate (item 1 of found) to user playlist targetPl' \
        -e '  return "ok"' \
        -e 'end tell' \
        -e 'end' \
        "$track_name" "$artist_name" "$target" "$new_playlist" 2>&1)

    case "$result" in
        ok)    echo "Added \"$track_name\" → $target" ;;
        error:*) print -u2 "${result#error: }"; return 1 ;;
        *)     print -u2 "$result"; return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# catalog — iTunes Search API-powered full catalog search (no auth required)
# ---------------------------------------------------------------------------
_catalog_open_in_music() {
    # Opens Music.app to the exact song page so the user can press play once.
    # Programmatic catalog playback via AppleScript is not possible without
    # UI automation or a paid MusicKit user token — this is Apple's design.
    local url="$1"
    osascript -e 'on run argv' \
        -e 'tell application "Music"' \
        -e '  activate' \
        -e '  open location (item 1 of argv)' \
        -e 'end tell' \
        -e 'end' "$url" 2>/dev/null
}

_catalog_add_to_library() {
    # Strategy: press Return to play the highlighted catalog track (album view),
    # then use AppleScript 'duplicate current track' to add it to the library.
    # The Song > Add to Library menu is only active when a track is playing —
    # it is greyed out when merely browsing a catalog page.
    #
    # Requires Accessibility permission for iTerm2.
    local access_err
    access_err=$(osascript \
        -e 'tell application "System Events"' \
        -e '  tell process "Music"' \
        -e '    keystroke return' \
        -e '  end tell' \
        -e 'end tell' 2>&1)
    if [[ "$access_err" == *"not allowed"* || "$access_err" == *"accessibility"* \
          || "$access_err" == *"1002"* ]]; then
        return 1
    fi

    # Wait up to 8 seconds for the catalog track to start playing
    local i state
    for i in $(seq 1 8); do
        sleep 1
        state=$(osascript -e 'tell application "Music" to get player state as string' 2>/dev/null)
        [[ "$state" == "playing" ]] && break
    done

    if [[ "$state" != "playing" ]]; then
        print -u2 "Track did not start playing after Return key."; return 1
    fi

    # Add currently playing catalog track to library (no-op if already there)
    osascript \
        -e 'tell application "Music"' \
        -e '  try' \
        -e '    duplicate current track to library playlist 1' \
        -e '  end try' \
        -e 'end tell' 2>/dev/null
    return 0
}

_catalog_wait_for_library() {
    # $1 = track name, $2 = artist name
    # Polls library playlist 1 until the track appears (up to 15 seconds).
    local tname="$1" tartist="$2" i found
    for i in $(seq 1 15); do
        sleep 1
        found=$(osascript -e 'on run argv' \
            -e 'set q to item 1 of argv' \
            -e 'set a to item 2 of argv' \
            -e 'set myTracks to {}' \
            -e 'tell application "Music"' \
            -e '  try' \
            -e '    set myTracks to myTracks & (every track of library playlist 1 whose name is q and artist is a)' \
            -e '  end try' \
            -e '  try' \
            -e '    set myTracks to myTracks & (every track of playlist "Liked Music" whose name is q and artist is a)' \
            -e '  end try' \
            -e '  return (count of myTracks) as string' \
            -e 'end tell' \
            -e 'end' "$tname" "$tartist" 2>/dev/null)
        [[ "${found:-0}" -ge 1 ]] && return 0
    done
    return 1
}

_itunes_search() {
    # $1 = search term, $2 = limit (default 15)
    # Uses the public iTunes Search API — no auth, no account needed.
    local term="$1" limit="${2:-15}"
    local encoded
    encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$term")
    curl -sS --max-time 8 \
        "https://itunes.apple.com/search?term=${encoded}&media=music&entity=song&limit=${limit}" \
        2>/dev/null
}

catalog() {
    local usage="Usage: catalog search QUERY

  search QUERY          Search the full Apple Music / iTunes catalog (no setup
                        required). Picks a song in fzf, adds it to your library
                        automatically, then starts playing — no manual steps.

  Requires: Accessibility permission for iTerm2
    System Settings > Privacy & Security > Accessibility → enable iTerm2"

    case "${1:-}" in
        search)
            shift
            [[ -z "$*" ]] && { printf '%s\n' "$usage"; return 1; }
            _need fzf  || return 1
            _need curl || return 1
            local query="$*"
            local raw
            raw=$(_itunes_search "$query" 20)
            if [[ -z "$raw" ]]; then
                print -u2 "No response from iTunes Search API. Check your network."; return 1
            fi
            # Parse results into "Song – Artist (Album)\tCOLLECTION_ID\tTRACK_ID\tVIEW_URL"
            local entries
            entries=$(echo "$raw" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for r in d.get("results", []):
    name    = r.get("trackName", "?")
    artist  = r.get("artistName", "?")
    album   = r.get("collectionName", "?")
    tid     = str(r.get("trackId", ""))
    cid     = str(r.get("collectionId", ""))
    viewurl = r.get("trackViewUrl", "")
    if tid and cid:
        print(f"{name} \u2013 {artist} ({album})\t{cid}\t{tid}\t{viewurl}")
' 2>/dev/null)
            if [[ -z "$entries" ]]; then
                print -u2 "No songs found for: $query"; return 1
            fi
            local selected
            selected=$(echo "$entries" | cut -f1 \
                | fzf --prompt="Catalog > " --height=20 \
                      --header="Apple Music catalog — select to add to library and play")
            [[ -z "$selected" ]] && return 0
            local cid tid view_url am_url
            cid=$(echo "$entries"      | awk -F'\t' -v s="$selected" '$1==s{print $2; exit}')
            tid=$(echo "$entries"      | awk -F'\t' -v s="$selected" '$1==s{print $3; exit}')
            view_url=$(echo "$entries" | awk -F'\t' -v s="$selected" '$1==s{print $4; exit}')
            am_url="https://music.apple.com/song/${tid}"

            # Parse track name and artist from "Song – Artist (Album)"
            local track_name artist_name
            track_name=$(echo "$selected" | sed 's/ – .*$//')
            artist_name=$(echo "$selected" | sed 's/^[^–]* – //' | sed 's/ (.*)//')

            # Record frontmost app so we can restore focus after Music.app opens
            local prev_app
            prev_app=$(osascript \
                -e 'tell application "System Events" to get name of first process whose frontmost is true' \
                2>/dev/null)

            echo "Opening in Music.app: $selected"
            _catalog_open_in_music "itmss://geo.music.apple.com/album/${cid}?i=${tid}&app=music"

            # Wait for Music.app to render the song page, then add to library
            sleep 2
            echo "Adding to library..."
            if ! _catalog_add_to_library; then
                echo ""
                print -u2 "Could not click 'Add to Library' — Accessibility permission needed."
                print -u2 "  System Settings > Privacy & Security > Accessibility → enable iTerm2"
                echo ""
                echo "Music.app is showing the song. Add it manually, then run:"
                echo "  am play -s \"$track_name\""
                return 1
            fi

            # Minimize Music.app and restore previous app focus
            _catalog_restore_focus() {
                osascript -e 'tell application "Music" to set miniaturized of window 1 to true' 2>/dev/null
                [[ -n "$prev_app" && "$prev_app" != "Music" ]] && \
                    osascript -e "tell application \"$prev_app\" to activate" 2>/dev/null
            }

            # Poll library until the track appears (up to 12 s)
            echo "Waiting for library sync..."
            if _catalog_wait_for_library "$track_name" "$artist_name"; then
                _catalog_restore_focus
                echo "Playing: $track_name"
                osascript -e 'on run argv' \
                    -e 'set q to item 1 of argv' \
                    -e 'set myTracks to {}' \
                    -e 'tell application "Music"' \
                    -e '  try' \
                    -e '    set myTracks to (every track of library playlist 1 whose name is q)' \
                    -e '  end try' \
                    -e '  if myTracks is not {} then play (item 1 of myTracks)' \
                    -e 'end tell' \
                    -e 'end' "$track_name" 2>/dev/null
            else
                # Sync timed out — still restore focus, give fallback command
                _catalog_restore_focus
                echo "Track added (library sync still in progress)."
                echo "Run when ready:  am play -s \"$track_name\""
            fi
            unfunction _catalog_restore_focus
            ;;

        *) printf '%s\n' "$usage" ;;
    esac
}

# ---------------------------------------------------------------------------
# volume — get or set Music.app playback volume
# ---------------------------------------------------------------------------
volume() {
    local usage="Usage: volume [up|down|N]

  (no args)             Show current volume (0-100).
  up                    Increase by 5%.
  down                  Decrease by 5%.
  N                     Set volume to N (0-100)."

    case "${1:-}" in
        "")
            osascript -e 'tell application "Music" to get sound volume' ;;
        up)
            osascript -e 'tell application "Music" to set sound volume to sound volume + 5' ;;
        down)
            osascript -e 'tell application "Music" to set sound volume to sound volume - 5' ;;
        [0-9]|[0-9][0-9]|100)
            osascript -e "tell application \"Music\" to set sound volume to $1" ;;
        *)
            printf '%s\n' "$usage"; return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# output — switch SYSTEM audio output device (hardware only, no virtual loopback)
# ---------------------------------------------------------------------------

# Genuine hardware output devices: filter out virtual/loopback devices that
# appear with the same device ID in both the input and output lists.
_hw_outputs() {
    _need SwitchAudioSource switchaudio-osx || return 1
    SwitchAudioSource -a -f json 2>/dev/null | python3 -c "
import sys, json
devs = []
for line in sys.stdin:
    line = line.strip()
    if line:
        try: devs.append(json.loads(line))
        except: pass
input_ids  = {d['id'] for d in devs if d['type'] == 'input'}
output_ids = {d['id'] for d in devs if d['type'] == 'output'}
virtual    = input_ids & output_ids   # same ID in both = loopback/virtual
for d in devs:
    if d['type'] == 'output' and d['id'] not in virtual:
        print(d['name'])
"
}

output() {
    _need fzf || return 1
    _need SwitchAudioSource switchaudio-osx || return 1

    if [[ "${1:-}" == "--list" ]]; then
        local current
        current=$(SwitchAudioSource -c 2>/dev/null)
        echo "System audio output devices (* = current):"
        _hw_outputs | while IFS= read -r dev; do
            [[ "$dev" == "$current" ]] && echo "* $dev" || echo "  $dev"
        done
        echo ""
        echo "For Music.app-specific AirPlay routing, use: am airplay --list"
        return 0
    fi

    local selected
    if [[ "$#" -eq 0 ]]; then
        selected=$(_hw_outputs \
            | fzf --prompt="System Output > " --height=20 \
                  --header="Real hardware outputs only. For Music.app AirPlay use: am airplay" \
                  --print-query | tail -1)
        [[ -z "$selected" ]] && return 0
    else
        selected="$*"
    fi

    if SwitchAudioSource -s "$selected" 2>/dev/null; then
        echo "System output switched to: $selected"
    else
        echo "Not a hardware device — attempting AirPlay switch via Control Center…"
        if osascript "$SCRIPT_DIR/switch-output.applescript" "$selected"; then
            echo "System output switched to: $selected"
        else
            print -u2 "Failed. Grant Terminal Accessibility access:"
            print -u2 "  System Settings → Privacy & Security → Accessibility"
            return 1
        fi
    fi
}

# ---------------------------------------------------------------------------
# airplay — Music.app-native AirPlay output routing (independent of system output)
# ---------------------------------------------------------------------------
airplay() {
    local usage="Usage: airplay [--list | DEVICE | off]

  (no args)             Fzf-select a Music.app AirPlay output (exclusive switch).
  --list                List available AirPlay outputs with active status.
  DEVICE                Route Music.app audio to DEVICE exclusively.
  off                   Stop AirPlay; play through the local Mac speakers."

    _am_airplay_devices() {
        # Returns lines of "* Name (kind)" or "  Name (kind)"
        # Bulk property reads avoid the 'kind as string' coercion failure in loops
        local names selected kinds
        names=$(osascript -e 'tell application "Music" to get name of AirPlay devices' \
            | tr ',' '\n' | sed 's/^ //')
        selected=$(osascript -e 'tell application "Music" to get selected of AirPlay devices' \
            | tr ',' '\n' | sed 's/^ //')
        kinds=$(osascript -e 'tell application "Music" to get kind of AirPlay devices' \
            | tr ',' '\n' | sed 's/^ //')
        paste <(printf '%s\n' ${(f)names}) \
              <(printf '%s\n' ${(f)selected}) \
              <(printf '%s\n' ${(f)kinds}) \
        | while IFS=$'\t' read -r nm sel knd; do
            [[ "$sel" == "true" ]] && echo "* $nm ($knd)" || echo "  $nm ($knd)"
        done
    }

    _am_airplay_switch() {
        # $1 = device name to activate exclusively, or "" to route to computer
        # Uses on-run argv to avoid injection with names containing quotes (e.g. 55" TV)
        # Retries up to 3 times: Music.app returns -50 (parameter error) when a device
        # is in a transient connecting/disconnecting state on the network.
        local target="$1" attempt err
        local -a cmd
        if [[ -z "$target" ]]; then
            cmd=(osascript
                -e 'tell application "Music"'
                -e '  repeat with d in AirPlay devices'
                -e '    set selected of d to (kind of d is computer)'
                -e '  end repeat'
                -e 'end tell')
        else
            cmd=(osascript -e 'on run argv'
                -e 'tell application "Music"'
                -e '  repeat with d in AirPlay devices'
                -e '    set selected of d to (name of d is (item 1 of argv))'
                -e '  end repeat'
                -e 'end tell'
                -e 'end' "$target")
        fi
        for attempt in 1 2 3; do
            err=$("${cmd[@]}" 2>&1) && return 0
            [[ "$err" != *"-50"* ]] && { print -u2 "$err"; return 1; }
            (( attempt < 3 )) && sleep 2
        done
        print -u2 "$err"; return 1
    }

    case "${1:-}" in
        --list)
            echo "Music.app AirPlay outputs (* = currently active):"
            _am_airplay_devices | sed 's/^/  /'
            ;;
        off)
            _am_airplay_switch "" && echo "Music output: switched to local Mac speakers" ;;
        "")
            _need fzf || return 1
            local devices raw selected
            raw=$(_am_airplay_devices)
            [[ -z "$raw" ]] && { print -u2 "No AirPlay devices found in Music.app."; return 1; }
            selected=$(printf '%s\n' "$raw" \
                | fzf --prompt="Music Output > " --height=20 \
                      --header="* = active  |  Tab=multi-select not supported; select one")
            [[ -z "$selected" ]] && return 0
            # Strip marker and kind suffix  "* Name (kind)" → "Name"
            local devname
            devname=$(echo "$selected" | sed 's/^[* ] //' | sed 's/ ([^)]*)$//')
            _am_airplay_switch "$devname" && echo "Music output → $devname"
            ;;
        *)
            _am_airplay_switch "$*" && echo "Music output → $*" \
                || { printf '%s\n' "$usage"; return 1; }
            ;;
    esac

    unfunction _am_airplay_devices _am_airplay_switch
}

# ---------------------------------------------------------------------------
# Top-level dispatch
# ---------------------------------------------------------------------------
_usage="Usage: am [command] [options]

  play -s [PATTERN]     Fzf/play a song.
  play -r [PATTERN]     Fzf/play an album.
  play -a [PATTERN]     Fzf/play by artist.
  play -p [PATTERN]     Fzf/play a playlist.
  play -g [PATTERN]     Fzf/play by genre.
  play -l               Play entire library.
  play ... -S           Enable shuffle before playback.

  list -s               List all songs.
  list -r [PATTERN]     List albums or songs in album.
  list -a [PATTERN]     List artists or songs by artist.
  list -p [PATTERN]     List playlists or songs in playlist.
  list -g [PATTERN]     List genres or songs in genre.

  np                    Open Now Playing TUI.
  np -t                 Now Playing TUI (text-only, no album art).

  pause                 Pause playback.
  resume                Resume playback.
  stop                  Stop playback.

  volume                Show current volume (0-100).
  volume up             Increase volume by 5%.
  volume down           Decrease volume by 5%.
  volume N              Set volume to N (0-100).

  output                Fzf-select system audio output device.
  output --list         List real hardware output devices (no virtual/loopback).
  output DEVICE         Switch system output to DEVICE.

  airplay               Fzf-select Music.app AirPlay output (music-only routing).
  airplay --list        List Music.app AirPlay outputs with active status.
  airplay DEVICE        Route Music.app audio to DEVICE exclusively.
  airplay off           Stop AirPlay; play through Mac speakers.

  add                   Fzf-pick a playlist and add the current track.
  add PLAYLIST          Add current track to PLAYLIST directly.
  add --new PLAYLIST    Create PLAYLIST if needed and add current track.

  catalog search QUERY  Search iTunes catalog → fzf → auto-add to library → play.
                        No account required. Needs Accessibility permission for iTerm2.

  check                 Verify all dependencies are installed."

if [[ "$#" -eq 0 ]]; then
    printf '%s\n' "$_usage"
else
    case "$1" in
        np)     shift; np "$@" ;;
        list)   shift; list "$@" ;;
        play)   shift; play "$@" ;;
        output)  shift; output "$@" ;;
        airplay) shift; airplay "$@" ;;
        pause)   osascript -e 'tell application "Music" to pause' ;;
        resume) osascript -e 'tell application "Music" to play' ;;
        stop)   osascript -e 'tell application "Music" to stop' ;;
        volume) shift; volume "$@" ;;
        add)     shift; add "$@" ;;
        catalog) shift; catalog "$@" ;;
        check)   _check_deps ;;
        *)      printf '%s\n' "$_usage" ;;
    esac
fi
