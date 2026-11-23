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
sudo pacman -S lichii                # Switch 2: Lichii
sudo pacman -S lichii-bc250          # Switch 2: the BC-250 Lichii fork (can be installed beside lichii)
sudo pacman -S kytyps5-native-git    # PS5: KytyPS5-Native
```

## Lichii (lichii)

Until 2026-11-12 this package was called `lichii-bc250`; that name is now the BC-250 fork below. An installed
old `lichii-bc250` is replaced by `lichii` on the next `pacman -Syu` (pacman asks), with the same binaries, so
Steam shortcuts keep working.

[Lichii](https://github.com/zortos293/lichii), a Switch 2 emulator based on Eden, compiled for the BC-250:

- `-march=znver2 -mtune=znver2`, without RDSEED (broken on this APU) and XSAVES
- upstream's PGO profile plus ThinLTO
- system Qt 6, SDL3, FFmpeg and Boost instead of the bundled copies
- ships `lichii`, `lichii-cli` and the room server `lichii-room` (upstream's `eden-cli`/`eden-room`, renamed so
  they do not clash with Eden)

CI checks for a new upstream release four times a day and rebuilds when there is one, so `pacman -Syu` keeps it
current. The package version is upstream's build number (`build-130` → `130-<pkgrel>`).

### lichii-steam-sync

Installed together with `lichii` and with `lichii-bc250`. Adds every game in `~/Games/Switch2` (`.nup`, `.nx`, `.xci`, `.nsp`) to
Steam as a non-Steam shortcut, with the name and artwork from Nintendo's store (or SteamGridDB with an API key).

```sh
lichii-steam-sync                      # add new games, update existing shortcuts
lichii-steam-sync --migrate            # take over Eglantine/Lichii AppImage shortcuts (artwork and play time stay)
lichii-steam-sync --env NAME=VALUE     # add a launch variable to every shortcut (remembered)
lichii-steam-sync --clear-env          # forget the remembered variables
lichii-steam-sync --prune              # remove shortcuts of games that are gone, without asking
lichii-steam-sync --dry-run            # show what would change
lichii-steam-sync --emulator lichii --migrate        # switch the shortcuts to lichii
lichii-steam-sync --emulator lichii-bc250 --migrate  # ... or to the BC-250 fork
```

The shortcuts start `lichii-bc250` when it is installed, else `lichii`; with both installed the script says so.
`--emulator` picks one (or the path of another Lichii build); `--migrate` also switches the shortcuts that
already exist, keeping their artwork, play time and Steam settings.

Steam is closed while the shortcut list is written and started again afterwards.

- **Collection:** every shortcut it makes goes into the Steam collection **"Switch 2"** (`--collection NAME` for
  another name, `--no-collection` to leave collections alone). Shortcuts of deleted games are taken out of it.
- **Sync from Steam:** the script adds a shortcut for itself, **"Sync Switch 2 games"**, so you can run it with its default
  settings from Big Picture / Gaming Mode. Started from Steam it continues in a systemd user unit of its own
  (`journalctl --user -u lichii-steam-sync` shows what it did), closes Steam while it writes and starts it again.
  When there is nothing new, Steam stays open. Run from Steam it also removes the shortcuts of games whose file is
  gone (`--prune`). The shortcut is added once, when the package is installed;
  if you removed it, `lichii-steam-sync --add-self` adds it again. It keeps itself off Steam's "Recent games".
- **Optional, at every login:** `systemctl --user enable lichii-syncer` makes sure the "Sync Switch 2 games" shortcut is there
  for the Steam account that logged in last, before Steam starts (Gaming Mode and desktop alike). It leaves
  Steam alone when Steam is already running.

Tips for the BC-250:

- Mesh shaders: this repository's Mesa offers them (DirectMesh), but not yet for the ones Lichii's games use
  (Ocarina of Time's among them: black screens, missing geometry). So mesh draws go through Lichii's own compute
  fallback: `lichii` shortcuts get `EDEN_NX2_FORCE_MESH_FALLBACK=1`, and `lichii-bc250` sets it itself (also on
  the command line). `lichii-steam-sync --native-mesh` leaves it out of `lichii` shortcuts (remembered;
  `--no-native-mesh` undoes it), `LICHII_BC250_NATIVE_MESH=1` does the same for `lichii-bc250`.
  (`EDEN_NX2_NO_MESH=1` is a different switch: it skips mesh draws, which loses geometry.)
- Lichii needs a lot of memory (Ocarina of Time: ~10 GB plus ~6 GB of GPU memory): use enough swap on a fast SSD,
  not on a USB stick.
- Gaming Mode: `lichii` and `lichii-bc250` have gamescope composite while they run (`GAMESCOPE_COMPOSITE_FORCE`,
  set back when the emulator exits). Otherwise gamescope shows the game's frames directly, and those must fit in
  the BC-250's 512 MB of VRAM: with a game running, opening a menu could fail there ("drm: flip error: Cannot
  allocate memory") and take gamescope down with the game. `LICHII_DIRECT_SCANOUT=1` (launch option) turns it off.

## Lichii BC-250 fork (lichii-bc250)

[lichii-bc250](https://github.com/lethevimlet/lichii-bc250) is a fork of Lichii tuned for the BC-250 itself (RADV
query and semaphore fixes, the task/mesh shader fallback Zelda: Ocarina of Time needs, less memory use on 16 GB of
shared RAM, frame pacing). It has no releases: the package is built from the newest commit of its `main` branch,
with the same flags as `lichii` (`-march=znver2`, no RDSEED/XSAVES, PGO with the fork's own profile, ThinLTO).
The version is the commit date, commit count and hash (`20261112.r30626.g83071fda4-<pkgrel>`).

- `lichii-bc250` (the Qt emulator), `lichii-bc250-cli` (upstream's `eden-cli`) and `lichii-bc250-room`; nothing
  clashes with `lichii`, so both can be installed. Both use the same Eden folders (`~/.config/eden`,
  `~/.local/share/eden`, `~/.cache/eden`).
- `lichii-bc250` and `lichii-bc250-cli` set the fork's BC-250 tuning variables first (texture cache caps, split GPU
  thread, frames ahead, shader workers: `/usr/lib/lichii-bc250/lichii-bc250-env`). A variable you set yourself
  wins. The fork's launcher also sets `EDEN_NX2_VSYNC_HZ=30 EDEN_NX2_SWAP_INTERVAL=2 EDEN_VI2_MAX_RESOLUTION_MODE=1`,
  which are for Ocarina of Time only; `lichii-steam-sync` adds them to that game's shortcut by itself.
- The fork's settings template is in `/usr/share/doc/lichii-bc250/game.ini` (`oot.ini` before the fork's v18):
  `lichii-bc250-cli -f -c /usr/share/doc/lichii-bc250/game.ini -g <game>` (copy it first to change it).
  `lichii-bc250` (Qt) does not read it; per-game settings go in `~/.config/eden/custom/<TitleID>.ini`.
- Mesh draws go through Lichii's compute fallback (`EDEN_NX2_FORCE_MESH_FALLBACK=1`, see "Tips for the
  BC-250"); `LICHII_BC250_NATIVE_MESH=1` tries DirectMesh's mesh shaders instead.
- Steam shortcuts: `lichii-steam-sync` (installed with it) uses `lichii-bc250` when it is installed.
- The system tuning in the fork's README (swappiness, compaction, swapfile, UMA, TTM limit) is not done by the
  package.

## KytyPS5-Native (kytyps5-native-git)

`kytyps5-native-git` packages [KytyPS5-Native](https://github.com/superkeka/KytyPS5-Native)
through its BC-250 beta fork [KytyPS5-Native-beta](https://github.com/dmorazasanchez/KytyPS5-Native-beta),
which merges superkeka's `main` and adds BC-250 work (frame generation, title profiles):
PS5 games, with their GPU work running natively on the BC-250's PS5 APU (gfx1013).
It is built from the newest commit of the fork's `main` branch and rebuilt
whenever that moves (on 2026-11-17 from superkeka's `main`, from 2026-11-12 to
2026-11-17 from the fork's releases). The version is the commit date, commit count and hash
(`20261117.r2448.gf820b8e-<pkgrel>`). Only use game files you obtained legally.

```bash
sudo pacman -S kytyps5-native-git
kytyps5-native        # the launcher; also in the application menu as KytyPS5-Native
```

**Installing it changes nothing on your system.** The kernel parameters, the
helper service and the group below are yours to set. Without them the emulator
still starts, but large games stall while loading and games heavy on async
compute are unplayable.

Where everything is:

| Path | What |
|---|---|
| `/usr/lib/kytyps5-native/` | The program, read-only: `kyty_launcher`, `kyty_emulator`, `kytyps5-run.sh`, `kyty-lodhw`, `assets/`, `VERSION` |
| `/usr/bin/kytyps5-native` | Starts the launcher (also in the application menu) |
| `/usr/bin/kytyps5-run` | Starts a game from a Steam shortcut (step 3) |
| `/usr/bin/kytyps5-steam-sync` | Adds the games in `~/Games/PS5` to Steam as shortcuts, with their own name and artwork (step 3) |
| `/usr/bin/kyty-upscaler-scan` | Scans a game for the upscaler and frame generation and writes its profile to `~/.config/KytyPS5-Native/upscaler-profiles/` (`kyty-upscaler-scan ensure /path/to/game`) |
| `/usr/share/kytyps5-native-git/` | The fork's per-game defaults and tested profiles (`title-defaults`, `title-profiles`, `astro-templates`) |
| `/usr/bin/kyty_emulator` | The emulator on the command line (`kyty_emulator --help`, `kyty_emulator --game /path/to/game`) |
| `/usr/lib/systemd/system/kyty-lodhw.service` | The GPU helper (step 2), runs `/usr/lib/kytyps5-native/kyty-lodhw` as root, socket `/run/kyty-lodhw.sock` |
| `/usr/share/doc/kytyps5-native-git/` | Upstream's README and its kernel notes (`bc250-amdgpu.md`) |
| `~/.local/share/KytyPS5-Native/package/` | Your copy of the program. KytyPS5-Native keeps its saves and caches next to the program, which cannot be written in `/usr/lib`, so `kytyps5-native` and `kytyps5-run` copy it here (about 30 MB) on first start and after each package update, and run it from here. Games started from the launcher keep their saves and caches here too |
| `~/.local/share/KytyPS5-Native/data/` | Saves and caches of games started from Steam shortcuts; logs in `../logs/<title id>.log` |
| `~/.config/Kyty/Kyty.ini` | Launcher settings (game folders, options) |
| `~/.config/KytyPS5-Native/` | Optional `boot.webm` / `exit.webm`, played before a game from Steam and after leaving it |

The system Qt is used instead of upstream's bundled copy, and there is no
self-updater: `pacman -Syu` updates it.

Tested on a BC-250 (2026-10-29, upstream release `KytyPS5-Native-2026-10-29-b9a29ef`):
installs cleanly, creates no group and enables nothing, the launcher and
`kyty_emulator` start, the helper serves its socket to members of `render` and
refuses everyone else. On 2026-10-30 ASTRO BOT played from a Steam shortcut in
Gaming Mode (VRAM 512 MB, steps 1-3), in HDR, with a USB DualSense's motion,
haptics, adaptive triggers and speaker.

What you need besides the package:

- **Your own game dumps, decrypted.** Kyty runs a game from a folder that
  contains `eboot.bin` (with `sce_sys/param.json` for its title and id), or from
  a ZArchive (`.zar`) of such a folder, which it reads without unpacking. No
  games, firmware or system software come with it.
- **No PS5 firmware, BIOS or keys.** KytyPS5, which this fork builds on, implements
  the PS5's system libraries itself; the only modules it loads are the ones a game
  ships in its own `sce_module/` folder.
- **VRAM set to 512 MB** in the BIOS for the larger games (Gran Turismo 7, ASTRO
  BOT): the rest of the 16 GB is then RAM the game needs. On the modded P3.00
  "Chipset Menu" BIOS: Chipset > GFX Configuration > UMA Frame Buffer Size >
  512M. On the stock BIOS, without flashing:
  `sudo ./bc250memcfg UMA_SIZE 512` with
  [bc250_memcfg](https://github.com/fanoush/bc250_memcfg), then reboot.
  `cat /sys/class/drm/card*/device/mem_info_vram_total` shows 536870912 after it.
- **Memory:** 14 GiB of GTT for the larger games (step 1). Gran Turismo 7 uses
  about 12.6 of the board's 14.8 GB, so close other programs; a Steam shortcut
  (step 3) unloads Steam itself while the game runs.
- **Disk space** for the dumps, plus shader and pipeline caches that grow per game.
- Vulkan through the Mesa (RADV) of [linux-cachyos-bc250](https://github.com/MastaG/linux-cachyos-bc250) for presentation and as fallback;
  the native path runs the game's own GPU commands.

### 1. Kernel parameters

| Parameter | Needed? | What it does |
|---|---|---|
| `ttm.pages_limit=3670016` | Yes | 14 GiB GTT. Without it games over 8 GiB of guest memory (Gran Turismo 7, ASTRO BOT, My First Gran Turismo) stall while loading |
| `amdgpu.sched_policy=2 amdgpu.vm_update_mode=0 amdgpu.cwsr_enable=0` | Recommended | Lets Kyty run the game's async compute on KFD queues. Without them games heavy on async compute (ASTRO BOT) are unplayable |
| `amdgpu.bc250_gfx_eop_events=2` | Optional, untested | Lets the native GPU backend take a game's end-of-pipe completion points straight from its interrupts, as the PS5 kernel does. Without it Kyty raises them itself from its KFD queues and a relay queue, which upstream rates the same games at the same speed. Needs a kernel from linux-cachyos-bc250 (`0024-bc250-kfd-eop-events.patch`) |

`sched_policy=2`, `vm_update_mode=0` and `cwsr_enable=0` apply to **everything**
on the board, not only to Kyty. `sched_policy=2` helps some games and hurts
others (see
[Optional AMDGPU scheduler tuning](https://github.com/MastaG/linux-cachyos-bc250#optional-amdgpu-scheduler-tuning)), and the
[ROCm / KFD](https://github.com/MastaG/linux-cachyos-bc250/blob/main/docs/ROCM.md) guide recommends it for compute. If other
games get worse, take them out again while you are not playing PS5 games.
`bc250_gfx_eop_events` is off by default in the linux-cachyos-bc250 kernels because any
non-zero value sends every end-of-pipe interrupt of every game on the board
through that path, and no BC-250 board has run it yet; try it only if you want
to help test it. Upstream's explanation of each option, and of its own patched
amdgpu (most of which the linux-cachyos-bc250 kernels now carry as patches `0008` and
`0023`-`0027`), is in `/usr/share/doc/kytyps5-native-git/bc250-amdgpu.md`.

Add them on CachyOS with Limine (each `sed` appends inside the quotes of the
existing `KERNEL_CMDLINE[default]+="…"` line, the only one `limine-mkinitcpio`
reads). If you already added `amdgpu.sched_policy=2` for scheduler tuning, use
`amdgpu.vm_update_mode=0 amdgpu.cwsr_enable=0` on the second line instead:

```bash
sudo sed -i 's|^\(KERNEL_CMDLINE\[default\]+=".*\)"$|\1 ttm.pages_limit=3670016"|' /etc/default/limine
sudo sed -i 's|^\(KERNEL_CMDLINE\[default\]+=".*\)"$|\1 amdgpu.sched_policy=2 amdgpu.vm_update_mode=0 amdgpu.cwsr_enable=0"|' /etc/default/limine
# optional, untested (see above):
# sudo sed -i 's|^\(KERNEL_CMDLINE\[default\]+=".*\)"$|\1 amdgpu.bc250_gfx_eop_events=2"|' /etc/default/limine
sudo limine-mkinitcpio
sudo reboot
```

Check after the reboot:

```bash
grep -o 'ttm.pages_limit=[0-9]*' /proc/cmdline                       # ttm.pages_limit=3670016
cat /sys/module/amdgpu/parameters/{sched_policy,vm_update_mode,cwsr_enable}   # 2, 0, 0
cat /sys/module/amdgpu/parameters/bc250_gfx_eop_events                # 2
```

Kyty also checks the GTT limit and `sched_policy` when a game starts from a
Steam shortcut, and names the ones that are off in its first notification.

To remove them again:

```bash
sudo sed -i -e 's| ttm.pages_limit=3670016||' \
    -e 's| amdgpu.sched_policy=2 amdgpu.vm_update_mode=0 amdgpu.cwsr_enable=0||' \
    -e 's| amdgpu.bc250_gfx_eop_events=2||' /etc/default/limine
