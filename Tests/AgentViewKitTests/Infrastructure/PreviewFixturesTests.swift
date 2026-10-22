import AVFoundation
import AppKit
import EditorDiff
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

@Suite @MainActor struct PreviewFixturesTests {
  /// The text of the thought of the tests.
  static let thoughtText = "Read the parser first."

  /// The title of the tool call of the tests.
  static let toolCallTitle = "Run swift test"

  @Test func theEntryOfAThoughtItemIsAThoughtEntryWithItsText() throws {
    let entry = try #require(PreviewFixtures.entry(.thought(Self.thoughtText), as: ThoughtEntry.self))

    #expect(entry.content == [.text(TextContent(text: Self.thoughtText))])
  }

  @Test func theEntryOfAnItemOfAnotherKindIsNil() {
    #expect(PreviewFixtures.entry(.thought(Self.thoughtText), as: ToolCallEntry.self) == nil)
  }

  @Test func theFirstEntryOfAKindSkipsTheEntriesOfOtherKinds() {
    let session = SessionModel.preview(transcript: [
      .user("Why does the build fail?"),
      .toolCall(title: Self.toolCallTitle, kind: .execute, status: .pending),
    ])

    #expect(PreviewFixtures.firstEntry(in: session, as: ToolCallEntry.self)?.title == Self.toolCallTitle)
  }

  /// The name of the case of a field kind.
  ///
  /// - Parameter kind: The kind of an elicitation field.
  /// - Returns: The name of the case, such as `text`.
  static func caseName(of kind: ElicitationFieldSchema.Kind) -> String {
    switch kind {
    case .text: "text"
    case .date: "date"
    case .number: "number"
    case .boolean: "boolean"
    case .singleChoice: "singleChoice"
    case .multiChoice: "multiChoice"
    }
  }

