import EditorSwiftUI
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Checks that each ACP and client status that the kit shows gives its
/// EditorKit status token (`EditorStatus`): the symbol, the tone, the label,
/// the detail and the liveness that `EditorStatusLabel` and the `.status`
/// inspector row show.
///
/// EditorKit's own tests check the label, the symbol and the tone of each
/// `EditorSymbol.Status`. These tests check only the map from ACP to
/// EditorKit, and the labels that the kit gives a status EditorKit does not
/// name.
@Suite struct EditorStatusACPTests {
  /// The wire value of a status that the kit does not know.
  static let customWireValue = "custom_status"

  /// The reason of a failed MCP server.
  static let reason = "The command was not found."

  // MARK: - Tool calls

  @Test(arguments: [
    (FoundationModelsACP.ToolCallStatus.inProgress, EditorSymbol.Status.inProgress),
    (.paused, .paused),
    (.completed, .completed),
    (.failed, .failed),
    (.cancelled, .cancelled),
    (.unknown(ToolStatusSymbol.lostWireValue), .lost),
  ])
  func eachKnownToolCallStatusIsTheEditorKitStatus(
    status: FoundationModelsACP.ToolCallStatus, expected: EditorSymbol.Status
  ) {
    #expect(EditorStatus(status) == EditorStatus(expected))
  }

  @Test func anUnknownToolCallStatusIsTheUnknownStatusWithItsWireValue() {
    let status = FoundationModelsACP.ToolCallStatus.unknown(Self.customWireValue)

    #expect(EditorStatus(status) == EditorStatus(.unknown, detail: Self.customWireValue))
  }

  @Test func aPendingToolCallHasTheLabelOfThePendingStatus() {
    #expect(EditorStatus(FoundationModelsACP.ToolCallStatus.pending).label == EditorStatus(EditorSymbol.Status.pending).label)
  }

  // MARK: - Plan entries

  @Test(arguments: [
    (FoundationModelsACP.PlanEntryStatus.pending, EditorSymbol.Status.pending),
    (.inProgress, .inProgress),
    (.completed, .completed),
    (.cancelled, .cancelled),
  ])
  func eachKnownPlanEntryStatusIsTheEditorKitStatus(
    status: FoundationModelsACP.PlanEntryStatus, expected: EditorSymbol.Status
  ) {
    #expect(EditorStatus(status) == EditorStatus(expected))
  }

  @Test func anUnknownPlanEntryStatusIsTheUnknownStatusWithItsWireValue() {
    let status = FoundationModelsACP.PlanEntryStatus.unknown(Self.customWireValue)

    #expect(EditorStatus(status) == EditorStatus(.unknown, detail: Self.customWireValue))
  }

  // MARK: - Compactions

  @Test(arguments: [
    (CompactionStatus.inProgress, EditorSymbol.Status.inProgress),
    (.completed, .completed),
    (.failed, .failed),
    (.cancelled, .cancelled),
  ])
  func eachKnownCompactionStatusIsTheEditorKitStatus(status: CompactionStatus, expected: EditorSymbol.Status) {
    #expect(EditorStatus(status) == EditorStatus(expected))
  }

  @Test func aCompactionWithNoUpdateSaysItHasNoStatusYet() {
    #expect(EditorStatus(SessionEntry.Compaction.unreportedStatus).label == "No status yet")
  }

  @Test func aCompactionWithNoUpdateShowsTheUnknownSymbol() {
    #expect(
      EditorStatus(SessionEntry.Compaction.unreportedStatus).systemImage
        == EditorSymbol.status(.unknown).systemImage)
  }

  @Test func anUnknownCompactionStatusIsTheUnknownStatusWithItsWireValue() {
    #expect(
      EditorStatus(CompactionStatus.unknown(Self.customWireValue))
        == EditorStatus(.unknown, detail: Self.customWireValue))
  }

  // MARK: - Send states

  @Test(arguments: [(SendState.pending, "Sending"), (.sent, "Sent"), (.failed, "Not sent")])
  func eachSendStateHasItsLabel(state: SendState, label: String) {
    #expect(EditorStatus(state).label == label)
  }

  @Test(arguments: [SendState.pending, .sent, .failed])
  func eachSendStateShowsTheSymbolOfItsEditorKitStatus(state: SendState) {
    #expect(EditorStatus(state).systemImage == EditorSymbol.status(.init(state)).systemImage)
  }

  // MARK: - MCP servers

  @Test(arguments: [
    (MCPServerStatus.notReported, "Not reported"),
    (.connecting, "Connecting"),
    (.connected, "Connected"),
    (.failed(reason: nil), EditorStatus(EditorSymbol.Status.failed).label),
    (.closed, "Closed"),
  ])
  func eachServerStatusHasItsLabel(status: MCPServerStatus, label: String) {
    #expect(EditorStatus(status).label == label)
  }

  @Test(arguments: [
    (MCPServerStatus.notReported, EditorSymbol.Tone.pending),
    (.connecting, .running),
    (.connected, .succeeded),
    (.failed(reason: nil), .failed),
    (.closed, .cancelled),
  ])
  func eachServerStatusDrawsInItsTone(status: MCPServerStatus, tone: EditorSymbol.Tone) {
    #expect(EditorStatus(status).tone == tone)
  }

  @Test func theDetailOfAFailedServerIsItsReason() {
    #expect(EditorStatus(MCPServerStatus.failed(reason: Self.reason)).detail == Self.reason)
  }

  @Test func aConnectingServerIsLive() {
    #expect(EditorStatus(MCPServerStatus.connecting).isLive)
  }

  // MARK: - Connections

  @Test func aConnectionAndAServerThatConnectShareTheirStatus() {
    #expect(EditorStatus(ConnectionState.connecting) == EditorStatus(MCPServerStatus.connecting))
  }

  @Test func aConnectionAndAServerThatAreConnectedShareTheirStatus() {
    #expect(EditorStatus(ConnectionState.connected) == EditorStatus(MCPServerStatus.connected))
  }

  @Test func theDetailOfAFailedConnectionIsItsError() {
    let status = EditorStatus(ConnectionState.failed(ConnectionError.closed))

    #expect(status.detail == ConnectionError.closed.localizedDescription)
  }

  @Test func aDisconnectedConnectionSaysSo() {
    #expect(EditorStatus(ConnectionState.disconnected).label == "Disconnected")
  }

  // MARK: - Summary

  @Test func theSummaryOfAStatusWithADetailIsTheLabelAndTheDetail() {
    let status = EditorStatus(.unknown, detail: Self.customWireValue)

    #expect(status.summary == "\(status.label): \(Self.customWireValue)")
  }

  @Test func theSummaryOfAStatusWithNoDetailIsItsLabel() {
    #expect(EditorStatus(EditorSymbol.Status.completed).summary == EditorStatus(EditorSymbol.Status.completed).label)
  }
}
