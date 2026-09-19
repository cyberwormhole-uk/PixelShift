# PixelShift

A jailbreak tweak that periodically nudges SpringBoard's status bar and dock
by a couple of pixels, cycling through 4 directions, to help prevent OLED
burn-in from static UI chrome. Configurable via a Settings.app pane
(enable/disable, shift amount, interval).

## What this actually does (read this first)

iOS does not expose an API to switch off individual display pixels — no
tweak, jailbroken or not, can do that directly. Two things are worth
knowing:

1. **True blacks already save power on OLED.** Any pixel rendering
   `#000000` is physically off on an OLED iPhone (X and later). This
   happens automatically with Dark Mode / black wallpapers — no tweak
   needed. This is the real "battery savings" lever.
2. **Pixel shifting only addresses burn-in**, not battery life. It works
   by slightly translating static UI elements over time so the same
   sub-pixels aren't lit in the exact same position for hours (same idea
   TVs use). That's what this tweak does — for the status bar and dock,
   which are the longest-static elements on a Home Screen.

Don't expect a battery-life improvement from the shifting itself — that
comes from your wallpaper/theme being dark, which is a separate (much
easier) change.

## Requirements

- A jailbroken device (this scaffold targets **rootless** jailbreaks —
  Dopamine, palera1n rootless — on iOS 15+)
- [Theos](https://theos.dev/docs/installation) installed on your build
  machine (macOS or Linux)
- A device to test on, reachable via SSH/USB, or a `.deb`/`.tipa` you
  sideload manually

## Building

You need a compiled `.deb`, not just these source files — a jailbroken
device can't run raw `Tweak.xm`. Two options:

### Option A — build locally

```bash
export THEOS=/path/to/theos       # if not already set
cd PixelShift
make package                      # builds a .deb in ./packages
```

To build + install directly to a device over SSH:

```bash
export THEOS_DEVICE_IP=192.168.x.x
export THEOS_DEVICE_PORT=22       # if not default
make package install
```

If you're on a **rootful** jailbreak instead, remove or comment out the
`THEOS_PACKAGE_SCHEME = rootless` line in the `Makefile`.

### Option B — build with GitHub Actions (no Mac/Linux machine needed)

`.github/workflows/build.yml` is included and does the whole build for
you on GitHub's servers:

1. Create a new GitHub repo and push the **contents of this folder to
   its root** (i.e. `Makefile`, `control`, `Tweak.xm`, `.github/`, etc.
   should sit directly at the repo root — not nested one level deeper).
2. Push to `main`, or open the repo's **Actions** tab and manually run
   the "Build PixelShift" workflow (`workflow_dispatch`).
3. When the run finishes, open it and download the **`PixelShift-deb`**
   artifact from the bottom of the run summary page — it's a zip
   containing the built `.deb`.

What the workflow does: installs Theos + `ldid` on a macOS runner,
downloads the iOS 15.5 SDK, runs `make package`, and uploads the
resulting `.deb`. It's cached, so repeat runs are much faster after the
first one. If you're targeting a different minimum iOS version, change
`TARGET := iphone:clang:latest:15.0` in the `Makefile` and the SDK
version (`iPhoneOS15.5.sdk`) in the workflow to match.

## Installing the built .deb on your device

Once you have the `.deb` (from either option above):

- **Easiest:** AirDrop/transfer it onto the device and open it with
  **Sileo** or **Zebra** — they'll offer to install it directly.
- **Via Filza:** copy the `.deb` onto the device (Files app share sheet,
  or download link), open it in Filza, tap it, and choose Install.
- **Via SSH:** `scp` it to the device, then
  ```bash
  dpkg -i PixelShift_1.0.0_iphoneos-arm64.deb
  killall -9 SpringBoard   # respring to load the tweak
  ```

After install, respring once (installing normally does this
automatically), then check **Settings → PixelShift** for the config
pane.

## Configuring

After installing, open **Settings → PixelShift**:
- **Enabled** — toggle the effect on/off
- **Shift Amount (px)** — 0.5–4px, default 2px (larger = more visible
  "jump," smaller = more subtle but less effective against burn-in)
- **Interval (seconds)** — how often it shifts, default every 2 minutes

Changes take effect live (via a Darwin notification) — no respring
needed for preference changes, only for install/uninstall.

## Compatibility

This project is configured for:
- **Jailbreak:** Dopamine (any version, including 3.0) — rootless
- **iOS:** 15.0–18.7.1 (deployment target 15.0, forward-compatible)
- **Devices:** A12/A13 and later (arm64e required, included in `ARCHS`)

No changes are needed for this combination — `THEOS_PACKAGE_SCHEME = rootless`
and the `arm64e` slice in `ARCHS` already cover it. The CI workflow builds
against the iOS 16.5 SDK, which is fine even though your device runs 18.7.1:
this tweak only uses stable, long-standing UIKit/Foundation APIs, so an
exact SDK-to-device version match isn't required.

## Project layout

```
PixelShift/
├── Tweak.xm                                   # the hook + shift logic
├── control                                    # package metadata
├── Makefile                                   # Theos build config
├── PixelShift.plist                           # restricts tweak to SpringBoard
└── layout/
    └── Library/
        ├── PreferenceBundles/PixelShiftPrefs.bundle/   # Settings UI
        └── PreferenceLoader/Preferences/PixelShift.plist
```

## Notes / things you may want to change

- `com.yourname.pixelshift` is a placeholder bundle ID — rename it
  throughout (`control`, `Tweak.xm`'s `kPrefsPath`, the prefs bundle
  identifiers) to your own reverse-DNS ID before shipping/distributing.
- The tweak currently only targets views whose class name contains
  `"StatusBar"` or `"Dock"`. On some iOS versions SpringBoard's private
  class names shift slightly between releases — if shifting doesn't
  seem to trigger on your iOS version, use a tool like `classdump` or
  `Flex`/`Cephei` runtime browsing on-device to find the exact private
  window/view class names for your version and adjust the filter in
  `-chromeWindows`.
- No `PixelShiftIcon` asset is bundled — Settings will fall back to a
  default icon. Add a `PixelShiftIcon@2x.png`/`@3x.png` to the prefs
  bundle folder if you want a custom one.
