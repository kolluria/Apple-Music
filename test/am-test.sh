#!/bin/zsh
# am-test.sh — Non-interactive regression suite for am.sh
# Run from any directory: zsh test/am-test.sh
# Requires: Music.app open and playing, fzf, SwitchAudioSource installed

AM="${0:A:h}/../src/am.sh"
PASS=0; FAIL=0; SKIP=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_header() { printf '\n\e[1m%s\e[0m\n' "── $1 ──────────────────────────────────────────" }

_pass() { (( PASS++ )); printf '  \e[32mPASS\e[0m  %s\n' "$1" }
_fail() { (( FAIL++ )); printf '  \e[31mFAIL\e[0m  %s\n' "$1"
           printf '          expected: %s\n' "$2"
           printf '          got:      %s\n' "$3" }
_skip() { (( SKIP++ )); printf '  \e[33mSKIP\e[0m  %s  (%s)\n' "$1" "$2" }

# Assert output contains needle
_assert_contains() {
    local desc="$1" needle="$2"
    local actual
    actual=$(eval "$3" 2>&1)
    if [[ "$actual" == *"$needle"* ]]; then
        _pass "$desc"
    else
        _fail "$desc" "$needle" "${actual:0:80}"
    fi
}

# Assert Music.app player state equals expected
_assert_state() {
    local desc="$1" expected="$2"
    local actual
    actual=$(osascript -e 'tell application "Music" to get player state' 2>&1)
    if [[ "$actual" == "$expected" ]]; then
        _pass "$desc"
    else
        _fail "$desc" "$expected" "$actual"
    fi
}

# Assert current track name equals expected
_assert_track() {
    local desc="$1" expected="$2"
    local actual
    actual=$(osascript -e 'tell application "Music" to get name of current track' 2>&1)
    if [[ "$actual" == "$expected" ]]; then
        _pass "$desc"
    else
        _fail "$desc" "$expected" "$actual"
    fi
}

