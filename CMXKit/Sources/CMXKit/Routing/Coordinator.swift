/// The navigation engine. The app target provides the implementation; the
/// package only ever asks it to show a step.
@MainActor
public protocol Coordinator: AnyObject {
    func show(step: AppStep)
}
