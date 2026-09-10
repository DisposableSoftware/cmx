// CMXKit — all cmx logic lives in this package so it is testable without an app host.
//
// Layer layout (see ../../../CLAUDE.md for the full contract):
//   Container/  composition root; the only place concrete types are constructed
//   Gateways/   all I/O — ZIP reading, ComicInfo.xml parsing, progress persistence
//   UseCases/   business logic — open a book, page navigation rules, prefetch policy
//   State/      observable shared state
//   Models/     domain types
//   Routing/    AppStep, AppRouter, AppRoutingUseCase
//   UI/         SwiftUI views, ViewModels, Action enums
//
// Data flows one direction: View -> ViewModel -> UseCase -> Gateway.
// Every layer boundary is a protocol.
