import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import UniformTypeIdentifiers

/// The values that the `#Preview` blocks of the kit show.
///
/// Each value comes from a preview model of FoundationModelsACPClient
/// (`SessionModel.preview(...)`). The preview model folds each item through
/// the merge engine that a live model uses, so a preview shows the state that
/// a live session makes.
enum PreviewFixtures {
  /// Makes the entry of one transcript item, as the object of its kind.
  ///
  /// - Parameters:
  ///   - item: The transcript item.
  ///   - type: The class of the entry object, such as `ThoughtEntry`.
  /// - Returns: The entry object of the item, or `nil` when the item makes
  ///   an entry of another kind.
  static func entry<Entry: AnyObject>(_ item: PreviewTranscriptItem, as type: Entry.Type) -> Entry? {
    firstEntry(in: .preview(transcript: [item]), as: type)
  }

  /// Finds the first entry of one kind in the transcript of a session.
  ///
  /// - Parameters:
  ///   - session: The session model.
  ///   - type: The class of the entry object, such as `ToolCallEntry`.
  /// - Returns: The first entry object of that class, or `nil` when the
  ///   transcript has no entry of that kind.
  static func firstEntry<Entry: AnyObject>(in session: SessionModel, as type: Entry.Type) -> Entry? {
    session.transcript.lazy.compactMap { $0.object as? Entry }.first
  }

  /// The id of the mode that asks before each tool call.
  static let defaultModeID = "default"

  /// The configuration options of a session: a `mode` select option, and a
  /// Boolean option with no category.
  static let configOptions = [
    SessionConfigOption(
      configId: SessionConfigId(rawValue: "mode"), name: "Mode", category: .mode,
      type: .select(
        SessionConfigSelect(
          currentValue: SessionConfigValueId(rawValue: defaultModeID),
          options: .array(
            [PermissionPresentation.planModeID, defaultModeID, PermissionPresentation.autoModeID].map {
              .object(["value": .string($0), "name": .string($0.capitalized)])
            })))),
    SessionConfigOption(
      configId: SessionConfigId(rawValue: "web-search"), name: "Web Search",
      type: .boolean(SessionConfigBoolean(currentValue: true))),
  ]

  /// A new preview session with ``configOptions``.
  static var configuredSession: SessionModel {
    .preview(configOptions: configOptions)
  }

  /// The size of the context window of the sample usage, in tokens.
  static let contextWindowSize = 200_000

  /// The tokens of the context window that the sample usage uses.
  static let usedTokens = 48_000

  /// The last usage report of a session.
  static let usage = UsageUpdate(size: contextWindowSize, used: usedTokens)

  /// A new preview session whose agent reported ``usage``.
  static var usageSession: SessionModel {
    .preview(transcript: [.update(.usageUpdate(usage))])
  }

  /// The MCP servers that the client sent to a session.
  static let mcpServers = [
    MCPServer.stdio(MCPServerStdio(command: AbsolutePath(rawValue: "/usr/local/bin/github-mcp"), name: "GitHub")),
    MCPServer.stdio(MCPServerStdio(command: AbsolutePath(rawValue: "/usr/local/bin/files-mcp"), name: "Files")),
  ]

  /// A new preview session with ``mcpServers``.
  static var mcpSession: SessionModel {
    .preview(mcpServers: mcpServers)
  }

  /// The first sentence of ``citedResponse``. The first source cites it.
  static let citedFirstSentence = "Swift 6 finds data races when it compiles the code."

  /// The second sentence of ``citedResponse``. The second source cites it.
  static let citedSecondSentence = "Each module can turn on the new language mode on its own."

  /// A response of one paragraph that cites two sources.
  static let citedResponse = "\(citedFirstSentence) \(citedSecondSentence)"

  /// The URL of the first source of ``citations``, which ``citedQuote`` also
  /// cites.
  static let concurrencySourceURL = URL(filePath: "/Users/preview/docs/concurrency.html")

