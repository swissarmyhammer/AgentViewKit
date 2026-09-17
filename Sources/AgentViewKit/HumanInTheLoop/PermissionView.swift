import SwiftUI

/// The in-thread card that asks the user for permission to do an operation
/// (plan.md §9 E, §12).
///
/// The card is a glass card with these parts:
///
/// - The title of the request, and its description when it has one.
/// - The subject. For a tool call, the card shows the title and the kind of
///   the ``ToolCallRecord`` in the ``SwiftUI/EnvironmentValues/agentThread``.
///   For a command, the card shows the command, the working directory, and,
///   when the thread has the related ``TerminalRecord``, a button that shows
///   the ``TerminalView`` of that record.
/// - One button for each option of the request, in the order of
///   ``PermissionPresentation/order(of:)``. The `allow_once` button is
///   prominent. The kept answers and the unknown kinds are secondary
///   (``PermissionPresentation/isSecondary(_:)``).
/// - A "switch to auto" button when
///   ``PermissionPresentation/autoModeOption(in:)`` gives an option for the
///   config options of the thread, and the request has an `allow_once`
///   option.
///
/// A press on an `allow` option sends the decision at once. A press on a
/// `reject` option shows a comment field. The Send button of the field, or
/// Return in the field, sends the decision with the comment. An empty comment
/// sends no comment. Esc sends ``PermissionDecision/Outcome/cancelled``.
///
/// The "switch to auto" button sends the `allow_once` option, then sets the
/// mode option to ``PermissionPresentation/autoModeValue``. This is the order
/// of `Docs/decisions/permission-ux.md`.
///
/// Each answer goes to
/// ``AgentThreadActions/respond(to:_:)-(PermissionRequest,_)`` of the
/// `threadActions` environment value. The card sends one answer only.
///
/// The view keeps the selected reject option and the comment in state. Give
/// each request its own view identity, for example with `.id(request.id)`.
public struct PermissionView: View {
  /// The accessibility identifier of the card.
  public static let identifier = "permission-card"
  /// The accessibility identifier of the title.
  public static let titleIdentifier = "permission-title"
  /// The accessibility identifier of the subject.
  public static let subjectIdentifier = "permission-subject"
  /// The start of the accessibility identifier of each option button.
  public static let optionIdentifierPrefix = "permission-option-"
  /// The accessibility identifier of the comment field.
  public static let commentIdentifier = "permission-comment"
  /// The accessibility identifier of the Send button of the comment field.
  public static let commentSubmitIdentifier = "permission-comment-submit"
  /// The accessibility identifier of the "switch to auto" button.
  public static let switchToAutoIdentifier = "permission-switch-auto"
  /// The accessibility identifier of the button that shows the terminal.
  public static let terminalLinkIdentifier = "permission-terminal-link"

  /// The symbol of the title.
  static let symbol = "hand.raised"
  /// The symbol of a tool call subject.
  static let toolCallSymbol = "wrench.and.screwdriver"
  /// The symbol of a command subject.
  static let commandSymbol = "terminal"
  /// The symbol of the working directory.
  static let directorySymbol = "folder"

  /// The accessibility identifier of the button of an option.
  ///
  /// - Parameter id: The identifier of the option.
  /// - Returns: `permission-option-<id>`.
  public static func optionIdentifier(for id: PermissionOptionID) -> String {
    AccessibilityIdentifier.make(prefix: optionIdentifierPrefix, value: id.rawValue)
  }

  /// The request to answer.
  let request: PermissionRequest

  /// The reject option that the user selected, or `nil`. While it has a
  /// value, the card shows the comment field.
  @State private var selectedReject: PermissionOption?

  /// The text of the comment field.
  @State private var comment = ""

  /// Whether the card shows the related terminal.
  @State private var showsTerminal = false

  /// Whether the card sent its answer.
  @State private var isAnswered = false

  /// Whether the card has the keyboard focus.
  @FocusState private var isFocused: Bool

  @Environment(\.threadActions) private var actions
  @Environment(\.agentThread) private var thread
  @Environment(\.agentTheme) private var theme

  /// Makes the card of `request`.
  ///
  /// - Parameter request: The request to answer.
  public init(request: PermissionRequest) {
    self.request = request
  }

  // MARK: Body

  public var body: some View {
    let options = PermissionPresentation.order(of: request.options)
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      header
      if let subject = request.subject {
        subjectView(subject)
      }
      optionButtons(options)
      if let selectedReject {
        commentRow(selectedReject)
      }
      switchToAutoButton(options)
    }
    .padding(theme.spacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
    .focusable()
    .focusEffectDisabled()
    .focused($isFocused)
    .defaultFocus($isFocused, true)
    .onExitCommand { send(PermissionDecision(outcome: .cancelled)) }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(request.title)
    .accessibilityIdentifier(Self.identifier)
  }

