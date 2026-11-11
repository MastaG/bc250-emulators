# bc250-emulators

Emulator packages built for the AMD BC-250 (Zen 2 CPU, Cyan Skillfish GPU) running CachyOS / Arch Linux,
published as a pacman repository.

This repository contains **packaging only**. It does not contain or distribute keys, firmware, BIOS files or
games: you need to dump those from your own hardware.

The kernel, Mesa and Proton packages for the BC-250 live in a separate repository,
[linux-cachyos-bc250](https://github.com/MastaG/linux-cachyos-bc250).

## Install

Add the repository to `/etc/pacman.conf`:

```ini
[bc250-emulators]
SigLevel = Optional TrustAll
Server = https://github.com/MastaG/bc250-emulators/releases/download/repo
```

Then:

```sh
sudo pacman -Syu
sudo pacman -S lichii-bc250
```

## Packages

### lichii-bc250

[Lichii](https://github.com/zortos293/lichii), a Switch 2 emulator based on Eden, compiled for the BC-250:

- `-march=znver2 -mtune=znver2`, without RDSEED (broken on this APU) and XSAVES
- upstream's PGO profile plus ThinLTO
- system Qt 6, SDL3, FFmpeg and Boost instead of the bundled copies
- ships `lichii`, `lichii-cli` and the room server `lichii-room` (upstream's `eden-cli`/`eden-room`, renamed so
  they do not clash with Eden)

CI checks for a new upstream release four times a day and rebuilds when there is one, so `pacman -Syu` keeps it
current. The package version is upstream's build number (`build-130` → `130-<pkgrel>`).

### lichii-steam-sync

Installed together with `lichii-bc250`. Adds every game in `~/Games/Switch2` (`.nup`, `.nx`, `.xci`, `.nsp`) to
Steam as a non-Steam shortcut, with the name and artwork from Nintendo's store (or SteamGridDB with an API key).

```sh
lichii-steam-sync                      # add new games, update existing shortcuts
lichii-steam-sync --migrate            # take over Eglantine/Lichii AppImage shortcuts (artwork and play time stay)
lichii-steam-sync --env NAME=VALUE     # add a launch variable to every shortcut (remembered)
lichii-steam-sync --clear-env          # forget the remembered variables
lichii-steam-sync --prune              # remove shortcuts of games that are gone, without asking
lichii-steam-sync --dry-run            # show what would change
```

Steam is closed while the shortcut list is written and started again afterwards.

Tips for the BC-250:

- Games that black-screen in 3D use mesh shaders the BC-250's driver cannot run yet; Lichii's own fallback
  avoids that: `lichii-steam-sync --env EDEN_NX2_FORCE_MESH_FALLBACK=1`
- Lichii needs a lot of memory (Ocarina of Time: ~10 GB plus ~6 GB of GPU memory): use enough swap on a fast SSD,
  not on a USB stick.

## Building locally

```sh
./scripts/build-lichii-bc250-package.sh     # resolves the newest Lichii release itself
```

The packages land in `out/repo/`.
