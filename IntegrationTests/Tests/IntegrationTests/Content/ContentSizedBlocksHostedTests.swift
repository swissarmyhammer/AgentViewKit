#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The text of a hosted block, which a test changes while the block shows.
  @Observable
  final class BlockText {
    /// The text that the block shows.
    var text: String

    /// Makes a source with `text`.
    init(_ text: String) {
      self.text = text
    }
  }

  /// One block of output in the scroll view of its host, in a window shorter
  /// than a long output, with the frame that the block lays out at.
  @MainActor struct ContentSizedBed {
    /// The width of the window: narrow, so a long line has to wrap.
    static let width: CGFloat = 320

    /// The height of the window: shorter than ``tallText``.
    static let height: CGFloat = 160

    /// The number of lines of ``tallText``.
    static let tallLineCount = 40

    /// The number of lines of ``threeLines``.
    static let shortLineCount = 3

    /// The number of words of ``longLine``.
    static let longLineWordCount = 80

    /// One short line.
    static let oneLine = "one line"

    /// A text of more lines than the window shows.
    static let tallText = (1...tallLineCount).map { "line \($0)" }.joined(separator: "\n")

    /// A text of three short lines.
    static let threeLines = (1...shortLineCount).map { "line \($0)" }.joined(separator: "\n")

    /// One line that is far wider than the window.
    static let longLine = Array(repeating: "wrap", count: longLineWordCount).joined(separator: " ")

    /// The harness that shows the scroll view of the host.
    let harness: HostedViewHarness<AnyView>

    /// The height of the window.
    let windowHeight: CGFloat

    /// The frame of the block.
    let recorder: FrameRecorder

    /// Mounts `block` in the scroll view of a host, and waits for its first
    /// layout.
    ///
    /// - Parameters:
    ///   - block: The block of output.
    ///   - windowHeight: The height of the window.
    init(_ block: some View, windowHeight: CGFloat = height) async {
      let recorder = FrameRecorder()
      self.recorder = recorder
      self.windowHeight = windowHeight
      harness = HostedViewHarness(
        AnyView(ScrollView { block.recordFrame(into: recorder) }),
        size: CGSize(width: Self.width, height: windowHeight))
      await settle(until: { (recorder.frame?.height ?? 0) > 0 })
    }

    /// The height of the block, or zero before its first layout.
    var height: CGFloat { recorder.frame?.height ?? 0 }

    /// Waits until the block is taller than the window, and the scroll view
    /// of the host is the one scroll view that scrolls.
    ///
    /// - Returns: Whether both hold before the wait gives up.
    func growsPastTheWindowAndScrollsAsOne() async -> Bool {
      let recorder = recorder
      let windowHeight = windowHeight
      let hosting = harness.hostingView
      return await settle(until: { (recorder.frame?.height ?? 0) > windowHeight && hosting.scrollsAsOne })
    }

    /// The height of `block` when it shows alone in a bed, once its layout
    /// has settled.
    ///
    /// - Parameter block: The block of output.
    /// - Returns: The height of its frame.
    static func settledHeight(of block: some View) async -> CGFloat {
      let bed = await ContentSizedBed(block)
      defer { bed.harness.close() }
      await settle()
      return bed.height
    }

    /// Waits until `block` is taller than `reference`: a long line that wraps
    /// takes more rows than the lines of the reference.
    ///
    /// - Parameters:
    ///   - block: The block of output.
    ///   - reference: The height to pass.
    /// - Returns: Whether the block passes the height before the wait gives up.
    static func grows(_ block: some View, tallerThan reference: CGFloat) async -> Bool {
      let bed = await ContentSizedBed(block)
      defer { bed.harness.close() }
      let recorder = bed.recorder
      return await settle(until: { (recorder.frame?.height ?? 0) > reference })
    }

    /// Mounts `block`, runs `grow`, which gives the block ``tallText``, and
    /// waits until the block is taller than the window and the scroll view of
    /// the host is the one scroll view that scrolls.
    ///
    /// - Parameters:
    ///   - block: The block, which shows a short text.
    ///   - windowHeight: The height of the window.
    ///   - grow: Changes the text of the block to ``tallText``.
    /// - Returns: Whether the block grew past the window and scrolls as one.
    /// - Throws: The error of `grow`.
    static func growsWithItsText(
      _ block: some View, windowHeight: CGFloat = height, grow: () async throws -> Void
    ) async rethrows -> Bool {
      let bed = await ContentSizedBed(block, windowHeight: windowHeight)
      defer { bed.harness.close() }
      try await grow()
      return await bed.growsPastTheWindowAndScrollsAsOne()
    }

    /// Whether the block that `make` builds wraps a long line: the block of
    /// ``longLine`` grows taller than the block of ``threeLines``.
    ///
    /// - Parameter make: Builds the block that shows a text.
    /// - Returns: Whether the long line takes more rows than three lines.
    /// - Throws: The error of `make`.
    static func wrapsALongLine<Block: View>(_ make: (String) async throws -> Block) async rethrows -> Bool {
      let short = try await make(threeLines)
      let shortHeight = await settledHeight(of: short)
      let long = try await make(longLine)
      return await grows(long, tallerThan: shortHeight)
    }
  }

  /// A multiline block of the kit takes the height of its content, grows as
  /// the content grows, wraps a long line to its width, and has no scroll of
  /// its own: the host scrolls it (style.md, "A multiline field fits its
  /// content").
  ///
  /// A production change that fails these tests: the editor of a block stops
  /// at a height of its own and scrolls inside the host, or keeps a long line
  /// on one row and scrolls it sideways.
  @Suite(.serialized, .hostedSerially) @MainActor struct ContentSizedBlocksHostedTests {
    /// A code block over `source`.
    ///
    /// - Parameter source: The code.
    /// - Returns: The block.
    static func codeBlock(_ source: BlockText) -> some View {
      BlockTextView(source: source) { CodeBlockView(code: $0, language: nil) }
    }

    /// A command output block over `source`.
    ///
    /// - Parameter source: The output.
    /// - Returns: The block.
    static func commandOutput(_ source: BlockText) -> some View {
      BlockTextView(source: source) { CommandOutputView(command: "make", output: $0, exitCode: nil) }
    }

    // MARK: - Code block

    @Test func aCodeBlockGrowsWithItsCodeAndTheHostScrollsIt() async {
      let source = BlockText(ContentSizedBed.oneLine)

      #expect(await ContentSizedBed.growsWithItsText(Self.codeBlock(source)) { source.text = ContentSizedBed.tallText })
    }

    @Test func aCodeBlockWrapsALongLine() async {
      #expect(await ContentSizedBed.wrapsALongLine { Self.codeBlock(BlockText($0)) })
    }

    // MARK: - Command output

    @Test func aCommandOutputGrowsWithItsOutputAndTheHostScrollsIt() async {
      let source = BlockText(ContentSizedBed.oneLine)

      #expect(
        await ContentSizedBed.growsWithItsText(Self.commandOutput(source)) { source.text = ContentSizedBed.tallText })
    }

    @Test func aCommandOutputWrapsALongLine() async {
      #expect(await ContentSizedBed.wrapsALongLine { Self.commandOutput(BlockText($0)) })
    }

    // MARK: - Terminal

    @Test func aTerminalGrowsWithItsOutputAndTheHostScrollsIt() async throws {
      let (session, terminal) = try await TerminalViewHostedTests.openTerminal(
        TerminalViewHostedTests.outputField(ContentSizedBed.oneLine))
      defer { session.close() }

      #expect(
        try await ContentSizedBed.growsWithItsText(TerminalView(entry: terminal)) {
          try await session.sendUpdate(
            SessionEntryRowsHostedTests.terminalUpdate(TerminalViewHostedTests.outputField(ContentSizedBed.tallText)))
        })
    }

    @Test func aTerminalWrapsALongLine() async throws {
      var sessions: [ScriptedSession] = []
      defer {
        for session in sessions { session.close() }
      }

      #expect(
        try await ContentSizedBed.wrapsALongLine { output in
          let (session, terminal) = try await TerminalViewHostedTests.openTerminal(
            TerminalViewHostedTests.outputField(output))
          sessions.append(session)
          return TerminalView(entry: terminal)
        })
    }
  }

  /// A block that shows the text of a ``BlockText``, so a change of the text
  /// redraws the block.
  struct BlockTextView<Block: View>: View {
    /// The source of the text.
    let source: BlockText

    /// Makes the block of a text.
    let block: (String) -> Block

    var body: some View {
      block(source.text)
    }
  }
#endif
