import AgentViewKitStyle
import Foundation

/// The agent symbols of the kit: each SF Symbol of a concept that only the
/// views of an agent thread show.
///
/// The shared symbols of the view kits, such as the error, the tool kinds
/// and the file operations, are in ``AgentViewKitStyle/SharedSymbol``. This
/// extension adds the concepts of the kit to the same table, so a view of
/// the kit reads each symbol as `SharedSymbol.<concept>`. A symbol name is
/// written in the two table files only: no other source file of the kit
/// writes a symbol name, and the two files write each name one time.
///
/// No symbol of the table is a clock symbol (`clock`, each `clock.*` symbol,
/// `timer`, `alarm`): a clock is a scheduled task (EditorKit `style.md`).
///
/// The symbols of the status of work and of a priority are not in this
/// table. They come from `ItemStatus` and `ItemPriority` of the EditorKit
/// `EditorStyle` target, so that the kits show the same symbol for the same
/// state: `ItemStatus.pending` for work that did not start, `.inProgress`
/// for work that runs, `.completed` for work that is complete, `.cancelled`
/// for work that the user cancelled, `.unknown` for a value that the kit does
/// not know, and `ItemPriority.low`, `.medium` and `.high` for the priority
/// of a plan entry.
nonisolated extension SharedSymbol {
  // MARK: - Agent state and stop reasons

  /// The symbol of a request to the user: an agent that waits for the user,
  /// and a permission request.
  static let userAction = "hand.raised.fill"

  /// The symbol of a response that stopped at its maximum number of tokens.
  static let maxTokens = "text.badge.xmark"

  /// The symbol of a response that stopped at its maximum number of model
  /// requests.
  static let maxTurnRequests = "arrow.trianglehead.2.clockwise.rotate.90"

  /// The symbol of a model that refused to continue.
  static let refusal = "exclamationmark.bubble.fill"

  /// The symbol of a response that the token limit cut off.
  static let truncated = "scissors"

  /// The symbol of a model that repeated itself.
  static let repeated = "repeat"

  /// The symbol of a model that used all of its reasoning tokens.
  static let reasoningLimit = "gauge.with.dots.needle.100percent"

  /// The symbol of a model that gave no answer.
  static let noOutput = "ellipsis.bubble"

  /// The symbol of a response that stopped because the model wrote no text
  /// for too long.
  static let stalled = "pause.circle.fill"

  // MARK: - Session and connection

  /// The symbol of a session that loads its history again: the history
  /// winds back, and the agent sends it again.
  static let replaying = "arrow.trianglehead.counterclockwise"

  /// The symbol of a history that can be partial: a page of text that the
  /// kit cannot vouch for.
  static let partialHistory = "questionmark.text.page"

  /// The symbol of an agent that is not connected, and of an MCP server whose
  /// connection is closed.
  static let disconnected = "bolt.horizontal.circle"

  /// The symbol of the connections to the agents.
  static let connection = "point.3.connected.trianglepath.dotted"

  /// The symbol of a process that a signal stopped.
  static let signal = "bolt.horizontal.circle.fill"

  /// The symbol of an agent.
  static let agent = "cpu"

  /// The symbol of a sign-in to an agent: the title of the auth card and its
  /// Sign In button.
  static let signIn = "person.badge.shield.checkmark"

  /// The symbol of the button that signs out of an agent.
  static let signOut = "rectangle.portrait.and.arrow.right"

  // MARK: - Buttons

  /// The symbol of a button that copies text to the pasteboard.
  static let copy = "document.on.document"

  /// The symbol of the button that copies the thread.
  static let copyThread = "document.on.clipboard"

  /// The symbol of a button that shares or exports: the Share button of an
  /// attachment and the Export button of a thread.
  static let share = "square.and.arrow.up"

  /// The symbol of an answer that accepts one time: the allow-once option of
  /// a permission request, the Accept button of a diff hunk and the Submit
  /// button of an elicitation form.
  static let accept = "checkmark"

  /// The symbol of the allow-always option of a permission request.
  static let acceptAlways = "checkmark.seal"

  /// The symbol of an answer that rejects one time: the reject-once option of
  /// a permission request, the Reject button of a diff hunk and the Decline
  /// button of an elicitation.
  static let reject = "xmark.circle"

  /// The symbol of the reject-always option of a permission request.
  static let rejectAlways = "xmark.seal"

  /// The symbol of a button that shows the details of a thing: the Show
  /// Error button of a banner.
  static let details = "text.magnifyingglass"

  /// The symbol of the Previous button of the request deck, which brings the
  /// request before the front request to the front.
  static let previousRequest = "chevron.backward"

  /// The symbol of the Next button of the request deck, which brings the
  /// request after the front request to the front.
  static let nextRequest = "chevron.forward"

  /// The symbol of the command that scrolls the thread to the next prompt.
  static let nextPrompt = "chevron.down"

  /// The symbol of the command that scrolls the thread to the previous
  /// prompt.
  static let previousPrompt = "chevron.up"

  /// The symbol of the command that expands or collapses each item of the
  /// thread.
  static let expandAll = "arrow.up.left.and.arrow.down.right"

  /// The symbol of the command that moves the focus to the composer.
  static let focusComposer = "character.cursor.ibeam"

  /// The symbol of the button that loads the next page of a list.
  static let loadMore = "arrow.down.to.line"

  /// The symbol of the button that shows all rows of an output.
  static let showAll = "rectangle.expand.vertical"

  /// The symbol of a suggested prompt.
  static let suggestion = "sparkles"

  /// The symbol of the button that starts a new session.
  static let newSession = "square.and.pencil"

  /// The symbol of the button that attaches a file to the prompt.
  static let attach = "paperclip"

  /// The symbol of a button that opens a thing in an other app: the Open
  /// button of a file and the Open in Browser button of the URL consent card.
  static let open = "arrow.up.forward.app"

  /// The symbol of a folder: the Reveal in Finder button and a working
  /// directory.
  static let folder = "folder"

  /// The symbol of the button that saves a file.
  static let save = "square.and.arrow.down"

  /// The symbol of the Quick Look button.
  static let quickLook = "eye"

  /// The symbol of a button that removes a value: an attachment or a date.
  static let remove = "xmark.circle.fill"

  /// The symbol of a button that sends text to the agent: the button that
  /// sends the prompt and the Send button of the comment of a permission
  /// request.
  static let send = "arrow.up"

  /// The symbol of the button that cancels the work of the session.
  static let stop = "stop.fill"

  /// The symbol of the button that starts the speech input.
  static let microphone = "microphone"

  /// The symbol of the speech input when the app cannot use the microphone.
  static let microphoneUnavailable = "microphone.slash"

  /// The symbol of the speech input while it listens. The level of the
  /// sound fills its bars.
  static let listening = "waveform"

  /// The symbol of the button that loads the earlier messages.
  static let loadEarlier = "arrow.up.to.line"

  /// The symbol of the button that scrolls to the bottom of the thread.
  static let scrollToBottom = "arrow.down"

  /// The symbol of the menu of the session options.
  static let options = "slider.horizontal.3"

  /// The symbol of a selected choice.
  static let selected = "inset.filled.circle"

  /// The symbol of a choice that the user did not make: a choice that is
  /// not selected, and a field with no answer.
  static let notChosen = "circle"

  // MARK: - Content

  /// The symbol of the list of sessions.
  static let sessionList = "list.bullet.rectangle"

  /// The symbol of a conversation, such as an empty thread or an empty list
  /// of sessions.
  static let conversation = "bubble.left.and.bubble.right"

  /// The symbol of the sources of an answer.
  static let sources = "books.vertical"

  /// The symbol of a compaction of the context.
  static let compaction = "arrow.down.right.and.arrow.up.left"

  /// The symbol of an audio that cannot play.
  static let audioFailure = "speaker.slash"

  /// The symbol of an image that cannot show.
  static let imageFailure = "photo.badge.exclamationmark"

  /// The symbol of an artifact.
  static let artifact = "richtext.page"

  /// The symbol of an activity timeline with no entries: the trace of an
  /// activity.
  static let activity = "waveform.path.ecg"

  /// The symbol of a question of the agent to the user.
  static let question = "questionmark.bubble"

  /// The symbol of the time of a transcript entry: its start time and its
  /// duration, the time that the entry took.
  static let entryTime = "calendar"

  // MARK: - Usage

  /// The symbol of the part of a whole that is in use, such as the tokens of
  /// the context window. The variable value of the symbol draws its ring up
  /// to the part.
  static let usage = "gauge.open"

  /// The symbol of a whole that is full: the usage ring at one hundred
  /// percent.
  static let usageFull = "gauge.open.with.lines.needle.84percent.exclamation"
}
