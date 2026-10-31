import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import SwiftUI

/// The tab chip of one field of an ``ElicitationLayout`` that shows tabs
/// (plan.md §13.1).
///
/// The chip shows the title, the required mark and the answered mark of its
/// field. The selected chip sits on the shared selection surface of
/// EditorKit. A chip is not a content tile, so it keeps the small padding of
/// a chip.
struct ElicitationTabChip: View {
  /// The context of the field of the tab.
  let field: ElicitationFieldContext

  /// Whether the layout shows the field of the tab now.
  let isSelected: Bool

  /// The action that selects the tab.
  let select: () -> Void

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.placedSecondary) private var placedSecondary

  var body: some View {
    let schema = field.schema
    let answered = ElicitationValidator.hasValidAnswer(value: field.value.wrappedValue, against: schema)
    Button(action: select) {
      HStack(spacing: editorStyle.spacing.xs) {
        Image(systemName: answered ? ElicitationLayout.answeredSymbol : ElicitationLayout.notAnsweredSymbol)
          .foregroundStyle(answered ? AnyShapeStyle(editorTheme.statusSucceeded) : placedSecondary)
        Text(schema.title)
        if schema.required {
          Text(verbatim: "*")
            .foregroundStyle(editorTheme.severityError)
        }
      }
      .padding(.horizontal, editorStyle.spacing.s)
      .padding(.vertical, editorStyle.spacing.xs)
      .selectableSurface(isSelected, radius: ElicitationLayout.tabRadius)
      .inlineEdge(radius: editorStyle.radii[ElicitationLayout.tabRadius])
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isButton)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityLabel(schema.title)
    .accessibilityValue(ElicitationTabMarks.text(required: schema.required, answered: answered))
    .accessibilityAction { select() }
    .accessibilityIdentifier(ElicitationView.tabIdentifier(for: schema.name))
  }
}

#Preview("Tab chips, the first selected") {
  @Previewable @State var answers: [String: JSONValue] = [:]
  let fields = PreviewFixtures.ElicitationFields.all.map { PreviewFixtures.fieldContext($0, answers: $answers) }
  HStack {
    ForEach(Array(fields.enumerated()), id: \.offset) { index, field in
      ElicitationTabChip(field: field, isSelected: index == fields.startIndex) {}
    }
  }
}