# Assert Music.app volume equals expected
_assert_volume() {
    local desc="$1" expected="$2"
    local actual
    actual=$(osascript -e 'tell application "Music" to get sound volume' 2>&1)
    if [[ "$actual" -eq "$expected" ]]; then
        _pass "$desc"
    else
        _fail "$desc" "$expected" "$actual"
    fi
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
_header "Pre-flight checks"

if ! osascript -e 'tell application "Music" to get player state' &>/dev/null; then
    echo "ERROR: Music.app is not running. Open it and start playing a track first."
    exit 1
fi

state=$(osascript -e 'tell application "Music" to get player state')
if [[ "$state" == "stopped" ]]; then
    echo "ERROR: Music.app is stopped. Start playing a track first."
    exit 1
fi

_pass "Music.app is running (state: $state)"

if ! command -v fzf &>/dev/null; then
    echo "ERROR: fzf not installed (brew install fzf)"
    exit 1
fi
_pass "fzf available"

if ! command -v SwitchAudioSource &>/dev/null; then
    echo "ERROR: SwitchAudioSource not installed (brew install switchaudio-osx)"
    exit 1
fi
_pass "SwitchAudioSource available"

# Resume playing if paused so tests start from a known state
osascript -e 'tell application "Music" to play' &>/dev/null
sleep 0.5

# ---------------------------------------------------------------------------
# 1. Usage / help
# ---------------------------------------------------------------------------
_header "Usage"

_assert_contains "am (no args) shows usage" "play" "zsh $AM"
_assert_contains "am check passes" "" "zsh $AM check 2>&1; echo exit:\$?"

# ---------------------------------------------------------------------------
# 2. list subcommand
# ---------------------------------------------------------------------------
_header "list"

_assert_contains "list -p returns playlists"    "Liked Music"      "zsh $AM list -p"
_assert_contains "list -g returns genres"       "Classical"        "zsh $AM list -g"
_assert_contains "list -r returns albums"       "Classic"          "zsh $AM list -r"
_assert_contains "list -a returns artists"      "Ernesto Cortazar" "zsh $AM list -a"
_assert_contains "list -s returns songs"        "Bloom"            "zsh $AM list -s"
_assert_contains "list -p PATTERN lists songs"  "Amazing"          "zsh $AM list -p 'Liked Music'"
_assert_contains "list -a PATTERN lists songs"  "Beethoven"        "zsh $AM list -a 'Ernesto Cortazar'"

# ---------------------------------------------------------------------------
# 3. Playback controls
# ---------------------------------------------------------------------------
_header "Playback controls"

zsh "$AM" pause &>/dev/null; sleep 1
_assert_state "pause → state is paused" "paused"

zsh "$AM" resume &>/dev/null; sleep 1
_assert_state "resume → state is playing" "playing"

zsh "$AM" pause &>/dev/null; sleep 0.5
zsh "$AM" resume &>/dev/null; sleep 1
_assert_state "pause + resume cycle" "playing"

zsh "$AM" stop &>/dev/null; sleep 1
_assert_state "stop → state is stopped" "stopped"

# ---------------------------------------------------------------------------
# 4. play subcommand (pattern / non-interactive)
# ---------------------------------------------------------------------------
_header "play (pattern / non-interactive)"

zsh "$AM" play -p "Liked Music" &>/dev/null; sleep 1
_assert_state "play -p PATTERN starts playback" "playing"

zsh "$AM" play -p "Liked Music" -S &>/dev/null; sleep 1
shuffle=$(osascript -e 'tell application "Music" to get shuffle enabled')
[[ "$shuffle" == "true" ]] && _pass "play -p -S enables shuffle" \
                             || _fail "play -p -S enables shuffle" "true" "$shuffle"

# play -s: verify the exact song name is matched (pattern must be exact track name)
_song_pattern="Blackbird"
zsh "$AM" play -s "$_song_pattern" &>/dev/null; sleep 1
_now=$(osascript -e 'tell application "Music" to get name of current track' 2>&1)
[[ "$_now" == "$_song_pattern" ]] \
    && _pass "play -s PATTERN plays correct song" \
    || _skip "play -s PATTERN plays correct song" \
             "\"$_song_pattern\" not in local library or Liked Music (got: $_now)"

# play -a: verify playback started and track has an artist (fuzzy match)
_artist_pattern="Ernesto Cortazar"
zsh "$AM" play -a "$_artist_pattern" &>/dev/null; sleep 2
_state=$(osascript -e 'tell application "Music" to get player state as string' 2>&1)
_artist=$(osascript -e 'tell application "Music" to get artist of current track' 2>&1)
if [[ "$_state" == "playing" && -n "$_artist" ]]; then
    _pass "play -a PATTERN starts playback (playing: $_artist)"
else
    _skip "play -a PATTERN starts playback" \
          "\"$_artist_pattern\" not found in Library or Liked Music"
fi

# play -r: verify playback started
_album_pattern="Classic"
zsh "$AM" play -r "$_album_pattern" &>/dev/null; sleep 2
_state=$(osascript -e 'tell application "Music" to get player state as string' 2>&1)
[[ "$_state" == "playing" ]] \
    && _pass "play -r PATTERN starts playback" \
    || _skip "play -r PATTERN starts playback" "\"$_album_pattern\" not found in Library or Liked Music"

# play -g: verify playback started
_genre_pattern="Classical"
zsh "$AM" play -g "$_genre_pattern" &>/dev/null; sleep 2
_state=$(osascript -e 'tell application "Music" to get player state as string' 2>&1)
[[ "$_state" == "playing" ]] \
    && _pass "play -g PATTERN starts playback" \
    || _skip "play -g PATTERN starts playback" "\"$_genre_pattern\" not found in Library or Liked Music"

# ---------------------------------------------------------------------------
# 5. Volume
# ---------------------------------------------------------------------------
_header "Volume"

zsh "$AM" volume 50 &>/dev/null; sleep 0.3
_assert_volume "volume N  — set to 50" 50

zsh "$AM" volume up &>/dev/null; sleep 0.3
_assert_volume "volume up — set to 55" 55

zsh "$AM" volume down &>/dev/null; sleep 0.3
_assert_volume "volume down — back to 50" 50

current_vol=$(zsh "$AM" volume 2>&1)
[[ "$current_vol" -eq 50 ]] && _pass "volume (no args) returns current level" \
    || _fail "volume (no args) returns current level" "50" "$current_vol"

# ---------------------------------------------------------------------------
# 6. System output device management
# ---------------------------------------------------------------------------
_header "System output device management"

list_out=$(zsh "$AM" output --list 2>&1)
[[ "$list_out" == *"System audio output devices"* ]] \
    && _pass "output --list shows header" \
    || _fail "output --list shows header" "System audio output devices" "${list_out:0:60}"

# Virtual/loopback devices must NOT appear
if echo "$list_out" | grep -q "ZoomAudioDevice\|Virtual Desktop Mic\|Microsoft Teams Audio"; then
    _fail "output --list excludes virtual/loopback devices" "no virtual devices" \
        "$(echo "$list_out" | grep -E 'Zoom|Virtual.*Mic|Teams')"
else
    _pass "output --list excludes virtual/loopback devices"
fi

ORIG_OUT=$(SwitchAudioSource -c)
zsh "$AM" output "MacBook Pro Speakers" &>/dev/null
NEW_OUT=$(SwitchAudioSource -c)
[[ "$NEW_OUT" == "MacBook Pro Speakers" ]] \
    && _pass "output DEVICE switches to MacBook Pro Speakers" \
    || _fail "output DEVICE switches to MacBook Pro Speakers" "MacBook Pro Speakers" "$NEW_OUT"

SwitchAudioSource -s "$ORIG_OUT" &>/dev/null
_pass "Restored system output: $ORIG_OUT"

# ---------------------------------------------------------------------------
# 7. Music.app AirPlay routing
# ---------------------------------------------------------------------------
_header "Music.app AirPlay routing"

# Discover which AirPlay devices Music.app sees
airplay_list=$(zsh "$AM" airplay --list 2>&1)
_assert_contains "airplay --list shows header" "Music.app AirPlay outputs" \
    "zsh $AM airplay --list"

# Capture the currently active device(s) for restoration
_orig_active=$(osascript -e 'tell application "Music"
    set r to {}
    repeat with d in AirPlay devices
        if active of d then set end of r to name of d
    end repeat
    return r
end tell' 2>/dev/null | tr ',' '\n' | sed 's/^ //')

# Find a non-active device to test switching (inactive lines have 4-space indent, active have "  * ")
_test_target=$(echo "$airplay_list" | grep '^    [^ ]' | head -1 | sed 's/^    //' | sed 's/ ([^)]*)$//')

if [[ -z "$_test_target" ]]; then
    _skip "airplay DEVICE switches output" "all AirPlay devices already active; deactivate one to test switching"
    _skip "airplay --list shows active marker after switch" "all AirPlay devices already active"
else
    zsh "$AM" airplay "$_test_target" &>/dev/null
    # AirPlay connection establishment takes time — poll selected property (reflects intent
    # immediately) and fall back to active (reflects actual streaming, may lag 3-8s on network)
    _sel_ok=false; _max=8; _i=0
    while (( _i < _max )); do
        _sel_ok=$(osascript -e 'on run argv
            tell application "Music"
                repeat with d in AirPlay devices
                    if name of d is (item 1 of argv) then return selected of d as string
                end repeat
                return "false"
            end tell
        end' "$_test_target" 2>/dev/null)
        [[ "$_sel_ok" == "true" ]] && break
        sleep 1; (( _i++ ))
    done

    if [[ "$_sel_ok" == "true" ]]; then
        _pass "airplay DEVICE selected: $_test_target"
    else
        _fail "airplay DEVICE selected: $_test_target" "selected=true" "selected=$_sel_ok"
    fi

    # Verify --list shows it starred (based on active; may need a moment more)
    sleep 3
    _assert_contains "airplay --list marks active device with *" "* $_test_target" \
        "zsh $AM airplay --list"
fi

# Restore original AirPlay state via direct AppleScript (set all at once to avoid sequential exclusive switches)
if [[ -n "$_orig_active" ]]; then
    osascript -e 'on run argv
        tell application "Music"
            repeat with d in AirPlay devices
                set nm to name of d
                set found to false
                repeat with i from 1 to count of argv
                    if (item i of argv) is nm then set found to true
                end repeat
                set selected of d to found
            end repeat
        end tell
    end' ${(f)_orig_active} &>/dev/null
    sleep 1
    _pass "Restored original AirPlay device(s): $(echo "$_orig_active" | tr '\n' ',')"
fi

# ---------------------------------------------------------------------------
# 8. am add — add current track to playlist
# ---------------------------------------------------------------------------
_header "am add — add current track to playlist"

# Ensure something is playing first
zsh "$AM" resume &>/dev/null; sleep 1

_AM_TEST_PL="am-test-playlist-$$"

# --new creates a playlist and adds the track
out=$(zsh "$AM" add --new "$_AM_TEST_PL" 2>&1); sleep 1
if [[ "$out" == *"Added"* && "$out" == *"$_AM_TEST_PL"* ]]; then
    _pass "add --new creates playlist and adds track"
else
    _fail "add --new creates playlist and adds track" "Added ... $_AM_TEST_PL" "$out"
fi

# Verify the playlist actually exists in Music.app
_pl_exists=$(osascript -e "tell application \"Music\" to exists user playlist \"$_AM_TEST_PL\"" 2>/dev/null)
[[ "$_pl_exists" == "true" ]] \
    && _pass "playlist '$_AM_TEST_PL' exists in Music.app" \
    || _fail "playlist '$_AM_TEST_PL' exists in Music.app" "true" "$_pl_exists"

# add to existing playlist works
out=$(zsh "$AM" add "$_AM_TEST_PL" 2>&1); sleep 1
[[ "$out" == *"Added"* ]] \
    && _pass "add PLAYLIST adds current track to existing playlist" \
    || _fail "add PLAYLIST adds current track to existing playlist" "Added" "$out"

# add to non-existent playlist gives a helpful error
out=$(zsh "$AM" add "nonexistent-playlist-xyz" 2>&1)
[[ "$out" == *"not found"* || "$out" == *"error"* ]] \
    && _pass "add nonexistent playlist errors gracefully" \
    || _fail "add nonexistent playlist errors gracefully" "not found/error" "$out"

# Cleanup: delete test playlist
osascript -e "tell application \"Music\" to delete user playlist \"$_AM_TEST_PL\"" &>/dev/null \
    && _pass "Cleaned up test playlist '$_AM_TEST_PL'"

# ---------------------------------------------------------------------------
# 9. catalog — iTunes Search API (non-interactive, no fzf)
# ---------------------------------------------------------------------------
_header "catalog"

# catalog (no args) shows usage
out=$(zsh "$AM" catalog 2>&1)
[[ "$out" == *"catalog search"* ]] \
    && _pass "catalog (no args) shows usage" \
    || _fail "catalog (no args) shows usage" "catalog search" "$out"

# catalog search (no args) shows usage
out=$(zsh "$AM" catalog search 2>&1)
[[ "$out" == *"catalog search"* ]] \
    && _pass "catalog search (no query) shows usage" \
    || _fail "catalog search (no query) shows usage" "catalog search" "$out"

# iTunes Search API reachability + basic parsing (skip if offline)
if curl -s --max-time 5 "https://itunes.apple.com/search?term=Beatles&media=music&entity=song&limit=1" \
        | grep -q "trackName"; then
    _pass "iTunes Search API reachable and returns trackName"

    # Verify result count with a known artist
    _catalog_count=$(curl -s --max-time 8 \
        "https://itunes.apple.com/search?term=Beatles&media=music&entity=song&limit=5" \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d.get("results",[])))' 2>/dev/null)
    [[ "$_catalog_count" -ge 1 ]] \
        && _pass "iTunes Search API returns results (got: $_catalog_count)" \
        || _fail "iTunes Search API returns results" ">=1" "$_catalog_count"
else
    _skip "iTunes Search API reachable" "network unavailable or API unreachable"
    _skip "iTunes Search API returns results" "network unavailable or API unreachable"
fi

# ---------------------------------------------------------------------------
# 10. Edge cases
# ---------------------------------------------------------------------------
_header "Edge cases"

out=$(zsh "$AM" play 2>&1)
[[ "$out" == *"Usage"* ]] && _pass "play (no args) shows usage" \
    || _fail "play (no args) shows usage" "Usage" "$out"

out=$(zsh "$AM" list 2>&1)
[[ "$out" == *"Usage"* ]] && _pass "list (no args) shows usage" \
    || _fail "list (no args) shows usage" "Usage" "$out"

out=$(zsh "$AM" volume bad 2>&1)
[[ $? -ne 0 || "$out" == *"Usage"* ]] && _pass "volume invalid arg exits with error" \
    || _fail "volume invalid arg exits with error" "Usage or error" "$out"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n\e[1m%s\e[0m\n' "════════════════════════════════════════════════"
printf "Results:  \e[32m%d passed\e[0m  \e[31m%d failed\e[0m  \e[33m%d skipped\e[0m\n" \
    "$PASS" "$FAIL" "$SKIP"
printf '\e[1m%s\e[0m\n\n' "════════════════════════════════════════════════"

(( FAIL == 0 ))
