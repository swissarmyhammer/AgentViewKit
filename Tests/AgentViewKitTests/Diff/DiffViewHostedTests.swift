#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import Foundation
  import SwiftUI
  import Testing

  @Suite(.serialized, .hostedSerially) @MainActor struct DiffViewHostedTests {
    /// The longest time that a test waits for the view to change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows the file list and the hunk actions.
    static let tallSize = CGSize(width: 720, height: 900)

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
    /// - Returns: The harness, after one pump.
    static func mountDiff(log: CallLog, installsRenderer: Bool) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: tallSize) {
        Group {
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
        .transaction { $0.disablesAnimations = true }
      }
      harness.pump()
      return harness
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

      #expect(harness.element(identifier: DiffView.editorRendererIdentifier) != nil)
      #expect(harness.element(identifier: Self.rendererIdentifier(for: Self.firstPath)) == nil)
    }

    @Test func anInstalledRendererReplacesTheEditorKitRenderer() {
      let harness = Self.mountDiff(log: CallLog(), installsRenderer: true)
      defer { harness.close() }

      #expect(harness.element(identifier: Self.rendererIdentifier(for: Self.firstPath)) != nil)
      #expect(harness.element(identifier: DiffView.editorRendererIdentifier) == nil)
    }

    // MARK: - File list

    @Test func eachFileHasARowWithItsLanguageAndCounts() {
      let harness = Self.mountDiff(log: CallLog(), installsRenderer: false)
      defer { harness.close() }

      let first = harness.element(identifier: DiffView.identifier(for: Self.firstPath))
      let second = harness.element(identifier: DiffView.identifier(for: Self.secondPath))
      #expect(first?.label == "Swift diff, +2 \u{2212}1")
      #expect(second?.label == "Markdown diff, +1 \u{2212}1")
    }

    @Test func aPressOnAFileGivesThatFileToTheRenderer() async throws {
      let harness = Self.mountDiff(log: CallLog(), installsRenderer: true)
      defer { harness.close() }
      let secondRenderer = Self.rendererIdentifier(for: Self.secondPath)
      #expect(harness.element(identifier: secondRenderer) == nil)

      try harness.press(identifier: DiffView.identifier(for: Self.secondPath))
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: secondRenderer) != nil
      }

      #expect(harness.element(identifier: secondRenderer) != nil)
      #expect(harness.element(identifier: Self.rendererIdentifier(for: Self.firstPath)) == nil)
      #expect(harness.element(identifier: DiffView.acceptIdentifier(for: 0)) != nil)
      #expect(harness.element(identifier: DiffView.acceptIdentifier(for: 1)) == nil)
    }

    // MARK: - Actions

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
      let harness = HostedViewHarness(size: Self.tallSize) {
        Self.diffView(log: log)
          .diffRenderer { _, _ in SelectingRenderer() }
      }
      defer { harness.close() }
      harness.pump()

      try harness.press(identifier: SelectingRenderer.identifier)
      try harness.press(identifier: DiffView.attachIdentifier)

      #expect(
        log.attached == [DiffAttachment(file: Self.firstPath, lines: SelectingRenderer.lines)])
    }

    @Test func withNoActionsTheButtonsDoNotShow() {
      let harness = HostedViewHarness(size: Self.tallSize) { DiffView(patch: Self.patch) }
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: DiffView.identifier(for: Self.firstPath)) != nil)
      #expect(harness.element(identifier: DiffView.acceptIdentifier(for: 0)) == nil)
      #expect(harness.element(identifier: DiffView.rejectIdentifier(for: 0)) == nil)
      #expect(harness.element(identifier: DiffView.attachIdentifier) == nil)
    }

    @Test func environmentActionsReachADiffInAToolCall() throws {
      let log = CallLog()
      let id = "diff-tool-call"
      let call = ToolCallRecord(
        id: id, title: "Edit", kind: .edit, status: .completed,
        content: [.diff(patch: Self.patch)])
      let store = ExpandedBlocksStore()
      store.expand(id)
      let harness = HostedViewHarness(size: Self.tallSize) {
        ToolCallView(record: call)
          .environment(\.expandedBlocksStore, store)
          .diffActions(
            DiffActions(
              onAccept: { log.accepted.append(($0, $1)) },
              onReject: nil,
              onAttach: nil))
      }
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: DiffView.editorRendererIdentifier) != nil)
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