sudo limine-mkinitcpio
```

### 2. The GPU helper and the `render` group

`kyty-lodhw` is a small helper that runs as root and does what the PS5's kernel
does for a game: the GPU's texture LOD statistics, and TLB flushes for the KFD
queues. Kyty talks to it over `/run/kyty-lodhw.sock`. The package ships the
service but does not enable it. The socket belongs to the group `render`, which
every Arch system already has; only its members can use it. Being in `render` then
means real access: through the helper, every member can read GPU registers and
write the few it allows. On a single-user board that is you; keep it in mind if
other accounts are in `render`.

```bash
sudo usermod -aG render "$USER"
sudo systemctl enable --now kyty-lodhw.service
```

Log out and back in (or reboot) so the new group applies to your session, then
check:

```bash
id -nG | tr ' ' '\n' | grep -x render     # render
systemctl status kyty-lodhw.service       # active (running)
ls -l /run/kyty-lodhw.sock                # srw-rw---- root render
```

To undo: `sudo systemctl disable --now kyty-lodhw.service` and
`sudo gpasswd -d "$USER" render`. Removing the package also disables the service.

### 3. Playing

- **Launcher:** `kytyps5-native`, then add the game's folder.
- **Steam (Gaming Mode):** let `kytyps5-steam-sync` add your games (below), or
  add `/usr/bin/kytyps5-run` as a non-Steam game by hand and give it the game
  folder as launch option: `"/path/to/game"`. Optional: `--keep-steam` after
  the folder keeps Steam running during the game (by default it is unloaded to
  free 2-3 GB of RAM for large games). It uses `xprop` (`xorg-xprop`, installed with the package).
- **Turn Steam Input off for that shortcut** (its controller settings in Steam).
  With Steam Input on, Kyty sees only Steam's virtual pad: no motion controls,
  haptics, adaptive triggers or controller speaker.
- **HDR** is off by default from a Steam shortcut since upstream's build of
  2026-11-04: ASTRO BOT looks washed out in HDR and upstream has not found why
  yet (their issue #7). The game then renders in SDR, which gamescope shows
  correctly inside Steam's HDR output. To try HDR anyway:
  `mkdir -p ~/.config/KytyPS5-Native && touch ~/.config/KytyPS5-Native/hdr`
  (with Steam's HDR on, Settings > Display); remove the file to go back. On the
  KDE desktop, turn HDR on in the launcher's settings for the game.
- **A USB DualSense** gets its own levels each time a game starts: speaker 50%,
  haptics 90%, the controller's mixer 100% (a new controller otherwise sits at
  40% and 80%, far quieter than on a PS5). Other levels for one shortcut:
  `KYTYPS5_DS_SPEAKER=70 KYTYPS5_DS_HAPTICS=100 %command% "/path/to/game"`;
  `KYTYPS5_DS_SPEAKER=off` leaves the levels alone. `amixer` (`alsa-utils`) sets
  the mixer. With `bc250-dual-audio`, version 0.17 or newer is needed for the
  haptics to reach the controller.
- **Add-ons (DLC) from a Steam shortcut:** `kytyps5-run` passes a game's
  add-ons to the emulator in two ways, and uses both when both are there:
  - **An `addcont` folder inside the game folder**, for example
    `~/Games/PS5/PPSA26344-app0/addcont/`, holding add-on packages that each
    have their own `sce_sys/param.json`. It is passed as `--addcont-dir`, the
    same as the launcher's add-ons folder setting. Nothing else is needed: the
    shortcut stays the same.
  - **For a game packed as a `.zar`**, which cannot hold that folder: keep the
    `addcont` folder in a folder of the archive's name without `.zar`, next to
    it (`~/Games/PS5/PPSA26344-app0/addcont/` beside
    `~/Games/PS5/PPSA26344-app0.zar`; that folder holds nothing else).
    `kytyps5-steam-sync` adds `--addcont-dir=<that addcont folder>` to the
    shortcut's launch options, and `kytyps5-run` passes it on as
    `--addcont-dir`. The option goes again at the next sync once the folder is
    gone.
  - **A licence list**, `~/.config/KytyPS5-Native/addcont/<title id>`: one
    add-on label per line (`<label>`, or `<label>=<folder with its data>`), a
    `#` starts a comment. Each line is passed as `--addcont`.
    `kytyps5-steam-sync` fills it in for games known to wait forever on their
    loading screen without their licences. For Ghost of Yōtei (PPSA26344) these
    are the 15 labels the KytyPS5-Native-beta fork's own launcher registers.

  The game's log (`~/.local/share/KytyPS5-Native/logs/<title id>.log`) shows
  the add-ons passed on each start (`add-ons: ...`).
