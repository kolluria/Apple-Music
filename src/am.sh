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
                if [[ -f "$ART_DIR/tmp.png" ]]; then
                    art=$(clear; viu -b "$ART_DIR/tmp.png" -w 31 -h 14)
                elif [[ -f "$ART_DIR/tmp.jpg" ]]; then
                    art=$(clear; viu -b "$ART_DIR/tmp.jpg" -w 31 -h 14)
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

        if $text_mode; then
            clear
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
                osascript -e 'tell application "Music" to get name of every track' \
                    | tr ',' '\n' | sort | awk '!seen[$0]++' | /usr/bin/pr -t -a -3
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
        local clause="$1"; shift
        osascript \
            -e 'on run argv' \
            -e 'tell application "Music"' \
            -e "if (exists playlist \"$_tp\") then delete playlist \"$_tp\" end if" \
            -e "set name of (make new playlist) to \"$_tp\"" \
            -e "set theseTracks to every track of playlist \"Library\" ${clause}" \
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
                song=$(osascript -e 'tell application "Music" to get name of every track' \
                    | tr ',' '\n' | sed 's/^ //' | fzf --prompt="Song > " --height=20)
                [[ -z "$song" ]] && { unfunction _play_from_filter; return 0; }
                set -- "$song"
            fi
            osascript -e 'on run argv
                tell application "Music" to play track (item 1 of argv)
            end' "$@" ;;
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
# output — switch system audio output device (hardware or AirPlay)
# ---------------------------------------------------------------------------
output() {
    _need fzf || return 1
    _need SwitchAudioSource switchaudio-osx || return 1

    local selected
    if [[ "$#" -eq 0 ]]; then
        local hw_devices
        hw_devices=$(SwitchAudioSource -t output -a 2>/dev/null)
        # --print-query so the user can also type an AirPlay device name not in the list
        selected=$(printf '%s\n' "$hw_devices" \
            | fzf --prompt="Audio Output > " --height=20 \
                  --header="Hardware devices listed. Type any AirPlay device name to switch to it." \
                  --print-query | tail -1)
        [[ -z "$selected" ]] && return 0
    else
        selected="$*"
    fi

    # Try direct hardware switch first; AirPlay falls back to UI automation
    if SwitchAudioSource -s "$selected" 2>/dev/null; then
        echo "Output switched to: $selected"
    else
        echo "Attempting AirPlay switch via Control Center (requires Accessibility permission)…"
        if osascript "$SCRIPT_DIR/switch-output.applescript" "$selected"; then
            echo "Output switched to: $selected"
        else
            print -u2 "Failed. Grant Terminal Accessibility access:"
            print -u2 "  System Settings → Privacy & Security → Accessibility"
            return 1
        fi
    fi
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

  output                Fzf-select audio output device.
  output DEVICE         Switch directly to DEVICE (hardware or AirPlay).

  check                 Verify all dependencies are installed."

if [[ "$#" -eq 0 ]]; then
    printf '%s\n' "$_usage"
else
    case "$1" in
        np)     shift; np "$@" ;;
        list)   shift; list "$@" ;;
        play)   shift; play "$@" ;;
        output) shift; output "$@" ;;
        pause)  osascript -e 'tell application "Music" to pause' ;;
        resume) osascript -e 'tell application "Music" to play' ;;
        stop)   osascript -e 'tell application "Music" to stop' ;;
        check)  _check_deps ;;
        *)      printf '%s\n' "$_usage" ;;
    esac
fi
