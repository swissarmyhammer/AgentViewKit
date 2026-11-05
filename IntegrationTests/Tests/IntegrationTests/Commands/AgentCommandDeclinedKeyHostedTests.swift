import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsTestSupport
import EditorCommandsUI
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The agent command target that a ``CommandTargetCaptureView`` reads from
/// the environment of an agent command scope.
@MainActor final class CommandTargetCapture {
  /// The target of the nearest agent command scope, or `nil` before the
  /// first render.
  var target: AgentCommandTarget?
}

/// A zero-size view that records the agent command target of the nearest
/// agent command scope on each render.
struct CommandTargetCaptureView: NSViewRepresentable {
  /// The capture that gets the target.
  let capture: CommandTargetCapture

  func makeNSView(context: Context) -> NSView {
    capture.target = context.environment.agentCommandTarget
    return NSView(frame: .zero)
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    capture.target = context.environment.agentCommandTarget
  }
}

/// A key that an agent command declines goes on to the next binding of its
/// chord (EditorKit ^jaxzzkn, AVK ^zb5td6w).
///
/// The decision for ``AgentCommand``: a declined key falls through. The
/// command declines when it has no target, or when the verb is not available
/// at the run; EditorKit checks that same availability just before the run,
/// so a key meets neither. The one decline a key meets is Focus Composer when
/// the composer cannot take the focus: the command did nothing, so the key
/// goes on to the next binding, as a key that no command binds does.
///
/// The test binds a chord that no agent verb uses to Focus Composer at the
/// thread scope, and the same chord to a recording command of the host at the
/// scope around the thread. It drives the chord through
/// `CommandRegistry.performKey(_:mode:at:payload:)`, the key path of the
/// registry, as the deck and navigation tests do.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentCommandDeclinedKeyHostedTests {
  /// The segment of the scope of the host around the thread.
  static let hostSegment = FocusSegment(kind: "declineHost")

  /// A chord that no agent verb binds: Control-Command-F.
  static let chord: KeyChord = "⌃⌘F"

  /// The id of the recording command of the host.
  nonisolated static let fallbackID: CommandID = "host.fallback"

  @Test func aKeyThatFocusComposerDeclinesRunsTheNextBindingOfTheChord() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let capture = CommandTargetCapture()
    let harness = HostedViewHarness(size: AgentCommandScopeHostedTests.windowSize) {
      AgentThreadView(session: session.model, connection: session.connection) {
        CommandTargetCaptureView(capture: capture)
      }
      .commandScope(segment: Self.hostSegment)
      .commandSystem(system)
    }
    defer { harness.close() }
    harness.render()
    let focusRequests = ReportRecorder<Bool>()
    let reportFocus = focusRequests.report
    try #require(capture.target).composer = AgentComposerHook(
      owner: ObjectIdentifier(capture), canSubmit: { false }, submit: {}, load: { _ in },
      focus: {
        reportFocus(false)
        return false
      })
    let thread = FocusPath.root(Self.hostSegment).appending(AgentCommandTarget.segment(for: session.model))
    system.registry.bindKey(
      Self.chord.asSequence, to: .command(AgentCommandVerb.focusComposer.id), mode: .cua, at: thread)
    let fallbacks = CommandRunLog()
    system.registry.register(
      .makeRecording(id: Self.fallbackID, keys: [.cua: Self.chord], log: fallbacks), at: .root(Self.hostSegment))

    #expect(system.registry.performKey(Self.chord.asSequence, mode: .cua, at: thread))

    #expect(focusRequests.values == [false])
    #expect(fallbacks.runs.map(\.id) == [Self.fallbackID])
  }
}
