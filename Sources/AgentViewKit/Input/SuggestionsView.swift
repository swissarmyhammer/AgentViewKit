import SwiftUI

/// A horizontal row of suggested prompts in Liquid Glass chips (plan.md §9 D).
///
/// A tap on a chip sets the composer text to the suggestion. The view writes
/// the text through ``SwiftUI/EnvironmentValues/promptText``, the
/// ``PromptEditorContext/text`` binding of the nearest ``PromptInputView``.
/// The view is empty when the list is empty, or when it is not in a composer.
///
/// ``DefaultPromptAccessory`` shows this view with the prompts of
/// ``SwiftUI/EnvironmentValues/promptSuggestions``, in the empty state and
/// after a turn.
public struct SuggestionsView: View {
  /// The start of the accessibility identifier of each chip.
  public static let chipIdentifierPrefix = "prompt-suggestion-"

  /// The suggested prompts, in the order to show.
  let suggestions: [String]

  @Environment(\.promptText) private var text
  @Environment(\.agentTheme) private var theme

  /// Makes the row.
  ///
  /// - Parameter suggestions: The suggested prompts, in the order to show.
  public init(suggestions: [String]) {
    self.suggestions = suggestions
  }

  /// The accessibility identifier of the chip at `index`.
  ///
  /// Two suggestions can have the same text, so the identifier holds the
  /// position of the chip.
  ///
  /// - Parameter index: The position of the suggestion in the list.
  /// - Returns: The identifier, such as `prompt-suggestion-0`.
  public static func chipIdentifier(at index: Int) -> String {
    AccessibilityIdentifier.make(prefix: chipIdentifierPrefix, value: String(index))
  }

  public var body: some View {
    if let text, !suggestions.isEmpty {
      ScrollView(.horizontal) {
        HStack(spacing: theme.spacing.s) {
          ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
            Button(suggestion) {
              text.wrappedValue = AttributedString(suggestion)
            }
            .buttonStyle(.glass)
            .help(String(localized: "Use this prompt"))
            .accessibilityIdentifier(Self.chipIdentifier(at: index))
          }
        }
      }
      .scrollIndicators(.hidden)
    }
  }
}
