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

  @Test func theToolCallStatusesShowEachStatusSymbolWithItsOwnLabel() {
    let statuses = PreviewFixtures.toolCallStatuses

    #expect(
      Set(statuses.map(ToolStatusSymbol.name(for:)))
        == [
          SharedSymbol.pending, SharedSymbol.inProgress, SharedSymbol.completed, SharedSymbol.error,
          SharedSymbol.cancelled, SharedSymbol.warning, SharedSymbol.unknown,
        ])
    #expect(Set(statuses.map(ToolStatusSymbol.label(for:))).count == statuses.count)
  }

  @Test func thePlanEntryStatusesShowEachStatusSymbolWithItsOwnLabel() {
    let statuses = PreviewFixtures.planEntryStatuses

    #expect(
      Set(statuses.map(TaskListView.statusSymbol))
        == [
          SharedSymbol.pending, SharedSymbol.inProgress, SharedSymbol.completed, SharedSymbol.cancelled,
          SharedSymbol.unknown,
        ])
    #expect(Set(statuses.map(TaskListView.statusLabel)).count == statuses.count)
  }

  @Test func thePlanEntryPrioritiesShowEachPrioritySymbolWithItsOwnLabel() {
    let priorities = PreviewFixtures.planEntryPriorities

    #expect(
      Set(priorities.map(TaskListView.prioritySymbol))
        == [SharedSymbol.highPriority, SharedSymbol.mediumPriority, SharedSymbol.lowPriority, SharedSymbol.unknown])
    #expect(Set(priorities.map(TaskListView.priorityLabel)).count == priorities.count)
  }

  @Test func theNoticeSeveritiesShowEachSeveritySymbolWithItsOwnLabel() {
    let severities = PreviewFixtures.noticeSeverities

    #expect(
      Set(severities.map(NoticeBanner.symbolName(for:)))
        == [SharedSymbol.information, SharedSymbol.warning, SharedSymbol.error, SharedSymbol.unknown])
    #expect(Set(severities.map(NoticeBanner.severityLabel)).count == severities.count)
  }

  @Test func theStatusSymbolNamesAreDifferentSystemSymbols() {
    let names = PreviewFixtures.statusSymbolNames

    #expect(!names.isEmpty)
    #expect(Set(names).count == names.count)
    #expect(names.allSatisfy { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }, "\(names)")
  }

  @Test func theHeaderSymbolsAreTheSymbolsOfTheAgentHeaderAndOfTheEmptyConversation() throws {
    let symbols = PreviewFixtures.headerSymbols
    let emptyConversationSymbol = try #require(ConversationEmptyContent.standard.systemImage)

    #expect(symbols.map(\.name) == [AgentInfoHeader.symbol, emptyConversationSymbol])
    #expect(Set(symbols.map(\.header)).count == symbols.count)
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

  @Test func theFormElicitationNamesTheShortWhoAsks() throws {
    let pending = try #require(PreviewFixtures.elicitationSession.pendingElicitations.first)

    #expect(pending.agentPath == PreviewFixtures.WhoAsks.short.agentPath)
    #expect(pending.source == PreviewFixtures.WhoAsks.short.source)
  }

  @Test func theEachKindFormElicitationGivesOneFieldOfEachKind() throws {
    let kinds = try Self.fields(of: PreviewFixtures.eachKindFormElicitation).map { Self.caseName(of: $0.kind) }

    #expect(kinds.count == PreviewFixtures.ElicitationFields.all.count)
    #expect(Set(kinds) == Set(PreviewFixtures.ElicitationFields.all.map { Self.caseName(of: $0.kind) }))
  }

  @Test func theInvalidFieldElicitationHasOneFieldWhoseDefaultFailsAConstraint() throws {
    let fields = try Self.fields(of: PreviewFixtures.invalidFieldElicitation)

    let failing = fields.filter { !ElicitationValidator.validate($0.defaultValue, against: $0).isSatisfied }

    #expect(fields.count > failing.count)
    #expect(failing.count == 1)
    #expect(failing.allSatisfy { $0.defaultValue != nil })
  }

  @Test func theElicitationCardSessionHoldsItsRequestAndItsTranscript() {
    let session = PreviewFixtures.elicitationCardSession(
      asking: PreviewFixtures.urlElicitation, transcript: PreviewFixtures.scrolledTranscript)

    #expect(session.pendingElicitations.map(\.request) == [PreviewFixtures.urlElicitation])
    #expect(session.transcript.count == PreviewFixtures.scrolledTranscript.count)
  }

  @Test func theElicitationCardSessionHasNoTranscriptByDefault() {
    let session = PreviewFixtures.elicitationCardSession(asking: PreviewFixtures.formElicitation)

    #expect(session.pendingElicitations.map(\.request) == [PreviewFixtures.formElicitation])
    #expect(session.transcript.isEmpty)
  }

  @Test func theLongWhoAsksHasLongerNamesThanTheShortWhoAsks() {
    let short = PreviewFixtures.WhoAsks.short
    let long = PreviewFixtures.WhoAsks.long

    #expect(long.agentPath.joined().count > short.agentPath.joined().count)
    #expect(long.source.count > short.source.count)
  }

  @Test func eachWhoAsksGivesALine() {
    let rootLabel = PreviewFixtures.agentName

    #expect(
      [PreviewFixtures.WhoAsks.short, PreviewFixtures.WhoAsks.long].allSatisfy {
        ElicitationHeader.whoAsks(agentPath: $0.agentPath, source: $0.source, rootLabel: rootLabel) != nil
      })
  }

  @Test func theWithdrawnNoticesTellTheirTitleAndTheReason() {
    let notices = [
      (PreviewFixtures.withdrawnNotice, PreviewFixtures.formElicitation.message),
      (PreviewFixtures.longTitleWithdrawnNotice, PreviewFixtures.longWithdrawnTitle),
    ]

    #expect(
      notices.allSatisfy { notice, title in
        notice.text == RequestDeck.withdrawnText(title: title, reason: PreviewFixtures.withdrawalReason)
      })
    #expect(Set(notices.map(\.0.id)).count == notices.count)
  }

  @Test func theLongWithdrawnTitleIsLongerThanTheTitleOfTheWithdrawnNotice() {
    #expect(PreviewFixtures.longWithdrawnTitle.count > PreviewFixtures.formElicitation.message.count)
  }

  @Test func theScrolledTranscriptHoldsAMessagePairForEachTurn() {
    #expect(PreviewFixtures.scrolledTranscript.count == PreviewFixtures.scrolledTurnCount * Self.messagesPerTurn)
  }

  /// The fields of a form-mode elicitation, as the card shows them.
  ///
  /// - Parameter request: The form-mode elicitation.
  /// - Returns: The fields of its requested schema, in form order.
  /// - Throws: An issue when the preview session holds no pending
  ///   elicitation.
  static func fields(of request: CreateElicitationRequest) throws -> [ElicitationFieldSchema] {
    let pending = try #require(PreviewFixtures.elicitationCardSession(asking: request).pendingElicitations.first)
    return ElicitationFieldSchema.normalize(from: ElicitationView.requestedSchema(of: pending))
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
    let service = RecordingAttachmentFileService()
    let attachment = PreviewFixtures.localFileAttachment

    #expect(service.run(.revealAttachment, on: attachment))
    #expect(service.run(.saveAttachment, on: attachment))

    #expect(
      service.calls
        == [.init(verb: .revealAttachment, attachment: attachment), .init(verb: .saveAttachment, attachment: attachment)])
  }

  // MARK: - Transcript items

  @Test func theUserMessageSampleIsAUserMessageWithTheQuestion() throws {
    let entry = try #require(PreviewFixtures.MessageSample.user.entry)

    #expect(entry.role == .user)
    #expect(entry.content == [.text(TextContent(text: PreviewFixtures.userQuestion))])
  }

  @Test func theAgentMessageSampleIsAnAgentMessageWithTheAnswer() throws {
    let entry = try #require(PreviewFixtures.MessageSample.agent.entry)

    #expect(entry.role == .assistant)
    #expect(entry.content == [.text(TextContent(text: PreviewFixtures.agentAnswer))])
  }

  @Test func theStreamingMessageSampleIsOneAgentMessageWithABlockForEachChunk() throws {
    let entry = try #require(PreviewFixtures.MessageSample.streaming.entry)

    #expect(entry.role == .assistant)
    #expect(entry.content == PreviewFixtures.streamedAnswerChunks.map { .text(TextContent(text: $0)) })
    #expect(PreviewFixtures.MessageSample.streaming.session.transcript.count == 1)
  }

  @Test func theFailureMessageSampleShowsTheBuildErrorInACodeBlock() throws {
    let entry = try #require(PreviewFixtures.MessageSample.failure.entry)
    let code = try Self.codeBlockText(of: Self.text(of: entry.content))

    #expect(entry.role == .assistant)
    #expect(code.contains(PreviewFixtures.buildError))
  }

  @Test func theLongMessageSampleIsLongerThanEachOtherMessageSample() throws {
    let long = try Self.text(of: #require(PreviewFixtures.MessageSample.long.entry).content)
    let others = PreviewFixtures.MessageSample.allCases.filter { $0 != .long }.compactMap(\.entry)

    #expect(others.count == PreviewFixtures.MessageSample.allCases.count - 1)
    #expect(others.allSatisfy { long.count > Self.text(of: $0.content).count })
  }

  @Test func theCompleteThoughtSampleIsAThoughtWithItsText() throws {
    let entry = try #require(PreviewFixtures.ThoughtSample.complete.entry)

    #expect(entry.content == [.text(TextContent(text: PreviewFixtures.completeThought))])
  }

  @Test func theStreamingThoughtSampleIsOneThoughtWithABlockForEachChunk() throws {
    let entry = try #require(PreviewFixtures.ThoughtSample.streaming.entry)

    #expect(entry.content == PreviewFixtures.streamedThoughtChunks.map { .text(TextContent(text: $0)) })
    #expect(PreviewFixtures.ThoughtSample.streaming.session.transcript.count == 1)
  }

  @Test func theContentOfEachKindHoldsABlockOfEachKindForTheUser() {
    let content = PreviewFixtures.contentOfEachKind

    #expect(Set(content.map(\.kind)) == Set(FoundationModelsACP.ContentBlock.Kind.allCases))
    #expect(content.allSatisfy { $0.isVisibleToUser })
  }

  @Test func theImageAndTheSoundOfTheContentHoldTheirBytes() throws {
    let content = PreviewFixtures.contentOfEachKind
    let image = try #require(content.lazy.compactMap(Self.imageData(of:)).first)
    let sound = try #require(content.lazy.compactMap(Self.audioData(of:)).first)

    #expect(NSImage(data: image) != nil)
    #expect(String(decoding: sound.prefix(Self.riffTag.utf8.count), as: UTF8.self) == Self.riffTag)
  }

  @Test func theDeepJSONIsDeeperThanTheSmallJSONAndHoldsALongerValue() throws {
    let small = PreviewFixtures.smallJSON
    let deep = PreviewFixtures.deepJSON
    let longestSmall = try #require(Self.strings(in: small).map(\.count).max())
    let longestDeep = try #require(Self.strings(in: deep).map(\.count).max())

    #expect(Self.depth(of: deep) > Self.depth(of: small))
    #expect(longestDeep > longestSmall)
  }

  /// The tag at the start of a WAVE file.
  static let riffTag = "RIFF"

  /// The joined text of the text blocks of an entry.
  ///
  /// - Parameter content: The content blocks of the entry.
  /// - Returns: The text of each text block, in order, with no separator.
  static func text(of content: [FoundationModelsACP.ContentBlock]) -> String {
    content.map { block in
      if case .text(let text) = block { text.text } else { "" }
    }
    .joined()
  }

  /// The text of the code blocks of a Markdown text.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The text of each run in a code block, in order.
  /// - Throws: The error of a text that Foundation cannot parse.
  static func codeBlockText(of markdown: String) throws -> String {
    let parsed = try AttributedString(markdown: markdown, options: .init(interpretedSyntax: .full))
    return parsed.runs
      .filter { run in
        run.presentationIntent?.components.contains { component in
          if case .codeBlock = component.kind { true } else { false }
        } ?? false
      }
      .map { String(parsed[$0.range].characters) }
      .joined()
  }

  /// The bytes of an image block.
  ///
  /// - Parameter block: A content block.
  /// - Returns: The decoded bytes, or `nil` for a block of another kind.
  static func imageData(of block: FoundationModelsACP.ContentBlock) -> Data? {
    if case .image(let image) = block { Data(base64Encoded: image.data) } else { nil }
  }

  /// The bytes of a sound block.
  ///
  /// - Parameter block: A content block.
  /// - Returns: The decoded bytes, or `nil` for a block of another kind.
  static func audioData(of block: FoundationModelsACP.ContentBlock) -> Data? {
    if case .audio(let audio) = block { Data(base64Encoded: audio.data) } else { nil }
  }

  /// The number of levels of objects and arrays of a JSON value.
  ///
  /// - Parameter value: The JSON value.
  /// - Returns: 0 for a scalar, and one more than the deepest member for an
  ///   object or an array.
  static func depth(of value: JSONValue) -> Int {
    switch value {
    case .object(let members): 1 + (members.values.map(depth(of:)).max() ?? 0)
    case .array(let items): 1 + (items.map(depth(of:)).max() ?? 0)
    case .null, .bool, .number, .string: 0
    }
  }

  /// The string values of a JSON value, at each level.
  ///
  /// - Parameter value: The JSON value.
  /// - Returns: Each string value, in no set order.
  static func strings(in value: JSONValue) -> [String] {
    switch value {
    case .string(let string): [string]
    case .object(let members): members.values.flatMap(strings(in:))
    case .array(let items): items.flatMap(strings(in:))
    case .null, .bool, .number: []
    }
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
