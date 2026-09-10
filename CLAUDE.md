# cmx — macOS CBZ Reader

A minimal macOS comic reader. Opens `.cbz` archives, shows one page at a time, advances with the
keyboard, and reads embedded `ComicInfo.xml` metadata when the archive has it.

Native app: **Xcode + Swift + SwiftUI**. No cross-platform layers, no web views.

---

## Product scope

Keep this app small. The feature list is the whole feature list:

- Open a `.cbz` file (File ▸ Open, drag-and-drop onto the window or Dock icon, and `cmx file.cbz`-style
  document open events).
- Display one page, fit to window, no chrome over the image.
- Advance / go back by keyboard (see **Keyboard map**).
- Show metadata from `ComicInfo.xml` if present — title/series/number in the window title, full fields
  in a small inspector.
- Remember the last page read per file, so reopening resumes.

Quick Look thumbnails and previews ship as two app extensions (see **Quick Look** below). The window
sizes itself to the opening page's proportions, and there is an About window (**cmx is pronounced
"see-mix"**) carrying third-party license attribution. The last comic reopens on launch, and
recent comics appear under File ▸ Open Recent and in the Dock menu.

Dual-page layout is toggled with `d` (see **Dual-page layout** below).

Deliberately **out of scope** unless explicitly asked: a library/shelf browser, `.cbr`/RAR support
(detected and explained, never read), reading-direction toggles, cloud sync, annotations,
iOS/iPadOS targets. A settings screen is anticipated but not yet built — the Router is
in place so adding one is additive.

There is no comic library and no collection model. The app opens whatever file it is handed and
nothing more.

"Minimal UI" is a hard constraint, not a starting point. Default to no new controls: the image fills
the window, and anything else is hidden until asked for.

---

## Architecture

This project follows the **Container / UseCase / Router / Gateway** layered architecture documented at:

`~/Notes/Tech Notes/Work Notes/Architecture Design.md`

That note is the source of truth for the pattern. Read it before adding a layer. Everything below is
how the pattern maps onto *this* app — where it applies, and where it intentionally does not.

### Data flow

One direction only: **View → ViewModel → UseCase → Gateway**. State flows back up through observable
properties. A View never touches a UseCase; a UseCase never imports SwiftUI.

### Layer map for cmx

| Layer | Types in this app | Responsibility |
|---|---|---|
| **Gateway** | `ArchiveGateway`, `MetadataGateway`, `ReadingProgressGateway` | All I/O: unzip, XML parse, persistence |
| **UseCase** | `ReaderUseCase` | Open a book, page navigation rules, prefetch policy |
| **State** | `ReaderState` | Observable shared state (current book, page index, metadata) |
| **ViewModel** | `ReaderViewModel` | `ReaderAction` in, observable state out |
| **View** | `ReaderView`, `MetadataInspector` | SwiftUI only; submits actions |
| **Router** | `AppRouter`, `AppRoutingUseCase`, `Coordinator` | Which screen comes next |
| **UseCase** | `CoverUseCase` | Cover + metadata for the Quick Look extensions (no UI state) |
| **UI** | `CoverPreview`, `AboutView`, `LicenseList` | Views the extensions and app shell host |
| **UI** | `WindowFit` | Pure window geometry; the host owns the NSWindow |
| **Container** | `ReaderContainer` | Composition root — the only place concrete types are built |

Every boundary in that table is a **protocol**. Concrete implementations (`ZipArchiveGateway`,
`ComicInfoMetadataGateway`, `DefaultReaderUseCase`) are internal to their layer and referenced only
by the Container.

### How the pattern applies here

- **The Router is thin today, and that is fine.** `AppStep` currently has little more than `.reader`
  and `.settings`, so `AppRouter.nextStep(from:with:)` is nearly trivial. It exists anyway: settings
  and other screens are expected, and routing through a Router from the start means adding a screen is
  additive rather than a restructure. Keep the Router a **pure function** of its inputs — it decides
  the next step and performs no navigation; the `Coordinator` does that. Unit test it directly.
