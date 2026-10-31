import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The empty state of a list or a pane: a `ContentUnavailableView` that draws
/// in the `ui` font role of the theme.
///
/// A `ContentUnavailableView` sets the fonts of its title and its description
/// itself, so the root font of `.editorTheme(_:)` does not reach them, and a
/// `.font(_:)` on the view does nothing. Only a font on the text inside it
/// counts. This view gives the role at the text styles that the system view
/// uses on macOS: the bold `title2` and the `title3`.
public struct EmptyStateView: View {
  /// The accessibility identifier of the title.
  public static let titleIdentifier = "empty-state-title"

  /// The accessibility identifier of the description.
  public static let descriptionIdentifier = "empty-state-description"

  /// The title.
  let title: String

  /// The SF Symbol above the title.
  let systemImage: String

  /// The line below the title.
  let description: Text

  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.placedSecondary) private var placedSecondary

  /// Makes an empty state.
  ///
  /// - Parameters:
  ///   - title: The title.
  ///   - systemImage: The SF Symbol above the title.
  ///   - description: The line below the title.
  public init(_ title: String, systemImage: String, description: Text) {
    self.title = title
    self.systemImage = systemImage
    self.description = description
  }

  public var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: systemImage)
        .font(editorTheme.font(for: .ui, style: .title2).weight(.bold))
        .accessibilityIdentifier(Self.titleIdentifier)
    } description: {
      description
        .font(editorTheme.font(for: .ui, style: .title3))
        .foregroundStyle(placedSecondary)
        .accessibilityIdentifier(Self.descriptionIdentifier)
    }
  }
}

#Preview("Empty state") {
  EmptyStateView("Nothing Here", systemImage: SharedSymbol.binary, description: Text(verbatim: "The items show here."))
}
