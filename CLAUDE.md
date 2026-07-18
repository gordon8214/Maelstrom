# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Maelstrom is an open-source SDL3 port of Ambrosia Software's classic asteroids-style
Macintosh game. It is a single C/C++/Objective-C executable that runs on Windows, Linux,
macOS, iOS, Android, and the Web, with game-controller support, touch controls, LAN/Steam
multiplayer, replays, and Steam integration.

## Build & Run

The build is CMake-driven. External dependencies (SDL, SDL_net, PhysFS, Steamworks SDK) are
git submodules under `external/` — clone with `--recurse-submodules` or run
`git submodule update --init --recursive` before building.

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
./build/Release/Maelstrom          # multi-config generators nest under Release/
```

Run from the repo root (or an install dir) so the game finds the `Data/` and `mods/` folders.

Key CMake options (all default ON/TRUE unless noted):
- `USE_VENDORED_SDL`, `USE_VENDORED_SDL_NET`, `USE_VENDORED_PHYSFS` — set `OFF` to use system
  packages instead of the submodules (Linux CI builds with `-DUSE_VENDORED_SDL=OFF`).
- `STEAM` — Steam integration; ON only on Windows/Linux/macOS, guarded by `ENABLE_STEAM`.
- `STANDALONE_INSTALL` — install everything into one directory (default) vs. XDG layout
  (`MAELSTROM_USE_XDG_DIRS`, defines `MAELSTROM_DATA`/`MAELSTROM_MODS` install paths).

Platform-specific projects: `android-project/` (Gradle), `Xcode/` (iOS/macOS app), Web via
Emscripten (`emcmake cmake …`; `Data/` and `mods/` get preloaded into the WASM bundle).

There is **no unit test suite** — this is a game; verify changes by building and running.
`build-scripts/test-versioning.sh` only tests version-string extraction, not gameplay.
CI (`.github/workflows/main.yml`) builds Windows/Linux/macOS on every push and PR.

**Do not edit anything under `external/`** — those are vendored upstream submodules.

## Architecture

The code is layered into internal static libraries plus the game itself. Understanding the
layering is the fastest way to know where a change belongs:

- **`game/`** — all Maelstrom-specific logic: game loop, physics, objects, menus, scoring,
  networking, replays, Steam. This is where feature work usually goes.
- **`screenlib/`** — a self-contained, data-driven UI toolkit (`UIManager`, `UIPanel`,
  `UIElement*`, `UIDialog`, `UITemplates`). Knows nothing about Maelstrom; talks to the game
  through abstract interfaces (`UIFontInterface`, `UISoundInterface`, `UIImageInterface`).
- **`maclib/`** (builds as `SDLmac`) — reads the *original Macintosh resource fork* data
  (resources, fonts, sounds, MacBinary/AppleSingle). Sprites, sounds, and fonts in `Data/`
  are still in classic-Mac resource formats; this library decodes them at runtime.
- **`utils/`** — support code: `prefs` (persisted preferences), `loadxml`/`rapidxml` (XML),
  `hashtable`, `array`, `files`, `ErrorBase`.
- **`miniz/`** — vendored zlib-style compression used for mod archives.

### Entry point and main loop

`game/main.cpp` uses SDL3's callback-based main (`SDL_MAIN_USE_CALLBACKS`) rather than a
classic `main()` loop — SDL calls `SDL_AppInit`/`SDL_AppIterate`/`SDL_AppEvent`/`SDL_AppQuit`.
Global services are singletons declared in `game/Maelstrom_Globals.h`: `screen` (`FrameBuf`),
`ui` (`UIManager`), `fontserv`, `sound`, `prefs`. Read this header first — it is the map of
cross-module globals, sound resource IDs, and panel/dialog name constants.

### Data-driven UI

Screens are **XML layouts in `Data/UI/`** (`main.xml`, `game.xml`, `lobby.xml`, …), not
hard-coded. Each `<Panel>`/`<Dialog>` names a C++ *delegate* (e.g. `MainPanel`, `GamePanel`)
that is registered in `game/MaelstromUI.cpp` and subclasses `UIPanelDelegate`
(`OnLoad`/`OnShow`/`OnTick`/`OnDraw`/`OnAction`). Delegates fetch elements by name via
`GetElement<T>("name")`. Layout uses anchor-based positioning and reusable `<template>`s
(see `Data/UI/UITemplates.xml`); `condition="PHONE"` / `condition="!PHONE"` / `TABLET` swap
layouts per form factor (`IsPhone()`/`IsTablet()` in `main.cpp`). To add or change a screen you
typically edit both the XML and its delegate.

### Game objects and simulation

`game/object.{h,cpp}` defines the `Object` base class; concrete entities (rocks, shots, the
player ship, enemies, prizes) live in `game/objects.cpp` and `game/player.cpp`, driven by
`GamePanelDelegate` in `game/game.cpp`. The simulation is a **deterministic, frame-locked
step**: a fixed frame delay advances all objects identically given the same RNG seed and the
same per-frame inputs.

This determinism is the foundation for two features — keep it intact when touching simulation
or `game/fastrand.*`:
- **Replays** (`game/replay.cpp`) store only the seed + recorded input stream, then replay by
  re-running the simulation. High-score entries are watchable replays.
- **Networking** (`game/netplay.cpp`, `game/protocol.h`) is lockstep: peers exchange only
  per-frame inputs over UDP (SDL_net) and each runs the identical simulation. A lobby server
  acts purely as an address broker; hosting/joining games then talk peer-to-peer. All players
  must share identical sprites (a CRC, `gSpriteCRC`, guards this).

### Mods

`game/mods.cpp` mounts mod archives with **PhysFS** (`external/physfs/extras/physfssdl3.*`).
A mod is a zip of `Data/`-shaped folders dropped in `mods/`; `Maelstrom_1980.zip` ships as the
built-in example. Because netplay compares sprite CRCs, all peers must use the same mod.

### Steam

`game/steam.cpp` (compiled only when `STEAM`/`ENABLE_STEAM`) wraps achievements, game
recording timeline events, and Remote Play. Guard all Steam calls behind the compile flag.

### macres tool

`macres/` is a **separate standalone executable** (its own `CMakeLists.txt`, not built by the
main project) that exports original Mac resource packs into moddable form:
`macres --export <file> <output_directory>`.

## Conventions

- The codebase predates SDL3 and modern C++ idioms in places; **match the surrounding style**
  rather than modernizing opportunistically. It uses classic-Mac-derived types (`Bool`,
  `MPoint`, `Rect`, `Blit`) and manual memory management.
- Every source file carries the zlib-license header — preserve it on new files.
- Warnings are enabled (`-Wall -Wextra`) but several are intentionally suppressed in
  `CMakeLists.txt` (`-Wno-sign-compare`, `-Wno-unused-parameter`, …); don't churn code solely
  to silence those.
- The version lives in `CMakeLists.txt` (`MAJOR/MINOR/MICRO_VERSION`); bump it there.
