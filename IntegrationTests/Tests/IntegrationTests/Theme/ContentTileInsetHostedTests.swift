#if DEBUG
  import AppKit
  import EditorStyle
  import EditorTestSupport
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Hosted tests of the tile tokens on two content tiles (card ^ey6v778): a
  /// bordered tile, the card of a permission request, and a tile whose fill
  /// is clear, terminal output.
  ///
  /// Each tile insets its content from its edge by the tile padding
  /// (`.contentTile()`), and puts the tile gap between its header and its
  /// body (`ContentTileStack`). The tests read the accessibility frames of
  /// the parts of each tile, and the frame of the `NSTextView` of the
  /// terminal output. Each frame is in screen points, and the y axis goes up.
  @Suite(.serialized, .hostedSerially) @MainActor struct ContentTileInsetHostedTests {
    /// The largest difference, in points, between two lengths that a test
    /// counts as the same length. An accessibility frame can be rounded to a
    /// whole pixel, and the window of the harness takes the backing scale of
    /// the machine: one on a runner of CI, two on a Retina display.
    static let layoutTolerance: CGFloat = 1

    /// The display scales of a request card: a runner of CI has a scale of
    /// one, and a Retina display has a scale of two.
    nonisolated static let displayScales: [CGFloat] = [1, 2]

    /// The largest distance, in points, from the top of the accessibility
    /// frame of a request card with no tile padding to the top of the frame
    /// of its title.
    ///
    /// The distance is not zero, and no part of it is padding. The frame of
    /// the card is the outer edge of its 1 pt stroke, which is centered on
    /// the edge, so it reaches 0.5 pt past the layout. That stroke sits on an
    /// edge that snaps to a whole pixel, 0.46 pt at a scale of one. The frame
    /// of the title is 16 pt high, in the 16.08 pt box of its `Label`. These
    /// parts come to 1.04 pt at a scale of one, and to 0.54 pt at a scale of
    /// two, where the snap moves the edge 0.04 pt the other way.
    static let bareTitleLimit: CGFloat = 1.5

    /// The output of the terminal of the tests.
    static let output = "Build complete!"

    /// The tile tokens of the default style, which the tile views read.
    static let tile = EditorStyle.default.tile

    /// Expects that two lengths are the same within ``layoutTolerance``.
    ///
    /// - Parameters:
    ///   - measured: The length that the test measured.
    ///   - expected: The length of the tile token.
    ///   - what: The name of the length, for the message.
    static func expectLength(_ measured: CGFloat, is expected: CGFloat, _ what: String) {
      #expect(abs(measured - expected) <= layoutTolerance, "\(what): \(measured), expected \(expected)")
    }

    /// Mounts the terminal output of a command that exited, with a header,
    /// one line of output and a footer.
    ///
    /// - Parameter terminal: The terminal entry of a command that exited.
    /// - Returns: The harness, after one render pass.
    static func mountTerminal(_ terminal: TerminalEntry) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(TerminalView(entry: terminal))
      harness.render()
      return harness
    }

    /// Opens a scripted session with the terminal of a command that exited.
    ///
    /// - Returns: The session and the terminal entry.
    /// - Throws: The error of the transport.
    static func openExitedTerminal() async throws -> (ScriptedSession, TerminalEntry) {
      try await TerminalViewHostedTests.openTerminal(
        [
          TerminalViewHostedTests.headerFields,
          TerminalViewHostedTests.outputField(output),
          #""exitStatus": {"exitCode": \#(TerminalViewHostedTests.successExitCode)}"#,
        ].joined(separator: ", "))
    }

    /// The frame of the first option button of the request card in
    /// `harness`: the first part of the body of the card.
    ///
    /// - Parameter harness: The harness of the card.
    /// - Returns: The frame of the Allow Once button.
    /// - Throws: An issue when the card has no such button.
    static func firstOptionFrame(in harness: HostedViewHarness<some View>) throws -> CGRect {
      try #require(
        harness.frame(
          identifier: PermissionView.optionIdentifier(for: PermissionViewHostedTests.optionID(.allowOnce))))
    }

    /// The frames of the parts of a request card at one tile padding and one
    /// display scale.
    ///
    /// - Parameters:
    ///   - pending: The pending request of the card.
    ///   - session: The scripted session that holds the request.
    ///   - padding: The tile padding of the style of the card.
    ///   - displayScale: The display scale of the card.
    /// - Returns: The frames of the card, the title and the first option.
    /// - Throws: An issue when the card has no such part.
    static func cardFrames(
      of pending: PendingPermissionRequest, in session: ScriptedSession, padding: CGFloat, displayScale: CGFloat
    ) throws -> (card: CGRect, title: CGRect, firstOption: CGRect) {
      var style = EditorStyle.default
      style.tile.padding = padding
      let harness = HostedViewHarness(size: PermissionViewHostedTests.cardSize) {
        PermissionView(request: pending, session: session.model)
          .environment(\.editorStyle, style)
          .environment(\.displayScale, displayScale)
          .transaction { $0.disablesAnimations = true }
      }
      harness.render()
      defer { harness.close() }
      return (
        try #require(harness.frame(identifier: PermissionView.identifier)),
        try #require(harness.frame(identifier: PermissionView.titleIdentifier)),
        try firstOptionFrame(in: harness)
      )
    }

    @Test(arguments: displayScales)
    func theRequestCardInsetsItsContentByTheTilePadding(displayScale: CGFloat) async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let pending = try await session.receivePermissionRequest(
        id: PermissionViewHostedTests.agentRequestID, params: PermissionViewHostedTests.makeParams())

      let padded = try Self.cardFrames(of: pending, in: session, padding: Self.tile.padding, displayScale: displayScale)
      let bare = try Self.cardFrames(of: pending, in: session, padding: 0, displayScale: displayScale)

      Self.expectLength(padded.firstOption.minX - padded.card.minX, is: Self.tile.padding, "leading inset")
      // The two cards differ only in the padding, so the parts of ``bareTitleLimit`` cancel
      // and the difference is the padding itself, at each scale.
      let paddedInset = padded.card.maxY - padded.title.maxY
      let bareInset = bare.card.maxY - bare.title.maxY
      #expect(paddedInset - bareInset == Self.tile.padding, "top inset: \(paddedInset) less \(bareInset)")
      #expect(bareInset <= Self.bareTitleLimit, "bare top inset: \(bareInset)")
    }

    @Test func theRequestCardPutsTheTileGapBetweenItsHeaderAndItsBody() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = try await PermissionViewHostedTests.mountCard(in: session)
      defer { harness.close() }

      let title = try #require(harness.frame(identifier: PermissionView.titleIdentifier))
      let firstOption = try Self.firstOptionFrame(in: harness)

      Self.expectLength(title.minY - firstOption.maxY, is: Self.tile.gap, "header-to-body gap")
    }

    @Test func theTerminalOutputStartsOnTheLeadingEdgeOfTheHeader() async throws {
      let (session, terminal) = try await Self.openExitedTerminal()
      defer { session.close() }
      let harness = Self.mountTerminal(terminal)
      defer { harness.close() }

      let tile = try #require(harness.frame(identifier: TerminalView.identifier))
      let textView = try #require(views(ofType: NSTextView.self, in: harness.hostingView).first)
      let output = harness.screenFrame(of: textView)

      Self.expectLength(output.minX - tile.minX, is: Self.tile.padding, "leading inset of the output")
    }

    @Test func theTerminalOutputHasTheTileGapAboveAndBelowIt() async throws {
      let (session, terminal) = try await Self.openExitedTerminal()
      defer { session.close() }
      let harness = Self.mountTerminal(terminal)
      defer { harness.close() }

      let command = try #require(harness.frame(identifier: TerminalView.commandIdentifier))
      let footer = try #require(harness.frame(identifier: TerminalView.footerIdentifier))
      let textView = try #require(views(ofType: NSTextView.self, in: harness.hostingView).first)
      let output = harness.screenFrame(of: textView)

      Self.expectLength(command.minY - output.maxY, is: Self.tile.gap, "header-to-body gap")
      Self.expectLength(output.minY - footer.maxY, is: Self.tile.gap, "body-to-footer gap")
    }

    @Test func theTerminalOutputInsetsItsHeaderAndFooterByTheTilePadding() async throws {
      let (session, terminal) = try await Self.openExitedTerminal()
      defer { session.close() }
      let harness = Self.mountTerminal(terminal)
      defer { harness.close() }

      let tile = try #require(harness.frame(identifier: TerminalView.identifier))
      let command = try #require(harness.frame(identifier: TerminalView.commandIdentifier))
      let footer = try #require(harness.frame(identifier: TerminalView.footerIdentifier))

      Self.expectLength(tile.maxY - command.maxY, is: Self.tile.padding, "top inset")
      Self.expectLength(footer.minY - tile.minY, is: Self.tile.padding, "bottom inset")
    }
  }
#endif
