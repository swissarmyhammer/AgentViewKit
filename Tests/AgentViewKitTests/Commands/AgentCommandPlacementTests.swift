@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsTestSupport
import EditorCommandsUI
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// Tests for the places of the agent commands in the menus, the context
/// menus and the keys (AVK-1).
///
/// A test that waits for the agent waits with `ObservationWait.until` on a
/// value of the session model that the frame is certain to change, with no
/// clock.
@MainActor struct AgentCommandPlacementTests {
  /// The verbs of the Session menu.
  static let sessionMenuVerbs: Set<AgentCommandVerb> = [
    .send, .cancel, .focusComposer, .copyThread, .approvePending, .rejectPending,
  ]

  /// The verbs of the View menu.
  static let viewMenuVerbs: Set<AgentCommandVerb> = [
    .jumpToNext, .jumpToPrevious, .nextRequest, .previousRequest, .toggleExpandAll, .scrollToBottom,
  ]

  /// The verbs of the Edit menu.
  static let editMenuVerbs: Set<AgentCommandVerb> = [.copyMessage]

  /// The menu of `verb` in the design (AVK-1, D41), or `nil` when the verb
  /// is in none of the three menu tables.
  ///
  /// - Parameter verb: The verb.
  /// - Returns: The menu path.
  static func designMenu(of verb: AgentCommandVerb) -> MenuPath? {
    if sessionMenuVerbs.contains(verb) { return .session }
    if viewMenuVerbs.contains(verb) { return .view }
    if editMenuVerbs.contains(verb) { return .edit }
    return nil
  }

  /// The id of the command that a host registers for the tool call scope.
  nonisolated static let hostToolCallCommandID: CommandID = "host.rollBackToBeforeThis"

  /// The title of the command that a host registers for the tool call scope.
  nonisolated static let hostToolCallCommandTitle = "Roll Back to Before This"

  /// The ACP `toolCallId` of the tool call scope of the tests.
  static let toolCallID = "call-1"

  // MARK: - Menus

  @Test func eachVerbIsInTheMenuOfTheDesign() {
    for verb in AgentCommandVerb.allCases {
      #expect(verb.menu?.path == Self.designMenu(of: verb), "\(verb)")
    }
  }

  /// D41: the main menu, the context menus and the palette show the same
  /// commands, so no verb is left out of the main menu.
  @Test func eachVerbHasAPlaceInTheMainMenu() {
    for verb in AgentCommandVerb.allCases {
      #expect(verb.menu != nil, "\(verb)")
    }
  }

  /// EditorKit puts the rows of the Edit path right after the Cut, Copy,
  /// Paste, Delete and Select All rows of the system Edit menu.
  @Test func copyMessageIsInTheEditMenuAfterTheCopyRows() {
    #expect(AgentCommandVerb.copyMessage.menu?.path == .edit)
    #expect(SystemMenuSlot.builtInSlots[.edit] == .after(.pasteboard))
  }

