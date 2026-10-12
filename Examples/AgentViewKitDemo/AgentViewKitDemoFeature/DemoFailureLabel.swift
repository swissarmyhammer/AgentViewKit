import AgentViewKit
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The text of a failed request of a demo tab, in the error color of the
/// EditorKit theme.
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
    Label(String(describing: error), systemImage: Self.symbol)
      .foregroundStyle(editorTheme.severityError)
      .padding()
      .accessibilityIdentifier(identifier)
  }
}
