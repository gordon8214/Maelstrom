---
description: Build an optimized (Release) Maelstrom.app with Xcode and install it into /Applications, replacing any existing copy.
argument-hint: [--clean] [--open]
---

Build an optimized, self-contained macOS `Maelstrom.app` and install it into
`/Applications`, replacing any copy that is already there.

Use the **Xcode** project, not the CMake build. The CMake build produces only a bare
executable that finds its `Data/`/`mods/` by walking up to the repo root (see
`utils/files.c` `InitDataPath()`), so it is *not* relocatable. The Xcode project copies
`Data/`, `mods/`, and `Docs/` into `Maelstrom.app/Contents/Resources/` and embeds the SDL
frameworks, so the resulting bundle runs from anywhere.

Arguments: `$ARGUMENTS`
- `--clean` — do a clean build (`clean build`) instead of an incremental one.
- `--open` — launch the app from `/Applications` after installing (default: don't).

Run every command from the repo root (`/Users/gordon/Projects/Maelstrom`).

## Step 1 — Preconditions

- Confirm the toolchain exists: `command -v xcodebuild`. If it's missing, stop and tell the
  user to install Xcode.
- The Xcode build depends on SDL subprojects under `external/`. They should already be
  present, but guard: if `external/SDL/Xcode/SDL/SDL.xcodeproj` or
  `external/SDL_net/Xcode/SDL_net.xcodeproj` is missing, run
  `git submodule update --init --recursive` first.

## Step 2 — Optimized build

Build into the gitignored `build/` tree with ad-hoc code signing (no Apple team/account
needed; a locally built app is never Gatekeeper-quarantined, so ad-hoc is fine):

```sh
xcodebuild \
  -project Xcode/Maelstrom.xcodeproj \
  -scheme Maelstrom \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/xcode-install \
  MACOSX_DEPLOYMENT_TARGET=12.0 \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES \
  build
```

With `--clean`, use `clean build` in place of `build`.

Capture the output and confirm it ends with `** BUILD SUCCEEDED **`. **If the build fails,
stop and surface the error — do not proceed to install a stale or broken bundle.**

Notes:
- `-destination 'generic/platform=macOS'` selects the native macOS variant of this
  multiplatform target, so the product lands in `Release/` (not `Release-maccatalyst/`).
- `MACOSX_DEPLOYMENT_TARGET=12.0` is **required**: the vendored SDL / SDL_net Xcode
  subprojects under `external/` hard-code a `10.13` deployment target that current Xcode
  rejects ("supported range is 12.0 to 27.0.x"). Passing it on the command line overrides
  every target in the build, including those subprojects. `external/` must not be edited, so
  the override lives here. Raise the value if a future Xcode drops 12.0.
- Ad-hoc signing (`-`) also re-signs the embedded `SDL3.framework` / `SDL3_net.framework`.
  If you'd rather sign with a real Developer ID, drop the three `CODE_SIGN*` overrides and
  let Xcode's automatic signing run.

## Step 3 — Locate the product

The built app is at:

```
build/xcode-install/Build/Products/Release/Maelstrom.app
```

Verify it exists before touching `/Applications`.

## Step 4 — Quit any running instance

Best-effort, ignore errors (a running instance shouldn't block replacement, but quitting
keeps it clean):

```sh
osascript -e 'quit app "Maelstrom"' 2>/dev/null; killall Maelstrom 2>/dev/null; true
```

## Step 5 — Replace in /Applications

```sh
rm -rf /Applications/Maelstrom.app
ditto build/xcode-install/Build/Products/Release/Maelstrom.app /Applications/Maelstrom.app
```

`/Applications` is normally writable by admin users. If either command fails with a
permission error, retry that same command under `sudo` and tell the user it needed elevated
permissions.

## Step 6 — Verify and report

- Confirm the install and that it's self-contained:
  ```sh
  ls -d /Applications/Maelstrom.app
  ls -d /Applications/Maelstrom.app/Contents/Resources/Data
  ```
  (The `Data` folder inside the bundle is what makes it runnable from anywhere.)
- Optionally check the ad-hoc signature: `codesign -v /Applications/Maelstrom.app`.
- Report the installed path to the user.
- If `--open` was passed, launch it: `open -a Maelstrom`. Otherwise, tell the user they can
  launch it from Launchpad / `/Applications`, or with `open -a Maelstrom`.
