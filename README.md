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

## Build

Requires macOS 27 and Xcode.

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
