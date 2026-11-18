import AppKit
import EditorCommands
import EditorCommandsUI
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests for ``AgentScopeAnchor``, the zero-size view that keeps the target
/// of a scope current and its commands registered.
///
/// Each test shows the anchor of a side card scope in an `NSHostingView`
/// with no window, and lays the view out. SwiftUI makes, updates and
/// dismantles the anchor in the layout pass, so no test waits, and no test
/// shows a window or takes the focus.
@MainActor struct AgentScopeAnchorTests {
  /// The question that the anchor writes to the target.
  static let question = "Why?"

  /// The objects of one test.
  @MainActor struct Fixture {
    /// The target of the anchor.
    let target = SideCardTarget()
    /// The system that the anchor registers in.
    let system = CommandSystem()
    /// The path of the scope.
    let path = FocusPath.root(AgentScopeKind.sideCard(SessionId(rawValue: "anchor")))
    /// The host of the anchor, with no window.
    let hosting = NSHostingView<AnyView>(rootView: AnyView(EmptyView()))

    /// The anchor of the scope: it writes ``AgentScopeAnchorTests/question``
    /// to the target, and registers the side card verbs.
    var anchor: AgentScopeAnchor<SideCardTarget> {
      AgentScopeAnchor(
        target: target, system: system, path: path,
        unregister: SideCardRegistration.deregister(at:from:),
        write: { target, _ in target.question = AgentScopeAnchorTests.question },
        register: { target, path, registry in
          SideCardRegistration.register(target, at: path, into: &registry)
        })
    }

    /// The ids of the commands at the path of the scope.
    var registeredIDs: Set<CommandID> {
      Set(self.system.registry.definitions(at: path).map(\.id))
    }

    /// Shows `view` in the host, and lays it out.
    ///
    /// - Parameter view: The view to show.
    func show(_ view: some View) {
      hosting.rootView = AnyView(view)
      hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
      hosting.layoutSubtreeIfNeeded()
    }
  }

  @Test func theAnchorWritesTheValuesToTheTargetWhenItMounts() {
    let fixture = Fixture()

    fixture.show(fixture.anchor)

    #expect(fixture.target.question == Self.question)
  }

  @Test func theAnchorRegistersTheCommandsAtThePathWhenItMounts() {
    let fixture = Fixture()

    fixture.show(fixture.anchor)

    #expect(fixture.registeredIDs == Set(SideCardVerb.allCases.map(\.id)))
  }

  @Test func theAnchorRemovesTheCommandsWhenItGoesAway() {
    let fixture = Fixture()
    fixture.show(fixture.anchor)

    fixture.show(EmptyView())

    #expect(fixture.registeredIDs.isEmpty)
  }
}