  /// The title and the description.
  private var header: some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Label(request.title, systemImage: Self.symbol)
        .font(.headline)
        .fontWeight(theme.symbolWeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(request.title)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(Self.titleIdentifier)
      if let description = request.description {
        Text(description)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  // MARK: Subject

  /// The view of the subject of the request.
  ///
  /// - Parameter subject: The subject.
  /// - Returns: The tool call summary, or the command with its terminal link.
  @ViewBuilder
  private func subjectView(_ subject: PermissionRequest.Subject) -> some View {
    switch subject {
    case .toolCall(let id):
      toolCallSummary(id: id)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Self.subjectIdentifier)
    case .command(let command, let cwd, _, let terminalId):
      VStack(alignment: .leading, spacing: theme.spacing.s) {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
          Label(command, systemImage: Self.commandSymbol)
            .font(.body.monospaced())
            .textSelection(.enabled)
          Label(cwd, systemImage: Self.directorySymbol)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Command \(command), in \(cwd)")
        .accessibilityIdentifier(Self.subjectIdentifier)
        if let terminalId, let record = thread?.terminals[terminalId] {
          terminalLink(record)
        }
      }
    }
  }

  /// The title and the kind of the tool call with `id`.
  ///
  /// - Parameter id: The identifier of the tool call.
  /// - Returns: The summary. When the thread has no such tool call, the
  ///   summary shows the identifier.
  @ViewBuilder
  private func toolCallSummary(id: String) -> some View {
    if case .toolCall(let record) = thread?.item(id: id) {
      HStack(spacing: theme.spacing.s) {
        Label(record.title, systemImage: Self.toolCallSymbol)
        Text(record.kind.wireValue)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } else {
      Label("Tool call \(id)", systemImage: Self.toolCallSymbol)
    }
  }

  /// The button that shows or hides the terminal, and the terminal.
  ///
  /// - Parameter record: The related terminal.
  /// - Returns: The link and, while it is open, the ``TerminalView``.
  private func terminalLink(_ record: TerminalRecord) -> some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      Button(showsTerminal ? "Hide Terminal" : "Show Terminal") {
        showsTerminal.toggle()
      }
      .buttonStyle(.link)
      .accessibilityIdentifier(Self.terminalLinkIdentifier)
      if showsTerminal {
        TerminalView(record: record)
      }
    }
  }

  // MARK: Options

  /// One button for each option.
  ///
  /// - Parameter options: The options in display order.
  /// - Returns: The row of buttons.
  private func optionButtons(_ options: [PermissionOption]) -> some View {
    HStack(spacing: theme.spacing.s) {
      ForEach(options) { option in
        optionButton(option)
      }
    }
    .disabled(isAnswered)
  }

  /// The button of one option, with the weight of its kind.
  ///
  /// - Parameter option: The option.
  /// - Returns: The button.
  @ViewBuilder
  private func optionButton(_ option: PermissionOption) -> some View {
    let button = Button(option.name) { select(option) }
      .accessibilityIdentifier(Self.optionIdentifier(for: option.id))
    if option.kind == .allowOnce {
      button.buttonStyle(.glassProminent)
    } else if PermissionPresentation.isSecondary(option.kind) {
      button.buttonStyle(.glass).foregroundStyle(.secondary)
    } else {
      button.buttonStyle(.glass)
    }
  }

  /// The comment field of a reject option, and its Send button.
  ///
  /// - Parameter option: The reject option that the user selected.
  /// - Returns: The row.
  private func commentRow(_ option: PermissionOption) -> some View {
    HStack(spacing: theme.spacing.s) {
      TextField("Tell the agent what to do instead", text: $comment)
        .textFieldStyle(.roundedBorder)
        .onSubmit { sendReject(option) }
        .accessibilityIdentifier(Self.commentIdentifier)
      Button("Send") { sendReject(option) }
        .buttonStyle(.glass)
        .accessibilityIdentifier(Self.commentSubmitIdentifier)
    }
    .disabled(isAnswered)
  }

  /// The "switch to auto" button, when the card offers it.
  ///
  /// - Parameter options: The options in display order.
  /// - Returns: The button, or no view.
  @ViewBuilder
  private func switchToAutoButton(_ options: [PermissionOption]) -> some View {
    if let modeOption = PermissionPresentation.autoModeOption(in: thread?.configOptions ?? []),
      let allow = options.first(where: { $0.kind == .allowOnce })
    {
      Button("Allow and Switch to Auto Mode") {
        switchToAuto(allow: allow, modeOption: modeOption)
      }
      .buttonStyle(.glass)
      .disabled(isAnswered)
      .accessibilityIdentifier(Self.switchToAutoIdentifier)
    }
  }

  // MARK: Actions

  /// Answers with `option`, or shows the comment field for a reject option.
  ///
  /// - Parameter option: The option that the user pressed.
  private func select(_ option: PermissionOption) {
    switch option.kind {
    case .rejectOnce, .rejectAlways:
      selectedReject = option
    case .allowOnce, .allowAlways, .unknown:
      send(PermissionDecision(outcome: .selected(option.id)))
    }
  }

  /// Answers with the reject option and the text of the comment field.
  ///
  /// - Parameter option: The reject option.
  private func sendReject(_ option: PermissionOption) {
    let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
    send(PermissionDecision(outcome: .selected(option.id), comment: text.isEmpty ? nil : text))
  }

  /// Answers with `allow`, then sets the mode option to auto.
  ///
  /// - Parameters:
  ///   - allow: The `allow_once` option of the request.
  ///   - modeOption: The option that
  ///     ``PermissionPresentation/autoModeOption(in:)`` gave.
  private func switchToAuto(allow: PermissionOption, modeOption: ConfigOption) {
    answer { actions, request in
      await actions.respond(to: request, PermissionDecision(outcome: .selected(allow.id)))
      await actions.setConfigOption(modeOption.id, PermissionPresentation.autoModeValue)
    }
  }

  /// Sends `decision` to the thread actions.
  ///
  /// - Parameter decision: The answer of the user.
  private func send(_ decision: PermissionDecision) {
    answer { actions, request in
      await actions.respond(to: request, decision)
    }
  }

  /// Runs `work` one time for the card.
  ///
  /// - Parameter work: The calls that answer the request.
  private func answer(
    _ work: @escaping @MainActor (any AgentThreadActions, PermissionRequest) async -> Void
  ) {
    guard !isAnswered else { return }
    isAnswered = true
    let actions = actions
    let request = request
    Task {
      await work(actions, request)
    }
  }
}
