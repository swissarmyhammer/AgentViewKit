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

  /// The sources of ``citedResponse``, with a marker at the end of each
  /// sentence.
  static let citations = CitationPayload(
    sources: [
      CitationSource(
        id: "concurrency", title: "Swift Concurrency",
        url: URL(filePath: "/Users/preview/docs/concurrency.html"),
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