  /// The sources of ``citedResponse``, with a marker at the end of each
  /// sentence.
  static let citations = CitationPayload(
    sources: [
      CitationSource(
        id: "concurrency", title: "Swift Concurrency",
        url: concurrencySourceURL,
        snippet: "The compiler checks that the code has no data race."),
      CitationSource(
        id: "migration", title: "Migrate to Swift 6",
        url: URL(filePath: "/Users/preview/docs/migration.html"),
        snippet: "Turn on the Swift 6 language mode one module at a time."),
    ],
    markers: [
      CitationMarker(sourceID: "concurrency", paragraphIndex: 0, offset: citedFirstSentence.count),
      CitationMarker(sourceID: "migration", paragraphIndex: 0, offset: citedResponse.count),
    ])

  /// The host of the URL of ``urlElicitation``.
  static let elicitationURLHost = "auth.example.com"

  /// The scope of each sample elicitation: the default preview session.
  static let elicitationScope = ElicitationSessionScope(sessionId: SessionModel.previewSessionId)

  /// A form-mode elicitation with three fields. A sub-agent asks it through a
  /// tool, so the card shows the "who asks" line.
  static let formElicitation = CreateElicitationRequest(
    message: "Give the details of the new package.",
    mode: .form(
      ElicitationFormMode(
        requestedSchema: ElicitationSchema(
          properties: .object([
            "name": .object(["type": .string("string"), "title": .string("Name"), "minLength": .number(1)]),
            "retries": .object([
              "type": .string("integer"), "title": .string("Retries"), "minimum": .number(0),
              "maximum": .number(ElicitationFields.maximumRetries),
            ]),
            "verbose": .object(["type": .string("boolean"), "title": .string("Verbose output")]),
          ]),
          required: ["name"]),
        scope: .session(elicitationScope))),
    meta: .object(["agentPath": .array([.string("planner")]), "source": .string("createPackage")]))

  /// A URL-mode elicitation that asks the user to sign in in the browser.
  static let urlElicitation = CreateElicitationRequest(
    message: "Sign in to the package registry.",
    mode: .url(
      ElicitationUrlMode(
        elicitationId: ElicitationId(rawValue: "preview-sign-in"),
        url: "https://\(elicitationURLHost)/sign-in",
        scope: .session(elicitationScope))))

  /// A new preview session with ``formElicitation`` and ``urlElicitation``
  /// pending, in that order.
  static var elicitationSession: SessionModel {
    .preview(pendingElicitations: [formElicitation, urlElicitation])
  }

  /// The prompts that the composer suggests to the user.
  static let suggestions = ["Explain the error", "Run the tests again", "Show the diff"]

  /// The directory of the files of the sample project.
  static let projectDirectory = URL(filePath: "/Users/preview/project", directoryHint: .isDirectory)

  /// The size of the sample source file, in bytes.
  static let sourceFileSize = 4_096

  /// The size of the sample log file, in bytes.
  static let logFileSize = 18_432

  /// The files that a user attached to a prompt: a source file and a log.
  /// The files are not on disk, so a preview that reads a file shows its
  /// failure state.
  static let attachments = [
    attachment(path: "Sources/Parser.swift", type: .swiftSource, size: sourceFileSize),
    attachment(path: "build.log", type: .log, size: logFileSize),
  ]

  /// Makes the attachment of one file of the sample project.
  ///
  /// - Parameters:
  ///   - path: The path of the file below ``projectDirectory``.
  ///   - type: The uniform type of the file.
  ///   - size: The size of the file, in bytes.
  /// - Returns: The attachment. Its name is the last part of `path`.
  private static func attachment(path: String, type: UTType, size: Int) -> Attachment {
    let url = projectDirectory.appending(path: path)
    return Attachment(
      id: AttachmentID(url.absoluteString), url: url, type: type, name: url.lastPathComponent, size: size)
  }

