#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import EditorStyle
  import Foundation
  import FoundationModelsACP
  import SwiftUI
  import Testing

  @Suite(.serialized, .hostedSerially) @MainActor struct DiffViewHostedTests {
    /// A size that shows the file chips and the hunk actions.
    nonisolated static let tallSize = CGSize(width: 720, height: 900)

    /// A width too narrow for the two file chips of the fixture patch on one
    /// line.
    nonisolated static let narrowWidth: CGFloat = 160

    /// The widths of the layout tests: a narrow one and a wide one. It is
    /// `nonisolated` because the arguments of a test use it.
    nonisolated static let layoutWidths = [narrowWidth, tallSize.width]

    /// The largest difference that layout rounding makes between two edges, in
    /// points.
    static let layoutTolerance: CGFloat = 1

    /// The start of the accessibility identifier of the test renderer.
    static let rendererPrefix = "test-renderer-"

    /// The path of the first file of the fixture patch.
    static let firstPath = "Sources/App.swift"

    /// The path of the second file of the fixture patch.
    static let secondPath = "README.md"

    /// A patch with two files. The first file has two hunks.
    static let patch = """
      diff --git a/Sources/App.swift b/Sources/App.swift
      --- a/Sources/App.swift
      +++ b/Sources/App.swift
      @@ -1,2 +1,2 @@
       import SwiftUI
      -let name = "old"
      +let name = "new"
      @@ -10 +10,2 @@
       }
      +// end
      diff --git a/README.md b/README.md
      --- a/README.md
      +++ b/README.md
      @@ -1 +1 @@
      -# Old
      +# New

      """

    /// A patch with one file: the second file of ``patch``.
    static let oneFilePatch = """
      diff --git a/README.md b/README.md
      --- a/README.md
      +++ b/README.md
      @@ -1 +1 @@
      -# Old
      +# New

      """

    /// A record of the calls that the diff view makes.
    final class CallLog {
      /// The file and the hunk index of each accept call.
      var accepted: [(String, Int)] = []

      /// The file and the hunk index of each reject call.
      var rejected: [(String, Int)] = []

      /// Each attachment that the view gave.
      var attached: [DiffAttachment] = []
    }

    /// The accessibility identifier of the test renderer for `file`.
    ///
    /// - Parameter file: The file that the view gave to the renderer.
    /// - Returns: `test-renderer-<file>`, or `test-renderer-none`.
    static func rendererIdentifier(for file: String?) -> String {
      rendererPrefix + (file ?? "none")
    }

    /// Makes a harness that shows the fixture patch with actions that write
    /// to `log`.
    ///
    /// - Parameters:
    ///   - log: The record of the calls.
    ///   - installsRenderer: `true` to install the test renderer.
    ///   - width: The width of the harness.
    /// - Returns: The harness, after one render pass.
    static func mountDiff(
      log: CallLog, installsRenderer: Bool, width: CGFloat = tallSize.width
    ) -> HostedViewHarness<some View> {
      let view = Group {
        if installsRenderer {
          diffView(log: log)
            .diffRenderer { _, file in
              Text("Rendered \(file ?? "none")")
                .accessibilityIdentifier(rendererIdentifier(for: file))
            }
        } else {
          diffView(log: log)
        }
      }
      return DiffHarness.mount(view, size: CGSize(width: width, height: tallSize.height))
    }

    /// The diff view of the fixture patch with actions that write to `log`.
    ///
    /// - Parameter log: The record of the calls.
    /// - Returns: The view.
    static func diffView(log: CallLog) -> DiffView {
      DiffView(
        patch: patch,
        onAccept: { log.accepted.append(($0, $1)) },
        onReject: { log.rejected.append(($0, $1)) },
        onAttach: { log.attached.append($0) })
    }

    // MARK: - Slot

    @Test func withNoRendererTheEditorKitRendererShows() {
      let harness = Self.mountDiff(log: CallLog(), installsRenderer: false)
      defer { harness.close() }

      #expect(!harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.root).isEmpty)
      #expect(harness.element(identifier: Self.rendererIdentifier(for: Self.firstPath)) == nil)
    }

    @Test func anInstalledRendererReplacesTheEditorKitRenderer() {
      let harness = Self.mountDiff(log: CallLog(), installsRenderer: true)
      defer { harness.close() }

      #expect(harness.element(identifier: Self.rendererIdentifier(for: Self.firstPath)) != nil)
      #expect(harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.root).isEmpty)
    }

    // MARK: - Layout

    /// The diff is a content tile (card ^ey6v778): the detail takes the full
    /// width of the tile, inside the tile padding on each side.
    @Test(arguments: layoutWidths) func theDetailIsAsWideAsTheContentOfTheTile(width: CGFloat) throws {
      let harness = Self.mountDiff(log: CallLog(), installsRenderer: true, width: width)
      defer { harness.close() }
      // The tile padding of the default style, which the diff view reads.
      let padding = EditorStyle.default.tile.padding

      let view = try #require(harness.frame(identifier: DiffView.containerIdentifier))
      let detail = try #require(harness.frame(identifier: DiffView.detailIdentifier))
      #expect(abs(detail.width - (view.width - padding - padding)) <= Self.layoutTolerance)
      #expect(abs(detail.minX - (view.minX + padding)) <= Self.layoutTolerance)
    }

    @Test(arguments: layoutWidths) func theChipsAreAboveTheDetail(width: CGFloat) throws {
      let harness = Self.mountDiff(log: CallLog(), installsRenderer: true, width: width)
      defer { harness.close() }

      let detail = try #require(harness.frame(identifier: DiffView.detailIdentifier))
      for path in [Self.firstPath, Self.secondPath] {
        let chip = try #require(harness.frame(identifier: DiffFileChip.identifier(for: path)))
        // The y axis of the screen goes up, so the bottom edge of a chip is
        // `minY` and the top edge of the detail is `maxY`.
        #expect(chip.minY >= detail.maxY - Self.layoutTolerance, "chip \(path)")
      }
    }

    @Test func theChipsShareALineWhenTheyFit() throws {
      let harness = Self.mountDiff(log: CallLog(), installsRenderer: true)
      defer { harness.close() }

      let first = try #require(harness.frame(identifier: DiffFileChip.identifier(for: Self.firstPath)))
      let second = try #require(harness.frame(identifier: DiffFileChip.identifier(for: Self.secondPath)))
      #expect(abs(second.minY - first.minY) <= Self.layoutTolerance)
      #expect(second.minX >= first.maxX)
    }

    @Test func theChipsWrapToASecondLineWhenTheyDoNotFit() throws {
      let harness = Self.mountDiff(log: CallLog(), installsRenderer: true, width: Self.narrowWidth)
      defer { harness.close() }

      let first = try #require(harness.frame(identifier: DiffFileChip.identifier(for: Self.firstPath)))
      let second = try #require(harness.frame(identifier: DiffFileChip.identifier(for: Self.secondPath)))
      // The y axis of the screen goes up, so a chip on the line below the
      // first chip has its top edge, `maxY`, under the bottom edge of the
      // first chip, `minY`.
      #expect(second.maxY <= first.minY)
      #expect(abs(second.minX - first.minX) <= Self.layoutTolerance)
    }

    // MARK: - File chips

    @Test func eachFileHasAChipWithItsLanguageAndCounts() {
      let harness = Self.mountDiff(log: CallLog(), installsRenderer: false)
      defer { harness.close() }

      let first = harness.element(identifier: DiffFileChip.identifier(for: Self.firstPath))
      let second = harness.element(identifier: DiffFileChip.identifier(for: Self.secondPath))
      #expect(first?.label == "Swift diff, +2 \u{2212}1")
      #expect(second?.label == "Markdown diff, +1 \u{2212}1")
    }

    @Test func withOneFileTheChipShows() {
      let harness = DiffHarness.mount(DiffView(patch: Self.oneFilePatch), size: Self.tallSize)
      defer { harness.close() }

      let chip = harness.element(identifier: DiffFileChip.identifier(for: Self.secondPath))
      #expect(chip?.label == "Markdown diff, +1 \u{2212}1")
    }

    @Test func aPressOnAChipGivesThatFileToTheRenderer() throws {
      let harness = Self.mountDiff(log: CallLog(), installsRenderer: true)
      defer { harness.close() }
      let secondRenderer = Self.rendererIdentifier(for: Self.secondPath)
      #expect(harness.element(identifier: secondRenderer) == nil)

      try harness.press(identifier: DiffFileChip.identifier(for: Self.secondPath))

      #expect(harness.element(identifier: secondRenderer) != nil)
      #expect(harness.element(identifier: Self.rendererIdentifier(for: Self.firstPath)) == nil)
      #expect(harness.element(identifier: DiffView.acceptIdentifier(for: 0)) != nil)
      #expect(harness.element(identifier: DiffView.acceptIdentifier(for: 1)) == nil)
    }

    // MARK: - Actions

    @Test func theHunkButtonsKeepTheirTextAsTheirLabels() {
      let harness = Self.mountDiff(log: CallLog(), installsRenderer: false)
      defer { harness.close() }

      #expect(harness.element(identifier: DiffView.acceptIdentifier(for: 1))?.label == "Accept hunk 2")
      #expect(harness.element(identifier: DiffView.rejectIdentifier(for: 1))?.label == "Reject hunk 2")
    }

    @Test func aPressOnAcceptGivesTheFileAndTheHunkIndex() throws {
      let log = CallLog()
      let harness = Self.mountDiff(log: log, installsRenderer: false)
      defer { harness.close() }

      try harness.press(identifier: DiffView.acceptIdentifier(for: 1))

      #expect(log.accepted.count == 1)
      #expect(log.accepted.first?.0 == Self.firstPath)
      #expect(log.accepted.first?.1 == 1)
      #expect(log.rejected.isEmpty)
    }

    @Test func aPressOnRejectGivesTheFileAndTheHunkIndex() throws {
      let log = CallLog()
      let harness = Self.mountDiff(log: log, installsRenderer: false)
      defer { harness.close() }

      try harness.press(identifier: DiffView.rejectIdentifier(for: 0))

      #expect(log.rejected.count == 1)
      #expect(log.rejected.first?.0 == Self.firstPath)
      #expect(log.rejected.first?.1 == 0)
      #expect(log.accepted.isEmpty)
    }

    @Test func aPressOnAttachGivesTheChangedLinesOfTheFile() throws {
      let log = CallLog()
      let harness = Self.mountDiff(log: log, installsRenderer: false)
      defer { harness.close() }

      try harness.press(identifier: DiffView.attachIdentifier)

      #expect(
        log.attached == [
          DiffAttachment(
            file: Self.firstPath,
            lines: ["-let name = \"old\"", "+let name = \"new\"", "+// end"])
        ])
    }

    @Test func aRendererSelectionIsTheAttachedLines() throws {
      let log = CallLog()
      let harness = DiffHarness.mount(
        Self.diffView(log: log).diffRenderer { _, _ in SelectingRenderer() }, size: Self.tallSize)
      defer { harness.close() }

      try harness.press(identifier: SelectingRenderer.identifier)
      try harness.press(identifier: DiffView.attachIdentifier)

      #expect(
        log.attached == [DiffAttachment(file: Self.firstPath, lines: SelectingRenderer.lines)])
    }

    @Test func withNoActionsTheButtonsDoNotShow() {
      let harness = DiffHarness.mount(DiffView(patch: Self.patch), size: Self.tallSize)
      defer { harness.close() }

      #expect(harness.element(identifier: DiffFileChip.identifier(for: Self.firstPath)) != nil)
      #expect(harness.element(identifier: DiffView.acceptIdentifier(for: 0)) == nil)
      #expect(harness.element(identifier: DiffView.rejectIdentifier(for: 0)) == nil)
      #expect(harness.element(identifier: DiffView.attachIdentifier) == nil)
    }

    // MARK: - Structured diff

    /// An ACP diff with one added file and no patch text.
    static let structuredDiff = FoundationModelsACP.Diff(changes: [
      DiffChange(operation: .add(DiffPathChange(path: AbsolutePath(rawValue: "/p/new.swift"))))
    ])

    @Test func aDiffWithNoPatchTextShowsTheFileOfEachChange() {
      let harness = DiffHarness.mount(DiffView(diff: Self.structuredDiff), size: Self.tallSize)
      defer { harness.close() }

      let file = harness.element(identifier: DiffFileChip.identifier(for: "/p/new.swift"))
      #expect(file?.label == "Added Swift file")
      #expect(harness.element(identifier: DiffView.noPatchIdentifier) != nil)
      #expect(harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.root).isEmpty)
      #expect(harness.element(identifier: DiffView.attachIdentifier) == nil)
    }

    @Test func aDiffWithGitPatchTextShowsThePatch() {
      let diff = FoundationModelsACP.Diff(
        changes: [], patch: DiffPatch(format: .gitPatch, text: Self.patch))
      let harness = DiffHarness.mount(DiffView(diff: diff), size: Self.tallSize)
      defer { harness.close() }

      let first = harness.element(identifier: DiffFileChip.identifier(for: Self.firstPath))
      #expect(first?.label == "Swift diff, +2 \u{2212}1")
      #expect(!harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.root).isEmpty)
      #expect(harness.element(identifier: DiffView.noPatchIdentifier) == nil)
    }

    @Test func environmentActionsReachADiffInAToolCall() async throws {
      let log = CallLog()
      let patchText = try #require(String(data: JSONEncoder().encode(Self.patch), encoding: .utf8))
      let fields = #"""
        "title": "Edit", "kind": "edit", "status": "completed",
        "content": [{"type": "diff", "changes": [], "patch": {"format": "git_patch", "text": \#(patchText)}}]
        """#
      let (session, call) = try await ToolCallViewHostedTests.openCall(id: "diff-tool-call", fields: fields)
      defer { session.close() }
      let store = ToolCallViewHostedTests.makeExpandedStore(for: call)
      let view = ToolCallView(entry: call)
        .environment(\.expandedBlocksStore, store)
        .diffActions(
          DiffActions(
            onAccept: { log.accepted.append(($0, $1)) },
            onReject: nil,
            onAttach: nil))
      let harness = DiffHarness.mount(view, size: Self.tallSize)
      defer { harness.close() }

      #expect(!harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.root).isEmpty)
      #expect(harness.element(identifier: DiffView.rejectIdentifier(for: 0)) == nil)
      try harness.press(identifier: DiffView.acceptIdentifier(for: 0))

      #expect(log.accepted.first?.0 == Self.firstPath)
      #expect(log.accepted.first?.1 == 0)
    }
  }

  /// A test renderer that selects fixed lines when a person presses it.
  private struct SelectingRenderer: View {
    /// The accessibility identifier of the button.
    static let identifier = "selecting-renderer"

    /// The lines that the button selects.
    static let lines = ["+let name = \"new\""]

    @Environment(\.diffLineSelection) private var selection

    var body: some View {
      Button("Select") {
        selection?.lines = Self.lines
      }
      .accessibilityIdentifier(Self.identifier)
    }
  }
#endif
