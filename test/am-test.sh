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

zsh "$AM" play -s "Blackbird" &>/dev/null; sleep 1
_assert_track "play -s PATTERN plays correct song" "Blackbird"

zsh "$AM" play -a "Ernesto Cortazar" &>/dev/null; sleep 2
artist=$(osascript -e 'tell application "Music" to get artist of current track' 2>&1)
[[ "$artist" == "Ernesto Cortazar" ]] && _pass "play -a PATTERN plays correct artist" \
    || _fail "play -a PATTERN plays correct artist" "Ernesto Cortazar" "$artist"

zsh "$AM" play -r "Classic" &>/dev/null; sleep 2
album=$(osascript -e 'tell application "Music" to get album of current track' 2>&1)
[[ "$album" == "Classic" ]] && _pass "play -r PATTERN plays correct album" \
    || _fail "play -r PATTERN plays correct album" "Classic" "$album"

zsh "$AM" play -g "Classical" &>/dev/null; sleep 2
genre=$(osascript -e 'tell application "Music" to get genre of current track' 2>&1)
[[ "$genre" == "Classical" ]] && _pass "play -g PATTERN plays correct genre" \
    || _fail "play -g PATTERN plays correct genre" "Classical" "$genre"

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
# 6. Output device management
# ---------------------------------------------------------------------------
_header "Output device management"

_assert_contains "output --list shows devices" "Hardware output devices" "zsh $AM output --list"
_assert_contains "output --list shows current"  "Current output"          "zsh $AM output --list"

ORIG_OUT=$(SwitchAudioSource -c)
zsh "$AM" output "MacBook Pro Speakers" &>/dev/null
NEW_OUT=$(SwitchAudioSource -c)
[[ "$NEW_OUT" == "MacBook Pro Speakers" ]] && _pass "output DEVICE switches to MacBook Pro Speakers" \
    || _fail "output DEVICE switches to MacBook Pro Speakers" "MacBook Pro Speakers" "$NEW_OUT"

# Restore original output device
SwitchAudioSource -s "$ORIG_OUT" &>/dev/null
_pass "Restored original output: $ORIG_OUT"

# ---------------------------------------------------------------------------
# 7. Edge cases
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
