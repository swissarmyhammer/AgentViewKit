@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// Tests for the command groups that a host can turn off (AVK-7e, D105 (f)).
///
/// Each test registers the commands with ``AgentCommandRegistration``, as the
/// mount of a scope does, in a registry with no window. The session is a
/// preview model that the test changes with `apply(_:)`, so each change is
/// done when the call returns.
@MainActor struct AgentCommandGroupTests {
  /// The verbs of each group, as the kits agreed them.
  static let expectedVerbs: [AgentCommandGroup: Set<AgentCommandVerb>] = [
    .compose: [.send, .focusComposer],
    .control: [.cancel, .approvePending, .rejectPending],
    .navigate: [
      .jumpToNext, .jumpToPrevious, .nextRequest, .previousRequest, .scrollToBottom, .toggleExpandAll,
    ],
    .clipboard: [.copyMessage, .copyThread],
    // The attachment verbs are of their own type; see
    // AgentAttachmentCommandsTests.
    .attachment: [],
  ]

  /// The id of a message item in the context menu tests.
  static let messageRowKey = "message-1"

  /// The id of a request item in the context menu tests.
  static let requestID = "request-1"

  /// The objects of one registration test.
  struct Fixture {
    /// The target of the scope.
    let target: AgentCommandTarget
    /// The session model of the scope.
    let model: SessionModel
    /// The path of the scope.
    let path: FocusPath
  }

  /// Makes a target for a preview session model, and the path of its scope.
  ///
  /// - Returns: The fixture.
  static func makeFixture() -> Fixture {
    let model = SessionModel.preview(requestSender: PreviewSessionRequestSender())
    let target = AgentCommandTarget()
    target.session = model
    let path = FocusPath.root(AgentCommandTarget.segment(for: model))
    return Fixture(target: target, model: model, path: path)
  }

  /// The ids of the verbs that are not in `groups`.
  ///
  /// - Parameter groups: The groups that are off.
  /// - Returns: The command ids of each other verb.
  static func ids(notIn groups: Set<AgentCommandGroup>) -> Set<CommandID> {
    Set(AgentCommandVerb.allCases.filter { !groups.contains($0.group) }.map(\.id))
  }

  // MARK: - Groups

  @Test func eachVerbIsInTheGroupOfTheAgreedSplit() {
    for verb in AgentCommandVerb.allCases {
      #expect(Self.expectedVerbs[verb.group]?.contains(verb) == true, "\(verb)")
    }
    for group in AgentCommandGroup.allCases {
      #expect(Set(group.verbs) == Self.expectedVerbs[group], "\(group)")
    }
  }

  @Test func eachGroupIdHasThePrefixOfTheKit() {
    #expect(
      AgentCommandGroup.allCases.map(\.id) == [
        "agent.compose", "agent.control", "agent.navigate", "agent.clipboard", "agent.attachment",
      ])
  }

  // MARK: - Registration

  @Test func theVerbsOfAGroupThatIsOffAreNotInTheDefinitionsOrThePalette() {
    let fixture = Self.makeFixture()
    var registry = CommandRegistry()

    AgentCommandRegistration.register(fixture.target, at: fixture.path, into: &registry, groupsOff: [.clipboard])

    let ids = Set(registry.definitions(at: fixture.path).map(\.id))
    let paletteIDs = Set(registry.eligible(path: fixture.path).map(\.id))
    #expect(ids == Self.ids(notIn: [.clipboard]))
    #expect(paletteIDs.isDisjoint(with: AgentCommandGroup.clipboard.verbs.map(\.id)))
  }

  @Test func theVerbsOfAGroupThatIsOffAreNotInTheContextMenus() {
    let fixture = Self.makeFixture()
    var registry = CommandRegistry()
    let messagePath = fixture.path.appending(FocusSegment(kind: AgentScopeKind.message, id: Self.messageRowKey))
    let requestPath = fixture.path.appending(FocusSegment(kind: AgentScopeKind.request, id: Self.requestID))

    AgentCommandRegistration.register(
      fixture.target, at: fixture.path, into: &registry, groupsOff: [.clipboard, .control])

    #expect(
      registry.contextMenuMirror(at: messagePath).map(\.id) == [AgentCommandVerb.jumpToNext, .jumpToPrevious].map(\.id))
    #expect(registry.contextMenuMirror(at: requestPath).isEmpty)
  }

  @Test func theChordsOfAGroupThatIsOffResolveToNothing() throws {
    let fixture = Self.makeFixture()
    fixture.model.apply(.stateUpdate(.running(RunningStateUpdate())))
    var registry = CommandRegistry()
    let chords = [StandardChords.stop, KeyChord.escape]
    AgentCommandRegistration.register(fixture.target, at: fixture.path, into: &registry)
    for chord in chords {
      try #require(
        registry.resolveKey(chord.asSequence, mode: .cua, at: fixture.path)
          == .command(AgentCommandVerb.cancel.id, scope: fixture.path), "\(chord)")
    }

    AgentCommandRegistration.register(fixture.target, at: fixture.path, into: &registry, groupsOff: [.control])

    for chord in chords {
      #expect(registry.resolveKey(chord.asSequence, mode: .cua, at: fixture.path) == .unbound, "\(chord)")
    }
  }

  @Test func aGroupThatIsOnAgainRegistersItsVerbsAgain() {
    let fixture = Self.makeFixture()
    var registry = CommandRegistry()
    AgentCommandRegistration.register(fixture.target, at: fixture.path, into: &registry, groupsOff: [.navigate])

    AgentCommandRegistration.register(fixture.target, at: fixture.path, into: &registry)

    #expect(Set(registry.definitions(at: fixture.path).map(\.id)) == Self.ids(notIn: []))
  }
}
