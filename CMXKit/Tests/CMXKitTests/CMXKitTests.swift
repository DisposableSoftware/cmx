// Tests for CMXKit. Uses Swift Testing (`import Testing`).
//
// Required coverage (see ../../../CLAUDE.md):
//   - page ordering: numeric-vs-lexicographic, junk-entry filtering
//   - ComicInfo.xml parsing: full, partial, absent, malformed
//   - ReaderUseCase navigation bounds at first and last page
//   - AppRouter.nextStep(from:with:) step transitions
//   - reading-progress round-trip, including a saved path that no longer exists
//
// UseCase tests use mock Gateways and never open a real archive off disk.
// Fixture archives belong in Fixtures/.
