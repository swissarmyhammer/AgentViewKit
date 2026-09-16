import SwiftUI

/// The six field slots of an elicitation form (plan.md §13.2).
///
/// Each ``ElicitationFieldSchema/Kind`` case has one slot. Each slot has one
/// typed override modifier.
public enum ElicitationFieldSlot: String, Sendable, Hashable, CaseIterable {
  /// The slot of ``ElicitationFieldSchema/Kind/text(minLength:maxLength:pattern:format:)``.
  case text
  /// The slot of ``ElicitationFieldSchema/Kind/number(integer:minimum:maximum:)``.
  case number
  /// The slot of ``ElicitationFieldSchema/Kind/boolean``.
  case toggle
  /// The slot of ``ElicitationFieldSchema/Kind/date(dateTime:)``.
  case date
  /// The slot of ``ElicitationFieldSchema/Kind/singleChoice(_:)``.
  case singleChoice
  /// The slot of ``ElicitationFieldSchema/Kind/multiChoice(_:minItems:maxItems:)``.
  case multiChoice

  /// Makes the slot of a field kind.
  ///
  /// - Parameter kind: The field kind.
  public init(_ kind: ElicitationFieldSchema.Kind) {
    switch kind {
    case .text: self = .text
    case .number: self = .number
    case .boolean: self = .toggle
    case .date: self = .date
    case .singleChoice: self = .singleChoice
    case .multiChoice: self = .multiChoice
    }
  }
}

/// The field view overrides of the environment (plan.md §13.2).
///
/// Set an override with a typed modifier, such as
/// ``SwiftUI/View/elicitationTextField(_:)``. ``ElicitationFieldView`` shows
/// the override of the slot of its field, or the default view when the slot
/// has no override.
public struct ElicitationFieldOverrides: Sendable {
  /// A function that makes the view of one field.
  public typealias Renderer = @MainActor (ElicitationFieldContext) -> AnyView

  /// The renderers, keyed by their slot.
  private var renderers: [ElicitationFieldSlot: Renderer] = [:]

  /// Makes an empty set of overrides.
  public init() {}

  /// The renderer of `slot`, or `nil` when the slot has no override.
  public subscript(slot: ElicitationFieldSlot) -> Renderer? {
    get { renderers[slot] }
    set { renderers[slot] = newValue }
  }
}

extension EnvironmentValues {
  /// The field view overrides that ``ElicitationFieldView`` reads.
  ///
  /// The value has no override until a host sets one with a typed modifier.
  @Entry public var elicitationFieldOverrides = ElicitationFieldOverrides()
}

extension View {
  /// Replaces the view of each text field in this view.
  ///
  /// - Parameter content: The function that makes the view of a field.
  /// - Returns: A view that gives the override to its subtree.
  public func elicitationTextField<Field: View>(
    @ViewBuilder _ content: @escaping @MainActor (ElicitationFieldContext) -> Field
  ) -> some View {
    elicitationFieldOverride(.text, content)
  }

  /// Replaces the view of each number field in this view.
  ///
  /// - Parameter content: The function that makes the view of a field.
  /// - Returns: A view that gives the override to its subtree.
  public func elicitationNumberField<Field: View>(
    @ViewBuilder _ content: @escaping @MainActor (ElicitationFieldContext) -> Field
  ) -> some View {
    elicitationFieldOverride(.number, content)
  }

  /// Replaces the view of each boolean field in this view.
  ///
  /// - Parameter content: The function that makes the view of a field.
  /// - Returns: A view that gives the override to its subtree.
  public func elicitationToggleField<Field: View>(
    @ViewBuilder _ content: @escaping @MainActor (ElicitationFieldContext) -> Field
  ) -> some View {
    elicitationFieldOverride(.toggle, content)
  }

  /// Replaces the view of each date field in this view.
  ///
  /// - Parameter content: The function that makes the view of a field.
  /// - Returns: A view that gives the override to its subtree.
  public func elicitationDateField<Field: View>(
    @ViewBuilder _ content: @escaping @MainActor (ElicitationFieldContext) -> Field
  ) -> some View {
    elicitationFieldOverride(.date, content)
  }

  /// Replaces the view of each single-choice field in this view.
  ///
  /// - Parameter content: The function that makes the view of a field.
  /// - Returns: A view that gives the override to its subtree.
  public func elicitationSingleChoiceField<Field: View>(
    @ViewBuilder _ content: @escaping @MainActor (ElicitationFieldContext) -> Field
  ) -> some View {
    elicitationFieldOverride(.singleChoice, content)
  }

  /// Replaces the view of each multi-choice field in this view.
  ///
  /// - Parameter content: The function that makes the view of a field.
  /// - Returns: A view that gives the override to its subtree.
  public func elicitationMultiChoiceField<Field: View>(
    @ViewBuilder _ content: @escaping @MainActor (ElicitationFieldContext) -> Field
  ) -> some View {
    elicitationFieldOverride(.multiChoice, content)
  }

  /// Sets the override of `slot` for this view and each view in it.
  ///
  /// - Parameters:
  ///   - slot: The slot to replace.
  ///   - content: The function that makes the view of a field.
  /// - Returns: A view that gives the override to its subtree.
  private func elicitationFieldOverride<Field: View>(
    _ slot: ElicitationFieldSlot,
    _ content: @escaping @MainActor (ElicitationFieldContext) -> Field
  ) -> some View {
    transformEnvironment(\.elicitationFieldOverrides) { overrides in
      overrides[slot] = { context in AnyView(content(context)) }
    }
  }
}
