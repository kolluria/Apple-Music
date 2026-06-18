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

## 2. Switch Audio Output

List all available hardware output devices:

```zsh
zsh src/am.sh output --list
```

Interactively pick an output device (hardware shown in list; type an AirPlay device name to switch to it):

```zsh
zsh src/am.sh output
```

Switch directly to a known device:

```zsh
# Hardware devices (Bluetooth, USB, built-in)
zsh src/am.sh output "Jabra Evolve2 40"
zsh src/am.sh output "MacBook Pro Speakers"

# AirPlay devices (requires iTerm2 in System Settings → Privacy & Security → Accessibility)
zsh src/am.sh output "Soundbar"
```

---

## 3. Start / Stop Music

```zsh
zsh src/am.sh pause          # pause playback
zsh src/am.sh resume         # resume from pause
zsh src/am.sh stop           # stop playback completely

zsh src/am.sh play -l        # play entire library
zsh src/am.sh play -p "Liked Music"   # restart a favourite playlist
```

---

## 4. Playlists (list, select, shuffle)

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

## 5. Volume

```zsh
zsh src/am.sh volume           # show current volume (0-100)
zsh src/am.sh volume up        # +5%
zsh src/am.sh volume down      # -5%
zsh src/am.sh volume 70        # set to 70
```

---

## 6. Now Playing TUI

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

## Tips

- **Tip for quick access**: symlink the script into your PATH:
  ```zsh
  ln -sf "$(pwd)/src/am.sh" /usr/local/bin/am
  # then just: am play -p "Liked Music"
  ```

- **AirPlay permission**: For `am output "Soundbar"` to work, grant your terminal app Accessibility access in:
  `System Settings → Privacy & Security → Accessibility`

- **Run tests** after any code change:
  ```zsh
  zsh test/am-test.sh
  ```
