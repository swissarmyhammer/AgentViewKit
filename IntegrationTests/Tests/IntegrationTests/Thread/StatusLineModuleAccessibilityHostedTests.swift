#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import EditorTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Tests that the modules of the status line of a root session are button
  /// elements, and that the glass of the header is one container element
  /// (^y43c2hw).
  ///
  /// A root session has no crumbs. VoiceOver presses a module through its
  /// element, and a UI test of the host, such as TestudoApp, reads the frame
  /// of each module and of the glass, so that it can find a point of the
  /// glass that is not on a control. Each test mounts a
  /// ``ThreadStatusHeader`` of a root session with a working folder, and
  /// reads the accessibility tree of the window.
  @Suite(.serialized, .hostedSerially) @MainActor struct StatusLineModuleAccessibilityHostedTests {
    /// The size of the window.
    static let size = CGSize(width: 640, height: 120)

    /// The working folder of the session of the tests.
    static let cwd = "/Users/me/code/Kit"

    /// The home folder that the `directory` module shows as `~`.
    static let homeFolder = URL(filePath: "/Users/me", directoryHint: .isDirectory)

    /// The title of the session: not the name of the folder, so that the
    /// line shows the `directory` and the `session` module.
    static let sessionTitle = "Review"

    /// The accessibility identifier of the `directory` module.
    static let directoryIdentifier = StatusLineView.identifier(for: .directory)

    /// The modules that the status line action of the tests got, in order.
    @MainActor final class ActionLog {
      /// The module of each run of the action.
      var modules: [StatusLineModuleID] = []
    }

    /// Mounts the header of a root session with ``cwd``, whose status line
    /// action records each module in `log`.
    ///
    /// - Parameter log: The log of the action.
    /// - Returns: The harness, after one render pass.
    static func mountHeader(log: ActionLog = ActionLog()) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: size) {
        ThreadStatusHeader(
          session: .preview(cwd: AbsolutePath(rawValue: cwd)), connection: .preview(),
          sessionTitle: sessionTitle, contextMenuPath: nil, select: { _ in }
        )
        .statusLineHomeFolder(homeFolder)
        .statusLineActions { module, _ in log.modules.append(module) }
        .transaction { $0.disablesAnimations = true }
      }
      harness.render()
      return harness
    }

    /// A production change that fails this test: the line of a root session
    /// is one element with no child again, so the module has no element.
    @Test func theDirectoryModuleIsAButtonInsideTheLine() {
      let harness = Self.mountHeader()
      defer { harness.close() }

      let roles = harness.elements(under: StatusLineView.identifier)
        .filter { $0.identifier == Self.directoryIdentifier }.map(\.role)

      #expect(roles == [NSAccessibility.Role.button.rawValue])
    }

    /// A production change that fails this test: the module has no
    /// accessibility action, so a press runs no host command.
    @Test func aPressOfTheDirectoryModuleRunsItsActionOneTime() throws {
      let log = ActionLog()
      let harness = Self.mountHeader(log: log)
      defer { harness.close() }

      try harness.perform(.press, on: Self.directoryIdentifier)

      #expect(log.modules == [.directory])
    }

    /// A production change that fails this test: the glass of the header has
    /// no element, or its frame does not hold the line.
    @Test func theFrameOfTheHeaderHoldsTheFrameOfTheLine() throws {
      let harness = Self.mountHeader()
      defer { harness.close() }

      let header = try #require(harness.frame(identifier: ThreadStatusHeader.identifier))
      let line = try #require(harness.frame(identifier: StatusLineView.identifier))

      #expect(header.contains(line), "header \(header), line \(line)")
    }

    /// A production change that fails this test: the line loses its label or
    /// its value, so VoiceOver does not read the text of the line or the
    /// full path of the folder.
    @Test func theLineKeepsItsLabelAndItsValue() throws {
      let harness = Self.mountHeader()
      defer { harness.close() }

      let line = try #require(harness.element(identifier: StatusLineView.identifier))

      #expect(line.label?.contains(Self.sessionTitle) == true)
      #expect([line.value, line.valueDescription].contains(Self.cwd))
    }
  }
#endif
