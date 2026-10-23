import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

// MARK: - Form view

/// The form of a form mode pending elicitation of a client model (plan.md
/// §3.2 "Pending requests", §13.1, §13.2).
///
/// The view makes the fields from the ACP `requestedSchema` with
/// ``ElicitationFieldSchema/normalize(from:)``. It keeps the answers, starts
/// each field at its default, and validates on each change. A field whose
/// default is not empty and not valid, for example a number above its
/// maximum, shows its errors as soon as the form appears, and the view
/// announces them at `.medium`, so the user learns why Submit is disabled.
/// Another field shows its errors only after the user changes its answer, or
/// after a call of ``ElicitationFooterContext/submit`` while the form is not
/// complete. Before that, its context has the validation state
/// ``FieldValidationState/satisfied``, so a required field with no default
/// shows no error on a new form. When a change of an answer shows new errors,
/// the view announces them at `.medium`. A submit attempt with a form that is
/// not complete sends nothing, shows the errors of each field, and announces
/// them at `.high` (`fieldErrorText(title:validation:)`). The header slot
/// names the agent, the layout slot shows the fields, and the footer slot
/// shows Submit, Decline, and Cancel. Submit is disabled until
/// ``ElicitationValidator/isComplete(values:schemas:)`` is `true`. Esc
/// cancels the elicitation. Each answer goes to the reply method of the
/// ``PendingElicitationOwner`` that holds the elicitation:
/// `acceptElicitation(_:content:)` with the answers as ACP JSON,
/// `declineElicitation(_:)` or `cancelElicitation(_:)`. The owner removes the
/// elicitation when it resolves. The accepted content has no empty answer
/// (see `answerContent(values:)`).
///
/// Before the send of an accepted answer, the view checks the content with
/// `PendingElicitation.validationIssue(of:)`. When the agent cannot accept
/// the answer, the view does not send it. The form stays open, shows a
/// localized kit text of the issue in the element ``failureIdentifier``, and
/// announces it. A change of an answer removes the failure.
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
  /// The accessibility identifier of the text that tells why the agent
  /// cannot accept the answer.
  public static let failureIdentifier = "elicitation-failure"

  /// The symbol of the Submit button, which accepts the elicitation.
  static let submitSymbol = SharedSymbol.accept
  /// The symbol of the Decline button, which rejects the elicitation.
  static let declineSymbol = SharedSymbol.reject
  /// The symbol of the Cancel button, which closes the elicitation with no
  /// answer.
  static let cancelSymbol = SharedSymbol.dismiss

  /// The accessibility identifier of the tab of the field named `name`.
  ///
  /// - Parameter name: The property name of the field.
  /// - Returns: `elicitation-tab-<name>`.
  public static func tabIdentifier(for name: String) -> String {
    AccessibilityIdentifier.make(prefix: tabIdentifierPrefix, value: name)
  }

  /// The pending elicitation that the form answers.
  let request: PendingElicitation

  /// The model that holds the elicitation.
  let owner: any PendingElicitationOwner

  /// The JSON form of the ACP `requestedSchema` of the request.
  let requestedSchema: JSONValue

  /// The fields of the request, in the order of the form.
  let fields: [ElicitationFieldSchema]

  /// The answers, keyed by field name. A field with no answer has no key.
  @State private var values: [String: JSONValue]

  /// The text that tells why the agent cannot accept the last submitted
  /// answer, or `nil` when there is no such failure. A change of
  /// ``values`` removes it.
  @State private var answerFailure: String?

  /// The names of the fields that show their errors before a submit attempt:
  /// each field whose default is not empty and not valid
  /// (``fieldsWithInvalidDefault(_:)``), and each field whose answer the user
  /// changed.
  @State private var errorShowingFields: Set<String>

  /// Whether the user tried to submit the form while it was not complete.
  /// After that, each field shows its errors.
  @State private var submitAttempted = false

  @Environment(\.elicitationLayoutOverride) private var layoutOverride
  @Environment(\.elicitationFooterOverride) private var footerOverride
  @Environment(\.elicitationTabThreshold) private var tabThreshold
  @Environment(\.agentTheme) private var theme
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.announcer) private var announcer

  /// Makes the form of a pending elicitation.
  ///
  /// - Parameters:
  ///   - request: A pending elicitation of `owner`.
  ///   - owner: The model that holds the elicitation: a `SessionModel` or a
  ///     `ConnectionModel`.
  public init(request: PendingElicitation, owner: any PendingElicitationOwner) {
    self.request = request
    self.owner = owner
    let requestedSchema = Self.requestedSchema(of: request)
    self.requestedSchema = requestedSchema
    let fields = ElicitationFieldSchema.normalize(from: requestedSchema)
    self.fields = fields
    _values = State(initialValue: Self.defaultValues(of: fields))
    _errorShowingFields = State(initialValue: Self.fieldsWithInvalidDefault(fields))
  }

  /// The JSON form of the ACP `requestedSchema` of a pending elicitation.
  ///
  /// The fields and the field titles of a failure text read this value.
  ///
  /// - Parameter request: The pending elicitation.
  /// - Returns: The `requestedSchema` of a form mode elicitation, or JSON
  ///   `null` for another mode. JSON `null` gives no fields.
  static func requestedSchema(of request: PendingElicitation) -> JSONValue {
    guard case .form(let form) = request.request.mode else { return .null }
    return JSONValue.encodedOrNull(form.requestedSchema)
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

  /// Whether the default of a field is not empty and does not pass
  /// validation, for example a number above the maximum of the field.
  ///
  /// The validation is ``ElicitationValidator/hasValidAnswer(value:against:)``.
  /// That function is also `false` for an empty answer, so this function
  /// first excludes an empty default: a required field with no default shows
  /// no error on a new form.
  ///
  /// - Parameter schema: The field.
  /// - Returns: `false` for a field with no default or with an empty default.
  static func hasInvalidDefault(_ schema: ElicitationFieldSchema) -> Bool {
    guard let value = schema.defaultValue, !ElicitationValidator.isEmpty(value) else { return false }
    return !ElicitationValidator.hasValidAnswer(value: value, against: schema)
  }

  /// The fields that show their errors as soon as the form appears.
  ///
  /// - Parameter fields: The fields of the form.
  /// - Returns: The name of each field whose default is not empty and not
  ///   valid (``hasInvalidDefault(_:)``). A required field with no default
  ///   is not in the set.
  static func fieldsWithInvalidDefault(_ fields: [ElicitationFieldSchema]) -> Set<String> {
    Set(fields.filter(hasInvalidDefault).map(\.name))
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      ElicitationHeaderSlot(request: request)
      layout
      failure
      footer
    }
    .padding(theme.spacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .focusable()
    .focusEffectDisabled()
    .onExitCommand { owner.cancelElicitation(request.id) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(Self.formIdentifier)
    .accessibilityFocusTarget(Self.formIdentifier)
    .onChange(of: values) { answerFailure = nil }
    .onAppear(perform: announceInvalidDefaults)
  }

  // MARK: Slots

  /// The layout override, or the default layout. Return in a one-line text
  /// field of the layout runs ``submitOnReturn()``.
  private var layout: some View {
    let context = ElicitationLayoutContext(
      fields: fields.map(fieldContext), tabThreshold: tabThreshold)
    return Group {
      if let layoutOverride {
        layoutOverride(context)
      } else {
        ElicitationLayout(context: context)
      }
    }
    .environment(\.elicitationReturnAction, ElicitationReturnAction(run: submitOnReturn))
  }

  /// The text that tells why the agent cannot accept the answer, when the
  /// check before the send found a failure.
  @ViewBuilder
  private var failure: some View {
    if let answerFailure {
      Text(answerFailure)
        .font(.callout)
        .foregroundStyle(editorTheme.severityError)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(Self.failureIdentifier)
    }
  }

  /// The footer override, or the default footer.
  @ViewBuilder
  private var footer: some View {
    let context = ElicitationFooterContext(
      canSubmit: ElicitationValidator.isComplete(values: values, schemas: fields),
      submit: submit,
      decline: { owner.declineElicitation(request.id) },
      cancel: { owner.cancelElicitation(request.id) }
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
  /// - Returns: The context. Its validation state is the state that the
  ///   field shows (``shownValidation(of:)``). A write to its binding is an
  ///   edit of the user (``edit(_:to:)``).
  private func fieldContext(_ schema: ElicitationFieldSchema) -> ElicitationFieldContext {
    let name = schema.name
    let binding = Binding<JSONValue?>(
      get: { values[name] },
      set: { edit(schema, to: $0) }
    )
    return ElicitationFieldContext(schema: schema, value: binding, validation: shownValidation(of: schema))
  }

  /// The validation state that a field shows.
  ///
  /// - Parameter schema: The field.
  /// - Returns: The state of the current answer when the default of the
  ///   field is not empty and not valid, when the user changed the field, or
  ///   when the user tried to submit the form, else
  ///   ``FieldValidationState/satisfied``.
  private func shownValidation(of schema: ElicitationFieldSchema) -> FieldValidationState {
    guard submitAttempted || errorShowingFields.contains(schema.name) else { return .satisfied }
    return ElicitationValidator.validate(values[schema.name], against: schema)
  }

  /// Keeps a new answer that the user gave to a field.
  ///
  /// A write of the current answer changes nothing. Another answer makes the
  /// field show its errors. When the field then shows errors that it did not
  /// show before, the view announces them at `.medium`.
  ///
  /// - Parameters:
  ///   - schema: The field.
  ///   - answer: The new answer, or `nil` for no answer.
  private func edit(_ schema: ElicitationFieldSchema, to answer: JSONValue?) {
    let name = schema.name
    guard values[name] != answer else { return }
    let shownBefore = shownValidation(of: schema)
    values[name] = answer
    errorShowingFields.insert(name)
    let shownAfter = ElicitationValidator.validate(answer, against: schema)
    guard !shownAfter.isSatisfied, shownAfter != shownBefore else { return }
    announcer.announce(Self.fieldErrorText(title: schema.title, validation: shownAfter), priority: .medium)
  }

  /// The text that announces the errors of one field.
  ///
  /// - Parameters:
  ///   - title: The title of the field.
  ///   - validation: The validation state of the answer of the field.
  /// - Returns: "“<title>”: " and the messages of `validation`, separated by
  ///   spaces.
  static func fieldErrorText(title: String, validation: FieldValidationState) -> String {
    let messages = validation.errors.joined(separator: " ")
    return String(localized: "“\(title)”: \(messages)", bundle: .module)
  }

  /// Shows the errors of each field after a submit attempt with a form that
  /// is not complete, and announces them at `.high` in the order of the form.
  private func showErrorsOfIncompleteForm() {
    submitAttempted = true
    announcer.announce(errorText(of: fields), priority: .high)
  }

  /// Announces at `.medium` the errors of each field whose default is not
  /// empty and not valid, in the order of the form, when the form appears.
  /// These fields show their errors at once, so the user learns why Submit
  /// is disabled. A form with no such field announces nothing.
  private func announceInvalidDefaults() {
    let text = errorText(of: fields.filter(Self.hasInvalidDefault))
    guard !text.isEmpty else { return }
    announcer.announce(text, priority: .medium)
  }

  /// The text that announces the errors of some fields.
  ///
  /// - Parameter schemas: The fields, in the order of the form.
  /// - Returns: The ``fieldErrorText(title:validation:)`` of the current
  ///   answer of each field that does not pass validation, separated by
  ///   spaces, or an empty text when each field passes.
  private func errorText(of schemas: [ElicitationFieldSchema]) -> String {
    let texts = schemas.compactMap { schema -> String? in
      let validation = ElicitationValidator.validate(values[schema.name], against: schema)
      return validation.isSatisfied ? nil : Self.fieldErrorText(title: schema.title, validation: validation)
    }
    return texts.joined(separator: " ")
  }

  /// The content of an accepted form.
  ///
  /// The content has no empty answer: no JSON `null`, no empty string, and
  /// no empty array. The agent validates each key of the content against its
  /// property, so an empty optional answer can fail a constraint such as
  /// `minLength`. The agent also cannot decode JSON `null`, and then cancels
  /// the full answer. `false` and `0` are answers, so they stay.
  ///
  /// - Parameter values: The answers, keyed by field name.
  /// - Returns: The answers that are not empty, keyed by field name.
  static func answerContent(values: [String: JSONValue]) -> [String: JSONValue] {
    values.filter { !ElicitationValidator.isEmpty($0.value) }
  }

  /// The text that the form shows and announces when the agent cannot
  /// accept the answer.
  ///
  /// The text is a localized kit text, not the English `failureText` of the
  /// issue. The rule is ``ElicitationValidator/message(for:)``, so a rule
  /// that the field check also has gives the sentence of the field check.
  /// The field is the `title` of its property, or the field name when the
  /// property has no title.
  ///
  /// - Parameters:
  ///   - issue: The issue of `PendingElicitation.validationIssue(of:)`.
  ///   - requestedSchema: The JSON form of the ACP `requestedSchema`.
  /// - Returns: "The agent cannot accept the answer for “<field>”: " and the
  ///   rule, or "The agent cannot accept this answer: " and the rule when
  ///   the issue has no field.
  static func failureText(
    for issue: PendingElicitation.ValidationIssue,
    requestedSchema: JSONValue
  ) -> String {
    let rule = ElicitationValidator.message(for: issue.kind)
    guard let field = issue.field else {
      return String(localized: "The agent cannot accept this answer: \(rule)", bundle: .module)
    }
    let title = ElicitationFieldSchema.title(ofProperty: field, in: requestedSchema)
    return String(localized: "The agent cannot accept the answer for “\(title)”: \(rule)", bundle: .module)
  }

  /// Sends the answers when each field passes validation and the check
  /// before the send finds no failure.
  ///
  /// When a field does not pass validation, the view sends nothing. It shows
  /// the errors of each field and announces them
  /// (``showErrorsOfIncompleteForm()``). The default footer disables Submit
  /// in that state, so only a custom footer that keeps its Submit enabled
  /// calls this function then.
  ///
  /// The check before the send is `PendingElicitation.validationIssue(of:)`:
  /// the rules of the agent (FoundationModelsExtras) on the same content
  /// that the view sends. When it finds an issue, the view does not send.
  /// The form stays open, shows the kit text of the issue
  /// (``failureText(for:requestedSchema:)``), and announces it at `.high`.
  ///
  /// The check cannot examine each answer. When FoundationModelsExtras
  /// cannot decode the schema, for example because a property has a type
  /// that Extras does not know, the check gives `nil` ("cannot check"). The
  /// view then sends, and the agent judges the answer. Thus a required
  /// property of such a type is not caught before the send.
  private func submit() {
    guard ElicitationValidator.isComplete(values: values, schemas: fields) else {
      showErrorsOfIncompleteForm()
      return
    }
    let content = JSONValue.object(Self.answerContent(values: values))
    if let issue = request.validationIssue(of: content) {
      let text = Self.failureText(for: issue, requestedSchema: requestedSchema)
      answerFailure = text
      announcer.announce(text, priority: .high)
      return
    }
    owner.acceptElicitation(request.id, content: content)
  }

  /// Presses Submit for Return in a one-line text field: sends the answers
  /// with ``submit()`` when the form is complete, as the enabled Submit
  /// button does. While the form is not complete, Submit is disabled, and
  /// Return does nothing.
  private func submitOnReturn() {
    guard ElicitationValidator.isComplete(values: values, schemas: fields) else { return }
    submit()
  }
}

// MARK: - Header

/// The default header of an elicitation card (plan.md §13.1, §13.4).
///
/// The header names the agent that asks for the input and shows the message
/// of the pending elicitation. An elicitation over ACP comes from the agent,
/// so the header names ``agentServer``.
///
/// Between the headline and the message, the header shows the "who asks"
/// line (identifier ``ElicitationView/whoAsksIdentifier``): the root label,
/// the `agentPath` and the `source` of the pending elicitation, for example
/// "root › planner › reviewer · runCode". The text is
/// ``whoAsks(agentPath:source:rootLabel:)``, and VoiceOver reads the line as
/// one element with the label of
/// ``whoAsksAccessibilityLabel(agentPath:source:rootLabel:)``, for example
/// "Asked by root, planner, reviewer, from runCode". The root label is the
/// ``SwiftUI/EnvironmentValues/elicitationRootAgentLabel`` environment value.
/// A request with an empty `agentPath` and no `source` shows no line.
///
/// ``ElicitationView`` and ``ElicitationURLConsentView`` show this header when
/// the environment has no header override (``SwiftUI/View/elicitationHeader(_:)``),
/// so the line shows on form cards, on URL cards and on waiting cards.
public struct ElicitationHeader: View {
  /// The symbol of the header.
  static let symbol = SharedSymbol.question

  /// The name of the server that each header shows. An elicitation over ACP
  /// comes from the agent.
  public static let agentServer = String(localized: "The agent", bundle: .module)

  /// The pending elicitation of the card.
  let request: PendingElicitation

  @Environment(\.agentTheme) private var theme

  /// Makes the default header.
  ///
  /// - Parameter request: The pending elicitation of the card.
  public init(request: PendingElicitation) {
    self.request = request
  }

  /// The title that names the server.
  ///
  /// - Parameter server: The display name of the server.
  /// - Returns: The title.
  public static func title(server: String) -> String {
    String(localized: "\(server) asks for input", bundle: .module)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Label(Self.title(server: Self.agentServer), systemImage: Self.symbol)
        .font(.headline)
      ElicitationWhoAsksLine(agentPath: request.agentPath, source: request.source)
      Text(request.request.message)
        .foregroundStyle(.secondary)
        .textSelection(.enabled)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(ElicitationView.headerIdentifier)
  }
}

/// The header slot of an elicitation card: the
/// ``SwiftUI/EnvironmentValues/elicitationHeaderOverride`` when the
/// environment has one, else ``ElicitationHeader``.
///
/// ``ElicitationView`` and ``ElicitationURLConsentView`` show this slot. Thus
/// one override replaces the header of a form card and of a URL card, in the
/// consent state and in the waiting state.
struct ElicitationHeaderSlot: View {
  /// The pending elicitation of the card.
  let request: PendingElicitation

  /// The header override of the app, or `nil`.
  @Environment(\.elicitationHeaderOverride) private var headerOverride

  var body: some View {
    if let headerOverride {
      headerOverride(request)
    } else {
      ElicitationHeader(request: request)
    }
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

  /// Accepts the elicitation with the answers. When ``canSubmit`` is
  /// `false`, the call sends nothing: each field shows its errors, and
  /// VoiceOver announces them. When the agent cannot accept the answers, the
  /// call does not send them, and the form shows the failure.
  public let submit: @MainActor () -> Void

  /// Declines the elicitation.
  public let decline: @MainActor () -> Void

  /// Cancels the elicitation.
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
/// The footer shows Cancel, Decline, and Submit. Submit is the primary action,
/// and it is disabled until each field passes validation. Return presses
/// Submit. The place of the card gives the button styles
/// (``RequestDeckPlace/style(of:)``): in content, Submit has the
/// `.glassProminent` style. In a ``RequestDeck`` in a bar of floating
/// controls, the card is on the glass of the deck, so Submit has the
/// `.borderedProminent` style, and Cancel and Decline have the `.bordered`
/// style.
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
      Button(
        String(localized: "Cancel", bundle: .module), systemImage: ElicitationView.cancelSymbol,
        role: .cancel
      ) { context.cancel() }
        .requestActionStyle(.standard)
        .accessibilityIdentifier(ElicitationView.cancelIdentifier)
      Button(
        String(localized: "Decline", bundle: .module), systemImage: ElicitationView.declineSymbol
      ) { context.decline() }
        .requestActionStyle(.standard)
        .accessibilityIdentifier(ElicitationView.declineIdentifier)
      Button(
        String(localized: "Submit", bundle: .module), systemImage: ElicitationView.submitSymbol
      ) { context.submit() }
        .requestActionStyle(.primary)
        .keyboardShortcut(.defaultAction)
        .disabled(!context.canSubmit)
        .accessibilityIdentifier(ElicitationView.submitIdentifier)
    }
  }
}

// MARK: - Slots

/// A function that makes the header of an elicitation card: a form card or a
/// URL card.
public typealias ElicitationHeaderRenderer = @MainActor (PendingElicitation) -> AnyView

/// A function that makes the footer of an elicitation form.
public typealias ElicitationFooterRenderer = @MainActor (ElicitationFooterContext) -> AnyView

extension EnvironmentValues {
  /// The override of the header of each elicitation card, or `nil` for
  /// ``ElicitationHeader``.
  ///
  /// ``ElicitationView`` and ``ElicitationURLConsentView`` read this value.
  /// The override replaces the header of the form card, and the header of the
  /// URL card in the consent state and in the waiting state.
  @Entry public var elicitationHeaderOverride: ElicitationHeaderRenderer? = nil

  /// The override of the footer of an elicitation form, or `nil` for
  /// ``ElicitationFooter``.
  @Entry public var elicitationFooterOverride: ElicitationFooterRenderer? = nil

  /// The action that Return in a one-line text field of the nearest
  /// ``ElicitationView`` runs, or `nil` outside a form.
  ///
  /// The form gives the action of Submit, so Return presses Submit as the
  /// footer says. Like Submit, the action does nothing while the form is
  /// not complete.
  @Entry var elicitationReturnAction: ElicitationReturnAction? = nil
}

/// The action that Return in a one-line text field of an ``ElicitationView``
/// runs (``SwiftUI/EnvironmentValues/elicitationReturnAction``).
///
/// The function is in a struct, not in the environment value itself: an
/// environment value that holds a closure can invalidate its dependents on
/// each update.
struct ElicitationReturnAction {
  /// The function that Return runs.
  let run: @MainActor () -> Void

  /// Runs the function.
  func callAsFunction() {
    run()
  }
}

extension View {
  /// Replaces the header of each elicitation card in this view: the form card
  /// of ``ElicitationView``, and the URL card of ``ElicitationURLConsentView``
  /// in the consent state and in the waiting state.
  ///
  /// A custom header must name the server of the request (plan.md §13.4).
  ///
  /// A custom header replaces the "who asks" line of ``ElicitationHeader``.
  /// To show the same line, give `agentPath` and `source` of the pending
  /// elicitation and the
  /// ``SwiftUI/EnvironmentValues/elicitationRootAgentLabel`` environment
  /// value to ``ElicitationHeader/whoAsks(agentPath:source:rootLabel:)`` and
  /// ``ElicitationHeader/whoAsksAccessibilityLabel(agentPath:source:rootLabel:)``.
  ///
  /// - Parameter content: The function that makes the header from the
  ///   pending elicitation of the card.
  /// - Returns: A view that gives the override to its subtree.
  public func elicitationHeader<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (PendingElicitation) -> Content
  ) -> some View {
    environment(\.elicitationHeaderOverride) { pending in AnyView(content(pending)) }
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

#Preview("Form") {
  let session = PreviewFixtures.elicitationSession
  if let request = session.pendingElicitations.first {
    ElicitationView(request: request, owner: session)
  }
}

#Preview("Form header") {
  if let request = PreviewFixtures.elicitationSession.pendingElicitations.first {
    ElicitationHeader(request: request)
  }
}

#Preview("Form footer") {
  ElicitationFooter(context: ElicitationFooterContext(canSubmit: true, submit: {}, decline: {}, cancel: {}))
}