  /// Each agent state that the state banner shows: an agent that runs, an
  /// agent that waits for the user, each idle stop reason of the ACP
  /// standard, and a state that the kit does not know.
  static let agentStates: [StateUpdate] = [
    .running(RunningStateUpdate()),
    .requiresAction(RequiresActionStateUpdate()),
    .idle(IdleStateUpdate()),
    .idle(IdleStateUpdate(stopReason: .endTurn)),
    .idle(IdleStateUpdate(stopReason: .cancelled)),
    .idle(IdleStateUpdate(stopReason: .maxTokens)),
    .idle(IdleStateUpdate(stopReason: .maxTurnRequests)),
    .idle(IdleStateUpdate(stopReason: .refusal)),
    .idle(IdleStateUpdate(stopReason: .error)),
    .unknown("paused", .object([:])),
  ]

  /// The message of the status bar for each of ``agentStates``, in order.
  ///
  /// The messages show each look of the bar: the symbol of a failure in the
  /// error color, the symbol of work that goes on with its live effect, and
  /// each other symbol in the secondary style.
  static var statusMessages: [StateBanner.Message] {
    agentStates.map(StateBanner.message(for:))
  }

  /// The message of the status bar for an idle state with the stop reason
  /// `error`: the failure that the Show Error button of the state banner
  /// goes with.
  static var failedTurnStatusMessage: StateBanner.Message {
    StateBanner.message(for: .idle(IdleStateUpdate(stopReason: .error)))
  }

  /// A status message whose title and explanation are longer than the
  /// texts of each of ``statusMessages``, so that the bar wraps them.
  static let longStatusMessage = StateBanner.Message(
    title: "The agent stopped because the package registry refused the credentials of the build service",
    explanation: """
      The agent reported this failure: the registry at packages.example.com answered 401 Unauthorized \
      for each of the three packages that the build needs. Sign in to the registry again, then send the \
      request again.
      """,
    symbolName: SharedSymbol.error,
    identifier: "preview-status-long")

  /// The width of a narrow column, in points. A status bar or a sign-in card
  /// in this column wraps its long texts, such as ``longStatusMessage`` and
  /// the name of ``longNameAuthMethod``.
  static let narrowWidth: CGFloat = 360

  /// The accessibility identifier of the button of ``statusAction(isEnabled:)``.
  static let statusActionIdentifier = "preview-status-action"

  /// Makes the button of a status bar: the Show Error button of the state
  /// banner. A press does nothing.
  ///
  /// - Parameter isEnabled: Whether the button takes a press.
  /// - Returns: The button.
  static func statusAction(isEnabled: Bool) -> StatusBar.Action {
    StatusBar.Action(
      title: "Show Error", systemImage: StateBanner.showErrorSymbol, identifier: statusActionIdentifier,
      isEnabled: isEnabled, perform: {})
  }

  /// The name of the agent of ``authConnection(methods:agentName:openSessions:)``.
  static let agentName = "preview-agent"

  /// A name of an agent that is longer than ``agentName``.
  static let longAgentName = "Northwind Traders Engineering Assistant for the Continuous Integration Service"

  /// The version of the agent of ``authConnection(methods:agentName:openSessions:)``.
  static let agentVersion = "1.0.0"

  /// A sign-in method that the agent runs through `auth/login`.
  static let agentAuthMethod = AuthMethod.agent(
    AuthMethodAgent(
      methodId: AuthMethodId(rawValue: "github"), name: "GitHub",
      description: "Sign in with your GitHub account."))

  /// A sign-in method that the client runs as a separate process in a
  /// terminal.
  static let terminalAuthMethod = AuthMethod.terminal(
    AuthMethodTerminal(
      methodId: AuthMethodId(rawValue: "terminal"), name: "Terminal", args: ["--login"],
      description: "Sign in with the agent program in a terminal."))

