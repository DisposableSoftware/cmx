# cmx

A minimal macOS comic reader for `.cbz` files. *cmx is pronounced "see-mix".*

It shows one page at a time, fit to the window, with nothing drawn over the image. It has no
library, so it opens whatever file you hand it and remembers where you left off.

## Features

- Open a comic from File ▸ Open, by dragging it onto the window or Dock icon, or by double-clicking
  it in Finder.
- Reopening a comic resumes at the last page you read. The last comic reopens on launch.
- Reads `ComicInfo.xml` metadata when present: series, number and title go in the window title, and
  the full fields are in the inspector (`⌘I`).
- Dual-page layout (`d`). Wide spread pages are never paired.
- Quick Look support: Finder thumbnails show the cover, and pressing space in Finder previews
  the comic.

CBR (RAR) archives are not supported. A RAR renamed to `.cbz` is detected, and cmx tells you to
convert it.

## Keys

| Key | Action |
|---|---|
| `Space` `→` `↓` `Page Down` `l` `j` | Next page |
| `Shift-Space` `←` `↑` `Page Up` `h` `k` | Previous page |
| `Home` / `End` | First / last page |
| `d` | Toggle dual-page layout |
| `f` / `Esc` | Toggle / exit full screen |
| `⌘I` | Comic info |
| `q` | Quit |

## Install

Requires macOS 27.

Download `cmx-1.0.zip` from [Releases](https://github.com/westongpt/cmx/releases), unzip it, and move
`cmx.app` to `/Applications`.

The build is not notarized, so macOS blocks it the first time with "cmx" Not Opened (or
"Apple could not verify…"). To allow it, do one of:

- **System Settings:** try to open cmx once and dismiss the warning. Then go to System Settings ▸
  Privacy & Security, scroll to Security, click **Open Anyway** next to the cmx message, and confirm.
- **Terminal:** clear the quarantine flag that macOS adds to downloaded files:

  ```sh
  xattr -dr com.apple.quarantine /Applications/cmx.app
  ```

You only need to do this once. To make cmx open `.cbz` files on double-click, choose Get Info on any
`.cbz` file in Finder, pick cmx under Open with, and click Change All.

## Build

Building from source avoids the warning entirely. Requires macOS 27 and Xcode.

```sh
scripts/install.sh            # build Release, install to /Applications, register .cbz handling
```

All logic lives in the `CMXKit` Swift package, which builds and tests without Xcode:

```sh
swift test --package-path CMXKit
```

`CLAUDE.md` covers the architecture and the CBZ handling rules.

## Third-party

[ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (MIT). The full license text is in the
app's About window.

## License

cmx is public domain under the [Unlicense](LICENSE). ZIPFoundation keeps its own MIT license.