- **Upscaler, frame generation and other per-game variables:** the package is
  built with the fork's upscaler and FSR 3 frame generation (also in the
  in-game menu of the HOME button). The runner restarts itself through
  `systemd-run`, which drops Steam's launch options, so per-game variables go
  in `~/.config/KytyPS5-Native/env/<title id>`: one `NAME=value` per line, a
  `#` starts a comment. For example, after `kyty-upscaler-scan ensure
  ~/Games/PS5/PPSA26344-app0`:
  ```
  KYTY_UPSCALER_PROFILE=/home/deck/.config/KytyPS5-Native/upscaler-profiles/<profile>.json
  KYTY_UPSCALER=game
  KYTY_UPSCALE_PRESET=dynamic
  KYTY_FRAMEGEN=fsr3
  ```
  Frame generation works in HDR too once the fork has the HDR fix
  (dmorazasanchez/KytyPS5-Native-beta#1).
- Upstream's Decky plugin is for SteamOS and installs its own copy of Kyty; it
  is not needed with this package.

#### Adding your games to Steam: `kytyps5-steam-sync`

Put each game in its own folder under `~/Games/PS5` (for example
`~/Games/PS5/PPSA21564-app0`, the folder with `eboot.bin` and `sce_sys/`), then
run from a terminal or over SSH:

```bash
kytyps5-steam-sync                  # adds every game in ~/Games/PS5 that has no shortcut yet
kytyps5-steam-sync /mnt/games/ps5   # another folder
kytyps5-steam-sync --list           # only show what it finds and what differs
kytyps5-steam-sync --dry-run        # show what it would do, change nothing
kytyps5-steam-sync --prune          # also remove shortcuts of games you deleted, without asking
```

Each shortcut gets the game's own name from `sce_sys/param.json` with ` (PS5)`
behind it, and the game's own pictures as Steam artwork: `pic0` as the library
banner and background, `icon0` as the icon and the cover (PS5 `.dds` pictures
are converted to PNG). Running it again changes nothing for games that already
have a shortcut, apart from updating their artwork if the game's pictures
changed. When a game's folder is gone, it asks whether to remove that shortcut
and its artwork; `--prune` removes them all without asking. Run from its Steam
shortcut ("Sync PS5 games") it always does that.

A ZArchive of a game folder in `~/Games/PS5` counts as a game too: Kyty plays a
`.zar` without unpacking it, and its name and pictures are read out of the
archive. Make one with `zarchive` (`sudo pacman -S zarchive`):
`zarchive PPSA21564-app0 PPSA21564-app0.zar`. When a game folder is replaced by its
`.zar` (the same name plus `.zar`), or the other way round, the shortcut is kept and
only points at the other one, so play time and Steam settings stay. A dumped game is
stored unpacked, so the archive is often much smaller: Gran Turismo 7 went from
303 GB to 163 GB, ASTRO BOT from 149 GB to 49 GB. A game whose add-ons sit
in its folder's `addcont` keeps them in a folder of the same name beside the `.zar`
(see the add-ons item above). Pack the game without its `addcont` folder (move it out
first): inside the archive, `kytyps5-run` cannot pass it on.

Steam only reads its shortcut list when it starts, so when Steam is running the
tool asks to stop it, writes the list and starts Steam again (`--yes` skips the
question). It keeps a backup of the list next to it
(`~/.local/share/Steam/userdata/<id>/config/shortcuts.vdf.bak-<date>`). Game
folders linked in from another drive work too. Afterwards, **turn Steam Input
off** for each new shortcut (see above). `kytyps5-steam-sync --help` lists the
other options.

- **Collection:** every shortcut it makes goes into the Steam collection **"PlayStation 5"** (`--collection NAME` for
  another name, `--no-collection` to leave collections alone). Shortcuts of deleted games are taken out of it.
- **Sync from Steam:** the script adds a shortcut for itself, **"Sync PS5 games"**, so you can run it with its default
  settings from Big Picture / Gaming Mode. Started from Steam it continues in a systemd user unit of its own
  (`journalctl --user -u kytyps5-steam-sync` shows what it did), closes Steam while it writes and starts it again.
  When there is nothing new, Steam stays open. The shortcut is added once, when the package is installed;
  if you removed it, `kytyps5-steam-sync --add-self` adds it again. It keeps itself off Steam's "Recent games".
- **Optional, at every login:** `systemctl --user enable kytyps5-native-syncer` makes sure the "Sync PS5 games" shortcut is there
  for the Steam account that logged in last, before Steam starts (Gaming Mode and desktop alike). It leaves
  Steam alone when Steam is already running.

## Building locally

```sh
./scripts/build-lichii-package.sh                # these resolve the newest upstream release/commit themselves
./scripts/build-lichii-bc250-package.sh
./scripts/build-kytyps5-native-git-package.sh
python3 -m unittest discover tests               # packaging tests
```

The packages land in `out/repo/`.

CI builds each package in its own job, side by side; a last job merges what they built into the release and
rewrites the database (`scripts/ci-build.sh --no-database` / `--database-only`).
