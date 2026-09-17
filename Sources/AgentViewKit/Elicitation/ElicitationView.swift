import SwiftUI

// MARK: - Form view

/// The form of a form mode elicitation request (plan.md §13.1, §13.2).
///
/// The view makes the fields from the `requestedSchema` with
/// ``ElicitationFieldSchema/normalize(from:)``. It keeps the answers, starts
/// each field at its default, and validates on each change. The header slot
/// names the server, the layout slot shows the fields, and the footer slot
/// shows Submit, Decline, and Cancel. Submit is disabled until
/// ``ElicitationValidator/isComplete(values:schemas:)`` is `true`. Esc
/// sends ``ElicitationResult/cancel``. Each answer goes to
/// ``AgentThreadActions/respond(to:_:)-(ElicitationRequest,_)`` of the
/// `threadActions` environment value.
///
/// The view keeps its answers in state. Give each request its own view
/// identity, for example with `.id(request.id)`, so that a new request
/// starts with new answers.
///
/// A URL mode request has no fields. Show it with
/// ``ElicitationURLConsentView`` (plan.md §13.3).
public struct ElicitationView: View {
  /// The accessibility identifier of the form.
  public static let formIdentifier = "elicitation-form"
  /// The accessibility identifier of the default header.
  public static let headerIdentifier = "elicitation-header"
  /// The start of the accessibility identifier of each field tab.
  public static let tabIdentifierPrefix = "elicitation-tab-"
  /// The accessibility identifier of the Submit button.
  public static let submitIdentifier = "elicitation-submit"
  /// The accessibility identifier of the Decline button.
  public static let declineIdentifier = "elicitation-decline"
  /// The accessibility identifier of the Cancel button.
  public static let cancelIdentifier = "elicitation-cancel"

  /// The accessibility identifier of the tab of the field named `name`.
  ///
  /// - Parameter name: The property name of the field.
  /// - Returns: `elicitation-tab-<name>`.
  public static func tabIdentifier(for name: String) -> String {
    AccessibilityIdentifier.make(prefix: tabIdentifierPrefix, value: name)
  }

  /// The request that the form answers.
  let request: ElicitationRequest

  /// The fields of the request, in the order of the form.
  let fields: [ElicitationFieldSchema]

  /// The answers, keyed by field name. A field with no answer has no key.
  @State private var values: [String: JSONValue]

  /// Whether the form has the keyboard focus.
  @FocusState private var isFocused: Bool

  @Environment(\.threadActions) private var actions
  @Environment(\.focusReporter) private var focusReporter
  @Environment(\.elicitationHeaderOverride) private var headerOverride
  @Environment(\.elicitationLayoutOverride) private var layoutOverride
  @Environment(\.elicitationFooterOverride) private var footerOverride
  @Environment(\.elicitationTabThreshold) private var tabThreshold
  @Environment(\.agentTheme) private var theme

  /// Makes the form of `request`.
  ///
  /// - Parameter request: The request to answer.
  public init(request: ElicitationRequest) {
    self.request = request
    let fields = Self.fields(of: request)
    self.fields = fields
    _values = State(initialValue: Self.defaultValues(of: fields))
  }

  /// The fields of a request.
  ///
  /// - Parameter request: The request.
  /// - Returns: The normalized fields of a form request, or no fields for a
  ///   URL request.
  static func fields(of request: ElicitationRequest) -> [ElicitationFieldSchema] {
    guard case .form(let requestedSchema) = request.mode else { return [] }
    return ElicitationFieldSchema.normalize(from: requestedSchema)
  }

  /// The first answers of a form.
  ///
  /// - Parameter fields: The fields of the form.
  /// - Returns: The default of each field that has one, keyed by field name.
  static func defaultValues(of fields: [ElicitationFieldSchema]) -> [String: JSONValue] {
    var values: [String: JSONValue] = [:]
    for field in fields {
      values[field.name] = field.defaultValue
    }
    return values
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      header
      layout
      footer
    }
    .padding(theme.spacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .focusable()
    .focusEffectDisabled()
    .focused($isFocused)
    .onExitCommand { respond(.cancel) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.formIdentifier)
    .onAppear {
      isFocused = true
      focusReporter?.focusMoved(to: Self.formIdentifier)
    }
  }

  // MARK: Slots

  /// The header override, or the default header.
  @ViewBuilder
  private var header: some View {
    if let headerOverride {
      headerOverride(request)
    } else {
      ElicitationHeader(request: request)
    }
  }

  /// The layout override, or the default layout.
  @ViewBuilder
  private var layout: some View {
    let context = ElicitationLayoutContext(
      fields: fields.map(fieldContext), tabThreshold: tabThreshold)
    if let layoutOverride {
      layoutOverride(context)
    } else {
      ElicitationLayout(context: context)
    }
  }

  /// The footer override, or the default footer.
  @ViewBuilder
  private var footer: some View {
    let context = ElicitationFooterContext(
      canSubmit: ElicitationValidator.isComplete(values: values, schemas: fields),
      submit: submit,
      decline: { respond(.decline) },
      cancel: { respond(.cancel) }
    )
    if let footerOverride {
      footerOverride(context)
    } else {
      ElicitationFooter(context: context)
    }
  }

  // MARK: Answers

  /// The context of one field, with a binding to its answer.
  ///
  /// - Parameter schema: The field.
  /// - Returns: The context. Its validation state is the state of the
  ///   current answer.
  private func fieldContext(_ schema: ElicitationFieldSchema) -> ElicitationFieldContext {
    let name = schema.name
    let binding = Binding<JSONValue?>(
      get: { values[name] },
      set: { values[name] = $0 }
    )
    return ElicitationFieldContext(schema: schema, value: binding)
  }