- **Single-screen navigation does not go through the Router.** Transient UI on the reader itself — the
  metadata inspector, an error alert — is a ViewModel-local `NavigationRoute`. The Router is for
  moving between screens, not for toggling a popover.
- **No Ports.** The package does not need them. The app target owns `NSOpenPanel`, the document
  lifecycle, and drag-and-drop, and hands the result to the package as a plain `URL`
  (`readerUseCase.open(url:)`). There is no host-app callback the package needs, so adding a protocol
  for one would be indirection with nothing behind it. If the package ever does need something only
  the app can provide, that is the moment to introduce a Port — not before.
- **No network layer.** Gateways here wrap the filesystem, ZIP decoding, and `UserDefaults`. The
  testability argument is identical: `ReaderUseCase` tests never touch a real archive.

### Target layout

A thin app target over a local Swift package. The package holds all logic so it can be tested without
an app host or a simulator.

```
cmx/
├── CLAUDE.md
├── cmx.xcodeproj              # thin app target: @main App, NSOpenPanel, document handling
├── cmx/
│   ├── cmxApp.swift           # builds ReaderContainer.build(...) at launch
│   ├── Coordinator/           # registers destination handlers (window, sheet)
│   └── cmx.entitlements       # sandbox off — hardened runtime only
└── CMXKit/                    # local SPM package — all logic lives here
    ├── Package.swift
    ├── Sources/CMXKit/
    │   ├── Container/         # ReaderContainer, Has* protocols
    │   ├── Gateways/          # protocols + concrete implementations
    │   ├── UseCases/          # ReaderUseCase protocol + DefaultReaderUseCase
    │   ├── State/             # ReaderState
    │   ├── Models/            # Page, ComicMetadata, Book
    │   ├── Routing/           # AppStep, AppRouter, AppRoutingUseCase
    │   └── UI/                # ReaderView, ReaderViewModel, ReaderAction
    └── Tests/CMXKitTests/
```

New logic goes in `CMXKit`. The app target should stay near-empty: lifecycle, menus, file panels,
drag-and-drop, and Coordinator registration only.

---

## CBZ domain rules

These are the details that cause real bugs. Honor them.

### Archive format

A `.cbz` is a plain **ZIP** containing image files, sometimes in nested folders. There is no index and
no guaranteed ordering in the central directory — **page order is derived, not read**.

Page list = archive entries, after:

1. Dropping directory entries, `__MACOSX/*`, `.DS_Store`, `Thumbs.db`, and any dotfile.
2. Keeping only image extensions: `jpg` `jpeg` `png` `gif` `webp` `avif` `bmp` `tif` `tiff` (match
   case-insensitively).
3. Sorting by full entry path using **natural / numeric-aware** comparison
   (`localizedStandardCompare`), so `page2.jpg` precedes `page10.jpg`. Plain lexicographic sorting is
   a bug.

An archive with zero image entries is a user-facing error ("no pages found"), not a crash.

### Metadata

`ComicInfo.xml` at the archive root, ComicRack schema. **Optional — its absence is the normal case and
must never surface as an error.** Parse leniently: unknown elements ignored, malformed XML degrades to
"no metadata" rather than failing the open.

Fields worth reading: `Series`, `Number`, `Count`, `Volume`, `Title`, `Summary`, `Writer`,
`Penciller`, `Inker`, `Colorist`, `Letterer`, `CoverArtist`, `Publisher`, `Year`, `Month`, `Day`,
`PageCount`, `LanguageISO`, `Genre`, `Web`.

Treat every field as optional and every numeric field as possibly non-numeric. Never trust
`PageCount` for navigation — it disagrees with the real page list often enough to matter; count
actual image entries instead.

Window title: `Series #Number — Title` when metadata exists, else the filename without extension.

### File type identity

macOS 27 declares **`public.cbz-archive`** natively (CoreTypes) — that is the UTI real `.cbz` files
carry. The app's document type, `UTType.cbzArchive`, and the LaunchServices association all use it;
do not invent a custom UTI (one existed briefly and matched nothing on disk). The
`UTImportedTypeDeclarations` entry in Info.plist re-imports the same identifier purely as a fallback.
The installed copy at `/Applications/cmx.app` is the registered `.cbz` handler; after reinstalling,
stale DerivedData copies can steal the registration — `lsregister -u` them if double-click opens the
wrong build.