  /// A sign-in method of the agent whose name is longer than the names of
  /// ``agentAuthMethod`` and ``terminalAuthMethod``.
  static let longNameAuthMethod = AuthMethod.agent(
    AuthMethodAgent(
      methodId: AuthMethodId(rawValue: "enterprise-sso"),
      name: "Northwind Traders single sign-on for the engineering organization",
      description: "Sign in with the account of your organization."))

  /// Makes a connection whose agent requires a sign-in.
  ///
  /// The connection has the `initialize` answer of an agent that lists
  /// `methods`, and its auth state asks for a sign-in with them.
  ///
  /// - Parameters:
  ///   - methods: The auth methods of the agent.
  ///   - agentName: The name of the agent in its `initialize` answer.
  ///   - openSessions: The models of the open sessions of the connection.
  /// - Returns: The preview connection model.
  static func authConnection(
    methods: [AuthMethod], agentName: String = Self.agentName, openSessions: [SessionModel] = []
  ) -> ConnectionModel {
    .preview(
      openSessions: openSessions,
      authState: .required(methods),
      initializeResponse: InitializeResponse(
        info: Implementation(name: agentName, version: agentVersion),
        protocolVersion: ACPClient.supportedProtocolVersion, authMethods: methods))
  }

  /// The exit status of a terminal sign-in that succeeded.
  nonisolated static let successfulExitStatus: Int32 = 0

  /// A terminal auth runner that starts no process. Each run ends at once
  /// with ``successfulExitStatus``, so that a preview shows the Run button
  /// of a terminal method and runs no agent program.
  nonisolated struct TerminalAuthRunnerStub: TerminalAuthRunner {
    /// Ends the run at once, and starts no process.
    ///
    /// - Parameters:
    ///   - arguments: The arguments to append to the agent command. The stub
    ///     does not read them.
    ///   - environment: The variables of the run. The stub does not read
    ///     them.
    /// - Returns: ``PreviewFixtures/successfulExitStatus``.
    func runTerminalAuth(arguments: [String], environment: [String: String]) async throws -> Int32? {
      PreviewFixtures.successfulExitStatus
    }
  }

  /// The terminal auth runner of the previews.
  static let terminalAuthRunner = TerminalAuthRunnerStub()

  /// The number of turns of ``scrolledSession``.
  static let scrolledTurnCount = 12

  /// A new preview session with a transcript that is longer than a window,
  /// so that the list scrolls under the bars of a thread. Each turn is a
  /// user message and an agent message.
  static var scrolledSession: SessionModel {
    .preview(
      transcript: (1...scrolledTurnCount).flatMap { turn -> [PreviewTranscriptItem] in
        [
          .user("What does step \(turn) of the build do?"),
          .agent("Step \(turn) compiles one module of the package and links it into the test bundle."),
        ]
      })
  }

  /// A Markdown text with each kind of formatting that a response shows:
  /// headings, a list, a numbered list, a table, inline code, and links.
  static let formattedMarkdown = """
    # Parse the package manifest

    ## What changed

    The parser now reads `Package.swift` with `SwiftParser`, and it keeps the targets in the order of the file.

    - Each target keeps its name and its path.
    - A target with no path gets the path `Sources/<name>`.
    - Each dependency of a target names a product.

    1. Run `swift package describe --type json`.
    2. Compare its targets with the targets of the parser.
    3. Report each target that is different.

    | Target | Kind | Files |
    | --- | --- | --- |
    | AgentViewKit | library | 212 |
    | AgentViewKitTests | test | 148 |

    Read [the manifest reference](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html) \
    and [the Swift Package Manager guide](https://www.swift.org/documentation/package-manager/).
    """

  /// A quote that cites its source, with a link to it. A text block shows no
  /// citation pill, so this is how its Markdown cites a source.
  static let citedQuote = """
    > \(citedFirstSentence)
    >
    > — [Swift Concurrency](\(concurrencySourceURL.absoluteString))
    """

  /// The number of sentences of ``longParagraph``.
  static let longParagraphSentenceCount = 12

