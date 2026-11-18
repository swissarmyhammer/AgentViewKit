import AgentViewKitStyle
import EditorCommandsUI
import EditorStyle
import EditorSwiftUI
import FoundationModelsACPClient
import SwiftUI

/// The side card of `/btw`: a question, and the answer of another session as
/// it streams (D205).
///
/// The host runs the side question in a session of its own, the fork, and
/// gives its `SessionModel` to the card. The card shows the question, and
/// the agent messages of the transcript of the fork as they stream, with the
/// Markdown renderer of the thread (``ResponseView``). A progress mark shows
/// while the turn of the fork runs.
///
/// The card has three buttons, each the EditorKit command button of a
/// ``SideCardVerb`` in the scope of the card, so the context menu, the
/// Session menu, the keys and the command palette run the same command when
/// the card has the focus:
///
/// - Send to Chat puts "Side question: <question>", a blank line and
///   "Answer: <answer>" into the composer of the thread that shows the card,
///   at the caret, with no send, as Mention… inserts its text. With
///   `onSendToChat`, the host gets the text instead.
/// - Open runs `onOpen`: the host shows the fork as a thread.
/// - Close runs `onClose`: the host removes the card. Escape on a focused
///   card also runs Close.
///
/// When the fork needs input (a pending permission request or a pending
/// elicitation), the card shows "Needs input" and the Open button only.
/// When the host turns off ``AgentCommandGroup/sideCard``, the card shows no
/// button, as an attachment does with its group off.
///
/// The card floats on the glass of the floating controls (D110), and its
/// text uses the vibrant label role (`PlacedLabel`). Show the cards of a
/// thread with ``AgentThreadView/sideCards(_:)``:
///
/// ```swift
/// AgentThreadView(session: session)
///   .sideCards {
///     ForEach(sideQuestions.reversed()) { side in
///       SideQuestionCard(
///         question: side.question, session: side.fork,
///         onOpen: { host.open(side) }, onClose: { host.remove(side) })
///     }
///   }
/// ```
///
/// The card is one accessibility element group with the label "Side
/// question" and the question text, with the identifier ``identifier``.
public struct SideQuestionCard: View {
  /// The accessibility identifier of each side card.
  public nonisolated static let identifier = "side-card"

  /// The question of the card.
  let question: String

  /// The session model of the fork.
  let session: SessionModel

  /// The Open action of the host.
  let onOpen: @MainActor () -> Void

  /// The Close action of the host.
  let onClose: @MainActor () -> Void

  /// The Send to Chat action of the host, or `nil` for the composer of the
  /// thread.
  let onSendToChat: (@MainActor (String) -> Void)?

  /// The style of the editor, for the spacing and the fonts of the card.
  @Environment(\.editorStyle) private var editorStyle

  /// The command groups that are off. With the group of the side card off,
  /// the card shows no button.
  @Environment(\.agentCommandGroupsOff) private var groupsOff

  /// The target of the scope of the card.
  @State private var target = SideCardTarget()

  /// Makes the side card of a question and of the session model of its fork.
  ///
  /// - Parameters:
  ///   - question: The question of the user.
  ///   - session: The session model of the fork that answers the question.
  ///   - onOpen: Shows the fork as a thread.
  ///   - onClose: Removes the card.
  ///   - onSendToChat: Takes the text of Send to Chat, or `nil` to insert
  ///     the text in the composer of the thread that shows the card.
  public init(
    question: String, session: SessionModel, onOpen: @escaping @MainActor () -> Void,
    onClose: @escaping @MainActor () -> Void, onSendToChat: (@MainActor (String) -> Void)? = nil
  ) {
    self.question = question
    self.session = session
    self.onOpen = onOpen
    self.onClose = onClose
    self.onSendToChat = onSendToChat
  }

  /// The card: the question, the streamed answer of the fork or "Needs
  /// input", and the command buttons of the side card verbs, in the scope of
  /// the card.
  public var body: some View {
    FloatingGlassContainer(spacing: editorStyle.spacing.s) {
      VStack(alignment: .leading, spacing: editorStyle.spacing.s) {
        header
        answerOrNeedsInput
        if !groupsOff.contains(.sideCard) {
          buttons
        }
      }
      .padding(editorStyle.spacing.m)
      .frame(maxWidth: .infinity, alignment: .leading)
      .modifier(SideCardScope(target: target, values: values))
      .floatingGlass()
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Self.accessibilityLabelText)
    .accessibilityValue(question)
    .accessibilityIdentifier(Self.identifier)
  }

  /// The values that the card gives to the target of its scope.
  private var values: SideCardValues {
    SideCardValues(
      question: question, session: session, open: onOpen, close: onClose, hostSend: onSendToChat)
  }