  @Test func theDefinitionsCarryThePlacesAndTheIcons() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model)

    for verb in AgentCommandVerb.allCases {
      let definition = try #require(fixture.system.registry.definition(for: verb.id, at: fixture.path))
      #expect(definition.menu == verb.menu, "\(verb)")
      #expect(definition.contextMenu == verb.contextMenu, "\(verb)")
      #expect(definition.icon == verb.icon, "\(verb)")
    }
  }

  // MARK: - Stop keys

  @Test func stopShowsCommandPeriodAndBothKeysStopWhileRunning() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model)
    let cancel = try #require(fixture.system.registry.definition(for: AgentCommandVerb.cancel.id, at: fixture.path))
    #expect(cancel.keys[.cua] == StandardChords.stop)

    try await AgentCommandsTests.sendState(ScriptedSession.runningState, to: session)

    for chord in [StandardChords.stop, KeyChord.escape] {
      #expect(
        fixture.system.registry.resolveKey(chord.asSequence, mode: .cua, at: fixture.path)
          == .command(AgentCommandVerb.cancel.id, scope: fixture.path), "\(chord)")
    }
  }

  @Test func theRegistrationBindsTheSecondStopKeyOneTime() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let target = AgentCommandTarget()
    target.session = session.model
    let path = FocusPath.root(AgentCommandTarget.segment(for: session.model))
    var registry = CommandRegistry()

    AgentCommandRegistration.register(target, at: path, into: &registry)
    AgentCommandRegistration.register(target, at: path, into: &registry)

    for chord in [StandardChords.stop, KeyChord.escape] {
      let actions = registry.keymapStack(for: .cua, at: path).bindings(for: chord.asSequence).map(\.action)
      #expect(actions == [.command(AgentCommandVerb.cancel.id)], "\(chord)")
    }
  }

  // MARK: - Context menus

  @Test func theContextMenuOfAMessageShowsCopyMessageAndTheJumps() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let userKeys = try await AgentCommandsTests.sendTurns(to: session)
    let fixture = AgentCommandsTests.makeFixture(session: session.model)
    let path = fixture.path.appending(AgentScopeKind.message(rowKey: userKeys[0]))

    let ids = fixture.system.registry.contextMenuMirror(at: path).map(\.id)

    #expect(ids == [AgentCommandVerb.copyMessage, .jumpToNext, .jumpToPrevious].map(\.id))
  }

  /// A command that is not available for the item does not show in the
  /// context menu of the item, and the main menu still shows it, disabled
  /// (AVK-9). The context menu reads the policy that ``AgentItemScope``
  /// passes to `.commandContextMenu`. With no scroll anchors, Next Prompt and
  /// Previous Prompt are not available.
  @Test func theContextMenuOfAMessageHidesTheJumpsThatTheViewMenuDisables() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let userKeys = try await AgentCommandsTests.sendTurns(to: session)
    let fixture = AgentCommandsTests.makeFixture(session: session.model)
    let path = fixture.path.appending(AgentScopeKind.message(rowKey: userKeys[0]))

    let contextIDs = fixture.system.registry.contextMenuMirror(at: path, unavailable: .agentItem).map(\.id)
    let viewItems = fixture.system.registry.menuMirror(at: path).first { $0.path == .view }?.items ?? []

    for verb in [AgentCommandVerb.jumpToNext, .jumpToPrevious] {
      #expect(!contextIDs.contains(verb.id), "\(verb)")
      #expect(viewItems.first { $0.id == verb.id }?.isEnabled == false, "\(verb)")
    }
  }

  @Test func theContextMenuOfARequestCardShowsApproveAndReject() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model)
    let request = try await session.receivePermissionRequest(id: AgentCommandsTests.agentRequestID)
    let path = fixture.path.appending(AgentScopeKind.request(request.id))

    let items = fixture.system.registry.contextMenuMirror(at: path)

    #expect(items.map(\.id) == [AgentCommandVerb.approvePending, .rejectPending].map(\.id))
    #expect(items.allSatisfy { $0.isEnabled })
  }

  /// A command of another kit names the tool call scope by its kind text
  /// only, for example "Roll Back to Before This" of SnapshotViewKit (AVK-7c).
  /// The context menu of a tool call shows that command and no agent verb.
  /// The context menu of a message does not show it.
  @Test func aHostCommandOfTheToolCallScopeShowsOnlyInTheContextMenuOfAToolCall() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let userKeys = try await AgentCommandsTests.sendTurns(to: session)
    let fixture = AgentCommandsTests.makeFixture(session: session.model)
    let definition = CommandDefinition(
      id: Self.hostToolCallCommandID, title: .static(Self.hostToolCallCommandTitle),
      contextMenu: ContextMenuPlacement(group: 0, order: 0),
      requires: .enclosing(AgentScopeKind.toolCall)
    ) { _ in
      AlwaysAvailableCommand(id: Self.hostToolCallCommandID, title: Self.hostToolCallCommandTitle)
    }
    var registry = fixture.system.registry
    registry.register(definition, at: fixture.path)
    let toolCallPath = fixture.path.appending(AgentScopeKind.toolCall(Self.toolCallID))
    let messagePath = fixture.path.appending(AgentScopeKind.message(rowKey: userKeys[0]))

    let toolCallIDs = registry.contextMenuMirror(at: toolCallPath).map(\.id)
    let messageIDs = registry.contextMenuMirror(at: messagePath).map(\.id)

    #expect(toolCallIDs == [Self.hostToolCallCommandID])
    #expect(!messageIDs.contains(Self.hostToolCallCommandID))
  }

  /// With no message in the path, the Edit menu shows Copy Message disabled,
  /// as the menu shows each command that does not apply now (D41). The
  /// palette leaves out a disabled command, so it does not show the row.
  @Test func copyMessageIsDisabledOutsideTheScopeOfAMessage() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let userKeys = try await AgentCommandsTests.sendTurns(to: session)
    let fixture = AgentCommandsTests.makeFixture(
      session: session.model, items: AgentCommandsTests.messageItems(of: session.model))
    let messagePath = fixture.path.appending(AgentScopeKind.message(rowKey: userKeys[0]))

    let threadRows = fixture.system.registry.eligible(path: fixture.path).filter(\.isVisible)
    let messageRows = fixture.system.registry.eligible(path: messagePath).filter(\.isVisible)

    #expect(threadRows.first { $0.id == AgentCommandVerb.copyMessage.id }?.isEnabled == false)
    #expect(threadRows.contains { $0.id == AgentCommandVerb.approvePending.id })
    #expect(messageRows.first { $0.id == AgentCommandVerb.copyMessage.id }?.isEnabled == true)
    #expect(!messageRows.contains { $0.id == AgentCommandVerb.approvePending.id })
  }

  /// The scope of a request card is the scope of another item, so neither
  /// its context menu nor the main menu shows Copy Message there.
  @Test func copyMessageDoesNotShowInTheScopeOfARequest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model)
    let request = try await session.receivePermissionRequest(id: AgentCommandsTests.agentRequestID)
    let path = fixture.path.appending(AgentScopeKind.request(request.id))

    let ids = fixture.system.registry.eligible(path: path).filter(\.isVisible).map(\.id)

    #expect(!ids.contains(AgentCommandVerb.copyMessage.id))
  }

  // MARK: - Commands of an item

  @Test func copyMessageCopiesTheMessageOfItsScope() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let userKeys = try await AgentCommandsTests.sendTurns(to: session)
    let pasteboard = FakePasteboard()
    let fixture = AgentCommandsTests.makeFixture(
      session: session.model, items: AgentCommandsTests.messageItems(of: session.model)
    ) { $0.pasteboard = pasteboard }
    let path = fixture.path.appending(AgentScopeKind.message(rowKey: userKeys[1]))

    #expect(!fixture.system.perform(AgentCommandVerb.copyMessage.id))
    #expect(fixture.system.registry.perform(AgentCommandVerb.copyMessage.id, at: path, clicked: path))

    #expect(pasteboard.contents == "Question 1.")
  }

  @Test func approveInTheScopeOfACardAnswersThatRequest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let starts = ReportRecorder<String>()
    let requests = try await AgentCommandsTests.receiveTwoPermissionRequests(in: session)
    let fixture = AgentCommandsTests.makeFixture(
      session: model, items: AgentCommandsTests.requestItems(of: model)
    ) { $0.requestStartReport = starts.report }
    try #require(model.frontRequest?.id == requests.first.id)
    let path = fixture.path.appending(AgentScopeKind.request(requests.second.id))

    try #require(fixture.system.registry.perform(AgentCommandVerb.approvePending.id, at: path, clicked: path))
    // The command starts the answer in the same step as the dispatch, so a
    // dispatch that started nothing stops the test here.
    try #require(starts.values == [ScriptedSession.permissionMethod])
    let result = await session.result(ofRequest: AgentCommandsTests.secondRequestID)

    #expect(result?["outcome"]?["optionId"]?.stringValue == AgentCommandsTests.allowOptionID)
    #expect(model.pendingPermissions.map(\.id) == [requests.first.id])
  }
}
