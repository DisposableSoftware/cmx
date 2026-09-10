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

Deliberately **out of scope** unless explicitly asked: a library/shelf browser, `.cbr`/RAR support,
two-page spreads, reading-direction toggles, cloud sync, annotations, iOS/iPadOS targets. A settings
screen is anticipated but not yet built — the Router is in place so adding one is additive.

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
| `Space`, `→`, `↓`, `Page Down` | Next page |
| `Shift-Space`, `←`, `↑`, `Page Up` | Previous page |
| `Home` / `End` | First / last page |
| `⌘O` | Open file |
| `⌘I` | Toggle metadata inspector |
| `Esc` | Exit full screen |

Rules: at the first or last page the corresponding key is a no-op — never wrap, never beep. Key
handling belongs in the View via SwiftUI `.onKeyPress` and `Commands`; the resulting
`ReaderAction.nextPage` / `.previousPage` carries no key information into the ViewModel. Bounds logic
lives in the UseCase, not in the key handler.

---

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