### Mislabeled archives

RARs wearing a `.cbz` extension are common in the wild, so `ZipArchiveGateway` sniffs magic bytes
before handing the file to ZIPFoundation — content is trusted over extension, the same rule
`cbz-tool` (`../cbz-tool`, `archive::is_rar_file`) applies. `Rar!` throws `ArchiveError.rarArchive`
and anything that isn't a ZIP throws `.unrecognizedFormat`; both explain themselves and already name
the file, so `DefaultReaderUseCase` surfaces their text verbatim rather than wrapping it. CBR is
still out of scope — the error tells the user to convert, it does not attempt to read RAR.

### Quick Look

Two sandboxed app extensions live in the bundle's `PlugIns/`, both declaring
`public.cbz-archive` and both thin shells over CMXKit:

| Target | Extension point | Job |
|---|---|---|
| `cmxThumbnail` | `com.apple.quicklook.thumbnail` | Finder icon = the cover page |
| `cmxPreview` | `com.apple.quicklook.preview` | Space-bar panel: cover + metadata |

`CoverUseCase` (built by `CoverContainer`) is their whole entry point; `CoverPreview` lives in the
package's UI layer so the extension only hosts it. Notes that cost real time to learn:

- Extensions are **sandboxed even though the app is not**. That is fine: Quick Look grants read
  access to the one file being previewed, so no user-selected-file entitlement is needed.