  /// A paragraph that is longer than a window is wide, so that it wraps over
  /// many lines.
  static let longParagraph = (1...longParagraphSentenceCount)
    .map { step in
      "Step \(step) of the build compiles one module of the package, links it into the test bundle, "
        + "and records how long the compiler took for each file of the module."
    }
    .joined(separator: " ")

  /// The citation pills of ``citedResponse``: one at the end of each
  /// sentence, from the markers of ``citations``.
  static var citationPlacements: [CitationPlacement] {
    citations.placementsByParagraph()[0] ?? []
  }

  /// The text of ``textResource``: the last lines of a build log.
  static let buildLogText = """
    Compiling AgentViewKit Parser.swift
    Compiling AgentViewKit Lexer.swift
    Build complete! (12.48s)
    """

  /// A resource with text contents: a build log of the sample project.
  static let textResource = embeddedResource(
    path: "build.log", mimeType: "text/plain", member: "text", value: buildLogText)

  /// The size of the contents of ``binaryResource``, in bytes.
  static let binaryResourceSize = 24_576

  /// A resource with binary contents: an archive of the sample project. Its
  /// bytes are zeros.
  static let binaryResource = embeddedResource(
    path: "Archives/Release.zip", mimeType: "application/zip", member: "blob",
    value: Data(count: binaryResourceSize).base64EncodedString())

  /// A resource with text contents whose URI is longer than the URIs of
  /// ``textResource`` and ``binaryResource``.
  static let longURIResource = embeddedResource(
    path: "Packages/NorthwindTraders/ContinuousIntegration/BuildService/Configuration/"
      + "RegistryCredentials/registry-credentials-for-the-package-registry-of-the-build-service.log",
    mimeType: "text/plain", member: "text", value: buildLogText)

  /// Makes an embedded resource of one file of the sample project.
  ///
  /// - Parameters:
  ///   - path: The path of the file below ``projectDirectory``.
  ///   - mimeType: The MIME type of the file.
  ///   - member: The member of the contents: `text` or `blob`.
  ///   - value: The text, or the base64 bytes of the blob.
  /// - Returns: The resource, as the raw JSON of an ACP embedded resource.
  private static func embeddedResource(
    path: String, mimeType: String, member: String, value: String
  ) -> FoundationModelsACP.EmbeddedResource {
    FoundationModelsACP.EmbeddedResource(
      resource: .object([
        "uri": .string(projectDirectory.appending(path: path).absoluteString),
        "mimeType": .string(mimeType),
        member: .string(value),
      ]))
  }

  /// A patch that changes one line of one file.
  static let smallPatch = """
    --- a/Sources/Parser.swift
    +++ b/Sources/Parser.swift
    @@ -1,3 +1,3 @@
     struct Parser {
    -  let source: String
    +  let source: Substring
     }
    """

  /// The number of steps that ``largePatch`` changes.
  static let largePatchStepCount = 120

  /// A patch that changes a line for each of ``largePatchStepCount`` steps,
  /// so that the diff is longer than a window.
  static var largePatch: String {
    let opening = " struct BuildPlan {"
    let closing = " }"
    let changes = (1...largePatchStepCount).flatMap { step in
      [
        "-  let step\(step) = Step(index: \(step), isCached: false)",
        "+  let step\(step) = Step(index: \(step), isCached: true)",
      ]
    }
    let lineCount = largePatchStepCount + [opening, closing].count
    let header = [
      "--- a/Sources/BuildPlan.swift", "+++ b/Sources/BuildPlan.swift", "@@ -1,\(lineCount) +1,\(lineCount) @@",
    ]
    return (header + [opening] + changes + [closing]).joined(separator: "\n")
  }

  /// A patch that adds a new file, so that it only adds lines.
  static let addedOnlyPatch = """
    --- /dev/null
    +++ b/Sources/Lexer.swift
    @@ -0,0 +1,3 @@
    +struct Lexer {
    +  let source: String
    +}
    """

