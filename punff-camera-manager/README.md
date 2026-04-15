# punff-camera-manager

Tinder-style photo sorter for Olympus EPL-2. Go + Fyne.

## Requirements

```
sudo pacman -S go gcc libx11 libxcursor libxrandr libxinerama mesa
```

Fyne needs CGO and a few X11/GL libs. On CachyOS these are usually present.

## Build & run

```bash
cd ~/punff-site/punff-camera-manager   # or wherever you put this
make build
./punff-camera-manager
```

First run will download deps via `go mod tidy` (~30s, needs internet).

## Controls

| Key      | Action                              |
|----------|-------------------------------------|
| ←        | Trash (JPEG + ORF → system trash)   |
| ↓        | Archive (JPEG → kamera-backup, ORF trashed) |
| ↑        | Edit (JPEG + ORF → to-edit/)        |
| →        | Post (JPEG → assets/photos/, copy to archive, ORF trashed) |
| R        | Rotate 90° clockwise                |
| Ctrl+Z   | Undo last action                    |

**Deploy button** — runs `build.sh` then `deploy.sh` with auto-selected defaults.
Press it once after sorting your whole batch.

## Paths (hardcoded, edit main.go if needed)

- Camera:   `/run/media/punff/disk/DCIM/101OLYMP/`
- Photos:   `~/punff-site/assets/photos/`
- Edit:     `~/punff-site/to-edit/`
- Archive:  `~/Documents/kamera-backup/`
- Trash:    `~/.local/share/Trash/files/`

## Notes

- Rotation is visual only while previewing. The JPEG is moved as-is.
  If you need the rotation baked in, use `exiftool -r` or `jpegtran` afterward.
- Undo restores the file to its original camera path. Works for all four actions.
- Deploy pipes `y`, `2`, and empty lines (defaults) into `deploy.sh` stdin.