  /// The question, with the progress mark while the turn of the fork runs.
  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: editorStyle.spacing.s) {
      PlacedLabel(verbatim: question)
        .frame(maxWidth: .infinity, alignment: .leading)
      if Self.isRunning(session) {
        ProgressView()
          .controlSize(.small)
          .accessibilityLabel(Self.runningText)
      }
    }
  }

  /// "Needs input" while the fork needs input, else the answer.
  @ViewBuilder private var answerOrNeedsInput: some View {
    if Self.needsInput(session) {
      HStack(spacing: editorStyle.spacing.s) {
        DecorativeSymbolImage(name: Self.needsInputSymbol)
        PlacedLabel(verbatim: Self.needsInputText, textColor: .secondary)
      }
    } else {
      ForEach(Self.answerEntries(of: session), id: \.id) { entry in
        ResponseView(
          id: Self.responseID(of: entry, in: session),
          markdown: ThreadExporter.markdown(for: entry.content))
      }
    }
  }

  /// The buttons of the card: the command button of each verb that the state
  /// of the fork shows.
  private var buttons: some View {
    ControlStack(.horizontal) {
      ForEach(Self.verbs(needsInput: Self.needsInput(session)), id: \.self) { verb in
        EditorToolbarButton(command: verb.id)
          .accessibilityIdentifier(verb.identifier)
      }
    }
  }
}

// MARK: - Model

/// The model of a side card: the texts that the card shows and the rules
/// that the commands and the tests read, with no view.
extension SideQuestionCard {
  /// The accessibility label of each side card.
  static var accessibilityLabelText: String {
    String(localized: "Side question", bundle: .module)
  }

  /// The text that a card shows while the fork needs input.
  static var needsInputText: String {
    String(localized: "Needs input", bundle: .module)
  }

  /// The accessibility label of the progress mark of a card.
  static var runningText: String {
    String(localized: "Answering", bundle: .module)
  }

  /// The symbol before ``needsInputText``: the symbol of a request to the
  /// user.
  static let needsInputSymbol = AgentSymbol.userAction

  /// The text of Send to Chat: "Side question: <question>", a blank line, and
  /// "Answer: <answer>".
  ///
  /// - Parameters:
  ///   - question: The question of the card.
  ///   - answer: The answer of the fork, as Markdown.
  /// - Returns: The text.
  static func chatText(question: String, answer: String) -> String {
    String(localized: "Side question: \(question)\n\nAnswer: \(answer)", bundle: .module)
  }

  /// The agent message entries of the transcript of the fork, in order.
  ///
  /// - Parameter session: The session model of the fork.
  /// - Returns: The entries.
  static func answerEntries(of session: SessionModel) -> [AgentMessageEntry] {
    session.transcript.compactMap { entry in
      guard case .agentMessage(let message) = entry else { return nil }
      return message
    }
  }

  /// The answer of the fork: the Markdown of the texts of its agent
  /// messages, in order (`ThreadExporter.markdown(ofTexts:templates:)`).
  ///
  /// - Parameter session: The session model of the fork.
  /// - Returns: The Markdown, or an empty string when the fork has no answer
  ///   yet.
  static func answer(of session: SessionModel) -> String {
    let texts = answerEntries(of: session).flatMap { ThreadExporter.texts(of: $0.content) }
    return ThreadExporter.markdown(ofTexts: texts, templates: .bundled)
  }

  /// Tells if the fork needs input: it has a pending permission request or
  /// a pending elicitation.
  ///
  /// - Parameter session: The session model of the fork.
  /// - Returns: `true` when the fork waits for the user.
  static func needsInput(_ session: SessionModel) -> Bool {
    !session.pendingRequests.isEmpty
  }

  /// Tells if the turn of the fork runs, so the card shows its progress mark.
  ///
  /// - Parameter session: The session model of the fork.
  /// - Returns: `true` while the work state of the fork is `.running`.
  static func isRunning(_ session: SessionModel) -> Bool {
    session.workState == .running
  }

  /// The verbs whose buttons a card shows, in order.
  ///
  /// - Parameter needsInput: Whether the fork needs input.
  /// - Returns: Open alone while the fork needs input, else Send to Chat,
  ///   Open and Close.
  static func verbs(needsInput: Bool) -> [SideCardVerb] {
    needsInput ? [.openSideCard] : SideCardVerb.allCases
  }

  /// The id of the model of the response of `entry`, unique in the thread
  /// that shows the card: the session id of the fork and the row key of the
  /// entry.
  ///
  /// - Parameters:
  ///   - entry: The agent message entry.
  ///   - session: The session model of the fork.
  /// - Returns: The id.
  static func responseID(of entry: AgentMessageEntry, in session: SessionModel) -> String {
    "\(identifier)-\(session.sessionId.rawValue)-\(entry.id.rowKey)"
  }
}

#Preview("Side question card") {
  SideQuestionCard(
    question: "What does the parser do?",
    session: .preview(transcript: [.agent("It reads the tokens.")]), onOpen: {}, onClose: {}
  )
  .padding()
}
