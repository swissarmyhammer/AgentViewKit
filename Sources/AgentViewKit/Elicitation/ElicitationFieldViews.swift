import EditorCore
import EditorSwiftUI
import SwiftUI

// MARK: - Field view

/// The view of one elicitation field (plan.md §13.1, §13.2).
///
/// The view reads the slot of ``ElicitationFieldSchema/kind``. When the
/// environment has an override for that slot, the view shows the override.
/// Otherwise the view shows the default field view of the kind. Set an
/// override with a typed modifier, such as
/// ``SwiftUI/View/elicitationTextField(_:)``.
public struct ElicitationFieldView: View {
  /// The start of the accessibility identifier of each field.
  public static let identifierPrefix = "elicitation-field-"

  /// The context of the field.
  let context: ElicitationFieldContext

  @Environment(\.elicitationFieldOverrides) private var overrides

  /// Makes the view of a field.
  ///
  /// - Parameter context: The context of the field.
  public init(context: ElicitationFieldContext) {
    self.context = context
  }

  /// The accessibility identifier of the field named `name`.
  ///
  /// - Parameter name: The property name of the field.
  /// - Returns: `elicitation-field-<name>`.
  public static func identifier(for name: String) -> String {
    identifierPrefix + name
  }

  /// The accessibility identifier of the main control of the field named
  /// `name`.
  ///
  /// - Parameter name: The property name of the field.
  /// - Returns: `elicitation-field-<name>-control`.
  public static func controlIdentifier(for name: String) -> String {
    identifier(for: name) + "-control"
  }

  /// The accessibility identifier of the control of one choice of the field
  /// named `name`.
  ///
  /// - Parameters:
  ///   - name: The property name of the field.
  ///   - value: The value of the choice.
  /// - Returns: `elicitation-field-<name>-choice-<value>`.
  public static func choiceIdentifier(for name: String, value: String) -> String {
    identifier(for: name) + "-choice-" + value
  }

  /// The accessibility identifier of the validation messages of the field
  /// named `name`.
  ///
  /// - Parameter name: The property name of the field.
  /// - Returns: `elicitation-field-<name>-errors`.
  public static func errorsIdentifier(for name: String) -> String {
    identifier(for: name) + "-errors"
  }

  public var body: some View {
    if let override = overrides[ElicitationFieldSlot(context.schema.kind)] {
      override(context)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(context.identifier)
    } else {
      defaultField
    }
  }

  /// The default field view of the kind of the field.
  @ViewBuilder
  private var defaultField: some View {
    switch context.schema.kind {
    case .text:
      ElicitationTextField(context: context)
    case .number:
      ElicitationNumberField(context: context)
    case .boolean:
      ElicitationToggleField(context: context)
    case .date:
      ElicitationDateField(context: context)
    case .singleChoice:
      ElicitationSingleChoiceField(context: context)
    case .multiChoice:
      ElicitationMultiChoiceField(context: context)
    }
  }
}

// MARK: - Chrome

/// The parts that each default field view shows around its control: the
/// title, the required mark, the description, and the validation messages.
///
/// The chrome is one accessibility container with the identifier of the
/// field.
struct ElicitationFieldChrome<Control: View>: View {
  /// The text that VoiceOver reads for the required mark.
  static var requiredLabel: String { "Required" }

  /// The context of the field.
  let context: ElicitationFieldContext

  /// The control of the field.
  let control: Control

  @Environment(\.agentTheme) private var theme

  /// Makes the chrome.
  ///
  /// - Parameters:
  ///   - context: The context of the field.
  ///   - control: The control of the field.
  init(context: ElicitationFieldContext, @ViewBuilder control: () -> Control) {
    self.context = context
    self.control = control()
  }

