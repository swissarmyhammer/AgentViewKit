import EditorDiff
import EditorStyle
import EditorSwiftUI
import SwiftUI

/// What a view kit shows for a diff: the EditorKit `DiffView`, or a note in
/// its place.
///
/// The diff takes the ``SwiftUI/EnvironmentValues/diffLayout`` and has no
/// soft wrap: the inline layout takes the EditorKit wrap mode `.none`, so a
/// line wider than the view scrolls sideways, and the text, the line-number
/// gutters and the line colors keep one row for each line (finding of
/// ^8q34yt8). The side-by-side layout keeps one row for each line already. The
/// EditorKit `DiffView` reads the EditorKit theme of the environment.
///
/// The note is a label in the `ui` font role and `\.themeSecondary`, for a
/// patch that a kit cannot read, a binary file or a diff that failed to load.
/// VoiceOver reads the note as its text.
///
/// The view has no padding of its own (EditorKit `style.md`, rule 10).
public struct DiffContentView: View {
  /// What the view shows.
  private enum Content {
    /// A parsed patch.
    case diff(UnifiedDiff)

    /// A note in place of a diff.
    case note(text: String, systemImage: String, identifier: String)
  }

  /// What the view shows.
  private let content: Content

  @Environment(\.diffLayout) private var layout
  @Environment(\.themeSecondary) private var themeSecondary

  /// Makes the view of a parsed patch.
  ///
  /// - Parameter diff: The parsed patch.
  public init(diff: UnifiedDiff) {
    content = .diff(diff)
  }

  /// Makes a note in place of a diff.
  ///
  /// - Parameters:
  ///   - text: The text of the note.
  ///   - systemImage: The SF Symbol of the note.
  ///   - identifier: The accessibility identifier of the note.
  public init(note text: String, systemImage: String, identifier: String) {
    content = .note(text: text, systemImage: systemImage, identifier: identifier)
  }

  public var body: some View {
    switch content {
    case .diff(let diff):
      EditorSwiftUI.DiffView(patch: diff)
        .diffLayout(layout.documentLayout)
        .diffWrapMode(.none)
    case .note(let text, let systemImage, let identifier):
      Label(text, systemImage: systemImage)
        .foregroundStyle(themeSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier(identifier)
    }
  }
}

#Preview("A diff") {
  if let diff = try? UnifiedDiff.parse(StylePreviewFixtures.patch) {
    DiffContentView(diff: diff)
  }
}

#Preview("A note") {
  DiffContentView(note: StylePreviewFixtures.fileName, systemImage: SharedSymbol.binary, identifier: "note")
}
