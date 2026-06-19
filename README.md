# Apple Music CLI Player

*Tested on macOS 12 & 13 (likely to work on macOS 10.15, 11). **Can be called with the system default zsh.** I recommend aliasing am.sh to `alias am=zsh path/to/am.sh`, or moving its three individual functions into your .zshrc.*

**Goal:** Provide a simple command-line interface to listing out, playing songs from, and utilizing controls for Music.app.  I decided against using a library such as ncurses to build a full TUI application, as I think it is preferable to interface via quick commands and a light "widget".

<img src="np.png" width="800"/>

## Quick Start

```sh
alias am='zsh /path/to/src/am.sh'
am check   # verify all dependencies are installed
```

Required: [fzf](https://github.com/junegunn/fzf), [SwitchAudioSource](https://github.com/deweller/switchaudio-osx) (`brew install fzf switchaudio-osx`)  
Optional: [Viu](https://github.com/atanunq/viu) (`brew install viu`) — needed for album art in `np`

See [common-usages.md](common-usages.md) for a quick reference of day-to-day commands.

## Now Playing (np)

Enjoy a simple "Now Playing" widget from your terminal.  Uses standard Unix tooling/piping, AppleScript for interfacing with Apple Music, and [Viu](https://github.com/atanunq/viu) for displaying the album art images.  It also includes keyboard shortcut bindings for basic playback controls.  Apart from toggling shuffle, toggling repeat, and changing the Music.app-specific volume, the other controls are already accessible from the special Fn key functions/touch bar.  

Dependencies: [Viu](https://github.com/atanunq/viu) (unless you always use text mode)

Configuration: 

* `album-art.applescript` lives in `src/` alongside `am.sh` — no additional setup needed.
* (Optional) In the np() func of am.sh, adjust the `-h` dimension of the album art (look for the two calls to `viu`) to ensure a square appearance with your terminal emulator's line spacing

Usage (aliased): `am np`

Usage (not aliased): `zsh am.sh np`
```
np                    Open the "Now Playing" TUI widget.
                      (Music.app track must be actively
		      playing or paused)
np -t		      Open in text mode (disables album art)

np keybindings:

p                     Play / Pause
f                     Forward one track
b                     Backward one track
>                     Begin fast forwarding current track
<                     Begin rewinding current track
R                     Resume normal playback
+                     Increase Music.app volume 5%
-                     Decrease Music.app volume 5%
s                     Toggle shuffle
r                     Toggle song repeat
o                     Switch system audio output device
q                     Quit np
Q                     Quit np and Music.app
?                     Show / hide keybindings
```

Notes: 
* Attempting to play the previous track with an empty queue will kill the script
* album-art.applescript is a modified version of [this script,](https://dougscripts.com/itunes/2014/10/save-current-tracks-artwork/) written by AppleScript wizard [Doug Adams](https://dougscripts.com/itunes/faq_cont.php)♡

## List

List out all song groupings of a specific type or all songs of a specific song grouping in your library.  The song grouping type is dictated by the flag you pass. By calling list without specifying a title after the flag, you will see a printout of all the titles of that flag's collection type. 

Usage (aliased): `am list [-grouping] [name]`

Usage (not aliased): `zsh am.sh list [-grouping] [name]`
```
list -s               List all songs in your library.
list -r               List all records.
list -r PATTERN       List all songs in the record PATTERN.
list -a               List all artists.
list -a PATTERN       List all songs by the artist PATTERN.
list -p               List all playlists.
list -p PATTERN       List all songs in the playlist PATTERN.
list -g               List all genres.
list -g PATTERN       List all songs in the genre PATTERN.
```
Example: `am list -r In Rainbows` (not case-sensitive; partial matches work)

Notes: 
* Music.app does not need to be open or closed; it should launch itself silently when `list` is called
* Searches both the local Library and Liked Music playlist (covers local and streaming tracks)
* Remember to escape any special characters or punctuation if passing a title (or wrap it in double quotes)
* Multi-word names can be passed unquoted: `am list -a Ernesto Cortazar`

## Play

Begin playback of different song groupings or a specific song grouping in your library. The song grouping type is dictated by the flag you pass.  By calling play without specifying a title after the flag, you are prompted to select a title of that flag's collection type on the fly via [fzf](https://github.com/junegunn/fzf). Unfortunately there is no simple way to play, for example, a specific album or songs from a specific artist with AppleScript, but I was able to modify code shared by a "jccc" [here](https://discussions.apple.com/thread/1053355), as a workaround which involves automatically creating a single temporary playlist in your library that is utilized by play().

Dependencies: [fzf](https://github.com/junegunn/fzf) (unless you always play groupings by name)

Usage (aliased): `am play [-grouping] [name] [-S]`

Usage (not aliased): `zsh am.sh play [-grouping] [name] [-S]`
```
play -s               Fzf for a song and begin playback.
play -s PATTERN       Play the song PATTERN.
play -r               Fzf for a record and begin playback.
play -r PATTERN       Play from the record PATTERN.
play -a               Fzf for an artist and begin playback.
play -a PATTERN       Play from the artist PATTERN.
play -p               Fzf for a playlist and begin playback.
play -p PATTERN       Play from the playlist PATTERN.
play -g               Fzf for a genre and begin playback.
play -g PATTERN       Play from the genre PATTERN.
play -l               Play from your entire library.

-S                    Enable shuffle before playback (combinable with any flag above).
```
Example: `am play -a Radiohead` (not case-sensitive; partial matches work)

Notes: 
* Music.app does not need to be open or closed; it should launch itself silently when `play` is called
* Searches both the local Library and Liked Music playlist (covers local and streaming tracks)
* Remember to escape any special characters or punctuation if passing a title (or wrap it in double quotes)
* Multi-word names can be passed unquoted: `am play -a Ernesto Cortazar`
* calling `-p Library` will result in quite a delay, unlike `-l`, because it requires copying all the songs in your library into the temporary playlist

## Volume

Get or set Music.app's playback volume (0–100, independent of system volume).

Usage (aliased): `am volume [up|down|N]`

```
volume                Show current volume (0-100).
volume up             Increase by 5%.
volume down           Decrease by 5%.
volume N              Set volume to N (0-100).
```

## Output

Switch the macOS **system-wide** audio output device. Affects all applications. Virtual and loopback devices (e.g. ZoomAudioDevice) are automatically filtered out.

Dependencies: [SwitchAudioSource](https://github.com/deweller/switchaudio-osx) (`brew install switchaudio-osx`)

Usage (aliased): `am output [--list | DEVICE]`

```
output                Fzf-pick a hardware output device.
output --list         List real hardware output devices (* = current).
output DEVICE         Switch system output to DEVICE directly.
```

Note: For Music.app-specific audio routing to AirPlay speakers, use `am airplay` instead.

## AirPlay

Route **Music.app's audio specifically** to an AirPlay device, independent of the system output. Useful when you want music on a TV or soundbar while system sounds stay on the Mac's speakers.

Usage (aliased): `am airplay [--list | DEVICE | off]`

```
airplay               Fzf-pick a Music.app AirPlay output (exclusive switch).
airplay --list        List available AirPlay outputs (* = currently active).
airplay DEVICE        Route Music.app audio to DEVICE exclusively.
airplay off           Stop AirPlay; play through local Mac speakers.
```

Example: `am airplay "Soundbar"` or `am airplay '55" Crystal UHD'`

## Add

Add the currently playing track to a user playlist. Works for both locally downloaded and streaming tracks (the command saves the track to your library first if needed).

Usage (aliased): `am add [PLAYLIST | --new PLAYLIST]`

```
add                   Fzf-pick a user playlist and add the current track.
add PLAYLIST          Add current track directly to PLAYLIST (must exist).
add --new PLAYLIST    Create PLAYLIST if needed, then add current track.
```

Note: There is a ~4 second delay for streaming tracks while Music.app saves them to your library.

## Catalog

Search the full Apple Music / iTunes catalog without any account or token setup. Uses the public iTunes Search API.

Dependencies: [fzf](https://github.com/junegunn/fzf), `curl`, `python3`

Usage (aliased): `am catalog search QUERY`

```
catalog search QUERY  Search the catalog, fzf-pick a result, open in Music.app.
```

Example: `am catalog search "bohemian rhapsody"`

Note: Apple Music's scripting API cannot auto-play catalog tracks that are not already in your library — this is Apple's design. After selecting a result, Music.app opens to that song's page; press play once. Use `am add` afterward to save it to your library for instant play next time.

### Known Problems

- Error: `execution error: Music got an error: Application isn't running. (-600)`
  - Solution: Reboot. It seems to occur occasionally after having had Music.app open for too long while your Mac has slept. Other potential solutions can be found [here](https://stackoverflow.com/questions/19957268/applescript-fails-with-error-600-when-launched-over-ssh-on-mavericks)
- Blinking for each output refresh when running np()
  - Consider using a lighter-weight terminal emulator, or even Terminal.app, where this doesn't seem to occur. I am not sure how to mitigate this for heavier terminal emulators such as iTerm2

### Ideas For Improvement

* It would be nice to be able to queue (as opposed to immediately play) a song or a group of songs, though there is no native corresponding AppleScript function to accomplish this at present
* This project could be forked and used in the backend to create a full client alternative to Music.app, though it would not be possible to browse for and save tracks outside of the user's library
* See the Script Editor.app's dictionary API (Music.sdef) for an exhaustive reference of all the native Music.app variables and functions that can be interfaced via AppleScript