  var body: some View {
    let schema = context.schema
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      HStack(spacing: theme.spacing.xs) {
        Text(schema.title)
          .font(.headline)
        if schema.required {
          Text(verbatim: "*")
            .foregroundStyle(theme.statusColors.failed)
            .accessibilityLabel(Self.requiredLabel)
        }
      }
      if let description = schema.description {
        Text(description)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      control
      if !context.validation.errors.isEmpty {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(context.validation.errors, id: \.self) { message in
            Text(message)
          }
        }
        .font(.caption)
        .foregroundStyle(theme.statusColors.failed)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(ElicitationFieldView.errorsIdentifier(for: schema.name))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(context.identifier)
  }
}

// MARK: - Text

/// The default view of a text field (plan.md §13.1).
///
/// The view shows an EditorKit input. The input is one line when the field
/// has a `maxLength` of ``multiLineThreshold`` or less. Otherwise the input
/// has more lines. Each edit writes the text to the binding. An empty text
/// writes `nil`.
public struct ElicitationTextField: View {
  /// The largest `maxLength` of a one-line input.
  public static let multiLineThreshold = 200

  /// The smallest height of a multi-line input, in points.
  static let multiLineMinimumHeight: CGFloat = 60

  /// The context of the field.
  let context: ElicitationFieldContext
  /// The model that the host gives, or `nil` when the view keeps its own.
  let suppliedModel: EditorModel?

  /// The model that the view keeps when the host gives no model.
  @State private var ownModel = TextFieldModelSlot()

  @Environment(\.agentTheme) private var theme

  /// Makes a text field that keeps its own model.
  ///
  /// - Parameter context: The context of the field.
  public init(context: ElicitationFieldContext) {
    self.init(context: context, model: nil)
  }

  /// Makes a text field that edits `model`.
  ///
  /// The view changes the text of `model` to the answer of the binding, and
  /// writes each edit of `model` to the binding.
  ///
  /// - Parameters:
  ///   - context: The context of the field.
  ///   - model: The model to edit, or `nil` to keep an own model.
  public init(context: ElicitationFieldContext, model: EditorModel?) {
    self.context = context
    self.suppliedModel = model
  }

  /// Tells whether a field of `kind` uses a multi-line input.
  ///
  /// - Parameter kind: The field kind.
  /// - Returns: `true` for a text kind with no `maxLength`, or with a
  ///   `maxLength` above ``multiLineThreshold``.
  public static func isMultiLine(_ kind: ElicitationFieldSchema.Kind) -> Bool {
    guard case .text(_, let maxLength, _, _) = kind else { return false }
    guard let maxLength else { return true }
    return maxLength > multiLineThreshold
  }

  public var body: some View {
    let answer = context.value.wrappedValue?.stringValue ?? ""
    let model = suppliedModel ?? ownModel.model(text: answer)
    ElicitationFieldChrome(context: context) {
      input(model: model)
        .editorTheme(theme.editorTheme)
        .padding(theme.spacing.xs)
        .overlay(
          RoundedRectangle(cornerRadius: theme.radii.s, style: .continuous)
            .strokeBorder(.separator)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(context.schema.title)
        .accessibilityIdentifier(context.controlIdentifier)
    }
    .onChange(of: answer, initial: true) {
      if model.text != answer {
        model.replaceAll(answer)
      }
    }
    .onChange(of: model.text) { _, text in
      let newValue: JSONValue? = text.isEmpty ? nil : .string(text)
      if context.value.wrappedValue != newValue {
        context.value.wrappedValue = newValue
      }
    }
  }

  /// The EditorKit input for `model`.
  ///
  /// - Parameter model: The model to edit.
  /// - Returns: A one-line field or a multi-line editor.
  @ViewBuilder
  private func input(model: EditorModel) -> some View {
    if Self.isMultiLine(context.schema.kind) {
      EditorView(model: model)
        .editorSizingMode(.intrinsic)
        .editorWrapMode(.viewportWidth)
        .frame(minHeight: Self.multiLineMinimumHeight)
    } else {
      SingleLineField(model: model, id: context.identifier)
        .editorSizingMode(.intrinsic)
    }
  }
}

/// The model that an ``ElicitationTextField`` keeps when the host gives no
/// model.
///
/// The slot makes the model at the first read. A `@State` value that holds
/// the model directly would make a new model each time SwiftUI makes the
/// view value again.
private final class TextFieldModelSlot {
  /// The model, or `nil` before the first read.
  private var model: EditorModel?

