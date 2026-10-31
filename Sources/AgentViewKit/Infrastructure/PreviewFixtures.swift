import AVFoundation
import AppKit
import EditorStyle
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

  /// The agent path and the source of the "who asks" line of an elicitation
  /// card: the sub-agent that asks, and the tool inside it.
  struct WhoAsks {
    /// The names of the agents between the root agent and the agent that
    /// asks, outermost first.
    let agentPath: [String]

    /// The tool that asks inside the agent.
    let source: String

    /// Short names: one sub-agent and a short tool name.
    static let short = WhoAsks(agentPath: ["planner"], source: "createPackage")

    /// Names that are longer than a narrow column: ``longAgentName`` and a
    /// long tool name, so that the line truncates in the middle.
    static let long = WhoAsks(
      agentPath: [longAgentName], source: "createPackageWithTheRegistryCredentialsOfTheContinuousIntegrationService")

    /// The `_meta` of an elicitation that this agent path and this source
    /// ask.
    var meta: JSONValue {
      .object(["agentPath": .array(agentPath.map(JSONValue.string)), "source": .string(source)])
    }
  }

  /// The `Name` property of the sample forms: a text of at least one
  /// character.
  private static let nameProperty: [String: JSONValue] = [
    "type": .string("string"), "title": .string("Name"), "minLength": .number(1),
  ]

  /// The `Retries` property of the sample forms: an integer from zero to
  /// ``ElicitationFields/maximumRetries``.
  private static let retriesProperty: [String: JSONValue] = [
    "type": .string("integer"), "title": .string("Retries"), "minimum": .number(0),
    "maximum": .number(ElicitationFields.maximumRetries),
  ]

  /// The properties of ``formElicitation``: a text, an integer and a Boolean.
  private static let packageProperties: [String: JSONValue] = [
    "name": .object(nameProperty),
    "retries": .object(retriesProperty),
    "verbose": .object(["type": .string("boolean"), "title": .string("Verbose output")]),
  ]

  /// Makes a form-mode elicitation of the default preview session that
  /// ``WhoAsks/short`` asks, so that the card shows the "who asks" line.
  ///
  /// - Parameters:
  ///   - message: The message of the request.
  ///   - properties: The property schemas of the form, by property name.
  ///   - required: The names of the properties that need an answer.
  /// - Returns: The request.
  private static func formRequest(
    message: String, properties: [String: JSONValue], required: [String]
  ) -> CreateElicitationRequest {
    CreateElicitationRequest(
      message: message,
      mode: .form(
        ElicitationFormMode(
          requestedSchema: ElicitationSchema(properties: .object(properties), required: required),
          scope: .session(elicitationScope))),
      meta: WhoAsks.short.meta)
  }

  /// A form-mode elicitation with three fields. A sub-agent asks it through a
  /// tool, so the card shows the "who asks" line.
  static let formElicitation = formRequest(
    message: "Give the details of the new package.", properties: packageProperties, required: ["name"])

  /// A form-mode elicitation with one field of each kind of
  /// ``ElicitationFields``: a text, an integer, a Boolean, a date, a single
  /// choice and a multiple choice.
  static let eachKindFormElicitation = formRequest(
    message: "Plan the release of the new package.",
    properties: merged(
      packageProperties,
      with: [
        ElicitationFields.dueDate.name: .object([
          "type": .string("string"), "title": .string(ElicitationFields.dueDate.title), "format": .string("date"),
        ]),
        ElicitationFields.platform.name: .object([
          "type": .string("string"), "title": .string(ElicitationFields.platform.title),
          "oneOf": choiceList(ElicitationFields.platformChoices),
        ]),
        ElicitationFields.checks.name: .object([
          "type": .string("array"), "title": .string(ElicitationFields.checks.title), "minItems": .number(1),
          "items": .object(["anyOf": choiceList(ElicitationFields.checkChoices)]),
        ]),
      ]),
    required: ["name", ElicitationFields.platform.name])

  /// Makes the JSON list of the titled choices of a property.
  ///
  /// - Parameter choices: The choices, in order.
  /// - Returns: A list of `{const, title}` objects.
  private static func choiceList(_ choices: [ElicitationFieldSchema.Choice]) -> JSONValue {
    .array(choices.map { .object(["const": .string($0.const), "title": .string($0.title)]) })
  }

  /// Adds members to the members of a JSON object.
  ///
  /// - Parameters:
  ///   - members: The members of the object.
  ///   - added: The members to add. An added member replaces a member of
  ///     `members` with the same name.
  /// - Returns: The members of both, by name.
  private static func merged(_ members: [String: JSONValue], with added: [String: JSONValue]) -> [String: JSONValue] {
    members.merging(added) { _, addedValue in addedValue }
  }

  /// The default name of ``invalidFieldElicitation``, which passes each
  /// constraint of its field.
  static let validPackageName = "swift-parser"

  /// The default number of retries of ``invalidFieldElicitation``: more than
  /// ``ElicitationFields/maximumRetries``.
  static let retriesAboveMaximum: Double = 9

  /// A form-mode elicitation whose `Retries` default is above its maximum, so
  /// that a field is not valid before the user types. The card keeps Submit
  /// disabled, and shows the error of the field as soon as it appears, so the
  /// user sees why Submit is disabled. The required `Name` field has a valid
  /// default.
  static let invalidFieldElicitation = formRequest(
    message: "Check the details of the new package.",
    properties: [
      "name": .object(merged(nameProperty, with: ["default": .string(validPackageName)])),
      "retries": .object(merged(retriesProperty, with: ["default": .number(retriesAboveMaximum)])),
    ],
    required: ["name"])

  /// Makes a new preview session with one pending elicitation, for the card
  /// of the elicitation. The session records the answer of the card and
  /// sends nothing.
  ///
  /// - Parameters:
  ///   - request: The pending elicitation.
  ///   - transcript: The transcript items of the session, in order.
  /// - Returns: The preview session.
  static func elicitationCardSession(
    asking request: CreateElicitationRequest, transcript: [PreviewTranscriptItem] = []
  ) -> SessionModel {
    .preview(transcript: transcript, pendingElicitations: [request])
  }

  /// The reason that the agent gave for each withdrawn request of the
  /// previews.
  static let withdrawalReason = "The agent read the details from the package manifest."

  /// A title of a request that is longer than the message of
  /// ``formElicitation``, so that the notice of its withdrawal wraps.
  static let longWithdrawnTitle = """
    Give the name, the version, the platforms, the products and the dependencies of each package \
    that the continuous integration service of Northwind Traders builds for the release
    """

  /// The notice of the withdrawal of ``formElicitation``, with
  /// ``withdrawalReason``.
  static let withdrawnNotice = WithdrawnNotice(
    id: UUID(), text: RequestDeck.withdrawnText(title: formElicitation.message, reason: withdrawalReason))

  /// The notice of the withdrawal of a request with ``longWithdrawnTitle``,
  /// with ``withdrawalReason``.
  static let longTitleWithdrawnNotice = WithdrawnNotice(
    id: UUID(), text: RequestDeck.withdrawnText(title: longWithdrawnTitle, reason: withdrawalReason))

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

  /// A Swift source file of the sample project. No file is at its URL, and
  /// ``attachmentPreviewLoader`` holds no text for it, so each preview of it
  /// shows a file that is missing.
  static let sourceFileAttachment = attachment(
    path: "Sources/Checkout/CartView.swift", type: .swiftSource, size: sourceFileSize)

  /// The build log of the sample project. No file is at its URL.
  /// ``attachmentPreviewLoader`` holds ``buildLogText`` as its text.
  static let logFileAttachment = attachment(path: "build.log", type: .log, size: logFileSize)

  /// The files that a user attached to a prompt: a source file and a log.
  /// The files are not on disk, so a preview that reads a file from disk
  /// shows its failure state.
  static let attachments = [sourceFileAttachment, logFileAttachment]

  /// Makes the attachment of one file of the sample project.
  ///
  /// - Parameters:
  ///   - path: The path of the file below ``projectDirectory``.
  ///   - type: The uniform type of the file.
  ///   - size: The size of the file, in bytes.
  ///   - url: The location of the bytes of the file, or `nil` for the path of
  ///     the file in the sample project.
  /// - Returns: The attachment. Its name is the last part of `path`, and its
  ///   identifier is the URL of the path in the sample project.
  private static func attachment(path: String, type: UTType, size: Int, url: URL? = nil) -> Attachment {
    let projectURL = projectDirectory.appending(path: path)
    return Attachment(
      id: AttachmentID(projectURL.absoluteString), url: url ?? projectURL, type: type,
      name: projectURL.lastPathComponent, size: size)
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
  static var statusMessages: [StatusBar.Message] {
    agentStates.map(StateBanner.message(for:))
  }

  /// The message of the status bar for an idle state with the stop reason
  /// `error`: the failure that the Show Error button of the state banner
  /// goes with.
  static var failedTurnStatusMessage: StatusBar.Message {
    StateBanner.message(for: .idle(IdleStateUpdate(stopReason: .error)))
  }

  /// A failure message whose title and explanation are longer than the
  /// texts of each of ``statusMessages``, so that the bar wraps them.
  static let longStatusMessage = StatusBar.Message(
    title: "The agent stopped because the package registry refused the credentials of the build service",
    explanation: """
      The agent reported this failure: the registry at packages.example.com answered 401 Unauthorized \
      for each of the three packages that the build needs. Sign in to the registry again, then send the \
      request again.
      """,
    symbolName: SharedSymbol.error,
    identifier: "preview-status-long", severity: .failure)

  /// A failure message with a short title and the long explanation of
  /// ``longStatusMessage``, so that the explanation wraps below the title line.
  static let longExplanationStatusMessage = StatusBar.Message(
    title: "The agent stopped", explanation: longStatusMessage.explanation, symbolName: SharedSymbol.error,
    identifier: "preview-status-long-explanation", severity: .failure)

  /// A message with a title and no explanation.
  static let titleOnlyStatusMessage = StatusBar.Message(
    title: "The agent stopped", explanation: "", symbolName: SharedSymbol.error,
    identifier: "preview-status-title-only", severity: .failure)

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

  /// A wire value that the kit does not know, as a later version of ACP can
  /// send it for a status, a priority or a severity.
  static let unknownWireValue = "deferred"

  /// Each status of a tool call that ``ToolStatusImage`` shows: each status
  /// of the ACP standard, the lost status
  /// (``ToolStatusSymbol/lostWireValue``) and a status that the kit does not
  /// know.
  static let toolCallStatuses: [FoundationModelsACP.ToolCallStatus] = [
    .pending, .inProgress, .completed, .failed, .cancelled, .unknown(ToolStatusSymbol.lostWireValue),
    .unknown(unknownWireValue),
  ]

  /// Each status of a plan entry: each status of the ACP standard and a
  /// status that the kit does not know.
  static let planEntryStatuses: [FoundationModelsACP.PlanEntryStatus] = [
    .pending, .inProgress, .completed, .cancelled, .unknown(unknownWireValue),
  ]

  /// Each priority of a plan entry: each priority of the ACP standard and a
  /// priority that the kit does not know.
  static let planEntryPriorities: [FoundationModelsACP.PlanEntryPriority] = [
    .high, .medium, .low, .unknown(unknownWireValue),
  ]

  /// Each severity of a session notice: each severity of the ACP standard
  /// and a severity that the kit does not know.
  static let noticeSeverities: [NoticeSeverity] = [.info, .warning, .error, .unknown(unknownWireValue)]

  /// The status symbols of the kit (``SharedSymbol``), for the preview of
  /// ``PreviewSymbolSheet``. Each row of that sheet shows the symbol and its
  /// name.
  static let statusSymbolNames = [
    ItemStatus.pending.systemImage, ItemStatus.inProgress.systemImage, ItemStatus.completed.systemImage, SharedSymbol.error,
    ItemStatus.cancelled.systemImage, ItemStatus.unknown.systemImage, SharedSymbol.warning, SharedSymbol.information,
  ]

  /// A decorative symbol of the kit, with the header that shows it.
  struct HeaderSymbol: Hashable {
    /// The name of the header that shows the symbol.
    let header: String

    /// The SF Symbol name.
    let name: String
  }

  /// Each decorative symbol that ``DecorativeSymbolImage`` shows: the symbol
  /// of ``AgentInfoHeader`` and the symbol of the standard
  /// ``ConversationEmptyState``.
  static let headerSymbols = [
    HeaderSymbol(header: "Agent header", name: AgentInfoHeader.symbol),
    HeaderSymbol(header: "Empty conversation", name: SharedSymbol.conversation),
  ]

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

  /// A transcript that is longer than a window, so that the list scrolls
  /// under the bars of a thread. Each of the ``scrolledTurnCount`` turns is a
  /// user message and an agent message.
  static let scrolledTranscript = (1...scrolledTurnCount).flatMap { turn -> [PreviewTranscriptItem] in
    [
      .user("What does step \(turn) of the build do?"),
      .agent("Step \(turn) compiles one module of the package and links it into the test bundle."),
    ]
  }

  /// A new preview session with ``scrolledTranscript``.
  static var scrolledSession: SessionModel {
    .preview(transcript: scrolledTranscript)
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
    and [the Swift Package Manager guide](\(packageManagerGuideURL)).
    """

  /// The web address of the guide of the Swift Package Manager.
  static let packageManagerGuideURL = "https://www.swift.org/documentation/package-manager/"

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
    Compiling Checkout CartView.swift
    Compiling Checkout PriceFormatter.swift
    Build complete! (12.48s)
    """

  /// A resource with text contents: a build log of the sample project.
  static let textResource = embeddedResource(
    path: "build.log", mimeType: "text/plain", member: "text", value: buildLogText)

  /// The size of the contents of ``binaryResource``, in bytes.
  static let binaryResourceSize = 24_576

  /// The path of the release archive of the sample project, below
  /// ``projectDirectory``.
  static let archivePath = "Archives/Release.zip"

  /// A resource with binary contents: an archive of the sample project. Its
  /// bytes are zeros.
  static let binaryResource = embeddedResource(
    path: archivePath, mimeType: "application/zip", member: "blob",
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

  /// A patch that changes one line of one file: it renames the search
  /// function of a search index.
  static let smallPatch = """
    --- a/Sources/Search/SearchIndex.swift
    +++ b/Sources/Search/SearchIndex.swift
    @@ -1,3 +1,3 @@
     struct SearchIndex {
    -  func find(_ query: String) -> [Document] { documents.filter { $0.title.contains(query) } }
    +  func matches(for query: String) -> [Document] { documents.filter { $0.title.contains(query) } }
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

  /// A patch that adds a new file, so that it only adds lines: a test of the
  /// function that ``smallPatch`` renames.
  static let addedOnlyPatch = """
    --- /dev/null
    +++ b/Tests/SearchTests/SearchIndexTests.swift
    @@ -0,0 +1,3 @@
    +@Test func aQueryMatchesEachTitleThatContainsIt() {
    +  #expect(SearchIndex.sample.matches(for: "tax").count == 2)
    +}
    """

  /// A patch that deletes a file, so that it only removes lines: the old
  /// search that ``smallPatch`` makes unused.
  static let removedOnlyPatch = """
    --- a/Sources/Search/LegacySearch.swift
    +++ /dev/null
    @@ -1,3 +0,0 @@
    -enum LegacySearch {
    -  static func find(_ query: String, in titles: [String]) -> [String] { titles.filter { $0.contains(query) } }
    -}
    """

  /// The number of rows of the output of ``cappedOutputRows`` that do not
  /// show.
  static let hiddenOutputRowCount = 48

  /// The rows of an output that has more rows than the row limit, so that
  /// the cap row shows.
  static var cappedOutputRows: CommandOutputView.VisibleRows {
    let rowLimit = CommandOutputView.defaultRowLimit
    return CommandOutputView.VisibleRows(
      output: buildOutput(lineCount: rowLimit + hiddenOutputRowCount), limit: rowLimit)
  }

  /// Makes the output of a build: one line for each module that the build
  /// compiles.
  ///
  /// - Parameter lineCount: The number of lines.
  /// - Returns: The lines, joined by line feeds.
  static func buildOutput(lineCount: Int) -> String {
    (1...lineCount)
      .map { row in "Compiling module \(row) of the package" }
      .joined(separator: "\n")
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

  /// The command of ``lintOutput``: the lint check of a web project. It
  /// ends with ``failingExitCode``.
  static let lintCommand = "npm run lint"

  /// The output of ``lintCommand``: one problem in one file, and the count of
  /// the problems. It is shorter than the row limit of the output view.
  static let lintOutput = """
    src/components/SearchBox.tsx
      14:7  error  'query' is assigned a value but never used  no-unused-vars

    ✖ 1 problem (1 error, 0 warnings)
    """

  /// The language of ``codeSample``: a language of the grammar bundle.
  static let codeSampleLanguage = "python"

  /// The name of the file of ``codeSample``. Its extension also names
  /// ``codeSampleLanguage``.
  static let codeSampleFilename = "tax.py"

  /// A short Python function that adds the tax to the sum of some prices,
  /// and a call of it.
  static let codeSample = """
    def total_with_tax(prices, rate=0.08):
        return round(sum(prices) * (1 + rate), 2)

    print(total_with_tax([9.99, 4.50]))
    """

  /// The plan of a release: a step that is done, a step in progress and a
  /// step to do, from the highest priority to the lowest.
  static let releasePlan = [
    PlanEntry(content: "Set the version number to 2.4.0", priority: .high, status: .completed),
    PlanEntry(content: "Write the release notes", priority: .medium, status: .inProgress),
    PlanEntry(content: "Tag the release and push the tag", priority: .low, status: .pending),
  ]

  // MARK: - Transcript items

  /// The question of ``MessageSample/user``.
  static let userQuestion = "Can you add a dark mode setting to the preferences window?"

  /// The answer of ``MessageSample/agent``: a plan for the feature of
  /// ``userQuestion``, with inline code.
  static let agentAnswer = """
    I will add a **Theme** picker to the General tab of the preferences, and save the choice in `UserDefaults`.
    """

  /// The chunks of ``MessageSample/streaming`` that the agent sent so far.
  /// The last chunk stops in the middle of a word.
  static let streamedAnswerChunks = [
    "I will add a Theme picker ", "to the General tab, and save ", "the choice in the user def",
  ]

  /// The error of the compiler that ``failureReport`` shows.
  static let buildError =
    "Sources/Preferences/ThemePicker.swift:27:9: error: missing argument for parameter 'store' in call"

  /// The answer of ``MessageSample/failure``: a build that failed, with the
  /// error of the compiler in a code block.
  static let failureReport = """
    The debug build failed with this error:

    ```
    \(buildError)
    ```

    `ThemePicker` now needs a store for the choice, and the preview of the window does not give one.
    """

  /// The answer of ``MessageSample/long``: each kind of formatting, then a
  /// paragraph that is longer than a window is wide.
  static let longAnswer = [formattedMarkdown, longParagraph].joined(separator: "\n\n")

  /// The text of ``ThoughtSample/complete``: a thought about a test that
  /// fails only at some hours.
  static let completeThought = """
    The invoice date test fails only after 17:00. It formats the date in UTC, but the expected text uses the local \
    time zone.
    """

  /// The chunks of ``ThoughtSample/streaming`` that the agent sent so far.
  /// The last chunk stops in the middle of a word.
  static let streamedThoughtChunks = [
    "The invoice date test fails ", "only after 17:00. It formats the date in UTC, ",
    "but the expected text uses the lo",
  ]

  /// The id of the message of the chunks of a sample that streams.
  static let streamedMessageID = MessageId(rawValue: "preview-streamed")

  /// Makes the items of one message that streams: one chunk update for each
  /// chunk, each with ``streamedMessageID``, so the merge engine folds them
  /// into one entry with a block for each chunk.
  ///
  /// - Parameters:
  ///   - chunks: The text of each chunk, in order.
  ///   - update: The session update of a chunk, such as
  ///     `SessionUpdate.agentMessageChunk`.
  /// - Returns: The transcript items.
  private static func streamedItems(
    _ chunks: [String], as update: (ContentChunk) -> SessionUpdate
  ) -> [PreviewTranscriptItem] {
    chunks.map { .update(update(ContentChunk(content: .text(TextContent(text: $0)), messageId: streamedMessageID))) }
  }

  /// A message of the transcript, in each state that the message previews
  /// show.
  enum MessageSample: CaseIterable {
    /// A question of the user.
    case user

    /// An answer of the agent.
    case agent

    /// An answer of the agent that still streams: the chunks so far.
    case streaming

    /// An answer of the agent that reports a failed build.
    case failure

    /// An answer of the agent that is longer than a window.
    case long

    /// The transcript items of the message.
    var transcript: [PreviewTranscriptItem] {
      switch self {
      case .user: [.user(userQuestion)]
      case .agent: [.agent(agentAnswer)]
      case .streaming: streamedItems(streamedAnswerChunks, as: SessionUpdate.agentMessageChunk)
      case .failure: [.agent(failureReport)]
      case .long: [.agent(longAnswer)]
      }
    }

    /// A new preview session with ``transcript``.
    var session: SessionModel {
      .preview(transcript: transcript)
    }

    /// The message entry of a new ``session``, or `nil` when the session has
    /// no user message and no agent message.
    var entry: MessageEntry? {
      let session = session
      return firstEntry(in: session, as: UserMessageEntry.self).map(MessageEntry.user)
        ?? firstEntry(in: session, as: AgentMessageEntry.self).map(MessageEntry.agent)
    }
  }

  /// A thought of the agent, in each state that the reasoning previews show.
  enum ThoughtSample: CaseIterable {
    /// A thought that the agent ended.
    case complete

    /// A thought that still streams: the chunks so far.
    case streaming

    /// The transcript items of the thought.
    var transcript: [PreviewTranscriptItem] {
      switch self {
      case .complete: [.thought(completeThought)]
      case .streaming: streamedItems(streamedThoughtChunks, as: SessionUpdate.agentThoughtChunk)
      }
    }

    /// A new preview session with ``transcript``.
    var session: SessionModel {
      .preview(transcript: transcript)
    }

    /// The thought entry of a new ``session``, or `nil` when the session has
    /// no thought.
    var entry: ThoughtEntry? {
      firstEntry(in: session, as: ThoughtEntry.self)
    }
  }

  /// The MIME type of the sound of ``contentOfEachKind``.
  private static let waveMIMEType = "audio/wav"

  /// The kind of the unknown block of ``contentOfEachKind``: a type that the
  /// ACP revision of the kit does not know.
  static let reviewSummaryKind = "review_summary"

  /// The content of an entry with a block of each kind that the kit shows, in
  /// the order of ``FoundationModelsACP/ContentBlock/Kind``: a text, an image,
  /// a sound, a resource link, a text resource and a binary resource, and a
  /// block of a kind that the kit does not know. The bytes of the image and of
  /// the sound are in the blocks, so the blocks read no file.
  static let contentOfEachKind: [FoundationModelsACP.ContentBlock] = [
    .text(TextContent(text: citedResponse)),
    .image(ImageContent(data: wideImageData.base64EncodedString(), mimeType: MediaType(rawValue: bitmapMIMEType))),
    .audio(AudioContent(data: audioData.base64EncodedString(), mimeType: MediaType(rawValue: waveMIMEType))),
    .resourceLink(ResourceLink(name: sourceFileAttachment.name, uri: sourceFileAttachment.url.absoluteString)),
    .resource(textResource),
    .resource(binaryResource),
    .unknown(reviewSummaryKind, smallJSON),
  ]

  /// The number of findings of the review of ``smallJSON``.
  static let reviewFindingCount = 2

  /// The members of ``smallJSON``: the summary of a review of
  /// ``sourceFileAttachment``.
  private static let reviewSummaryMembers: [String: JSONValue] = [
    "title": .string("Review of \(sourceFileAttachment.name)"),
    "status": .string("complete"),
    "findingCount": .number(Double(reviewFindingCount)),
  ]

  /// A JSON object of one level with short values: the summary of a review.
  static let smallJSON = JSONValue.object(reviewSummaryMembers)

  /// A session update of ``reviewSummaryKind``, a kind that the ACP revision
  /// of the kit does not know: the members of ``smallJSON``, and the
  /// `sessionUpdate` member that names the kind.
  static let reviewSummaryUpdate = JSONValue.object(
    merged(reviewSummaryMembers, with: ["sessionUpdate": .string(reviewSummaryKind)]))

  /// The line of the finding of ``deepJSON``.
  static let reviewFindingLine = 12

  /// A JSON object of several levels: a review, with its files, their
  /// findings, and the comment of each finding. The comment is
  /// ``longParagraph``, a value that is longer than a window is wide.
  static let deepJSON = JSONValue.object([
    "review": .object([
      "title": .string("Review of the checkout"),
      "files": .array([
        .object([
          "path": .string(sourceFileAttachment.url.absoluteString),
          "findings": .array([
            .object([
              "line": .number(Double(reviewFindingLine)),
              "comment": .string(longParagraph),
            ])
          ]),
        ])
      ]),
    ])
  ])

  // MARK: - Attachment previews

  /// The long side of ``wideImageAttachment``, in pixels: its width.
  static let wideImageLongSide = 480

  /// The short side of ``wideImageAttachment`` and of
  /// ``tallImageAttachment``, in pixels.
  static let imageShortSide = 120

  /// The long side of ``tallImageAttachment``, in pixels: its height.
  static let tallImageLongSide = 360

  /// The side of the square ``smallImageAttachment``, in pixels: smaller than
  /// each side of the other two images.
  static let smallImageSide = 12

  /// The pixel size of ``wideImageAttachment``.
  static let wideImageSize = CGSize(width: wideImageLongSide, height: imageShortSide)

  /// The pixel size of ``tallImageAttachment``.
  static let tallImageSize = CGSize(width: imageShortSide, height: tallImageLongSide)

  /// The pixel size of ``smallImageAttachment``.
  static let smallImageSize = CGSize(width: smallImageSide, height: smallImageSide)

  /// The bytes of ``wideImageAttachment``.
  private static let wideImageData = BitmapFile.data(size: wideImageSize)

  /// The bytes of ``tallImageAttachment``.
  private static let tallImageData = BitmapFile.data(size: tallImageSize)

  /// The bytes of ``smallImageAttachment``.
  private static let smallImageData = BitmapFile.data(size: smallImageSize)

  /// An image that is wider than it is tall: a banner of the sample project.
  static let wideImageAttachment = imageAttachment(path: "Images/banner.bmp", data: wideImageData)

  /// An image that is taller than it is wide: a sidebar of the sample project.
  static let tallImageAttachment = imageAttachment(path: "Images/sidebar.bmp", data: tallImageData)

  /// A very small image: an icon of the sample project.
  static let smallImageAttachment = imageAttachment(path: "Images/icon.bmp", data: smallImageData)

  /// The MIME type of the images of the previews.
  private static let bitmapMIMEType = "image/bmp"

  /// Makes the attachment of an image whose bytes are in a `data:` URL, so
  /// that the image preview reads no file.
  ///
  /// - Parameters:
  ///   - path: The path of the image below ``projectDirectory``.
  ///   - data: The bytes of the image, a BMP file.
  /// - Returns: The attachment. A `data:` URL of base64 bytes always parses;
  ///   were it not to, the URL is the path in the sample project, where no
  ///   file is.
  private static func imageAttachment(path: String, data: Data) -> Attachment {
    let dataURL = URL(string: "data:\(bitmapMIMEType);base64,\(data.base64EncodedString())")
    return attachment(path: path, type: .bmp, size: data.count, url: dataURL)
  }

  /// The number of lines of ``longLogText``.
  static let longLogLineCount = 400

  /// The text of ``longLogFileAttachment``: a build log that is longer than
  /// a window.
  static let longLogText = buildOutput(lineCount: longLogLineCount)

  /// The full build log of the sample project. ``attachmentPreviewLoader``
  /// holds ``longLogText`` as its text.
  static let longLogFileAttachment = attachment(
    path: "Logs/full-build.log", type: .log, size: Data(longLogText.utf8).count)

  /// The release archive of the sample project: a kind of file that has no
  /// preview, so it shows as a chip.
  static let archiveAttachment = attachment(path: archivePath, type: .zip, size: binaryResourceSize)

  /// The scheme of the URL of each in-memory audio and movie file. No system
  /// loader reads it, so AVFoundation asks ``MemoryMediaLoader`` for the
  /// bytes.
  static let memoryScheme = "avk-preview"

  /// The length of ``audioAttachment``, in seconds.
  static let audioDurationSeconds = 30

  /// The bytes of ``audioAttachment``: a WAVE file of silence.
  private static let audioData = WaveFile.data(seconds: audioDurationSeconds)

  /// A recording of the sample project. Its bytes are in memory.
  static let audioAttachment = mediaAttachment(path: "Recordings/standup.wav", type: .wav, data: audioData)

  /// The bytes of ``videoAttachment``: an MPEG-4 movie of 2 seconds, 128 × 72
  /// pixels, H.264, whose gradient changes in each frame. `AVAssetWriter`
  /// made it. A base64 text that does not decode gives no bytes, and the
  /// player then shows its failure.
  private static let videoData = Data(base64Encoded: videoBase64, options: .ignoreUnknownCharacters) ?? Data()

  /// A screen recording of the sample project. Its bytes are in memory.
  static let videoAttachment = mediaAttachment(path: "Recordings/demo.mp4", type: .mpeg4Movie, data: videoData)

  /// Makes the attachment of an audio or a movie file whose bytes are in
  /// memory.
  ///
  /// - Parameters:
  ///   - path: The path of the file below ``projectDirectory``.
  ///   - type: The uniform type of the file.
  ///   - data: The bytes of the file.
  /// - Returns: The attachment. Its URL has the scheme ``memoryScheme``. The
  ///   URL of a scheme and a path always parses; were it not to, the URL is
  ///   the path in the sample project, where no file is.
  private static func mediaAttachment(path: String, type: UTType, data: Data) -> Attachment {
    attachment(path: path, type: type, size: data.count, url: URL(string: "\(memoryScheme):///\(path)"))
  }

  /// The bytes of each in-memory file of the attachment previews, by the URL
  /// of its attachment.
  private static let memoryFiles: [URL: Data] = [
    wideImageAttachment.url: wideImageData,
    tallImageAttachment.url: tallImageData,
    smallImageAttachment.url: smallImageData,
    logFileAttachment.url: Data(buildLogText.utf8),
    longLogFileAttachment.url: Data(longLogText.utf8),
  ]

  /// The queue that ``mediaLoader`` answers on. It is not the main queue, so
  /// a busy main actor does not hold up a load.
  private static let mediaLoaderQueue = DispatchQueue(label: "AgentViewKit.PreviewFixtures.mediaLoader")

  /// The loader of the in-memory audio and movie files.
  private static let mediaLoader = MemoryMediaLoader(
    files: [
      audioAttachment.url: (audioAttachment.type, audioData),
      videoAttachment.url: (videoAttachment.type, videoData),
    ])

  /// The loader of the attachment previews. It reads no file on disk: it
  /// gives the text and the thumbnail of each in-memory file, and plays the
  /// in-memory audio and movie files. A file that it does not hold fails.
  static let attachmentPreviewLoader = AttachmentPreviewLoader(
    text: { url in memoryFiles[url].map { String(decoding: $0, as: UTF8.self) } },
    thumbnail: { url, _ in memoryFiles[url].flatMap(NSImage.init(data:)).map { .loaded($0) } ?? .failed },
    player: { url in memoryPlayer(of: url) })

  /// A loader whose loads end only when their task is cancelled, so that a
  /// preview shows its load state. Its players play nothing.
  static let pendingAttachmentPreviewLoader = AttachmentPreviewLoader(
    text: { _ in
      await waitForCancellation()
      return nil
    },
    thumbnail: { _, _ in
      await waitForCancellation()
      return .failed
    },
    player: { _ in AVPlayer() })

  /// The time between two checks of a pending load for the cancellation of
  /// its task.
  static let pendingLoadCheckInterval = Duration.seconds(1)

  /// Waits until the current task is cancelled.
  private static func waitForCancellation() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: pendingLoadCheckInterval)
    }
  }

  /// Makes a player of an in-memory audio or movie file.
  ///
  /// - Parameter url: The URL of the attachment, with the scheme
  ///   ``memoryScheme``.
  /// - Returns: The player. ``MemoryMediaLoader`` gives AVFoundation the
  ///   bytes of the file.
  private static func memoryPlayer(of url: URL) -> AVPlayer {
    let asset = AVURLAsset(url: url)
    asset.resourceLoader.setDelegate(mediaLoader, queue: mediaLoaderQueue)
    return AVPlayer(playerItem: AVPlayerItem(asset: asset))
  }

  /// The resource bundle of the kit: a local file that exists wherever the
  /// kit runs, so each file action can run on it. The previews write no file
  /// for it.
  static let localFileAttachment = Attachment(url: Bundle.module.bundleURL)

  /// A web page: the guide of the Swift Package Manager. A web URL that does
  /// not parse is the sample project directory, where no file is.
  static let webAttachment = Attachment(url: URL(string: packageManagerGuideURL) ?? projectDirectory)

  /// The attachment service of the previews, so that a press on a file action
  /// in the canvas opens nothing.
  static let attachmentFileService = RecordingAttachmentFileService()

  /// Gives AVFoundation the bytes of the in-memory audio and movie files.
  ///
  /// AVFoundation cannot read a URL of ``memoryScheme``, so it asks this
  /// delegate for the type, the length and the bytes of the file.
  nonisolated final class MemoryMediaLoader: NSObject, AVAssetResourceLoaderDelegate, Sendable {
    /// The type and the bytes of each file, by its URL.
    private let files: [URL: (type: UTType, data: Data)]

    /// Makes a loader of in-memory files.
    ///
    /// - Parameter files: The type and the bytes of each file, by its URL.
    init(files: [URL: (type: UTType, data: Data)]) {
      self.files = files
    }

    /// Answers a request for the bytes of a file.
    ///
    /// - Parameters:
    ///   - resourceLoader: The resource loader of the asset.
    ///   - loadingRequest: The request.
    /// - Returns: `true` when the loader holds the file and answered the
    ///   request. `false` for a file that it does not hold.
    func resourceLoader(
      _ resourceLoader: AVAssetResourceLoader,
      shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
      guard let url = loadingRequest.request.url, let file = files[url] else { return false }
      if let information = loadingRequest.contentInformationRequest {
        information.contentType = file.type.identifier
        information.contentLength = Int64(file.data.count)
        information.isByteRangeAccessSupported = true
      }
      if let dataRequest = loadingRequest.dataRequest {
        dataRequest.respond(with: file.data.subdata(in: Self.range(of: dataRequest, count: file.data.count)))
      }
      loadingRequest.finishLoading()
      return true
    }

    /// The bytes that a data request asks for.
    ///
    /// - Parameters:
    ///   - request: The data request.
    ///   - count: The length of the file, in bytes.
    /// - Returns: The range of the bytes, inside the file.
    private static func range(of request: AVAssetResourceLoadingDataRequest, count: Int) -> Range<Int> {
      let start = min(Int(request.requestedOffset), count)
      let end = request.requestsAllDataToEndOfResource ? count : min(count, start + request.requestedLength)
      return start..<end
    }
  }

  /// Bytes in little-endian order: the header of an in-memory file.
  private struct LittleEndianBytes {
    /// The bytes so far.
    private(set) var data = Data()

    /// Appends the ASCII bytes of a tag, such as `RIFF`.
    ///
    /// - Parameter tag: The tag.
    mutating func append(_ tag: String) {
      data.append(contentsOf: tag.utf8)
    }

    /// Appends an integer, least significant byte first.
    ///
    /// - Parameter value: The integer.
    mutating func append(_ value: some FixedWidthInteger) {
      withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
  }

  /// A WAVE file of silence: 8-bit mono PCM.
  private enum WaveFile {
    /// The samples in each second.
    static let sampleRate: UInt32 = 8_000

    /// The format code of PCM.
    static let pcmFormat: UInt16 = 1

    /// The number of channels.
    static let channelCount: UInt16 = 1

    /// The bits of each sample.
    static let bitsPerSample: UInt16 = 8

    /// The size of the `fmt ` chunk, in bytes.
    static let formatChunkSize: UInt32 = 16

    /// The bytes of the RIFF chunk after its size field and before the
    /// samples.
    static let headerSizeAfterRIFFSize: UInt32 = 36

    /// The value of a sample of silence. The samples of 8-bit PCM are
    /// unsigned, so silence is the middle value.
    static let silence: UInt8 = 0x80

    /// Makes the bytes of a WAVE file of silence.
    ///
    /// - Parameter seconds: The length of the sound.
    /// - Returns: The bytes of the file.
    static func data(seconds: Int) -> Data {
      let sampleCount = UInt32(seconds) * sampleRate
      let blockAlign = channelCount * bitsPerSample / UInt16(UInt8.bitWidth)
      var bytes = LittleEndianBytes()
      bytes.append("RIFF")
      bytes.append(headerSizeAfterRIFFSize + sampleCount * UInt32(blockAlign))
      bytes.append("WAVEfmt ")
      bytes.append(formatChunkSize)
      bytes.append(pcmFormat)
      bytes.append(channelCount)
      bytes.append(sampleRate)
      bytes.append(sampleRate * UInt32(blockAlign))
      bytes.append(blockAlign)
      bytes.append(bitsPerSample)
      bytes.append("data")
      bytes.append(sampleCount * UInt32(blockAlign))
      return bytes.data + Data(repeating: silence, count: Int(sampleCount) * Int(blockAlign))
    }
  }

  /// A BMP file: a 32-bit image with no compression, whose rows run from the
  /// top. Its pixels make a gradient: blue grows from left to right, and
  /// green from top to bottom.
  private enum BitmapFile {
    /// The size of the file header, in bytes.
    static let fileHeaderSize: UInt32 = 14

    /// The size of the info header, in bytes.
    static let infoHeaderSize: UInt32 = 40

    /// The number of color planes.
    static let planeCount: UInt16 = 1

    /// The bits of each pixel: blue, green, red and alpha.
    static let bitsPerPixel: UInt16 = 32

    /// Makes the bytes of a BMP file.
    ///
    /// - Parameter size: The pixel size of the image.
    /// - Returns: The bytes of the file.
    static func data(size: CGSize) -> Data {
      let width = Int(size.width)
      let height = Int(size.height)
      let pixels = gradient(width: width, height: height)
      let headerSize = fileHeaderSize + infoHeaderSize
      var bytes = LittleEndianBytes()
      bytes.append("BM")
      bytes.append(headerSize + UInt32(pixels.count))
      bytes.append(UInt32.zero)
      bytes.append(headerSize)
      bytes.append(infoHeaderSize)
      bytes.append(Int32(width))
      // A negative height puts the first row at the top.
      bytes.append(-Int32(height))
      bytes.append(planeCount)
      bytes.append(bitsPerPixel)
      // No compression, then the size of the pixels.
      bytes.append(UInt32.zero)
      bytes.append(UInt32(pixels.count))
      // No resolution, so the decoder uses its default, then no palette.
      bytes.append(Int32.zero)
      bytes.append(Int32.zero)
      bytes.append(UInt32.zero)
      bytes.append(UInt32.zero)
      return bytes.data + pixels
    }

    /// Makes the pixels of the gradient, in the order of ``PixelGrid``.
    ///
    /// - Parameters:
    ///   - width: The number of pixels in a row.
    ///   - height: The number of rows.
    /// - Returns: The blue, green, red and alpha bytes of each pixel.
    static func gradient(width: Int, height: Int) -> Data {
      Data(
        PixelGrid.positions(width: width, height: height).flatMap { position in
          [level(position.column, of: width), level(position.row, of: height), UInt8.zero, UInt8.max]
        })
    }

    /// The level of a color at one place of a gradient.
    ///
    /// - Parameters:
    ///   - index: The place, from zero.
    ///   - count: The number of places.
    /// - Returns: Zero at the first place, and the largest level at the last.
    static func level(_ index: Int, of count: Int) -> UInt8 {
      UInt8(Int(UInt8.max) * index / max(count - 1, 1))
    }
  }

  /// The base64 text of ``videoData``.
  private static let videoBase64 = """
    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
    dGNvAAAAAAAAAAIAAAAsAAACww==
    """

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
    /// A required text field: the name of the new package.
    static let packageName = ElicitationFieldSchema(
      name: "name", title: "Name", description: "The name of the new package.", required: true,
      kind: .text(minLength: 1, maxLength: nil, pattern: nil, format: nil), defaultValue: nil)

    /// The largest value of the ``retries`` field.
    static let maximumRetries: Double = 5

    /// An integer field with a range: the number of runs of a failed test.
    static let retries = ElicitationFieldSchema(
      name: "retries", title: "Retries", description: "How many times to run a failed test again.",
      required: false, kind: .number(integer: true, minimum: 0, maximum: maximumRetries),
      defaultValue: .number(1))

    /// A Boolean field: whether the output is verbose.
    static let verboseOutput = ElicitationFieldSchema(
      name: "verbose", title: "Verbose output", description: nil, required: false, kind: .boolean,
      defaultValue: .bool(false))

    /// A date field: the due date of the release.
    static let dueDate = ElicitationFieldSchema(
      name: "due", title: "Due date", description: "The last day for the release.", required: false,
      kind: .date(dateTime: false), defaultValue: nil)

    /// The choices of the ``platform`` field.
    static let platformChoices = [
      ElicitationFieldSchema.Choice(const: "macos", title: "macOS"),
      ElicitationFieldSchema.Choice(const: "ios", title: "iOS"),
    ]

    /// The choices of the ``checks`` field.
    static let checkChoices = [
      ElicitationFieldSchema.Choice(const: "lint", title: "Lint"),
      ElicitationFieldSchema.Choice(const: "test", title: "Test"),
      ElicitationFieldSchema.Choice(const: "docs", title: "Docs"),
    ]

    /// A field with one choice from a list: the platform of the release.
    static let platform = ElicitationFieldSchema(
      name: "platform", title: "Platform", description: nil, required: true,
      kind: .singleChoice(platformChoices), defaultValue: nil)

    /// A field with a set of choices from a list: the checks of the release.
    static let checks = ElicitationFieldSchema(
      name: "checks", title: "Checks", description: "The checks to run before the release.",
      required: false, kind: .multiChoice(checkChoices, minItems: 1, maxItems: nil), defaultValue: nil)

    /// Each field of the form, in form order.
    static let all = [packageName, retries, verboseOutput, dueDate, platform, checks]
  }
}
