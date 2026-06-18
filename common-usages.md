# Common Usages

Quick reference for day-to-day use of `am.sh`.

---

## 1. Fuzzy Search & Play

Pick anything interactively from your library using fzf:

```zsh
# Search and play a song
zsh src/am.sh play -s

# Search and play an album
zsh src/am.sh play -r

# Search and play by artist
zsh src/am.sh play -a

# Search and play a playlist
zsh src/am.sh play -p

# Search and play by genre
zsh src/am.sh play -g
```

Play directly without the fuzzy picker (exact name):

```zsh
zsh src/am.sh play -s "Blackbird"
zsh src/am.sh play -p "Liked Music"
zsh src/am.sh play -a "Ernesto Cortazar"
```

---

## 2. Switch System Audio Output

Controls the macOS system-level audio output (Bluetooth, USB, built-in speakers). Affects all apps.

List available hardware output devices (virtual/loopback devices like ZoomAudioDevice are filtered out):

```zsh
zsh src/am.sh output --list
```

Interactively pick a device:

```zsh
zsh src/am.sh output
```

Switch directly to a known device:

```zsh
zsh src/am.sh output "Jabra Evolve2 40"
zsh src/am.sh output "MacBook Pro Speakers"
```

---

## 3. Music.app AirPlay Routing

Controls where **Music.app specifically** sends its audio — independent of the system output.
Useful when you want only music going to your TV or soundbar while system sounds stay on speakers.

List Music.app AirPlay outputs (`*` = currently selected/routing):

```zsh
zsh src/am.sh airplay --list
```

Interactively pick an AirPlay destination (fzf picker):

```zsh
zsh src/am.sh airplay
```

Route Music.app audio to a specific AirPlay device:

```zsh
zsh src/am.sh airplay "Soundbar"
zsh src/am.sh airplay '55" Crystal UHD'
```

Route back to the local Mac speakers:

```zsh
zsh src/am.sh airplay off
```

---

## 4. Start / Stop Music

```zsh
zsh src/am.sh pause          # pause playback
zsh src/am.sh resume         # resume from pause
zsh src/am.sh stop           # stop playback completely

zsh src/am.sh play -l        # play entire library
zsh src/am.sh play -p "Liked Music"   # restart a favourite playlist
```

---

## 5. Playlists (list, select, shuffle)

List all playlists:

```zsh
zsh src/am.sh list -p
```

See songs inside a playlist:

```zsh
zsh src/am.sh list -p "Liked Music"
```

Pick and play a playlist interactively:

```zsh
zsh src/am.sh play -p
```

Play a playlist with shuffle:

```zsh
zsh src/am.sh play -p "Liked Music" -S
zsh src/am.sh play -p -S          # fzf-pick playlist and shuffle
```

---

## 6. Volume

```zsh
zsh src/am.sh volume           # show current volume (0-100)
zsh src/am.sh volume up        # +5%
zsh src/am.sh volume down      # -5%
zsh src/am.sh volume 70        # set to 70
```

---

## 7. Now Playing TUI

Shows track name, artist, album, progress bar, volume, shuffle/repeat state.
Press `?` inside to see all keybindings.

```zsh
zsh src/am.sh np        # with album art (requires viu: brew install viu)
zsh src/am.sh np -t     # text-only mode (faster, no viu needed)
```

Key bindings inside `np`:

| Key | Action |
|-----|--------|
| `p` | Play / Pause |
| `f` / `b` | Next / Previous track |
| `+` / `-` | Volume up / down |
| `s` | Toggle shuffle |
| `r` | Toggle repeat |
| `o` | Switch audio output |
| `q` | Quit |
| `Q` | Quit + close Music.app |

---

## 8. Add Current Track to a Playlist

Add the currently playing track (including streaming tracks) to any of your playlists.
The command uses a library-first workflow: it saves the track to your library, then copies it to the target playlist.

```zsh
am add                       # fzf-pick from your existing playlists
am add "Favorites"           # add directly to an existing playlist
am add --new "Road Trip"     # create the playlist if needed, then add
```

---

## 9. Full Apple Music Catalog Search

Search the full iTunes/Apple Music catalog — **no account, no setup, no token required**.

```zsh
am catalog search "vintunnava ar rahman"
am catalog search "bohemian rhap"         # typo-tolerant
am catalog search "Blackbird Beatles"
```

Results appear in fzf. Select a song and Music.app opens directly to that track page — **press play (or ↵) once** to start it.

**Why the manual press?** Apple's scripting API cannot auto-play catalog tracks that aren't in your library — this is an Apple limitation, not a bug. The workaround is a one-time press.

**Recommended workflow for new songs:**

```zsh
am catalog search "vintunnava ar rahman"
# → fzf picker appears, select the track
# → Music.app opens to that exact song, press play
am add "Favorites"              # saves it to your library while it's playing
# Next time, instant play from library:
am play -s "Vintunnavaa"
```

---

## 10. Known Limitations

**Radio / Genius Station**: Starting a radio station seeded from a specific song is not supported. Apple Music's "Start Station" feature is only accessible via the UI right-click menu — there is no AppleScript command or URL scheme that can open a song-seeded station without UI automation or a paid MusicKit developer token. Use `am catalog search` to find and play a song, then use the Radio tab inside Music.app to start a station.

---

## Tips

- **Tip for quick access**: symlink the script into your PATH:
  ```zsh
  ln -sf "$(pwd)/src/am.sh" /usr/local/bin/am
  # then just: am play -p "Liked Music"
  ```

- **System vs. Music AirPlay**: `am output` changes the macOS system audio device (all apps); `am airplay` routes only Music.app's audio to an AirPlay device. Use `am airplay` when you want music on your TV/soundbar but system sounds on your Mac.

- **Fuzzy search scope**: `am play -s` (interactive, no pattern) searches your local Library + Liked Music for speed. `am play -s PATTERN` (with a pattern) also searches your local library — it does **not** query the catalog. Use `am catalog search QUERY` to search the full iTunes catalog.

- **Workflow tip**: `am catalog search "query"` → play → `am add "Playlist"` to save it to a playlist for quick access later via `am play -p`.

- **Run tests** after any code change:
  ```zsh
  zsh test/am-test.sh
  ```
