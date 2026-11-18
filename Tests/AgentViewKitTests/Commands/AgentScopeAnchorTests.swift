import AgentViewKitTestSupport
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
/// Each test shows the anchor of a side card scope (``SideCardMount``, with
/// its production write and register steps) in an `NSHostingView` with no
/// window, and lays the view out. SwiftUI makes, updates and dismantles the
/// anchor in the layout pass, so no test waits, and no test shows a window
/// or takes the focus.
@MainActor struct AgentScopeAnchorTests {
  /// The question of the values of the card.
  static let question = "Why?"

  /// The objects of one test.
  @MainActor struct Fixture {
    /// The target of the anchor.
    let target = SideCardTarget()
    /// The system that the anchor registers in.
    let system = CommandSystem()
    /// The session model of the fork of the card.
    let session = SessionModel.preview(transcript: [.user(AgentScopeAnchorTests.question)])
    /// The path of the scope.
    let path = FocusPath.root(AgentScopeKind.sideCard(SessionId(rawValue: "anchor")))
    /// The host of the anchor, with no window.
    let hosting = NSHostingView<AnyView>(rootView: AnyView(EmptyView()))

    /// The mount of the scope: the anchor writes the values of the card to
    /// the target, and registers the side card verbs.
    var mount: SideCardMount {
      let values = SideCardValues(
        question: AgentScopeAnchorTests.question, session: session, open: {}, close: {},
        hostSend: nil)
      return SideCardMount(
        target: target,
        registration: SideCardMount.Registration(
          system: self.system, path: path, values: values, thread: nil, groupsOff: []))
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
      StyleViewHost.layOut(hosting)
    }
  }

  @Test func theAnchorWritesTheQuestionToTheTargetWhenItMounts() {
    let fixture = Fixture()

    fixture.show(fixture.mount)

    #expect(fixture.target.question == Self.question)
  }

  @Test func theAnchorWritesTheSessionToTheTargetWhenItMounts() {
    let fixture = Fixture()

    fixture.show(fixture.mount)

    #expect(fixture.target.session === fixture.session)
  }

  @Test func theAnchorRegistersTheCommandsAtThePathWhenItMounts() {
    let fixture = Fixture()

    fixture.show(fixture.mount)

    #expect(fixture.registeredIDs == Set(SideCardVerb.allCases.map(\.id)))
  }

  @Test func theAnchorRemovesTheCommandsWhenItGoesAway() {
    let fixture = Fixture()
    fixture.show(fixture.mount)
    #expect(fixture.registeredIDs == Set(SideCardVerb.allCases.map(\.id)))

    fixture.show(EmptyView())

    #expect(fixture.registeredIDs.isEmpty)
  }
}
