import SwiftUI

/// The state of a demo tab that starts its content.
///
/// The ACP tab and the Gallery tab of the demo app hold this state. Each tab
/// starts its agent one time with ``start(_:with:)``. The demo app shows a
/// phase that has not started with its `DemoStartView`.
///
/// - `Started`: The content of the tab after the start, for example the
///   running agent.
public enum DemoStartPhase<Started> {
  /// The start runs.
  case starting

  /// The start failed with the error.
  case failed(any Error)

  /// The start gave the content of the tab.
  case started(Started)

  /// Runs the start of a tab one time.
  ///
  /// The start runs the operation only while the phase is ``starting``. The
  /// operation sets the phase that it gives, for example ``started(_:)``. An
  /// operation that throws sets ``failed(_:)`` with its error. A phase that
  /// started or failed does not run the operation again.
  ///
  /// - Parameters:
  ///   - phase: The phase of the tab.
  ///   - operation: Starts the content of the tab and sets the phase.
  public static func start(_ phase: Binding<Self>, with operation: () async throws -> Void) async {
    guard case .starting = phase.wrappedValue else { return }
    do {
      try await operation()
    } catch {
      phase.wrappedValue = .failed(error)
    }
  }
}
