import AgentViewKitTestSupport
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Tests for the side card of `/btw` (D205): the answer that the card shows,
/// the text of Send to Chat, the state of the fork, and the buttons that the
/// card shows.
///
/// A test that waits for the agent waits with `ObservationWait.until` on a
/// value of the session model that the last frame is certain to change, with
/// no clock. No test shows a window.
@MainActor struct SideQuestionCardTests {
  /// The question of the side card.
  static let question = "What does the parser do?"

  /// The first chunk of the streamed answer.
  static let firstChunk = "It reads "

  /// The second chunk of the streamed answer.
  static let secondChunk = "the tokens."

  /// The `messageId` of the streamed answer.
  static let answerMessageID = "side-answer"

  // MARK: - Answer

  /// A production change that fails this test: the card reads only the
  /// first chunk of the agent message, or reads the user message.
  @Test func theAnswerIsTheStreamedAgentMessageOfTheFork() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model

    for chunk in [Self.firstChunk, Self.secondChunk] {
      try await session.sendUpdate(
        WireBlockJSON.makeChunk(
          "agent_message_chunk", messageID: Self.answerMessageID,
          block: WireBlockJSON.makeText(chunk)))
    }
    try await session.sendUpdate(ScriptedSession.endTurnState)
    await ObservationWait.until { model.agentState != nil }

    #expect(SideQuestionCard.answer(of: model) == Self.firstChunk + Self.secondChunk)
  }

  @Test func theAnswerHasTheAgentMessagesAndNoUserMessage() {
    let session = SessionModel.preview(
      transcript: [.user(Self.question), .agent("One."), .agent("Two.")])

    #expect(SideQuestionCard.answer(of: session) == "One.\n\nTwo.")
  }

  @Test func theCardShowsTheProgressMarkWhileTheTurnRuns() {
    let session = SessionModel.preview()
    session.apply(.stateUpdate(.running(RunningStateUpdate())))

    #expect(SideQuestionCard.isRunning(session))
  }

  @Test func theCardShowsNoProgressMarkWhenTheTurnEnds() {
    let session = SessionModel.preview(transcript: [.agent("Done.")])

    #expect(!SideQuestionCard.isRunning(session))
  }

  // MARK: - Send to Chat

  @Test func theChatTextHasTheQuestionABlankLineAndTheAnswer() {
    let text = SideQuestionCard.chatText(question: "Why?", answer: "Because.")

    #expect(text == "Side question: Why?\n\nAnswer: Because.")
  }

  // MARK: - Needs input

  @Test func aPendingPermissionRequestOfTheForkNeedsInput() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }

    _ = try await session.receivePermissionRequest(id: AgentCommandFixtures.agentRequestID)

    #expect(SideQuestionCard.needsInput(session.model))
  }

  @Test func aPendingElicitationOfTheForkNeedsInput() throws {
    let session = SessionModel.preview(pendingElicitations: [try Self.elicitation])

    #expect(SideQuestionCard.needsInput(session))
  }

  @Test func aForkWithNoPendingRequestNeedsNoInput() {
    #expect(!SideQuestionCard.needsInput(SessionModel.preview(transcript: [.agent("Done.")])))
  }

  @Test func theNeedsInputTextIsInTheCatalog() {
    #expect(SideQuestionCard.needsInputText == "Needs input")
  }

  @Test func aCardThatNeedsInputShowsTheOpenButtonOnly() {
    #expect(SideQuestionCard.verbs(needsInput: true) == [.openSideCard])
  }

  @Test func aCardThatNeedsNoInputShowsSendToChatOpenAndClose() {
    #expect(
      SideQuestionCard.verbs(needsInput: false)
        == [.sendSideCardToChat, .openSideCard, .closeSideCard])
  }

  // MARK: - Accessibility

  @Test func theCardHasTheSideCardIdentifier() {
    #expect(SideQuestionCard.identifier == "side-card")
  }

  @Test func theCardHasTheSideQuestionLabel() {
    #expect(SideQuestionCard.accessibilityLabelText == "Side question")
  }

  @Test func eachButtonHasTheIdentifierOfTheCard() {
    #expect(
      SideCardVerb.allCases.map(\.identifier)
        == ["side-card-send", "side-card-open", "side-card-close"])
  }

  /// The params of a form elicitation of the preview session.
  static var elicitationParams: String {
    ScriptedSession.makeFormElicitationParams(sessionId: SessionModel.previewSessionId.rawValue)
  }

  /// A form elicitation of the preview session.
  static var elicitation: CreateElicitationRequest {
    get throws {
      try JSONDecoder().decode(
        CreateElicitationRequest.self,
        from: Data(Self.elicitationParams.utf8))
    }
  }
}