- `cmxThumbnail` must stay **nonisolated** — `QLThumbnailProvider` is a nonisolated superclass, so
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` makes the override fail to compile. `cmxPreview` keeps
  MainActor isolation because it is an `NSViewController`.
- In the thumbnail drawing block, fill the **context's own pixel extent** (`context.width/height`),
  not the `contextSize` you passed in. Quick Look hands back a context scaled by the screen factor,
  and drawing into the point-sized rect leaves the page in the bottom-left quadrant.
- Extension bundle ids must be prefixed by the host app's (`lol.weston.cmx.cmx*`); the target
  template defaults to `com.yourcompany.*`.
- `NSExtension` in an extension's Info.plist is a **dictionary**. The `AddInfoPlist` MCP tool can
  only write dictionary *arrays*, so it silently produces the wrong shape here — write that plist
  directly and `plutil -lint` it.
- `qlmanage -t` produced no output for these extensions even when they work. Verify with
  `QLThumbnailGenerator` from a small script instead, and reset with `qlmanage -r cache`.
- `pluginkit -mAv | grep cmx` lists both; `pluginkit -p <point>` matches nothing and is not a
  useful check.

### Performance

A comic is 20–200 large images; loading them all is an easy way to eat a gigabyte of RAM.

- Decode the current page on demand, off the main actor.
- Prefetch only immediate neighbors (±1, maybe ±2).
- Bounded cache (a handful of decoded pages), evicting by distance from the current page.
- Keep the archive handle open for the session rather than reopening per page.
- Cancel in-flight decodes when the user pages past them.

---

## Keyboard map

Paging is the primary interaction and must feel instant.

| Key | Action |
|---|---|
| `Space`, `→`, `↓`, `Page Down`, `l`, `j` | Next page |
| `Shift-Space`, `←`, `↑`, `Page Up`, `h`, `k` | Previous page |
| `Home` / `End` | First / last page |
| `d` | Toggle dual-page layout |
| `f` | Toggle full screen |
| `q` | Quit |
| `⌘O` | Open file |
| `⌘I` | Toggle metadata inspector |
| `Esc` | Exit full screen |

Every reading command also appears in the menu bar with a ⌘ shortcut, because on a Mac the menu bar
is how an app documents itself. The two layers coexist deliberately: bare keys are the reading
posture, menu shortcuts are the discoverable ones. They never double-fire — menu key equivalents are
consumed before the view's `onKeyPress` ever sees them.

| Menu | Item | Shortcut |
|---|---|---|
| File | Open… / Open Recent ▸ | `⌘O` |
| View | Dual Page (toggle) | `⌘2` |
| View | Comic Info (toggle) | `⌘I` |
| View | Enter Full Screen | `⌃⌘F` (system) |
| Go | Next / Previous Page | `⌘→` / `⌘←` |
| Go | First / Last Page | `⌘Home` / `⌘End` |

Reading commands are disabled with no book open. `CommandMenu` and `CommandGroup` do **not** accept
`.disabled()` — it goes on the individual items.

Rules: at the first or last page the corresponding key is a no-op — never wrap, never beep. Key
handling belongs in the View via SwiftUI `.onKeyPress` and `Commands`; the resulting
`ReaderAction.nextPage` / `.previousPage` carries no key information into the ViewModel. Bounds logic
lives in the UseCase, not in the key handler. Split by ownership: paging keys (including `hjkl`) are
domain input and live in the package's `ReaderView`; `q` (quit) and `f` (fullscreen) are app-shell
keys handled in the app target's `RootView`, reached when the reader lets the press bubble up.

---

## Dual-page layout

`d` toggles `ReaderState.isDualPage`. When on, `secondaryImage` holds the right-hand page and
`displayedPageCount` is 2.

**A wide page is never paired.** A landscape page is already a two-page spread — scanned that way, or
a wide layout page — so pairing it would put four pages of content on screen and squash both.
`SpreadRules` (pure, unit-tested) decides: pair only when dual-page is on, a companion exists, and
neither page is landscape. `DefaultReaderUseCase.companion(for:at:in:)` checks the current page's
shape *before* decoding a companion, so a solo wide page costs no extra decode.

Navigation follows what is on screen: forward steps by `displayedPageCount`, so a solo wide page
advances by one and a pair by two. Backward steps by the fixed dual stride and is clamped to 0 —
without the clamp, toggling mid-book can leave an odd index from which page 1 is unreachable.
Companion pages are fetched with `refocus: false` so the right-hand page does not drag
`ArchiveSession`'s eviction window forward.

Pairing starts wherever you are rather than forcing odd/even alignment: there is no cover-alone
special case, and the mode is not persisted across launches. Toggling does not resize the window —
it re-renders in place, because a window jumping on every `d` press would be worse than letterboxing.

Verified live via synthetic keystrokes on a 6-page fixture whose page 3 is wide:
`1 / 6` → `d` → `1–2 / 6` → `3 / 6` (alone) → `4–5 / 6` → `6 / 6`.

## Recent comics and session restore

`ReadingProgressGateway` persists both the page within a book and which book was open last.
`lastOpenedURL` returns nil for a file that has moved or been deleted, so a vanished comic is simply
"no session" rather than an error — the same rule the per-file progress follows.

On launch with no document, `AppDelegate` waits 250 ms before calling `restoreLastSession()`. The
delay is deliberate: Finder can deliver an open event slightly after launch, and restoring
immediately would load two comics back to back. `restoreLastSession()` is also a no-op when a book is
already open, so a document handed over at launch always wins.

Open Recent is fed by `NSDocumentController.noteNewRecentDocumentURL`, which also populates the Dock
icon's menu. It is driven from `state.book?.url` changing — that only happens on a *successful* open,
so a mislabeled CBR or a broken file never lands in the menu. Note that
`CommandGroup(replacing: .newItem)` removes the stock New/Open/**Open Recent** group wholesale, which
is why Open Recent has to be rebuilt by hand.

## Window sizing

Opening a book publishes `ReaderState.coverGeometry` — the aspect ratio of the page shown at open
(page 1, unless progress resumed further in). `RootView` observes it and calls `WindowSizing.fit`,
which asks `WindowFit.contentSize` in the package for the geometry and then moves the NSWindow.

Only on open: resizing on every page turn would fight the user, and double-page spreads would make
the window jump. `CoverGeometry` carries a fresh `UUID` so reopening the same file still triggers a
resize.

`WindowFit`'s rules, in order: anchor on the window's current height (or 85% of the screen if the
window is still at its minimum, meaning the user has never sized it), shrink to fit 95% of the
screen preserving aspect, then grow to the minimum size — also preserving aspect, so minimums win
over screen fit on a screen too small for them. Measured behavior: portrait/landscape/square pages
produce windows matching their aspect to within 0.001. Heights vary run to run because of the
screen-fit clamp; that is rule 2 working, not a bug.

Gotcha: the main SwiftUI window reports **zero chrome** (`contentRect(forFrameRect:) == frame`), so
its content aspect equals its frame aspect. A plain `NSWindow` on this OS has 32pt of chrome, and
the About window does too. Don't hardcode a title-bar height — read it from the window.

## About window

A separate `Window` scene (`AppWindow.about`), replacing the stock panel via
`CommandGroup(replacing: .appInfo)` because the standard About panel can't show the pronunciation or
full license texts. It is not a Router step — the Router covers screens inside the main window, and
this is its own scene.

`OpenSourceLicense.all` in CMXKit holds third-party attribution, including full license text since
MIT requires the notice to ship. **CMXKit owns this list because CMXKit owns the dependencies** — add
or drop a package and its attribution travels with it. Today that is ZIPFoundation (MIT) alone.

## Conventions

- **Swift 6 language mode**, strict concurrency. Toolchain here is Swift 6.4.
- Minimum deployment target **macOS 15.0** (adjust in one place if that changes).
- `@MainActor` on ViewModels and Views. Gateways and UseCases are actor-isolated or `Sendable`; image
  decoding happens off the main actor.
- `@Observable` for state, not `ObservableObject`, on new code.
- Views submit `ReaderAction` values. Do not expose mutating methods from a ViewModel to a View.
- No force unwraps (`!`) and no `try!` in non-test code. Archive contents are untrusted input.
- Dependencies: prefer none. ZIP reading is the one defensible third-party need — if a package is
  added for it, it stays behind `ArchiveGateway` so it can be swapped without touching another file.
- File naming matches the primary type. One primary type per file.

### Testing

Logic lives in `CMXKit` precisely so it is testable without a UI. What must have tests:

- Page ordering, including the numeric-vs-lexicographic cases and junk-entry filtering.
- `ComicInfo.xml` parsing: full file, partial file, absent file, malformed XML.
- `ReaderUseCase` navigation bounds at first and last page.
- `AppRouter.nextStep(from:with:)` — it is a pure function, so assert step transitions directly. Keep
  this test in place as screens are added; it is the cheapest place to catch routing regressions.
- Reading-progress persistence round-trip, including a saved path that no longer exists.

To eyeball a SwiftUI view without launching the app, render it with `ImageRenderer` from a throwaway
test. Two hard limits: it draws **nothing** inside a `ScrollView`, and `Button`/`Link` come out as
placeholder blocks — which is why `LicenseList` is split out of `AboutView`. `NSApp` is nil outside a
running app, so use `NSApplication.shared`.

Use fixture `.cbz` files in `Tests/CMXKitTests/Fixtures/` — a few tiny images beat a real comic.
UseCase tests use mock Gateways; they never open a real archive off disk. Don't test SwiftUI views
directly — if something is hard to test, move it out of the View.

---

## Build and test

Logic work (the common case) needs no Xcode:

```sh
swift build --package-path CMXKit
swift test  --package-path CMXKit
```

Whole app:

```sh
xcodebuild -project cmx.xcodeproj -scheme cmx -destination 'platform=macOS' build
xcodebuild -project cmx.xcodeproj -scheme cmx -destination 'platform=macOS' test
```

**If `xcodebuild` fails** with `tool 'xcodebuild' requires Xcode`, the active developer directory is
still pointed at the Command Line Tools. Fix it once:

```sh
sudo xcode-select -s /Applications/Xcode.app
xcodebuild -version          # verify
```

`swift build` / `swift test` against `CMXKit` work either way, so logic work is never blocked on this.

### Install

```sh
scripts/install.sh            # build Release, install to /Applications, lsregister
scripts/install.sh --no-build # reinstall the last Release build (from build/)
```

The script quits a running cmx, builds Release into `build/` (gitignored), copies with `ditto`
(preserves the code signature — never plain `cp`), and force-registers with LaunchServices so the
`.cbz` association and icons refresh immediately. Run it whenever a change should reach the installed
copy — the file association points at `/Applications/cmx.app`, not at DerivedData builds.

The default-handler choice (cmx opens `.cbz`) is a one-time LaunchServices setting already made; it
survives reinstalls and is NOT part of the script. If it's ever lost: Finder → Get Info on a `.cbz` →
Open with → cmx → Change All.

**Definition of done:** the package builds clean and `swift test` passes, with no new warnings. When
the change touches the app target, it must also build. Don't report a task complete before that.

---

## Working notes

- **State after the first dev pass (2026-09-09):** all layers implemented and wired; 40 package
  tests pass; the app target builds. Not yet done: a settings screen (Router is wired but
  `AppCoordinator.show(step:)` is a no-op), any preferences UI, and a real app icon. The app has not
  been exercised by hand yet — first manual smoke test still outstanding.
- The app target uses **synchronized folder groups** (`objectVersion 110`): any file added under
  `cmx/` joins the target automatically, no pbxproj edit needed. The local `CMXKit` package reference
  was hand-wired into the pbxproj (`XCLocalSwiftPackageReference`, ids `CA…AA/AB/AC`).
- Xcode's MCP bridge can hold a stale in-memory project model after on-disk restructuring — it once
  re-saved a ghost copy of the project into `cmx/` and reported a vacuous 0.5s "successful" build.
  If an MCP build looks too fast or produces no product, close and reopen the workspace, and treat
  `xcodebuild` as ground truth.
- App icon + `.cbz` document icon are generated, not hand-drawn. `scripts/generate-icons.sh` redraws
  everything and installs it (appiconset PNGs + `cmx/cbz.icns`); `generate-icons.swift` does the
  drawing. Edit the script, never the PNGs.
- **Every size is drawn at its own pixel size — nothing is downscaled.** A single 1024 master looked
  fine at 128px and was mush at 16px: a 9pt panel stroke scales to 0.14px and vanishes, so the two
  lower panels merged into one grey block. The `Detail` enum picks artwork per size — `minimal` (16px:
  accent band plus one bordered panel), `simplified` (32–64px: bubble plus two bordered panels), and
  `full` (128px+: the original drawing, unchanged).
- Small-size rules that actually mattered, all learned the hard way: separate shapes with **gaps of
  filled background, never hairline strokes**; give panels a border on *every* side, since a gutter
  alone lets them merge into the page; snap rects to whole pixels and re-centre after snapping, or
  rounding shunts the motif sideways; put page edges on **half**-pixels so a 1px border lands in one
  column instead of straddling two; skip shadows, rotation, halftone and text below 128px.
- Verify with an ASCII pixel map (`colorAt` per pixel) rather than by eye — that is what caught a
  guard silently dropping the 16px panel entirely. Note that `NSWorkspace.icon(forFile:)` can serve a
  generic placeholder at some sizes; render the `.icns` representations directly to check the file.
- A `.xcodeproj` is a generated-looking bundle; edit it through Xcode, MCP tools, or careful targeted
  changes, not bulk rewrites.
- **App Sandbox off.** The app opens any `.cbz` anywhere on the filesystem, so it ships unsandboxed:
  no user-selected-file entitlement, and no security-scoped bookmarks — persisting a plain file path
  for resume works and reopens correctly. This rules out Mac App Store distribution, which is the
  right trade for a personal tool; direct distribution needs only Developer ID signing and
  notarization. If MAS ever becomes a goal, sandboxing is the change that forces bookmark-based
  persistence, so keep path handling inside `ReadingProgressGateway` where it can be swapped.
- Resume state keyed by file path will go stale when files move or are deleted. Treat a missing path
  as "no saved progress", never as an error.