  /// Sends the answers when each field passes validation.
  private func submit() {
    guard ElicitationValidator.isComplete(values: values, schemas: fields) else { return }
    respond(.accept(.object(values)))
  }

  /// Sends `result` to the thread actions.
  ///
  /// - Parameter result: The answer of the user.
  private func respond(_ result: ElicitationResult) {
    actions.startRespond(to: request, result)
  }
}

// MARK: - Header

/// The default header of an elicitation form (plan.md §13.1, §13.4).
///
/// The header names the server that asks for the input and shows the
/// message of the request.
public struct ElicitationHeader: View {
  /// The symbol of the header.
  static let symbol = "questionmark.bubble"

  /// The request of the form.
  let request: ElicitationRequest

  @Environment(\.agentTheme) private var theme

  /// Makes the default header.
  ///
  /// - Parameter request: The request of the form.
  public init(request: ElicitationRequest) {
    self.request = request
  }

  /// The title that names the server.
  ///
  /// - Parameter server: The display name of the server.
  /// - Returns: The title.
  public static func title(server: String) -> String {
    "\(server) asks for input"
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Label(Self.title(server: request.server), systemImage: Self.symbol)
        .font(.headline)
      Text(request.message)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(ElicitationView.headerIdentifier)
  }
}

// MARK: - Footer

/// The data that the kit gives to the footer slot of an elicitation form
/// (plan.md §13.1, §13.2).
///
/// A custom footer must offer the three actions (plan.md §13.4).
public struct ElicitationFooterContext {
  /// Whether each field passes validation. Enable Submit only when this is
  /// `true`.
  public let canSubmit: Bool

  /// Sends the answers with ``ElicitationResult/accept(_:)``. The call does
  /// nothing when ``canSubmit`` is `false`.
  public let submit: @MainActor () -> Void

  /// Sends ``ElicitationResult/decline``.
  public let decline: @MainActor () -> Void

  /// Sends ``ElicitationResult/cancel``.
  public let cancel: @MainActor () -> Void

  /// Makes a footer context.
  ///
  /// - Parameters:
  ///   - canSubmit: Whether each field passes validation.
  ///   - submit: The function that sends the answers.
  ///   - decline: The function that declines the request.
  ///   - cancel: The function that cancels the request.
  public init(
    canSubmit: Bool,
    submit: @escaping @MainActor () -> Void,
    decline: @escaping @MainActor () -> Void,
    cancel: @escaping @MainActor () -> Void
  ) {
    self.canSubmit = canSubmit
    self.submit = submit
    self.decline = decline
    self.cancel = cancel
  }
}

/// The default footer of an elicitation form (plan.md §13.1).
///
/// The footer shows Cancel, Decline, and Submit. Submit has the
/// `.glassProminent` style, and it is disabled until each field passes
/// validation. Return presses Submit.
public struct ElicitationFooter: View {
  /// The context of the footer.
  let context: ElicitationFooterContext

  @Environment(\.agentTheme) private var theme

  /// Makes the default footer.
  ///
  /// - Parameter context: The context of the footer.
  public init(context: ElicitationFooterContext) {
    self.context = context
  }

  public var body: some View {
    HStack(spacing: theme.spacing.s) {
      Spacer()
      Button("Cancel", role: .cancel) { context.cancel() }
        .accessibilityIdentifier(ElicitationView.cancelIdentifier)
      Button("Decline") { context.decline() }
        .accessibilityIdentifier(ElicitationView.declineIdentifier)
      Button("Submit") { context.submit() }
        .buttonStyle(.glassProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(!context.canSubmit)
        .accessibilityIdentifier(ElicitationView.submitIdentifier)
    }
  }
}

// MARK: - Slots

/// A function that makes the header of an elicitation form.
public typealias ElicitationHeaderRenderer = @MainActor (ElicitationRequest) -> AnyView

/// A function that makes the footer of an elicitation form.
public typealias ElicitationFooterRenderer = @MainActor (ElicitationFooterContext) -> AnyView

extension EnvironmentValues {
  /// The override of the header of an elicitation form, or `nil` for
  /// ``ElicitationHeader``.
  @Entry public var elicitationHeaderOverride: ElicitationHeaderRenderer? = nil

  /// The override of the footer of an elicitation form, or `nil` for
  /// ``ElicitationFooter``.
  @Entry public var elicitationFooterOverride: ElicitationFooterRenderer? = nil
}

extension View {
  /// Replaces the header of each elicitation form in this view.
  ///
  /// A custom header must name the server of the request (plan.md §13.4).
  ///
  /// - Parameter content: The function that makes the header.
  /// - Returns: A view that gives the override to its subtree.
  public func elicitationHeader<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (ElicitationRequest) -> Content
  ) -> some View {
    environment(\.elicitationHeaderOverride) { request in AnyView(content(request)) }
  }

  /// Replaces the footer of each elicitation form in this view.
  ///
  /// A custom footer must offer Submit, Decline, and Cancel (plan.md §13.4).
  ///
  /// - Parameter content: The function that makes the footer.
  /// - Returns: A view that gives the override to its subtree.
  public func elicitationFooter<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (ElicitationFooterContext) -> Content
  ) -> some View {
    environment(\.elicitationFooterOverride) { context in AnyView(content(context)) }
  }
}