  /// The model of the slot. The first read makes a model that holds `text`.
  ///
  /// - Parameter text: The text of a new model.
  /// - Returns: The model.
  func model(text: String) -> EditorModel {
    if let model {
      return model
    }
    let model = EditorModel(text)
    self.model = model
    return model
  }
}

// MARK: - Number

/// The default view of a number field (plan.md §13.1).
///
/// The view shows a slider when the field has a minimum and a maximum.
/// Otherwise it shows a stepper with a number input. An integer field moves
/// in steps of one and writes whole numbers.
public struct ElicitationNumberField: View {
  /// The step of the stepper.
  public static let step: Double = 1

  /// The largest width of the number input of the stepper, in points.
  static let numberInputMaximumWidth: CGFloat = 160

  /// The context of the field.
  let context: ElicitationFieldContext

  @Environment(\.agentTheme) private var theme

  /// Makes a number field.
  ///
  /// - Parameter context: The context of the field.
  public init(context: ElicitationFieldContext) {
    self.context = context
  }

  public var body: some View {
    ElicitationFieldChrome(context: context) {
      control
    }
  }

  /// The slider or the stepper.
  @ViewBuilder
  private var control: some View {
    if case .number(let integer, let minimum, let maximum) = context.schema.kind {
      let number = numberBinding(integer: integer, minimum: minimum)
      if let minimum, let maximum, minimum < maximum {
        HStack(spacing: theme.spacing.s) {
          slider(number, range: minimum...maximum, integer: integer)
            .accessibilityIdentifier(context.controlIdentifier)
          Text(number.wrappedValue, format: .number)
            .monospacedDigit()
        }
      } else {
        Stepper(
          value: number,
          in: (minimum ?? -.greatestFiniteMagnitude)...(maximum ?? .greatestFiniteMagnitude),
          step: Self.step
        ) {
          TextField(context.schema.title, value: number, format: .number)
            .labelsHidden()
            .frame(maxWidth: Self.numberInputMaximumWidth)
        }
        .accessibilityLabel(context.schema.title)
        .accessibilityIdentifier(context.controlIdentifier)
      }
    }
  }

  /// The slider over `range`.
  ///
  /// - Parameters:
  ///   - number: The binding to the number.
  ///   - range: The bounds of the field.
  ///   - integer: Whether the slider moves in steps of one.
  /// - Returns: The slider.
  @ViewBuilder
  private func slider(
    _ number: Binding<Double>,
    range: ClosedRange<Double>,
    integer: Bool
  ) -> some View {
    if integer {
      Slider(value: number, in: range, step: Self.step) {
        Text(context.schema.title)
      }
      .labelsHidden()
    } else {
      Slider(value: number, in: range) {
        Text(context.schema.title)
      }
      .labelsHidden()
    }
  }

  /// A binding that reads the answer as a number and writes a number.
  ///
  /// - Parameters:
  ///   - integer: Whether the field takes whole numbers only.
  ///   - minimum: The lower bound, which the control shows when there is no
  ///     answer.
  /// - Returns: The binding.
  private func numberBinding(integer: Bool, minimum: Double?) -> Binding<Double> {
    let value = context.value
    return Binding(
      get: { value.wrappedValue?.doubleValue ?? minimum ?? 0 },
      set: { newValue in
        value.wrappedValue = .number(integer ? newValue.rounded() : newValue)
      }
    )
  }
}

// MARK: - Toggle

/// The default view of a boolean field (plan.md §13.1).
///
/// The view shows a switch. The switch shows `false` when there is no
/// answer.
public struct ElicitationToggleField: View {
  /// The context of the field.
  let context: ElicitationFieldContext