  @Test func theElicitationFieldsHoldOneFieldOfEachKindWithItsOwnName() {
    let fields = PreviewFixtures.ElicitationFields.all

    #expect(
      fields.map { Self.caseName(of: $0.kind) }
        == ["text", "number", "boolean", "date", "singleChoice", "multiChoice"])
    #expect(Set(fields.map(\.name)).count == fields.count)
  }

  @Test func theAttachmentsAreFilesOfTheSampleProjectWithTheirOwnIDs() {
    let attachments = PreviewFixtures.attachments

    #expect(!attachments.isEmpty)
    #expect(Set(attachments.map(\.id)).count == attachments.count)
    #expect(attachments.allSatisfy { $0.url.isFileURL && $0.url.lastPathComponent == $0.name })
  }

  @Test func theConfiguredSessionHasAModeOptionForThePicker() {
    let options = PreviewFixtures.configuredSession.configOptions

    #expect(options == PreviewFixtures.configOptions)
    #expect(PermissionModePicker.modeOption(in: options ?? []) != nil)
  }

  @Test func theUsageSessionHoldsTheSampleUsage() {
    #expect(PreviewFixtures.usageSession.usage == PreviewFixtures.usage)
  }

  @Test func theMCPSessionHasAnItemForEachServer() {
    let items = PreviewFixtures.mcpSession.mcpServers

    #expect(items.map(\.server) == PreviewFixtures.mcpServers.map(Optional.some))
  }

  @Test func eachCitationMarkerNamesASourceAndFitsTheResponse() {
    let citations = PreviewFixtures.citations
    let sourceIDs = Set(citations.sources.map(\.id))

    #expect(!citations.markers.isEmpty)
    #expect(citations.markers.allSatisfy { sourceIDs.contains($0.sourceID) })
    #expect(citations.markers.allSatisfy { $0.offset <= PreviewFixtures.citedResponse.count })
  }

  @Test func theElicitationSessionHoldsTheFormRequestThenTheURLRequest() {
    let pending = PreviewFixtures.elicitationSession.pendingElicitations

    #expect(pending.map(\.request) == [PreviewFixtures.formElicitation, PreviewFixtures.urlElicitation])
  }

  @Test func theFormElicitationGivesAFieldForEachPropertyAndNamesWhoAsks() throws {
    let pending = try #require(PreviewFixtures.elicitationSession.pendingElicitations.first)

    #expect(ElicitationView.requestedSchema(of: pending) != .null)
    #expect(
      ElicitationFieldSchema.normalize(from: ElicitationView.requestedSchema(of: pending)).map(\.name)
        == ["name", "retries", "verbose"])
    #expect(!pending.agentPath.isEmpty)
    #expect(pending.source != nil)
  }

  @Test func theURLElicitationNamesTheHostOfItsURL() throws {
    let pending = try #require(PreviewFixtures.elicitationSession.pendingElicitations.last)

    #expect(pending.targetHost == PreviewFixtures.elicitationURLHost)
  }

  @Test func theFieldContextReadsAndWritesTheAnswerOfItsOwnField() {
    var answers: [String: JSONValue] = [:]
    let binding = Binding(get: { answers }, set: { answers = $0 })
    let field = PreviewFixtures.ElicitationFields.text

    let context = PreviewFixtures.fieldContext(field, answers: binding)
    context.value.wrappedValue = .string(Self.thoughtText)

    #expect(context.schema == field)
    #expect(answers == [field.name: .string(Self.thoughtText)])
    #expect(context.value.wrappedValue == .string(Self.thoughtText))
  }

  @Test func theStatusMessagesShowEachLookOfTheBarWithTheirOwnIdentifiers() {
    let messages = PreviewFixtures.statusMessages

    #expect(messages.count == PreviewFixtures.agentStates.count)
    #expect(Set(messages.map(\.identifier)).count == messages.count)
    #expect(messages.contains { $0.isFailure })
    #expect(messages.contains { $0.isOngoing })
    #expect(messages.contains { !$0.isFailure && !$0.isOngoing })
  }

  @Test func theLongStatusMessageIsLongerThanEachStatusMessage() {
    let long = PreviewFixtures.longStatusMessage

    #expect(PreviewFixtures.statusMessages.allSatisfy { long.title.count > $0.title.count })
    #expect(PreviewFixtures.statusMessages.allSatisfy { long.explanation.count > $0.explanation.count })
  }

  @Test func theFailedTurnStatusMessageIsTheFailureOfAnIdleStateWithAnError() {
    let message = PreviewFixtures.failedTurnStatusMessage

    #expect(message.isFailure)
    #expect(message.identifier == StateBanner.failedTurnIdentifier)
  }

  @Test func theStatusActionTakesAPressOnlyWhenItIsEnabled() {
    #expect(PreviewFixtures.statusAction(isEnabled: true).isEnabled)
    #expect(!PreviewFixtures.statusAction(isEnabled: false).isEnabled)
  }

  @Test func theAuthConnectionAsksForASignInWithItsMethods() {
    let methods = [PreviewFixtures.agentAuthMethod, PreviewFixtures.terminalAuthMethod]

    let connection = PreviewFixtures.authConnection(methods: methods)

    #expect(connection.authState == .required(methods))
    #expect(connection.authMethods == methods)
    #expect(connection.canLogin)
  }

  @Test func theAuthConnectionHoldsItsOpenSession() {
    let session = SessionModel.preview()

    let connection = PreviewFixtures.authConnection(methods: [PreviewFixtures.agentAuthMethod], openSessions: [session])

    #expect(connection.openSessions.map(\.sessionId) == [session.sessionId])
  }

  @Test func theAuthConnectionNamesItsAgent() {
    let connection = PreviewFixtures.authConnection(
      methods: [PreviewFixtures.longNameAuthMethod], agentName: PreviewFixtures.longAgentName)

    #expect(connection.initializeResponse?.info.name == PreviewFixtures.longAgentName)
  }

  @Test func theLongNamesAreLongerThanTheOtherNames() throws {
    let longName = try #require(Self.name(of: PreviewFixtures.longNameAuthMethod))
    let otherMethods = [PreviewFixtures.agentAuthMethod, PreviewFixtures.terminalAuthMethod]
    let otherNames = otherMethods.compactMap(Self.name(of:))

    #expect(otherNames.count == otherMethods.count)
    #expect(otherNames.allSatisfy { longName.count > $0.count })
    #expect(PreviewFixtures.longAgentName.count > PreviewFixtures.agentName.count)
  }

  @Test func theTerminalAuthRunnerReportsASuccessfulRun() async throws {
    let status = try await PreviewFixtures.terminalAuthRunner.runTerminalAuth(arguments: [], environment: [:])

    #expect(status == PreviewFixtures.successfulExitStatus)
  }

  @Test func theScrolledSessionHoldsAMessagePairForEachTurn() {
    let transcript = PreviewFixtures.scrolledSession.transcript

    #expect(transcript.count == PreviewFixtures.scrolledTurnCount * Self.messagesPerTurn)
  }

  @Test func theFormattedMarkdownHoldsHeadingsListsATableInlineCodeAndLinks() throws {
    let features = try Self.markdownFeatures(of: PreviewFixtures.formattedMarkdown)

    #expect(features.isSuperset(of: ["heading", "list", "numberedList", "table", "code", "link"]))
  }

  @Test func theCitedQuoteIsAQuoteThatLinksToItsSource() throws {
    let features = try Self.markdownFeatures(of: PreviewFixtures.citedQuote)

    #expect(features.isSuperset(of: ["quote", "link"]))
  }

  @Test func theLongParagraphIsOneParagraphLongerThanTheFormattedMarkdown() {
    let paragraph = PreviewFixtures.longParagraph

    #expect(!paragraph.contains("\n"))
    #expect(paragraph.count > PreviewFixtures.formattedMarkdown.count)
  }

  @Test func theCitationPlacementsPutAPillAfterEachCitedSentence() {
    let placements = PreviewFixtures.citationPlacements

    #expect(
      placements.map(\.offset)
        == [PreviewFixtures.citedFirstSentence.count, PreviewFixtures.citedResponse.count])
    #expect(placements.map(\.number) == Array(1...PreviewFixtures.citations.sources.count))
  }

  @Test func theTextResourceHoldsTextAtAURI() {
    let resource = PreviewFixtures.textResource

    #expect(resource.resourceURI != nil)
    #expect(resource.resourceText != nil)
  }

  @Test func theBinaryResourceHoldsBytesAndNoText() throws {
    let resource = PreviewFixtures.binaryResource

    #expect(resource.resourceURI != nil)
    #expect(resource.resourceText == nil)
    #expect(try #require(resource.resourceBlob).count == PreviewFixtures.binaryResourceSize)
  }

  @Test func theLongURIResourceHoldsTextAtAURILongerThanTheOtherURIs() throws {
    let resource = PreviewFixtures.longURIResource
    let longURI = try #require(resource.resourceURI)
    let otherURIs = [PreviewFixtures.textResource, PreviewFixtures.binaryResource].compactMap(\.resourceURI)

    #expect(resource.resourceText != nil)
    #expect(otherURIs.allSatisfy { longURI.count > $0.count })
  }

  @Test func theSmallPatchAddsAndRemovesLines() throws {
    let counts = try Self.changedLineCounts(of: PreviewFixtures.smallPatch)

    #expect(counts.added > 0)
    #expect(counts.removed > 0)
  }

  @Test func theLargePatchChangesMoreLinesThanTheSmallPatch() throws {
    let large = try Self.changedLineCounts(of: PreviewFixtures.largePatch)
    let small = try Self.changedLineCounts(of: PreviewFixtures.smallPatch)

    #expect(large.added > small.added)
    #expect(large.removed > small.removed)
  }

  @Test func theAddedOnlyPatchAddsLinesAndRemovesNone() throws {
    let counts = try Self.changedLineCounts(of: PreviewFixtures.addedOnlyPatch)

    #expect(counts.added > 0)
    #expect(counts.removed == 0)
  }

  @Test func theRemovedOnlyPatchRemovesLinesAndAddsNone() throws {
    let counts = try Self.changedLineCounts(of: PreviewFixtures.removedOnlyPatch)

    #expect(counts.added == 0)
    #expect(counts.removed > 0)
  }

  @Test func theCappedOutputRowsShowTheRowLimitAndHideTheRest() {
    let rows = PreviewFixtures.cappedOutputRows

    #expect(rows.isCapped)
    #expect(rows.visibleCount == CommandOutputView.defaultRowLimit)
  }

  @Test func theExitSummariesAreASuccessAFailingCodeAndASignal() throws {
    let summaries = PreviewFixtures.exitSummaries

    #expect(summaries.map(\.outcome) == [.success, .failure, .failure])
    #expect(Set(summaries.map(\.label)).count == summaries.count)
    let last = try #require(summaries.last)
    #expect(Self.isSignal(last))
  }

  @Test func eachImageAttachmentHoldsAnImageOfItsOwnPixelSize() async throws {
    for (attachment, size) in Self.imageAttachmentsAndSizes {
      // The image preview reads the data URL through the URL loading system,
      // as `AsyncImage` does.
      let (data, _) = try await URLSession.shared.data(from: attachment.url)
      let bitmap = try #require(NSBitmapImageRep(data: data))

      #expect(CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh) == size)
      #expect(attachment.size == data.count)
    }
  }

  @Test func theImageSizesAreWideTallAndVerySmall() {
    let wide = PreviewFixtures.wideImageSize
    let tall = PreviewFixtures.tallImageSize
    let small = PreviewFixtures.smallImageSize

    #expect(wide.width > wide.height)
    #expect(tall.height > tall.width)
    #expect([wide, tall].allSatisfy { small.width < $0.height && small.height < $0.width })
  }

  @Test func theLoaderGivesTheThumbnailOfEachImageAttachment() async throws {
    let loader = PreviewFixtures.attachmentPreviewLoader

    for (attachment, size) in Self.imageAttachmentsAndSizes {
      let thumbnail = try #require(Self.loadedValue(of: await loader.thumbnail(attachment.url, Self.displayScale)))

      #expect(thumbnail.size == size)
    }
  }

  @Test func theLoaderGivesTheTextOfEachLogFile() async {
    let loader = PreviewFixtures.attachmentPreviewLoader

    #expect(await loader.text(PreviewFixtures.logFileAttachment.url) == PreviewFixtures.buildLogText)
    #expect(await loader.text(PreviewFixtures.longLogFileAttachment.url) == PreviewFixtures.longLogText)
  }

  @Test func theLongLogHasItsLineCountAndMoreLinesThanTheBuildLog() {
    let longLines = PreviewFixtures.longLogText.split(separator: "\n")

    #expect(longLines.count == PreviewFixtures.longLogLineCount)
    #expect(longLines.count > PreviewFixtures.buildLogText.split(separator: "\n").count)
  }

  @Test func theSourceFileIsNeitherOnDiskNorInTheLoader() async {
    let url = PreviewFixtures.sourceFileAttachment.url
    let loader = PreviewFixtures.attachmentPreviewLoader

    #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    #expect(await loader.text(url) == nil)
    #expect(Self.loadedValue(of: await loader.thumbnail(url, Self.displayScale)) == nil)
  }

  @Test func theLoaderPlaysTheAudioAttachmentFromMemory() async throws {
    let media = try await Self.media(of: PreviewFixtures.audioAttachment)

    #expect(media.isPlayable)
    #expect(media.trackTypes == [.audio])
    #expect(media.seconds == Double(PreviewFixtures.audioDurationSeconds))
  }

  @Test func theLoaderPlaysTheVideoAttachmentFromMemory() async throws {
    let media = try await Self.media(of: PreviewFixtures.videoAttachment)

    #expect(media.isPlayable)
    #expect(media.trackTypes == [.video])
    #expect(media.seconds > 0)
  }

  @Test func eachImageMediaAndArchiveAttachmentHasTheRendererOfItsKind() {
    let renderers = [
      PreviewFixtures.wideImageAttachment, PreviewFixtures.audioAttachment, PreviewFixtures.videoAttachment,
      PreviewFixtures.archiveAttachment,
    ].map { AttachmentView.renderer(for: $0.type) }

    #expect(renderers == [.image, .audio, .movie, .chip])
  }

  @Test func thePendingLoaderEndsOnlyWhenItsTaskIsCancelled() async throws {
    let loader = PreviewFixtures.pendingAttachmentPreviewLoader
    let url = PreviewFixtures.logFileAttachment.url
    let ends = ReportRecorder<String?>()
    let load = Task { ends.report(await loader.text(url)) }

    try await Task.sleep(for: Self.pendingLoadWait)
    #expect(ends.values.isEmpty)
    load.cancel()
    await load.value

    #expect(ends.values == [nil])
  }

  @Test func theLocalFileAttachmentTakesEachAction() {
    let attachment = PreviewFixtures.localFileAttachment

    #expect(Self.availableVerbs(for: attachment) == AgentAttachmentVerb.allCases)
  }

  @Test func theWebAttachmentTakesOnlyOpenAndShare() {
    #expect(Self.availableVerbs(for: PreviewFixtures.webAttachment) == [.openAttachment, .shareAttachment])
  }

  @Test func theSourceFileAttachmentTakesNoAction() {
    #expect(Self.availableVerbs(for: PreviewFixtures.sourceFileAttachment).isEmpty)
  }

  @Test func theRecordingFileServiceRecordsEachRunAndReportsThatItRan() {
    let service = PreviewFixtures.RecordingFileService()
    let attachment = PreviewFixtures.localFileAttachment

    #expect(service.run(.revealAttachment, on: attachment))
    #expect(service.run(.saveAttachment, on: attachment))

    #expect(
      service.calls
        == [.init(verb: .revealAttachment, attachment: attachment), .init(verb: .saveAttachment, attachment: attachment)])
  }

  /// The scale of the display that the thumbnail tests give the loader.
  static let displayScale: CGFloat = 2

  /// How long the pending load test waits before it cancels the load. A load
  /// that ends at once ends in this time.
  static let pendingLoadWait = Duration.milliseconds(50)

  /// Each image attachment of the previews, with the pixel size of its image.
  static var imageAttachmentsAndSizes: [(attachment: AgentViewKit.Attachment, size: CGSize)] {
    [
      (PreviewFixtures.wideImageAttachment, PreviewFixtures.wideImageSize),
      (PreviewFixtures.tallImageAttachment, PreviewFixtures.tallImageSize),
      (PreviewFixtures.smallImageAttachment, PreviewFixtures.smallImageSize),
    ]
  }

  /// The value of a load that ended with a value.
  ///
  /// - Parameter state: The state of the load.
  /// - Returns: The loaded value, or `nil` for a load that failed or did not
  ///   end.
  static func loadedValue<Value>(of state: PreviewLoadState<Value>) -> Value? {
    switch state {
    case .loaded(let value): value
    case .loading, .failed: nil
    }
  }

  /// The facts of the media that the preview loader plays for an attachment.
  ///
  /// - Parameter attachment: The audio or video attachment.
  /// - Returns: Whether the media can play, the media type of each track, and
  ///   the length in seconds.
  /// - Throws: The error of a load that AVFoundation cannot do.
  static func media(
    of attachment: AgentViewKit.Attachment
  ) async throws -> (isPlayable: Bool, trackTypes: [AVMediaType], seconds: Double) {
    let player = PreviewFixtures.attachmentPreviewLoader.player(attachment.url)
    let asset = try #require(player.currentItem?.asset)
    let (isPlayable, duration, tracks) = try await asset.load(.isPlayable, .duration, .tracks)
    return (isPlayable, tracks.map(\.mediaType), duration.seconds)
  }

  /// The verbs that can run on an attachment, in the order of the buttons.
  ///
  /// - Parameter attachment: The attachment.
  /// - Returns: Each verb whose availability is available.
  static func availableVerbs(for attachment: AgentViewKit.Attachment) -> [AgentAttachmentVerb] {
    AgentAttachmentVerb.allCases.filter { $0.availability(for: attachment).isAvailable }
  }

  /// The messages of one turn of the scrolled session: a user message and an
  /// agent message.
  static let messagesPerTurn = 2

  /// The Markdown features of a text.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The name of each block kind of the text that
  ///   ``featureName(of:)`` names, `code` for inline code, and `link` for a
  ///   link.
  /// - Throws: The error of a text that Foundation cannot parse.
  static func markdownFeatures(of markdown: String) throws -> Set<String> {
    let parsed = try AttributedString(markdown: markdown, options: .init(interpretedSyntax: .full))
    return Set(
      parsed.runs.flatMap { run -> [String] in
        let blocks = run.presentationIntent?.components.compactMap { featureName(of: $0.kind) } ?? []
        let code = run.inlinePresentationIntent?.contains(.code) == true ? ["code"] : []
        let link = run.link == nil ? [] : ["link"]
        return blocks + code + link
      })
  }

  /// The feature name of a block kind of Markdown.
  ///
  /// - Parameter kind: The block kind.
  /// - Returns: The name of a heading, a list, a numbered list, a table or a
  ///   quote, or `nil` for a kind that the previews do not name.
  static func featureName(of kind: PresentationIntent.Kind) -> String? {
    switch kind {
    case .header: "heading"
    case .unorderedList: "list"
    case .orderedList: "numberedList"
    case .table: "table"
    case .blockQuote: "quote"
    case .paragraph, .listItem, .codeBlock, .thematicBreak, .tableHeaderRow, .tableRow, .tableCell: nil
    @unknown default: nil
    }
  }

  /// The added and the removed lines of a patch, as the EditorKit renderer
  /// parses it.
  ///
  /// - Parameter patch: The patch text.
  /// - Returns: The number of added lines and of removed lines.
  /// - Throws: The parse error of a patch that EditorKit cannot read.
  static func changedLineCounts(of patch: String) throws -> (added: Int, removed: Int) {
    let lines = try EditorKitDiffRenderer.diff(of: patch, file: nil).get()
      .files.flatMap(\.hunks).flatMap(\.lines)
    return (lines.count { $0.kind == .added }, lines.count { $0.kind == .removed })
  }

  /// Whether a signal stopped the process of an exit.
  ///
  /// - Parameter summary: The exit summary.
  /// - Returns: `true` for a signal, and `false` for an exit code or an
  ///   unknown exit.
  static func isSignal(_ summary: TerminalView.ExitSummary) -> Bool {
    switch summary {
    case .signal: true
    case .code, .unknown: false
    }
  }

  /// The name of an auth method.
  ///
  /// - Parameter method: The auth method.
  /// - Returns: The name of an `agent` or a `terminal` method, or `nil` for a
  ///   method of a type that the kit does not know.
  static func name(of method: AuthMethod) -> String? {
    switch method {
    case .agent(let agent): agent.name
    case .terminal(let terminal): terminal.name
    case .unknown: nil
    }
  }
}
