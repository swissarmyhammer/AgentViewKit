@testable import AgentViewKit
import EditorCommands
import Foundation
import Testing

/// Tests for the file selection commands of an attachment scope, Add to
/// Selection and Extend Selection, with no window (card ^se9sxxe).
///
/// Each test registers the commands with ``AgentAttachmentRegistration``, as
/// the mount of the scope of a file view does, and runs them in the registry.
@MainActor struct AgentFileSelectionCommandsTests {
  /// The path of the attachment scope of the tests.
  static let path = FocusPath.root(FocusSegment(kind: AgentScopeKind.attachment, id: "selection-file"))

  /// The objects of one registration test.
  struct Fixture {
    /// The target of the scope, which the commands hold weakly.
    let target: AgentAttachmentTarget
    /// The registry with the commands of the target at ``path``.
    var registry: CommandRegistry
    /// The changes that the select action of the target got.
    let changes: ChangeLog
  }

  /// Registers the commands of a target whose select action records each
  /// change at ``path``.
  ///
  /// - Parameter selects: Whether the registration registers the selection
  ///   commands.
  /// - Returns: The fixture.
  static func register(selects: Bool) -> Fixture {
    let changes = ChangeLog()
    let target = AgentAttachmentTarget()
    target.select = { changes.values.append($0) }
    var registry = CommandRegistry()
    AgentAttachmentRegistration.register(target, at: path, into: &registry, selects: selects)
    return Fixture(target: target, registry: registry, changes: changes)
  }

  /// The changes that a select action got, in order.
  @MainActor final class ChangeLog {
    /// The changes, in order.
    var values: [AttachmentSelectionChange] = []
  }

  @Test func eachVerbHasTheKitPrefix() {
    for verb in AgentFileSelectionVerb.allCases {
      #expect(verb.id.rawValue == "agent.\(verb.rawValue)")
    }
  }

  @Test func eachVerbIsTitledAsTheAccessibilityActionOfItsChange() {
    for verb in AgentFileSelectionVerb.allCases {
      #expect(verb.title == verb.change.actionName, "\(verb)")
    }
  }

  @Test func aRunOfEachVerbGivesItsChangeToTheSelectAction() {
    let fixture = Self.register(selects: true)

    for verb in AgentFileSelectionVerb.allCases {
      #expect(fixture.registry.perform(verb.id, at: Self.path, clicked: Self.path), "\(verb)")
    }

    #expect(fixture.changes.values == [.toggle, .extend])
  }

  @Test func aScopeWhoseViewSelectsNoFileRegistersNoSelectionVerb() {
    let fixture = Self.register(selects: false)

    let ids = Set(fixture.registry.definitions(at: Self.path).map(\.id))

    #expect(ids.isDisjoint(with: AgentFileSelectionVerb.allCases.map(\.id)))
  }

  @Test func theSelectionVerbsAreInNoContextMenu() {
    let fixture = Self.register(selects: true)

    let ids = Set(fixture.registry.contextMenuMirror(at: Self.path).map(\.id))

    #expect(ids.isDisjoint(with: AgentFileSelectionVerb.allCases.map(\.id)))
  }

  @Test func theDeregistrationRemovesEachSelectionVerb() {
    var fixture = Self.register(selects: true)

    AgentAttachmentRegistration.deregister(at: Self.path, from: &fixture.registry)

    #expect(fixture.registry.definitions(at: Self.path).isEmpty)
  }

  @Test func noSelectionVerbRunsWhenTheTargetIsGone() {
    var registry = CommandRegistry()
    do {
      let target = AgentAttachmentTarget()
      target.select = { _ in }
      AgentAttachmentRegistration.register(target, at: Self.path, into: &registry, selects: true)
    }

    #expect(!registry.perform(AgentFileSelectionVerb.addFileToSelection.id, at: Self.path))
  }
}
