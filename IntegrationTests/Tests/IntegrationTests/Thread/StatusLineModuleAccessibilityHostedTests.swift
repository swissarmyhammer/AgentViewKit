#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import EditorTheme
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

    /// A short working folder, whose `directory` module shows one form.
    static let shortCwd = "/Users/me/Kit"

    /// The largest difference, in points, between the frame of a module
    /// element and the frame of its text.
    static let textFrameTolerance: CGFloat = 1

    /// A definition whose line shows only the `directory` module.
    static var directoryOnlyDefinition: StatusLineDefinition {
      get throws {
        var definition = StatusLines.defaultDefinition
        definition.format = try StatusLineFormat(parsing: "$directory")
        return definition
      }
    }

    /// The width of the text of the `directory` module of ``shortCwd`` in
    /// the font of the line.
    static var shortDirectoryTextWidth: CGFloat {
      get throws {
        let input = StatusLineInput(
          cwd: shortCwd, homeFolder: homeFolder.path(percentEncoded: false), sessionTitle: sessionTitle)
        let rendering = StatusLineRenderer.render(try directoryOnlyDefinition, input: input)
        let piece = try #require(rendering.pieces.first { $0.module == .directory })
        return NSHostingView(rootView: PieceTextProbe(piece: piece)).fittingSize.width
      }
    }

    /// The text of one part of the line in the font of the line, with no
    /// element and no frame of its own.
    struct PieceTextProbe: View {
      /// The part of the line.
      let piece: StatusLinePiece

      @Environment(\.editorTheme) private var editorTheme

      var body: some View {
        StatusLinePieceText(piece: piece)
          .font(editorTheme.font(for: .ui, style: StatusLineContent.textStyle))
          .lineLimit(1)
      }
    }

    /// The modules that the status line action of the tests got, in order.
    @MainActor final class ActionLog {
      /// The module of each run of the action.
      var modules: [StatusLineModuleID] = []
    }

    /// Mounts the header of a root session, whose status line action records
    /// each module in `log`.
    ///
    /// - Parameters:
    ///   - log: The log of the action.
    ///   - folder: The working folder of the session.
    ///   - definition: The status line definition.
    /// - Returns: The harness, after one render pass.
    static func mountHeader(
      log: ActionLog = ActionLog(), folder: String = cwd,
      definition: StatusLineDefinition = StatusLines.defaultDefinition
    ) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: size) {
        ThreadStatusHeader(
          session: .preview(cwd: AbsolutePath(rawValue: folder)), connection: .preview(),
          sessionTitle: sessionTitle, contextMenuPath: nil, select: { _ in }
        )
        .statusLine(definition)
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

    /// A production change that fails this test: an accessibility shape on
    /// the line goes to the one module of the line, so the module has the
    /// frame of the line, where a tap does nothing.
    @Test func theOneModuleOfALineIsNarrowerThanTheLine() throws {
      let harness = Self.mountHeader(folder: Self.shortCwd, definition: try Self.directoryOnlyDefinition)
      defer { harness.close() }

      let line = try #require(harness.frame(identifier: StatusLineView.identifier))
      let module = try #require(harness.frame(identifier: Self.directoryIdentifier))

      #expect(module.width > 0 && module.width < line.width, "line \(line), module \(module)")
    }

    /// A production change that fails this test: the one module of the line
    /// has a frame that is not the frame of its text.
    @Test func theOneModuleOfALineHasTheWidthOfItsText() throws {
      let textWidth = try Self.shortDirectoryTextWidth
      let harness = Self.mountHeader(folder: Self.shortCwd, definition: try Self.directoryOnlyDefinition)
      defer { harness.close() }

      let module = try #require(harness.frame(identifier: Self.directoryIdentifier))

      #expect(abs(module.width - textWidth) <= Self.textFrameTolerance, "module \(module), text \(textWidth)")
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
