#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import EditorStyle
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Hosted tests of a theme that sets its own tile tokens (card ^ey6v778).
  ///
  /// The tile tokens are EditorKit's `EditorStyle.tile`, so a theme or a host
  /// that sets them through `.editorStyle(_:)` changes each content tile of
  /// the kit. The tests show a transcript under a style with tile tokens
  /// unlike the default ones: a failed compaction, a tile with a border, and
  /// an expanded tool call, a tile with none, in two neighbouring rows. Each
  /// tile insets its content by the themed padding and puts the themed gap
  /// between its header and its body, and the themed margin separates the
  /// two rows. The frames are accessibility frames in screen points, and the
  /// y axis goes up.
  @Suite(.serialized, .hostedSerially) @MainActor struct ContentTileThemeHostedTests {
    /// A size that shows both rows of the transcript.
    static let tallSize = CGSize(width: 520, height: 1_400)

    /// The `toolCallId` of the tool call of the tests.
    static let toolCallID = "themed-tile-call"

    /// The themed inset of the content of a tile from its edge: unlike the
    /// default padding and unlike the other themed tokens.
    static let themedPadding: CGFloat = 22

    /// The themed space between the header and the body of a tile.
    static let themedGap: CGFloat = 15

    /// The themed space between two neighbouring tiles.
    static let themedMargin: CGFloat = 29

    /// The style of the tests: the default style with the themed tile tokens.
    static var themedStyle: EditorStyle {
      var style = EditorStyle.default
      style.tile = EditorStyle.Tile(padding: themedPadding, gap: themedGap, margin: themedMargin)
      return style
    }

    /// Opens a scripted session whose transcript holds a failed compaction
    /// and then a tool call.
    ///
    /// When a send fails, the helper closes the session before it throws.
    ///
    /// - Returns: The session and the entry of the tool call.
    /// - Throws: The error of the transport, or an issue when the model holds
    ///   no tool call.
    static func openThread() async throws -> (ScriptedSession, ToolCallEntry) {
      let session = try await ScriptedSession.open()
      do {
        return (session, try await sendEntries(to: session))
      } catch {
        session.close()
        throw error
      }
    }

    /// Sends the failed compaction and then the tool call to `session`, and
    /// waits for the model to hold the tool call.
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The entry of the tool call.
    /// - Throws: The error of the transport, or an issue when the model holds
    ///   no tool call.
    static func sendEntries(to session: ScriptedSession) async throws -> ToolCallEntry {
      let model = session.model
      try await session.sendUpdate(
        CompactionAndNoticeHostedTests.compactionUpdate(
          #""status": "failed", "error": "\#(CompactionAndNoticeHostedTests.failureReason)""#))
      try await session.sendUpdate(
        WireBlockJSON.makeToolCallUpdate(id: toolCallID, fields: ToolCallViewHostedTests.readFields))
      await ObservationWait.until { ToolCallEntryViewHostedTests.toolCallEntry(toolCallID, in: model) != nil }
      return try #require(ToolCallEntryViewHostedTests.toolCallEntry(toolCallID, in: model))
    }

    /// Mounts the transcript of `session` under ``themedStyle``, with `call`
    /// expanded, and makes one render pass.
    ///
    /// - Parameters:
    ///   - session: The scripted session.
    ///   - call: The tool call entry to expand.
    /// - Returns: The harness.
    static func mountThemed(_ session: ScriptedSession, expanding call: ToolCallEntry) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: tallSize) {
        ConversationView(session: session.model)
          .environment(\.expandedBlocksStore, ToolCallViewHostedTests.makeExpandedStore(for: call))
          .editorStyle(themedStyle)
          .transaction { $0.disablesAnimations = true }
      }
      harness.render()
      return harness
    }

    /// The frame of the row of the compaction of the tests: the tile with a
    /// border.
    ///
    /// - Parameter harness: The harness that shows the transcript.
    /// - Returns: The frame of the row.
    /// - Throws: An issue when the transcript shows no such row.
    static func compactionRow(in harness: HostedViewHarness<some View>) throws -> CGRect {
      try #require(harness.frame(identifier: ItemRow.identifier(for: CompactionAndNoticeHostedTests.compactionKey)))
    }

    /// The frame of the header text of the compaction of the tests.
    ///
    /// - Parameter harness: The harness that shows the transcript.
    /// - Returns: The frame of the title, the element of the title and the
    ///   status.
    /// - Throws: An issue when the compaction shows no header.
    static func compactionHeader(in harness: HostedViewHarness<some View>) throws -> CGRect {
      try #require(
        harness.frame(identifier: CompactionEntryView.identifier(for: CompactionAndNoticeHostedTests.compactionKey)))
    }

    /// The frame of the error of the compaction of the tests: the first part
    /// of its body.
    ///
    /// - Parameter harness: The harness that shows the transcript.
    /// - Returns: The frame of the error text.
    /// - Throws: An issue when the compaction shows no error.
    static func compactionError(in harness: HostedViewHarness<some View>) throws -> CGRect {
      try #require(harness.frame(identifier: CompactionEntryView.errorIdentifier))
    }

    /// The frame of the toggle of `call`: the header of the tile with no
    /// border.
    ///
    /// - Parameters:
    ///   - call: The tool call entry.
    ///   - harness: The harness that shows the transcript.
    /// - Returns: The frame of the toggle.
    /// - Throws: An issue when the call shows no toggle.
    static func toggle(of call: ToolCallEntry, in harness: HostedViewHarness<some View>) throws -> CGRect {
      try #require(harness.frame(identifier: ToolCallView.toggleIdentifier(for: call.id.rowKey)))
    }

    @Test func theThemedPaddingInsetsTheTileWithABorder() async throws {
      let (session, call) = try await Self.openThread()
      defer { session.close() }
      let harness = Self.mountThemed(session, expanding: call)
      defer { harness.close() }

      let row = try Self.compactionRow(in: harness)
      let header = try Self.compactionHeader(in: harness)
      let error = try Self.compactionError(in: harness)

      ContentTileInsetHostedTests.expectLength(row.maxY - header.maxY, is: Self.themedPadding, "top inset")
      ContentTileInsetHostedTests.expectLength(error.minX - row.minX, is: Self.themedPadding, "leading inset")
    }

    @Test func theThemedGapSeparatesTheHeaderAndTheBodyOfTheTileWithABorder() async throws {
      let (session, call) = try await Self.openThread()
      defer { session.close() }
      let harness = Self.mountThemed(session, expanding: call)
      defer { harness.close() }

      let header = try Self.compactionHeader(in: harness)
      let error = try Self.compactionError(in: harness)

      // The frame of the header text is the title. Below it stands the status,
      // one line of the text style of the error, and then the gap of the tile.
      let statusLine = EditorStyle.default.spacing.xs + error.height

      ContentTileInsetHostedTests.expectLength(
        header.minY - error.maxY, is: statusLine + Self.themedGap, "header-to-body gap")
    }

    @Test func theThemedPaddingInsetsTheTileWithNoBorder() async throws {
      let (session, call) = try await Self.openThread()
      defer { session.close() }
      let harness = Self.mountThemed(session, expanding: call)
      defer { harness.close() }

      let tile = try #require(harness.frame(identifier: ToolCallView.identifier(for: call.id.rowKey)))
      let toggle = try Self.toggle(of: call, in: harness)

      ContentTileInsetHostedTests.expectLength(tile.maxY - toggle.maxY, is: Self.themedPadding, "top inset")
      ContentTileInsetHostedTests.expectLength(toggle.minX - tile.minX, is: Self.themedPadding, "leading inset")
    }

    @Test func theThemedGapSeparatesTheHeaderAndTheBodyOfTheTileWithNoBorder() async throws {
      let (session, call) = try await Self.openThread()
      defer { session.close() }
      let harness = Self.mountThemed(session, expanding: call)
      defer { harness.close() }

      let toggle = try Self.toggle(of: call, in: harness)
      let body = try #require(harness.frame(identifier: ToolCallView.bodyIdentifier(for: call.id.rowKey)))

      ContentTileInsetHostedTests.expectLength(toggle.minY - body.maxY, is: Self.themedGap, "header-to-body gap")
    }

    @Test func theThemedMarginSeparatesTheTwoTiles() async throws {
      let (session, call) = try await Self.openThread()
      defer { session.close() }
      let harness = Self.mountThemed(session, expanding: call)
      defer { harness.close() }

      let compaction = try Self.compactionRow(in: harness)
      let toolCall = try #require(harness.frame(identifier: ItemRow.identifier(for: call.id.rowKey)))

      ContentTileInsetHostedTests.expectLength(compaction.minY - toolCall.maxY, is: Self.themedMargin, "margin")
    }
  }
#endif
