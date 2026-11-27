#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import EditorTestSupport
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

    /// Mounts the header of a root session, whose status line action records
    /// each module in `log`.
    ///
    /// - Parameters:
    ///   - log: The log of the action.
    ///   - folder: The working folder of the session.
    ///   - definition: The status line definition.
    /// - Returns: The harness, after one render pass.
    static func mountHeader(
      log: StatusLineActionLog = StatusLineActionLog(), folder: String = StatusLineModuleFixtures.cwd,
      definition: StatusLineDefinition = StatusLines.defaultDefinition
    ) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: size) {
        StatusLineModuleFixtures.header(folder: folder, log: log, definition: definition)
          .transaction { $0.disablesAnimations = true }
      }
      harness.render()
      return harness
    }

    /// Mounts the header of a root session with the short working folder,
    /// whose line shows only the `directory` module.
    ///
    /// - Returns: The harness, after one render pass.
    /// - Throws: An error when the format of the definition does not parse.
    static func mountDirectoryOnlyHeader() throws -> HostedViewHarness<some View> {
      mountHeader(
        folder: StatusLineModuleFixtures.shortCwd, definition: try StatusLineModuleFixtures.directoryOnlyDefinition)
    }

    /// A production change that fails this test: the line of a root session
    /// is one element with no child again, so the module has no element.
    @Test func theDirectoryModuleIsAButtonInsideTheLine() {
      let harness = Self.mountHeader()
      defer { harness.close() }

      let roles = harness.elements(under: StatusLineView.identifier)
        .filter { $0.identifier == StatusLineModuleFixtures.directoryIdentifier }.map(\.role)

      #expect(roles == [NSAccessibility.Role.button.rawValue])
    }

    /// A production change that fails this test: the module has no
    /// accessibility action, so a press runs no host command.
    @Test func aPressOfTheDirectoryModuleRunsItsActionOneTime() throws {
      let log = StatusLineActionLog()
      let harness = Self.mountHeader(log: log)
      defer { harness.close() }

      try harness.perform(.press, on: StatusLineModuleFixtures.directoryIdentifier)

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

    /// A production change that fails this test: an accessibility shape on
    /// the line goes to the one module of the line, so the module has the
    /// frame of the line, where a tap does nothing.
    @Test func theOneModuleOfALineIsNarrowerThanTheLine() throws {
      let harness = try Self.mountDirectoryOnlyHeader()
      defer { harness.close() }

      let line = try #require(harness.frame(identifier: StatusLineView.identifier))
      let module = try #require(harness.frame(identifier: StatusLineModuleFixtures.directoryIdentifier))

      #expect(module.width > 0 && module.width < line.width, "line \(line), module \(module)")
    }

    /// A production change that fails this test: the one module of the line
    /// has a frame that is not the frame of its text.
    @Test func theOneModuleOfALineHasTheWidthOfItsText() throws {
      let textWidth = try StatusLineModuleFixtures.directoryTextWidth(folder: StatusLineModuleFixtures.shortCwd)
      let harness = try Self.mountDirectoryOnlyHeader()
      defer { harness.close() }

      let module = try #require(harness.frame(identifier: StatusLineModuleFixtures.directoryIdentifier))

      #expect(
        abs(module.width - textWidth) <= StatusLineModuleFixtures.textFrameTolerance,
        "module \(module), text \(textWidth)")
    }

    /// A production change that fails this test: the line loses its label or
    /// its value, so VoiceOver does not read the text of the line or the
    /// full path of the folder.
    ///
    /// The line is an `.accessibilityElement(children: .contain)` container.
    /// SwiftUI puts the value of a container in its value description alone,
    /// and VoiceOver reads it from there. Thus the test reads only that field,
    /// as the unit test `StatusLineModuleAccessibilityTests` does.
    @Test func theLineKeepsItsLabelAndItsValue() throws {
      let harness = Self.mountHeader()
      defer { harness.close() }

      let line = try #require(harness.element(identifier: StatusLineView.identifier))

      #expect(line.label?.contains(StatusLineModuleFixtures.sessionTitle) == true)
      #expect(line.valueDescription == StatusLineModuleFixtures.cwd)
    }
  }
#endif
