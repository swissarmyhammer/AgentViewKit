#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import EditorDiff
  import Foundation
  import PackageFileSupport
  import SwiftUI
  import Testing

  /// Tests for the EditorKit renderer that ``DiffView`` uses when the host
  /// installs no renderer (plan.md §4.1, decision 12).
  @Suite(.serialized, .hostedSerially) @MainActor struct DiffRendererDefaultHostedTests {
    /// A size that shows the file list and the renderer.
    static let size = CGSize(width: 720, height: 900)

    /// The path of the first file of the fixture patch.
    static let firstPath = "Sources/App.swift"

    /// The path of the second file of the fixture patch.
    static let secondPath = "README.md"

    /// A patch with two files.
    static let patch = """
      diff --git a/Sources/App.swift b/Sources/App.swift
      --- a/Sources/App.swift
      +++ b/Sources/App.swift
      @@ -1,2 +1,2 @@
       import SwiftUI
      -let name = "old"
      +let name = "new"
      diff --git a/README.md b/README.md
      --- a/README.md
      +++ b/README.md
      @@ -1 +1 @@
      -# Old
      +# New

      """

    /// A patch that the EditorKit parser does not accept: the hunk header
    /// on line 3 has no line ranges.
    static let unreadablePatch = """
      --- a/App.swift
      +++ b/App.swift
      @@ nothing @@
      +line

      """

    /// Makes a harness that shows `view`, after one pump.
    ///
    /// - Parameter view: The view to show.
    /// - Returns: The harness.
    static func mount(_ view: some View) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: size) {
        view.transaction { $0.disablesAnimations = true }
      }
      harness.pump()
      return harness
    }

    // MARK: - Default renderer

    @Test func withNoOverrideTheEditorKitRendererShows() {
      let harness = Self.mount(DiffView(patch: Self.patch))
      defer { harness.close() }

      #expect(!harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.root).isEmpty)
      #expect(harness.element(identifier: DiffView.unreadablePatchIdentifier) == nil)
    }

    @Test func theInlineLayoutHasNoColumns() {
      let harness = Self.mount(DiffView(patch: Self.patch).diffLayout(.inline))
      defer { harness.close() }

      #expect(!harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.root).isEmpty)
      #expect(harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.oldColumn).isEmpty)
      #expect(harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.newColumn).isEmpty)
    }

    @Test func anOverrideReplacesTheEditorKitRenderer() {
      let harness = Self.mount(
        DiffView(patch: Self.patch)
          .diffRenderer { _, _ in Text("Custom").accessibilityIdentifier("custom-renderer") })
      defer { harness.close() }

      #expect(harness.element(identifier: "custom-renderer") != nil)
      #expect(harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.root).isEmpty)
    }

    @Test func theSideBySideLayoutShowsTheEditorKitColumns() {
      let harness = Self.mount(DiffView(patch: Self.patch).diffLayout(.sideBySide))
      defer { harness.close() }

      #expect(!harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.root).isEmpty)
      #expect(!harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.oldColumn).isEmpty)
      #expect(!harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.newColumn).isEmpty)
    }

    @Test func anUnreadablePatchShowsTheLineOfTheParseError() {
      let harness = Self.mount(DiffView(patch: Self.unreadablePatch))
      defer { harness.close() }

      let row = harness.element(identifier: DiffView.unreadablePatchIdentifier)
      #expect(row?.label == "Cannot read the patch at line 3")
      #expect(harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.root).isEmpty)
    }

    // MARK: - Layout setting

    @Test func theLayoutDefaultsToInline() {
      #expect(EnvironmentValues().diffLayout == .inline)
    }

    @Test func eachLayoutMapsToTheEditorKitLayout() {
      #expect(DiffLayout.inline.documentLayout == .inline)
      #expect(DiffLayout.sideBySide.documentLayout == .sideBySide)
    }

    // MARK: - File filter

    @Test func aFilePathKeepsOnlyThatFile() throws {
      let diff = try EditorKitDiffRenderer.diff(of: Self.patch, file: Self.secondPath).get()
      #expect(diff.files.map(\.newPath) == [Self.secondPath])
    }

    @Test func noFilePathKeepsEachFile() throws {
      let diff = try EditorKitDiffRenderer.diff(of: Self.patch, file: nil).get()
      #expect(diff.files.map(\.newPath) == [Self.firstPath, Self.secondPath])
    }

    @Test func anUnknownFilePathKeepsEachFile() throws {
      let diff = try EditorKitDiffRenderer.diff(of: Self.patch, file: "Missing.swift").get()
      #expect(diff.files.count == 2)
    }

    @Test func aParseErrorGivesItsLine() {
      let result = EditorKitDiffRenderer.diff(of: Self.unreadablePatch, file: nil)
      #expect(throws: UnifiedDiffError.malformedHunkHeader(line: 3)) { try result.get() }
      #expect(EditorKitDiffRenderer.line(of: .malformedHunkHeader(line: 3)) == 3)
      #expect(EditorKitDiffRenderer.line(of: .hunkLineCountMismatch(line: 4)) == 4)
      #expect(EditorKitDiffRenderer.line(of: .unexpectedLine(line: 5)) == 5)
    }

    // MARK: - Source

    @Test func noDiffSourceHasTheOldPlaceholderText() throws {
      let directory = try PackageFiles.file("Sources/AgentViewKit/Diff")
      let files = try PackageFiles.swiftFiles(in: directory)
      #expect(!files.isEmpty)
      for file in files {
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(!text.contains("not installed"), "\(file.lastPathComponent) has the old placeholder text")
      }
    }
  }
#endif
