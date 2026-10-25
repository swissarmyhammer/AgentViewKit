import EditorStyle
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
/// while the agent does not run.
///
/// The glass of each chip has the id ``FloatingGlassID/suggestion(_:)`` with
/// the position of the chip (`.floatingGlassID(_:)`). Thus the
/// chips morph when they show or hide next to the composer (D113 answer 2).
public struct SuggestionsView: View {
  /// The start of the accessibility identifier of each chip.
  public static let chipIdentifierPrefix = "prompt-suggestion-"

  /// The symbol of each chip.
  static let chipSymbol = SharedSymbol.suggestion

  /// The suggested prompts, in the order to show.
  let suggestions: [String]

  @Environment(\.promptText) private var text
  @Environment(\.editorStyle) private var editorStyle

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
        HStack(spacing: editorStyle.spacing.s) {
          ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
            SuggestionChip(suggestion: suggestion, index: index, text: text)
          }
        }
      }
      .scrollIndicators(.hidden)
    }
  }
}

/// One chip of a ``SuggestionsView``: a Liquid Glass button that sets the
/// composer text to its suggestion.
///
/// The chip is a view of its own, so that a test can render its glass:
/// `ImageRenderer` draws nothing in the horizontal scroll view of
/// ``SuggestionsView``.
struct SuggestionChip: View {
  /// The suggested prompt of the chip.
  let suggestion: String

  /// The position of the chip in the list of suggestions.
  let index: Int

  /// The composer text that a tap on the chip sets.
  let text: Binding<AttributedString>

  var body: some View {
    Button(suggestion, systemImage: SuggestionsView.chipSymbol) {
      text.wrappedValue = AttributedString(suggestion)
    }
    .buttonStyle(.glass)
    .buttonBorderShape(.capsule)
    .floatingGlassID(FloatingGlassID.suggestion(index))
    .help(String(localized: "Use this prompt", bundle: .module))
    .accessibilityIdentifier(SuggestionsView.chipIdentifier(at: index))
    .agentControlScope(SuggestionsView.chipIdentifier(at: index))
  }
}

#Preview("Suggestions") {
  @Previewable @State var text = AttributedString()
  SuggestionsView(suggestions: PreviewFixtures.suggestions)
    .environment(\.promptText, $text)
}