  /// A patch that deletes a file, so that it only removes lines.
  static let removedOnlyPatch = """
    --- a/Sources/LegacyParser.swift
    +++ /dev/null
    @@ -1,3 +0,0 @@
    -struct LegacyParser {
    -  let source: String
    -}
    """

  /// The number of rows of the output of ``cappedOutputRows`` that do not
  /// show.
  static let hiddenOutputRowCount = 48

  /// The rows of an output that has more rows than the row limit, so that
  /// the cap row shows.
  static var cappedOutputRows: CommandOutputView.VisibleRows {
    let rowLimit = CommandOutputView.defaultRowLimit
    let output = (1...(rowLimit + hiddenOutputRowCount))
      .map { row in "Compiling module \(row) of the package" }
      .joined(separator: "\n")
    return CommandOutputView.VisibleRows(output: output, limit: rowLimit)
  }

  /// The exit code of a command that failed.
  static let failingExitCode = 1

  /// The name of the signal that stopped a command.
  static let stopSignal = "SIGTERM"

  /// Each exit that the exit label shows: a command that succeeded, a
  /// command that failed with an exit code, and a command that a signal
  /// stopped.
  static let exitSummaries: [TerminalView.ExitSummary] = [
    .code(CommandOutputView.successExitCode), .code(failingExitCode), .signal(stopSignal),
  ]

  /// Makes the context of one field of a form whose answers are in one
  /// dictionary.
  ///
  /// - Parameters:
  ///   - schema: The field schema.
  ///   - answers: The answers of the form, keyed by the name of the field.
  /// - Returns: A context whose value reads and writes the answer of
  ///   `schema.name`.
  static func fieldContext(
    _ schema: ElicitationFieldSchema, answers: Binding<[String: JSONValue]>
  ) -> ElicitationFieldContext {
    ElicitationFieldContext(schema: schema, value: answers[schema.name])
  }

  /// The fields of a sample elicitation form: one field of each kind.
  enum ElicitationFields {
    /// A required text field.
    static let text = ElicitationFieldSchema(
      name: "name", title: "Name", description: "The name of the new package.", required: true,
      kind: .text(minLength: 1, maxLength: nil, pattern: nil, format: nil), defaultValue: nil)

    /// The largest value of the ``number`` field.
    static let maximumRetries: Double = 5

    /// An integer field with a range.
    static let number = ElicitationFieldSchema(
      name: "retries", title: "Retries", description: "How many times to run a failed test again.",
      required: false, kind: .number(integer: true, minimum: 0, maximum: maximumRetries),
      defaultValue: .number(1))

    /// A Boolean field.
    static let boolean = ElicitationFieldSchema(
      name: "verbose", title: "Verbose output", description: nil, required: false, kind: .boolean,
      defaultValue: .bool(false))

    /// A date field.
    static let date = ElicitationFieldSchema(
      name: "due", title: "Due date", description: "The last day for the release.", required: false,
      kind: .date(dateTime: false), defaultValue: nil)

    /// A field with one choice from a list.
    static let singleChoice = ElicitationFieldSchema(
      name: "platform", title: "Platform", description: nil, required: true,
      kind: .singleChoice([
        ElicitationFieldSchema.Choice(const: "macos", title: "macOS"),
        ElicitationFieldSchema.Choice(const: "ios", title: "iOS"),
      ]),
      defaultValue: nil)

    /// A field with a set of choices from a list.
    static let multiChoice = ElicitationFieldSchema(
      name: "checks", title: "Checks", description: "The checks to run before the release.",
      required: false,
      kind: .multiChoice(
        [
          ElicitationFieldSchema.Choice(const: "lint", title: "Lint"),
          ElicitationFieldSchema.Choice(const: "test", title: "Test"),
          ElicitationFieldSchema.Choice(const: "docs", title: "Docs"),
        ], minItems: 1, maxItems: nil),
      defaultValue: nil)

    /// Each field of the form, in form order.
    static let all = [text, number, boolean, date, singleChoice, multiChoice]
  }
}
