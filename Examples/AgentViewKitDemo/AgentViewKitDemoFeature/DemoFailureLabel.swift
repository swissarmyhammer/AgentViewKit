import AgentViewKit
import SwiftUI

/// The bar of a failed request of a demo tab: a ``StatusBar`` with a failure
/// message, in the one banner layout of the kit.
///
/// The explanation is ``DemoFailureText/text(of:)``: the localized description
/// of the error when it has one, so that the user reads the message of the
/// error and not the name of its case. The text of the error can be long, so
/// the title line holds a short title of its own.
struct DemoFailureLabel: View {
  /// The title line of the bar.
  static let title = "The request failed"

  /// The error of the request.
  let error: any Error

  /// The accessibility identifier of the text of the bar.
  let identifier: String

  var body: some View {
    StatusBar(
      message: StatusBar.Message(
        title: Self.title, explanation: DemoFailureText.text(of: error), symbolName: SharedSymbol.error,
        identifier: identifier, severity: .failure),
      action: nil
    )
    .padding()
  }
}
