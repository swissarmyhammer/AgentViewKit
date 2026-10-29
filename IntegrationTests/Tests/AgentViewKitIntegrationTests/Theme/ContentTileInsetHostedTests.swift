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
    /// counts as the same length. An accessibility frame is rounded to a
    /// whole pixel, and the window of the harness has a backing scale of
    /// one.
    static let layoutTolerance: CGFloat = 1

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

    @Test func theRequestCardInsetsItsContentByTheTilePadding() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = try await PermissionViewHostedTests.mountCard(in: session)
      defer { harness.close() }

      let card = try #require(harness.frame(identifier: PermissionView.identifier))
      let title = try #require(harness.frame(identifier: PermissionView.titleIdentifier))
      let firstOption = try Self.firstOptionFrame(in: harness)

      Self.expectLength(firstOption.minX - card.minX, is: Self.tile.padding, "leading inset")
      Self.expectLength(card.maxY - title.maxY, is: Self.tile.padding, "top inset")
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
