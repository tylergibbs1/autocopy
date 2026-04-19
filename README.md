# AutoCopy

Tiny macOS menu bar app that copies any highlighted text to your clipboard — no ⌘C needed.

## Install

### Pre-built (easiest)
1. Download `AutoCopy-<version>.zip` from [Releases](https://github.com/tylergibbs1/autocopy/releases).
2. Unzip and drag `AutoCopy.app` to `/Applications`.
3. First launch: **right-click → Open** (the build is ad-hoc signed, so macOS Gatekeeper blocks double-click).
   Or strip the quarantine flag:
   ```bash
   xattr -dr com.apple.quarantine /Applications/AutoCopy.app
   ```
4. Grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility).

### Build from source
Requires macOS 13+ and the Xcode command-line tools (`xcode-select --install`).
```bash
git clone https://github.com/tylergibbs1/autocopy
cd autocopy
./Scripts/install.sh   # builds AutoCopy.app, copies to /Applications, launches
```
Or build without installing:
```bash
./Scripts/package_app.sh   # produces ./AutoCopy.app in-place
open AutoCopy.app
```

## Usage

- Click the clipboard icon in the menu bar to toggle on/off (⌘T).
- While on, whatever you highlight is copied to the clipboard automatically.
- Last-copied preview shows in the menu.
- Quit with ⌘Q.

## Why it works across rebuilds

Accessibility permissions are tied to the app's bundle identifier. The `.app` bundle uses a stable ID (`com.tylergibbs.autocopy`), so you grant the permission once and it sticks across rebuilds.

## License

MIT.
