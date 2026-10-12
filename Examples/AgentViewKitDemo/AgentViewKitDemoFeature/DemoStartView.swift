import SwiftUI

/// A demo tab that starts its content and shows the start with
/// ``DemoStartView``.
///
/// The ACP tab and the Gallery tab conform. Each tab gives the text and the
/// accessibility identifiers of its start, and ``DemoStartView`` reads them.
protocol DemoStartingTab {
  /// The accessibility identifier of the progress view of the start.
  static var startingIdentifier: String { get }

  /// The accessibility identifier of the text that shows a failed start.
  static var failureIdentifier: String { get }

  /// The text of the progress view of the start.
  var startingText: String { get }
}

/// The state of the start of a demo tab, in a column that has no content yet.
///
/// While the start runs, the view shows a progress view with the starting
/// text of the tab. After a failed start, it shows the ``DemoFailureLabel`` of
/// the error. After a start that gave the content of the tab, it shows
/// nothing. The ACP tab and the Gallery tab show their start with this view.
struct DemoStartView<Started>: View {
  /// The state of the start.
  let phase: DemoStartPhase<Started>

  /// The text of the progress view while the start runs.
  let startingText: String

  /// The accessibility identifier of the progress view.
  let startingIdentifier: String

  /// The accessibility identifier of the failure label.
  let failureIdentifier: String

  /// Makes the start view of a tab.
  ///
  /// - Parameters:
  ///   - phase: The state of the start of the tab.
  ///   - tab: The tab. The view shows its starting text and uses its
  ///     accessibility identifiers.
  init<Tab: DemoStartingTab>(phase: DemoStartPhase<Started>, tab: Tab) {
    self.phase = phase
    startingText = tab.startingText
    startingIdentifier = Tab.startingIdentifier
    failureIdentifier = Tab.failureIdentifier
  }

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
