import Foundation

/// The symbol table of the kit: each SF Symbol that a view of the kit shows.
///
/// Each constant is one concept, and each concept has one symbol. A view
/// reads the name of a concept from here, so all views of that concept change
/// together, and two concepts do not show the same symbol. A symbol name is
/// written in this file only. The package test `SymbolNameTests` makes sure
/// that no other source file of the kit writes a symbol name, and that this
/// file writes each name one time.
nonisolated enum SharedSymbol {
  // MARK: - Status

  /// The symbol of work that did not start: a pending tool call, plan entry
  /// or message.
  static let pending = "hourglass"

  /// The symbol of work that runs: a running tool call, plan entry or agent,
  /// and an MCP server that connects.
  static let inProgress = "ellipsis.circle.fill"

  /// The symbol of work that is complete: a completed tool call or plan
  /// entry, a complete turn, a sent message, a command that succeeded, an
  /// answered field and a connected MCP server.
  static let completed = "checkmark.circle.fill"

  /// The symbol of an error: a failed tool call, turn, message, command or
  /// connection, a failed MCP server, an error notice, an error card and a
  /// patch that the kit cannot read.
  static let error = "xmark.octagon.fill"

  /// The symbol of work that the user cancelled: a cancelled tool call, plan
  /// entry or turn.
  static let cancelled = "stop.circle.fill"

  /// The symbol of a value that the kit does not know: a status, a kind, a
  /// state, a stop reason, a severity, a priority, a file operation, an exit,
  /// the kind of a permission option or the status of an MCP server that the
  /// agent did not report.
  static let unknown = "questionmark.circle.fill"

  /// The symbol of a warning: a warning notice, a lost tool result, missing
  /// updates, an attachment that the agent does not accept and a link that
  /// leaves the app.
  static let warning = "exclamationmark.triangle.fill"

  /// The symbol of an information notice.
  static let information = "info.circle.fill"

  // MARK: - Tool kinds

  /// The symbol of a tool that reads a file.
  static let read = "text.document"

  /// The symbol of an edit: a tool that edits a file, and the Edit button of
  /// a message.
  static let edit = "pencil"

  /// The symbol of a deletion: a tool that deletes a file, and the Delete
  /// button of a session.
  static let delete = "trash"

  /// The symbol of a tool that moves a file.
  static let move = "arrow.left.arrow.right"

  /// The symbol of a tool that searches.
  static let search = "magnifyingglass"

  /// The symbol of a terminal or a shell command: the `execute` tool kind,
  /// a terminal, a command output row, a command in a permission request,
  /// the terminal link of a permission request and the Run button of a
  /// terminal sign-in.
  static let terminal = "apple.terminal"

  /// The symbol of the reasoning of the model: a thinking tool, a thought,
  /// and a turn that stopped during the reasoning.
  static let reasoning = "brain"

  /// The symbol of a tool that fetches a web resource.
  static let web = "globe"

  /// The symbol of a tool that changes the session mode.
  static let switchMode = "switch.2"

  /// The symbol of a tool: a tool of an other kind, a tool call in a
  /// permission request and the menu of the tools.
  static let tool = "wrench.and.screwdriver"

  // MARK: - Agent state and stop reasons

  /// The symbol of a request to the user: an agent that waits for the user,
  /// and a permission request.
  static let userAction = "hand.raised.fill"

  /// The symbol of a response that stopped at its maximum number of tokens.
  static let maxTokens = "text.badge.xmark"

  /// The symbol of a turn that stopped at its maximum number of model
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

  /// The symbol of a closed session.
  static let closed = "lock.fill"

  /// The symbol of a session that loads its history again.
  static let replaying = "clock.arrow.trianglehead.counterclockwise.rotate.90"

  /// The symbol of a history that can be partial.
  static let partialHistory = "clock.badge.questionmark"

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

  // MARK: - File operations of a diff

  /// The symbol of a file that a patch makes.
  static let addedFile = "plus.square"

  /// The symbol of a file that a patch removes.
  static let deletedFile = "minus.square"

  /// The symbol of a file whose lines a patch changes.
  static let modifiedFile = "dot.square"

  /// The symbol of a file that a patch moves to a new path.
  static let renamedFile = "arrow.right.square"

  /// The symbol of a file that a change copies to a new path.
  static let copiedFile = "plus.square.on.square"

  // MARK: - Buttons

  /// The symbol of a button that copies text to the pasteboard.
  static let copy = "document.on.document"

  /// The symbol of the button that copies the thread.
  static let copyThread = "document.on.clipboard"

  /// The symbol of a button that shares or exports: the Share button of an
  /// attachment and the Export button of a thread.
  static let share = "square.and.arrow.up"

  /// The symbol of a button that does a thing again: Refresh, Retry, the
  /// Reload button of a banner and the Reconnect button of the auth card.
  static let reload = "arrow.clockwise"

  /// The symbol of an answer that accepts one time: the allow-once option of
  /// a permission request and the Accept button of a diff hunk.
  static let accept = "checkmark"

  /// The symbol of the allow-always option of a permission request.
  static let acceptAlways = "checkmark.seal"

  /// The symbol of an answer that rejects one time: the reject-once option of
  /// a permission request and the Reject button of a diff hunk.
  static let reject = "xmark.circle"

  /// The symbol of the reject-always option of a permission request.
  static let rejectAlways = "xmark.seal"

  /// The symbol of a button that shows the details of a thing: the Show
  /// Error button of a banner.
  static let details = "text.magnifyingglass"

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

  /// The symbol of the button that opens a file in its app.
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

  /// The symbol of the button that closes a notice.
  static let dismiss = "xmark"

  /// The symbol of the button that sends the prompt.
  static let send = "arrow.up"

  /// The symbol of the button that stops the turn.
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

  /// The symbol of a row that expands.
  static let disclosure = "chevron.right"

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

  /// The symbol of a file location of a tool call.
  static let document = "document"

  /// The symbol of a plan entry with a high priority: three marks.
  static let highPriority = "exclamationmark.3"

  /// The symbol of a plan entry with a medium priority: two marks.
  static let mediumPriority = "exclamationmark.2"

  /// The symbol of a plan entry with a low priority: one mark.
  static let lowPriority = "exclamationmark"

  /// The symbol of a compaction of the context.
  static let compaction = "arrow.down.right.and.arrow.up.left"

  /// The symbol of an audio that cannot play.
  static let audioFailure = "speaker.slash"

  /// The symbol of an image that cannot show.
  static let imageFailure = "photo.badge.exclamationmark"

  /// The symbol of an artifact.
  static let artifact = "richtext.page"

  /// The symbol of an activity timeline with no entries.
  static let activity = "clock"

  /// The symbol of a question of the agent to the user.
  static let question = "questionmark.bubble"

  /// The symbol of the time of a transcript entry: its start time and its
  /// duration.
  static let entryTime = "timer"

  // MARK: - Usage

  /// The symbol of the part of a whole that is in use, such as the tokens of
  /// the context window. The variable value of the symbol draws its ring up
  /// to the part.
  static let usage = "gauge.open"

  /// The symbol of a whole that is full: the usage ring at one hundred
  /// percent.
  static let usageFull = "gauge.open.with.lines.needle.84percent.exclamation"
}
