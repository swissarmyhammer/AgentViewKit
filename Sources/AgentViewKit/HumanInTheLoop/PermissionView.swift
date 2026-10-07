import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The in-thread card that asks the user for permission to do an operation
/// (plan.md §9 E, §12; update.md §4.2 "Pending requests").
///
/// The card shows one `PendingPermissionRequest` of a `SessionModel`. It reads
/// each value from that request and from the session model in its body, and
/// keeps no copy of them.
///
/// The card is a glass card with these parts:
///
/// - The title of the request, and its description when it has one.
/// - The subject. For a tool call, the card shows the title and the kind of
///   the `ToolCallEntry` of the session model. For a command, the card shows
///   the command, the working directory, and, when the session model has the
///   related `TerminalEntry`, a button that shows the ``TerminalView`` of that
///   entry.
/// - One button for each option of the request, in the order of
///   `PermissionPresentation.order(of:)`. The `allow_once` button is
///   prominent. The kept answers and the unknown kinds are secondary
///   (``PermissionPresentation/isSecondary(kind:)``).
/// - A "switch to auto" button when
///   ``PermissionPresentation/autoModeOption(in:)`` gives an option for the
///   `configOptions` of the session model, and the request has an
///   `allow_once` option.
///
/// A press on an `allow` option calls `selectPermission(_:option:)` on the
/// session model at once. A press on a `reject` option shows a comment field.
/// The Send button of the field, or Return in the field, selects the option.
/// The wire has no field for a comment, so a comment that is not empty then
/// goes out as the next prompt (`Docs/decisions/permission-ux.md`). Esc calls
/// `cancelPermission(_:)`.
///
/// The "switch to auto" button selects the `allow_once` option, then sets the
/// mode option to ``PermissionPresentation/autoModeValue``. This is the order
/// of `Docs/decisions/permission-ux.md`.
///
/// The session model removes the request when it resolves, so the host
/// removes the card. The card answers only while the session model holds the
/// request: an answer after the request resolved does nothing.
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
  /// - Parameter id: The `optionId` of the option.
  /// - Returns: `permission-option-<id>`.
  public static func optionIdentifier(for id: PermissionOptionId) -> String {
    AccessibilityIdentifier.make(prefix: optionIdentifierPrefix, value: id.rawValue)
  }

  /// The pending request to answer.
  let request: PendingPermissionRequest

  /// The session model that holds the request.
  let session: SessionModel

  /// The reject option that the user selected, or `nil`. While it has a
  /// value, the card shows the comment field.
  @State private var selectedReject: FoundationModelsACP.PermissionOption?

  /// The text of the comment field.
  @State private var comment = ""

  /// Whether the card shows the related terminal.
  @State private var showsTerminal = false

  /// Whether the card has the keyboard focus.
  @FocusState private var isFocused: Bool

  @Environment(\.agentTheme) private var theme

  /// The action that moves the VoiceOver focus and tells the host.
  private let moveFocus = AccessibilityFocusMove()

  /// Makes the card of a pending permission request.
  ///
  /// - Parameters:
  ///   - request: A pending request of `session.pendingPermissions`.
  ///   - session: The session model that holds the request.
  public init(request: PendingPermissionRequest, session: SessionModel) {
    self.request = request
    self.session = session
  }

  // MARK: Body

  public var body: some View {
    let options = PermissionPresentation.order(of: request.request.options)
    VStack(alignment: .leading, spacing: theme.spacing.m) {
      header
      if let subject = request.request.subject {
        subjectView(for: subject)
      }
      optionButtons(for: options)
      if let selectedReject {
        commentRow(for: selectedReject)
      }
      switchToAutoButton(for: options)
    }
    .padding(theme.spacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
    .focusable()
    .focusEffectDisabled()
    .focused($isFocused)
    .defaultFocus($isFocused, true)
    .onExitCommand { session.startCancelPermission(request.id) }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(request.request.title)
    .accessibilityIdentifier(Self.identifier)
    .accessibilityFocusTarget(Self.identifier)
    .onAppear { moveFocus(to: Self.identifier) }
  }

  /// The title and the description.
  private var header: some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Label(request.request.title, systemImage: Self.symbol)
        .font(.headline)
        .fontWeight(theme.symbolWeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(request.request.title)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(Self.titleIdentifier)
      if let description = request.request.description {
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
  /// - Parameter subject: The ACP subject.
  /// - Returns: The tool call summary, the command with its terminal link, or
  ///   no view for a subject kind that the kit does not know.
  @ViewBuilder
  private func subjectView(for subject: RequestPermissionSubject) -> some View {
    switch subject {
    case .toolCall(let toolCall):
      toolCallSummary(id: toolCall.toolCall.toolCallId)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(Self.subjectIdentifier)
    case .command(let command):
      commandSummary(of: command)
    case .unknown:
      EmptyView()
    }
  }

  /// The title and the kind of the tool call with `id`.
  ///
  /// - Parameter id: The id of the tool call.
  /// - Returns: The summary from the `ToolCallEntry` of the session model.
  ///   When the session model has no such entry, the summary shows the id.
  @ViewBuilder
  private func toolCallSummary(id: ToolCallId) -> some View {
    if let entry = toolCallEntry(withID: id) {
      HStack(spacing: theme.spacing.s) {
        Label(entry.title ?? id.rawValue, systemImage: Self.toolCallSymbol)
        if let kind = entry.kind {
          Text(kind.wireValue)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    } else {
      Label("Tool call \(id.rawValue)", systemImage: Self.toolCallSymbol)
    }
  }

  /// The command, its working directory, and the link to its terminal.
  ///
  /// - Parameter command: The ACP command subject.
  /// - Returns: The summary, with the terminal link when the session model
  ///   has the `TerminalEntry` of the command.
  private func commandSummary(of command: CommandPermissionSubject) -> some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      VStack(alignment: .leading, spacing: theme.spacing.xs) {
        Label(command.command, systemImage: Self.commandSymbol)
          .font(.body.monospaced())
          .textSelection(.enabled)
        Label(command.cwd.rawValue, systemImage: Self.directorySymbol)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Command \(command.command), in \(command.cwd.rawValue)")
      .accessibilityIdentifier(Self.subjectIdentifier)
      if let terminalId = command.terminalId, let entry = terminalEntry(withID: terminalId) {
        terminalLink(to: entry)
      }
    }
  }

  /// The button that shows or hides the terminal, and the terminal.
  ///
  /// - Parameter entry: The related terminal entry of the session model.
  /// - Returns: The link and, while it is open, the ``TerminalView``.
  private func terminalLink(to entry: TerminalEntry) -> some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      Button(showsTerminal ? "Hide Terminal" : "Show Terminal") {
        showsTerminal.toggle()
      }
      .buttonStyle(.link)
      .accessibilityIdentifier(Self.terminalLinkIdentifier)
      if showsTerminal {
        TerminalView(entry: entry)
      }
    }
  }

  /// The tool call entry of the session model with the id of a tool call.
  ///
  /// - Parameter id: The id of the tool call.
  /// - Returns: The entry, or `nil` when the transcript has none.
  private func toolCallEntry(withID id: ToolCallId) -> ToolCallEntry? {
    transcriptEntry(withID: .toolCall(id)) { entry in
      if case .toolCall(let toolCall) = entry { toolCall } else { nil }
    }
  }

  /// The terminal entry of the session model with the id of a terminal.
  ///
  /// - Parameter id: The id of the terminal.
  /// - Returns: The entry, or `nil` when the transcript has none.
  private func terminalEntry(withID id: TerminalId) -> TerminalEntry? {
    transcriptEntry(withID: .terminal(id)) { entry in
      if case .terminal(let terminal) = entry { terminal } else { nil }
    }
  }

  /// The entry of the transcript of the session model with a wire id.
  ///
  /// - Parameters:
  ///   - id: The wire id of the entry.
  ///   - object: Gives the entry object of the expected kind.
  /// - Returns: The entry object, or `nil` when the transcript has no entry of
  ///   that kind with that id.
  private func transcriptEntry<Entry>(
    withID id: FoundationModelsACP.SessionEntry.ID, as object: (TranscriptEntry) -> Entry?
  ) -> Entry? {
    let identity = TranscriptEntry.ID.wire(id)
    return session.transcript.first { $0.id == identity }.flatMap(object)
  }

  // MARK: Options

  /// One button for each option.
  ///
  /// - Parameter options: The ACP options in display order.
  /// - Returns: The row of buttons.
  private func optionButtons(for options: [FoundationModelsACP.PermissionOption]) -> some View {
    HStack(spacing: theme.spacing.s) {
      ForEach(options, id: \.optionId) { option in
        optionButton(for: option)
      }
    }
  }

  /// The button of one option, with the weight of its kind.
  ///
  /// - Parameter option: The ACP option.
  /// - Returns: The button.
  @ViewBuilder
  private func optionButton(for option: FoundationModelsACP.PermissionOption) -> some View {
    let button = Button(option.name) { didPress(option: option) }
      .accessibilityIdentifier(Self.optionIdentifier(for: option.optionId))
    if option.kind == .allowOnce {
      button.buttonStyle(.glassProminent)
    } else if PermissionPresentation.isSecondary(kind: option.kind) {
      button.buttonStyle(.glass).foregroundStyle(.secondary)
    } else {
      button.buttonStyle(.glass)
    }
  }

  /// The comment field of a reject option, and its Send button.
  ///
  /// - Parameter option: The reject option that the user selected.
  /// - Returns: The row.
  private func commentRow(for option: FoundationModelsACP.PermissionOption) -> some View {
    HStack(spacing: theme.spacing.s) {
      TextField("Tell the agent what to do instead", text: $comment)
        .textFieldStyle(.roundedBorder)
        .onSubmit { sendReject(option: option) }
        .accessibilityIdentifier(Self.commentIdentifier)
      Button("Send") { sendReject(option: option) }
        .buttonStyle(.glass)
        .accessibilityIdentifier(Self.commentSubmitIdentifier)
    }
  }

  /// The "switch to auto" button, when the card offers it.
  ///
  /// - Parameter options: The ACP options in display order.
  /// - Returns: The button, or no view.
  @ViewBuilder
  private func switchToAutoButton(for options: [FoundationModelsACP.PermissionOption]) -> some View {
    if let modeOption = PermissionPresentation.autoModeOption(in: session.configOptions ?? []),
      let allow = options.first(where: { $0.kind == .allowOnce })
    {
      Button("Allow and Switch to Auto Mode") {
        switchToAuto(allow: allow, modeOption: modeOption)
      }
      .buttonStyle(.glass)
      .accessibilityIdentifier(Self.switchToAutoIdentifier)
    }
  }

  // MARK: Actions

  /// Selects `option`, or shows the comment field for a reject option.
  ///
  /// - Parameter option: The option that the user pressed.
  private func didPress(option: FoundationModelsACP.PermissionOption) {
    if PermissionPresentation.isReject(kind: option.kind) {
      selectedReject = option
    } else {
      answer(with: option, comment: nil)
    }
  }

  /// Selects the reject option with the text of the comment field.
  ///
  /// - Parameter option: The reject option.
  private func sendReject(option: FoundationModelsACP.PermissionOption) {
    let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
    answer(with: option, comment: text.isEmpty ? nil : text)
  }

  /// Selects `option` on the session model, then sends the comment as the
  /// next prompt, with `SessionModel.answerPermission(_:option:comment:)`.
  ///
  /// - Parameters:
  ///   - option: The option that the user selected.
  ///   - comment: The comment of the user, or `nil`.
  private func answer(with option: FoundationModelsACP.PermissionOption, comment: String?) {
    guard isPending else { return }
    session.answerPermission(request.id, option: option.optionId, comment: comment)
  }

  /// Selects `allow` on the session model, then sets the mode option to auto.
  ///
  /// - Parameters:
  ///   - allow: The `allow_once` option of the request.
  ///   - modeOption: The option that
  ///     ``PermissionPresentation/autoModeOption(in:)`` gave.
  private func switchToAuto(allow: FoundationModelsACP.PermissionOption, modeOption: SessionConfigOption) {
    guard isPending else { return }
    session.startSelectPermission(request.id, option: allow.optionId)
    session.startSetConfigOption(modeOption.configId, to: PermissionPresentation.autoModeValue)
  }

  /// Whether the session model still holds the request. An answer after the
  /// request resolved does nothing.
  private var isPending: Bool {
    session.pendingPermissions.contains { $0.id == request.id }
  }
}
