import AgentViewKit
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The text of a failed request of a demo tab, in the error color of the
/// EditorKit theme.
///
/// The text is ``DemoFailureText/text(of:)``: the localized description of
/// the error when it has one, so that the user reads the message of the
/// error and not the name of its case.
struct DemoFailureLabel: View {
  /// The symbol of the label.
  static let symbol = "xmark.octagon.fill"

  /// The error of the request.
  let error: any Error

  /// The accessibility identifier of the label.
  let identifier: String

  /// The EditorKit theme. The label uses its error color.
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    Label(DemoFailureText.text(of: error), systemImage: Self.symbol)
      .foregroundStyle(editorTheme.severityError)
      .padding()
      .accessibilityIdentifier(identifier)
  }
}
