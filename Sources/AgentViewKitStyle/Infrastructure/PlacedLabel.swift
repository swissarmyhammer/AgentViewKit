import AppKit
import EditorStyle
import EditorSwiftUI
import SwiftUI

/// A plain text that the user can select, in the text color of its place.
///
/// The view is an EditorKit `EditorLabel`. The label joins the text selection
/// region of the environment, so that the text is part of the one selection
/// of a thread (AgentViewKit `Docs/decisions/text-selection.md`). Use it for a
/// selectable text of a view that shows on glass and in content, such as a
/// card or a status text. A view that shows only in content uses an
/// `EditorLabel` directly.
///
/// The color of the text follows EditorKit `style.md`, rule 6:
///
/// - In content, the label draws the theme role of `textColor`
///   (`editorTextColor(_:)`).
/// - On glass and chrome (`\.showsVibrantText`), each run with no color of
///   its own draws in the system label color of the role
///   (`NSColor.labelColor` or `NSColor.secondaryLabelColor`), never in a
///   theme color.
///
/// The label draws in the font of its place (`.font(_:)`). VoiceOver sees one
/// static text element.
public struct PlacedLabel: View {
  /// The text, with its attributes.
  let text: AttributedString

  /// The text that VoiceOver reads in place of ``text``, or `nil` for the
  /// text.
  let accessibilityText: String?

  /// The text color role of the text that has no color of its own.
  let textColor: EditorTextColorRole

  @Environment(\.showsVibrantText) private var showsVibrantText

  /// Makes a label of a text with its attributes, such as a URL with its
  /// host in bold.
  ///
  /// - Parameters:
  ///   - text: The text, with its attributes.
  ///   - accessibilityLabel: The text that VoiceOver reads in place of
  ///     `text`, or `nil` for `text`.
  ///   - textColor: The text color role of the text that has no color of
  ///     its own. The default is `.primary`.
  public init(
    _ text: AttributedString, accessibilityLabel: String? = nil, textColor: EditorTextColorRole = .primary
  ) {
    self.text = text
    self.accessibilityText = accessibilityLabel
    self.textColor = textColor
  }

  /// Makes a label of a plain string, with no attributes.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - accessibilityLabel: The text that VoiceOver reads in place of
  ///     `text`, or `nil` for `text`.
  ///   - textColor: The text color role of the text. The default is
  ///     `.primary`.
  public init(verbatim text: String, accessibilityLabel: String? = nil, textColor: EditorTextColorRole = .primary) {
    self.init(AttributedString(text), accessibilityLabel: accessibilityLabel, textColor: textColor)
  }

  /// The `EditorLabel` of the text.
  public var body: some View {
    EditorLabel(Self.text(text, textColor: textColor, isVibrant: showsVibrantText), accessibilityLabel: accessibilityText)
      .editorTextColor(textColor)
  }

  /// The text that the label shows in a place.
  ///
  /// - Parameters:
  ///   - text: The text, with its attributes.
  ///   - textColor: The text color role of the text that has no color of its
  ///     own.
  ///   - isVibrant: `true` on glass and chrome.
  /// - Returns: `text` in content. On glass and chrome, `text` with the
  ///   system label color of `textColor` on each run that has no color of
  ///   its own.
  static func text(_ text: AttributedString, textColor: EditorTextColorRole, isVibrant: Bool) -> AttributedString {
    guard isVibrant else { return text }
    var result = text
    let color = systemColor(of: textColor)
    for run in text.runs where run.foregroundColor == nil && run.appKit.foregroundColor == nil {
      result[run.range].appKit.foregroundColor = color
    }
    return result
  }

  /// The system label color of a text color role: the color of a text on
  /// glass and chrome.
  ///
  /// - Parameter role: The text color role.
  /// - Returns: `NSColor.labelColor` for `.primary`, and
  ///   `NSColor.secondaryLabelColor` for `.secondary`.
  private static func systemColor(of role: EditorTextColorRole) -> NSColor {
    switch role {
    case .primary: .labelColor
    case .secondary: .secondaryLabelColor
    }
  }
}
