import SwiftUI

// MARK: - Layout context

/// The data that the kit gives to the layout slot of an elicitation form
/// (plan.md §13.1, §13.2).
///
/// The default layout is ``ElicitationLayout``. A custom layout gets the same
/// context from ``SwiftUI/View/elicitationLayout(_:)``. Show each field with
/// ``ElicitationFieldView``, so that the field overrides apply.
public struct ElicitationLayoutContext {
  /// The context of each field, in the order of the form.
  public let fields: [ElicitationFieldContext]

  /// The largest number of fields that the layout shows inline. A form with
  /// more fields shows one tab for each field.
  public let tabThreshold: Int

  /// Makes a layout context.
  ///
  /// - Parameters:
  ///   - fields: The context of each field.
  ///   - tabThreshold: The largest number of fields that show inline.
  public init(fields: [ElicitationFieldContext], tabThreshold: Int) {
    self.fields = fields
    self.tabThreshold = tabThreshold
  }

  /// Whether the layout shows one tab for each field. This is `true` when
  /// the form has more than ``tabThreshold`` fields.
  public var usesTabs: Bool {
    fields.count > tabThreshold
  }
}

// MARK: - Tab marks

/// The text of the required mark and the answered mark of a field tab
/// (plan.md §13.1).
///
/// VoiceOver reads this text as the value of the tab.
public nonisolated enum ElicitationTabMarks {
  /// The mark of a field that must have an answer.
  public static let required = "Required"
  /// The mark of a field that can stay empty.
  public static let optional = "Optional"
  /// The mark of a field with an answer that passes validation.
  public static let answered = "Answered"
  /// The mark of a field with no valid answer.
  public static let notAnswered = "No answer"

  /// The accessibility value of a tab.
  ///
  /// - Parameters:
  ///   - required: Whether the field must have an answer.
  ///   - answered: Whether the field has an answer that passes validation.
  /// - Returns: The two marks, with a comma between them.
  public static func text(required: Bool, answered: Bool) -> String {
    let requiredMark = required ? Self.required : optional
    let answeredMark = answered ? Self.answered : notAnswered
    return "\(requiredMark), \(answeredMark)"
  }
}

// MARK: - Default layout

/// The default layout of an elicitation form (plan.md §13.1).
///
/// When the form has ``ElicitationLayoutContext/tabThreshold`` fields or
/// fewer, the layout shows each field inline. Otherwise it shows a row of
/// tab chips and the field of the selected tab. Each chip shows the title,
/// the required mark, and the answered mark of its field.
public struct ElicitationLayout: View {
  /// The default largest number of fields that show inline. A form with
  /// more than one field shows tabs.
  public nonisolated static let defaultTabThreshold = 1

  /// The symbol of a tab with an answer.
  static let answeredSymbol = "checkmark.circle.fill"
  /// The symbol of a tab with no answer.
  static let notAnsweredSymbol = "circle"
  /// The opacity of the background of the selected tab.
  static let selectedTabOpacity = 0.2

  /// The context of the layout.
  let context: ElicitationLayoutContext

  /// The name of the field of the selected tab, or `nil` for the first
  /// field.
  @State private var selection: String?

  @Environment(\.agentTheme) private var theme

  /// Makes the default layout.
  ///
  /// - Parameter context: The context of the layout.
  public init(context: ElicitationLayoutContext) {
    self.context = context
  }

  public var body: some View {
    if context.usesTabs {
      tabbed
    } else {
      VStack(alignment: .leading, spacing: theme.spacing.m) {
        ForEach(context.fields, id: \.schema.name) { field in
          ElicitationFieldView(context: field)
        }
      }
    }
  }

  /// The tab row and the field of the selected tab.
  private var tabbed: some View {
    let selected =
      context.fields.first { $0.schema.name == selection } ?? context.fields.first
    return VStack(alignment: .leading, spacing: theme.spacing.m) {
      ScrollView(.horizontal) {
        HStack(spacing: theme.spacing.xs) {
          ForEach(context.fields, id: \.schema.name) { field in
            tab(field, isSelected: field.schema.name == selected?.schema.name)
          }
        }
      }
      .scrollIndicators(.hidden)
      if let selected {
        ElicitationFieldView(context: selected)
          .id(selected.schema.name)
      }
    }
  }

  /// The chip of one field.
  ///
  /// - Parameters:
  ///   - field: The context of the field.
  ///   - isSelected: Whether the layout shows the field now.
  /// - Returns: The chip.
  private func tab(_ field: ElicitationFieldContext, isSelected: Bool) -> some View {
    let schema = field.schema
    let answered = ElicitationValidator.isAnswered(field.value.wrappedValue, against: schema)
    return Button {
      selection = schema.name
    } label: {
      HStack(spacing: theme.spacing.xs) {
        Image(systemName: answered ? Self.answeredSymbol : Self.notAnsweredSymbol)
          .foregroundStyle(answered ? theme.statusColors.completed : .secondary)
        Text(schema.title)
        if schema.required {
          Text(verbatim: "*")
            .foregroundStyle(theme.statusColors.failed)
        }
      }
      .padding(.horizontal, theme.spacing.s)
      .padding(.vertical, theme.spacing.xs)
      .background(
        Capsule().fill(isSelected ? theme.accent.opacity(Self.selectedTabOpacity) : .clear)
      )
      .overlay(Capsule().strokeBorder(.separator))
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isButton)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityLabel(schema.title)
    .accessibilityValue(ElicitationTabMarks.text(required: schema.required, answered: answered))
    .accessibilityAction { selection = schema.name }
    .accessibilityIdentifier(ElicitationView.tabIdentifier(for: schema.name))
  }
}

// MARK: - Slot

/// A function that makes the layout of an elicitation form.
public typealias ElicitationLayoutRenderer = @MainActor (ElicitationLayoutContext) -> AnyView

extension EnvironmentValues {
  /// The override of the layout of an elicitation form, or `nil` for
  /// ``ElicitationLayout``.
  @Entry public var elicitationLayoutOverride: ElicitationLayoutRenderer? = nil

  /// The largest number of fields that an elicitation form shows inline.
  @Entry public var elicitationTabThreshold: Int = ElicitationLayout.defaultTabThreshold
}

extension View {
  /// Sets the largest number of fields that each elicitation form in this
  /// view shows inline. A form with more fields shows tabs.
  ///
  /// - Parameter tabThreshold: The largest number of inline fields.
  /// - Returns: A view that gives the threshold to its subtree.
  public func elicitationLayout(tabThreshold: Int) -> some View {
    environment(\.elicitationTabThreshold, tabThreshold)
  }

  /// Replaces the layout of each elicitation form in this view.
  ///
  /// - Parameter content: The function that makes the layout.
  /// - Returns: A view that gives the override to its subtree.
  public func elicitationLayout<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (ElicitationLayoutContext) -> Content
  ) -> some View {
    environment(\.elicitationLayoutOverride) { context in AnyView(content(context)) }
  }
}