  /// Makes a boolean field.
  ///
  /// - Parameter context: The context of the field.
  public init(context: ElicitationFieldContext) {
    self.context = context
  }

  public var body: some View {
    let value = context.value
    ElicitationFieldChrome(context: context) {
      Toggle(
        context.schema.title,
        isOn: Binding(
          get: { value.wrappedValue?.boolValue ?? false },
          set: { value.wrappedValue = .bool($0) }
        )
      )
      .labelsHidden()
      .toggleStyle(.switch)
      .accessibilityIdentifier(context.controlIdentifier)
    }
  }
}

// MARK: - Date

/// The default view of a date field (plan.md §13.1).
///
/// When there is no answer, the view shows a button that sets the answer to
/// the current date. When there is an answer, the view shows a `DatePicker`
/// and a button that removes the answer. A `date` field writes
/// `YYYY-MM-DD`. A `date-time` field writes an RFC 3339 time in UTC.
public struct ElicitationDateField: View {
  /// The accessibility identifier of the button that removes the answer of
  /// the field named `name`.
  ///
  /// - Parameter name: The property name of the field.
  /// - Returns: `elicitation-field-<name>-clear`.
  public static func clearIdentifier(for name: String) -> String {
    ElicitationFieldView.identifier(for: name) + "-clear"
  }

  /// The context of the field.
  let context: ElicitationFieldContext

  @Environment(\.calendar) private var calendar
  @Environment(\.timeZone) private var timeZone
  @Environment(\.agentTheme) private var theme

  /// Makes a date field.
  ///
  /// - Parameter context: The context of the field.
  public init(context: ElicitationFieldContext) {
    self.context = context
  }

  public var body: some View {
    ElicitationFieldChrome(context: context) {
      if case .date(let dateTime) = context.schema.kind {
        control(dateTime: dateTime)
      }
    }
  }

  /// The button or the picker.
  ///
  /// - Parameter dateTime: Whether the field has a time.
  /// - Returns: The control.
  @ViewBuilder
  private func control(dateTime: Bool) -> some View {
    let value = context.value
    let coding = ElicitationDateCoding(calendar: localCalendar, dateTime: dateTime)
    if let text = value.wrappedValue?.stringValue, let date = coding.date(from: text) {
      HStack(spacing: theme.spacing.s) {
        DatePicker(
          context.schema.title,
          selection: Binding(
            get: { date },
            set: { value.wrappedValue = .string(coding.string(from: $0)) }
          ),
          displayedComponents: dateTime ? [.date, .hourAndMinute] : [.date]
        )
        .labelsHidden()
        .accessibilityIdentifier(context.controlIdentifier)
        Button("Remove Date", systemImage: "xmark.circle") {
          value.wrappedValue = nil
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help("Remove Date")
        .accessibilityIdentifier(Self.clearIdentifier(for: context.schema.name))
      }
    } else {
      Button(dateTime ? "Set Date and Time" : "Set Date") {
        value.wrappedValue = .string(coding.string(from: Date()))
      }
      .accessibilityIdentifier(context.controlIdentifier)
    }
  }

  /// The calendar of the environment, in the time zone of the environment.
  private var localCalendar: Calendar {
    var calendar = calendar
    calendar.timeZone = timeZone
    return calendar
  }
}

/// The conversion between a `Date` and the text of a date field.
struct ElicitationDateCoding {
  /// The calendar that reads and writes a `date` value.
  let calendar: Calendar
  /// Whether the field is a `date-time` field.
  let dateTime: Bool

  /// The text of `date`.
  ///
  /// - Parameter date: The date.
  /// - Returns: `YYYY-MM-DD` in ``calendar`` for a `date` field, or an
  ///   RFC 3339 time in UTC for a `date-time` field.
  func string(from date: Date) -> String {
    if dateTime {
      return date.formatted(.iso8601)
    }
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    let year = parts.year ?? 0
    let month = parts.month ?? 0
    let day = parts.day ?? 0
    return String(format: "%04d-%02d-%02d", year, month, day)
  }

