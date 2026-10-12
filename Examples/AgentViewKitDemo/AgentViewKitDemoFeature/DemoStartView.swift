import SwiftUI

/// The state of the start of a demo tab, in a column that has no content yet.
///
/// While the start runs, the view shows a progress view with the starting
/// text. After a failed start, it shows the ``DemoFailureLabel`` of the error.
/// After a start that gave the content of the tab, it shows nothing. The ACP
/// tab and the Gallery tab show their start with this view.
struct DemoStartView: View {
  /// The state of the start.
  enum Phase {
    /// The start runs.
    case starting

    /// The start failed with the error.
    case failed(any Error)

    /// The start gave the content of the tab.
    case started
  }

  /// The state of the start.
  let phase: Phase

  /// The text of the progress view while the start runs.
  let startingText: String

  /// The accessibility identifier of the progress view.
  let startingIdentifier: String

  /// The accessibility identifier of the failure label.
  let failureIdentifier: String

  var body: some View {
    switch phase {
    case .starting:
      ProgressView(startingText)
        .accessibilityIdentifier(startingIdentifier)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed(let error):
      DemoFailureLabel(error: error, identifier: failureIdentifier)
    case .started:
      EmptyView()
    }
  }
}