  /// The date of `text`.
  ///
  /// - Parameter text: The answer text.
  /// - Returns: The date, or `nil` when the text is not a valid value.
  func date(from text: String) -> Date? {
    if dateTime {
      return (try? Date.ISO8601FormatStyle().parse(text))
        ?? (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
    }
    guard let match = text.wholeMatch(of: #/(\d{4})-(\d{2})-(\d{2})/#),
      let year = Int(match.1), let month = Int(match.2), let day = Int(match.3)
    else { return nil }
    let parts = DateComponents(year: year, month: month, day: day)
    guard parts.isValidDate(in: calendar) else { return nil }
    return calendar.date(from: parts)
  }
}

// MARK: - Single choice

/// The default view of a single-choice field (plan.md §13.1).
///
/// The view shows a radio group for up to ``radioGroupLimit`` choices, and a
/// menu for more choices.
public struct ElicitationSingleChoiceField: View {
  /// The largest number of choices that a radio group shows.
  public static let radioGroupLimit = 5

  /// The title of the menu item that removes the answer.
  static var noSelectionTitle: String { "None" }

  /// The accessibility identifier of the radio group of the field named
  /// `name`.
  ///
  /// - Parameter name: The property name of the field.
  /// - Returns: `elicitation-field-<name>-radio-group`.
  public static func radioGroupIdentifier(for name: String) -> String {
    ElicitationFieldView.identifier(for: name) + "-radio-group"
  }

  /// The accessibility identifier of the menu of the field named `name`.
  ///
  /// - Parameter name: The property name of the field.
  /// - Returns: `elicitation-field-<name>-menu`.
  public static func menuIdentifier(for name: String) -> String {
    ElicitationFieldView.identifier(for: name) + "-menu"
  }

  /// Tells whether `choices` show as a radio group.
  ///
  /// - Parameter choices: The choices of the field.
  /// - Returns: `true` for ``radioGroupLimit`` choices or fewer.
  public static func usesRadioGroup(_ choices: [ElicitationFieldSchema.Choice]) -> Bool {
    choices.count <= radioGroupLimit
  }

  /// The context of the field.
  let context: ElicitationFieldContext

  @Environment(\.agentTheme) private var theme

  /// Makes a single-choice field.
  ///
  /// - Parameter context: The context of the field.
  public init(context: ElicitationFieldContext) {
    self.context = context
  }

  public var body: some View {
    ElicitationFieldChrome(context: context) {
      if case .singleChoice(let choices) = context.schema.kind {
        if Self.usesRadioGroup(choices) {
          radioGroup(choices)
        } else {
          menu(choices)
        }
      }
    }
  }

  /// The selected value, or `nil` when there is no answer.
  private var selection: String? {
    context.value.wrappedValue?.stringValue
  }

  /// A radio button for each choice.
  ///
  /// - Parameter choices: The choices.
  /// - Returns: The group.
  private func radioGroup(_ choices: [ElicitationFieldSchema.Choice]) -> some View {
    let name = context.schema.name
    return VStack(alignment: .leading, spacing: theme.spacing.xs) {
      ForEach(choices) { choice in
        let isSelected = selection == choice.value
        Button {
          context.value.wrappedValue = .string(choice.value)
        } label: {
          Label(
            choice.title,
            systemImage: isSelected ? "largecircle.fill.circle" : "circle"
          )
        }
        .buttonStyle(.plain)
        .help(choice.description ?? choice.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "selected" : "")
        .accessibilityIdentifier(
          ElicitationFieldView.choiceIdentifier(for: name, value: choice.value))
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(context.schema.title)
    .accessibilityIdentifier(Self.radioGroupIdentifier(for: name))
  }

  /// A menu with each choice.
  ///
  /// - Parameter choices: The choices.
  /// - Returns: The menu.
  private func menu(_ choices: [ElicitationFieldSchema.Choice]) -> some View {
    let value = context.value
    return Picker(
      context.schema.title,
      selection: Binding<String?>(
        get: { value.wrappedValue?.stringValue },
        set: { value.wrappedValue = $0.map(JSONValue.string) }
      )
    ) {
      Text(Self.noSelectionTitle).tag(String?.none)
      ForEach(choices) { choice in
        Text(choice.title).tag(Optional(choice.value))
      }
    }
    .pickerStyle(.menu)
    .labelsHidden()
    .accessibilityIdentifier(Self.menuIdentifier(for: context.schema.name))
  }
}

// MARK: - Multi choice

/// The default view of a multi-choice field (plan.md §13.1).
///
/// The view shows a checkbox for each choice. When the answer has
/// `maxItems` values, each clear checkbox is disabled. The answer keeps the
/// order of the choices.
public struct ElicitationMultiChoiceField: View {
  /// The context of the field.
  let context: ElicitationFieldContext

  @Environment(\.agentTheme) private var theme

  /// Makes a multi-choice field.
  ///
  /// - Parameter context: The context of the field.
  public init(context: ElicitationFieldContext) {
    self.context = context
  }

  /// Tells whether a further check is disabled.
  ///
  /// - Parameters:
  ///   - selectedCount: The number of selected values.
  ///   - maxItems: The largest number of selected values, or `nil`.
  /// - Returns: `true` when `selectedCount` is `maxItems` or more.
  public static func isAtLimit(selectedCount: Int, maxItems: Int?) -> Bool {
    guard let maxItems else { return false }
    return selectedCount >= maxItems
  }

  public var body: some View {
    ElicitationFieldChrome(context: context) {
      if case .multiChoice(let choices, _, let maxItems) = context.schema.kind {
        checkboxes(choices, maxItems: maxItems)
      }
    }
  }

  /// The selected values of the answer.
  private var selected: [String] {
    guard case .array(let elements)? = context.value.wrappedValue else { return [] }
    return elements.compactMap(\.stringValue)
  }

  /// A checkbox for each choice.
  ///
  /// - Parameters:
  ///   - choices: The choices.
  ///   - maxItems: The largest number of selected values, or `nil`.
  /// - Returns: The group.
  private func checkboxes(
    _ choices: [ElicitationFieldSchema.Choice],
    maxItems: Int?
  ) -> some View {
    let selected = Set(selected)
    let isAtLimit = Self.isAtLimit(selectedCount: selected.count, maxItems: maxItems)
    let name = context.schema.name
    return VStack(alignment: .leading, spacing: theme.spacing.xs) {
      ForEach(choices) { choice in
        let isOn = selected.contains(choice.value)
        Toggle(
          choice.title,
          isOn: Binding(
            get: { isOn },
            set: { write(choice.value, isOn: $0, choices: choices) }
          )
        )
        .toggleStyle(.checkbox)
        .disabled(isAtLimit && !isOn)
        .help(choice.description ?? choice.title)
        .accessibilityIdentifier(
          ElicitationFieldView.choiceIdentifier(for: name, value: choice.value))
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(context.schema.title)
    .accessibilityIdentifier(context.controlIdentifier)
  }

  /// Adds `value` to the answer or removes it, and writes the answer in the
  /// order of `choices`.
  ///
  /// - Parameters:
  ///   - value: The value of the choice.
  ///   - isOn: Whether the choice is selected.
  ///   - choices: The choices of the field.
  private func write(_ value: String, isOn: Bool, choices: [ElicitationFieldSchema.Choice]) {
    var values = Set(selected)
    if isOn {
      values.insert(value)
    } else {
      values.remove(value)
    }
    let ordered = choices.map(\.value).filter(values.contains)
    context.value.wrappedValue = .array(ordered.map(JSONValue.string))
  }
}
