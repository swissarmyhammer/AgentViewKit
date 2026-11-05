#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import EditorInspector
  import EditorInspectorTestSupport
  import EditorSwiftUI
  import EditorTestSupport
  import Foundation
  import Observation
  import SwiftUI
  import Testing

  /// The diff preview takes the full height of its content: in a tool call
  /// and in an inspector, the host scrolls the diff as one with the rest, no
  /// scroll view inside the diff scrolls by itself, and the diff grows while
  /// it shows when its patch grows (EditorKit ^sjjykvg).
  ///
  /// Each test reads the layout, never a pixel: the frame of the view
  /// (EditorKit's `FrameRecorder`, or `InspectorDriver.frame(of:)` for a row)
  /// and the scroll views that scroll (`NSView.scrollsAsOne`). A change of the
  /// patch comes from the model, never from the mouse or the keyboard focus.
  @Suite(.serialized, .hostedSerially) @MainActor struct DiffGrowthHostedTests {
    /// The width of the window, in points.
    static let width: CGFloat = 480

    /// The height of the window, in points: less than the diff of
    /// ``shortLineCount`` lines, so the host scrolls.
    static let height: CGFloat = 240

    /// The size of the window.
    static let size = CGSize(width: width, height: height)

    /// The number of changed lines of the first patch.
    static let shortLineCount = 20

    /// The number of changed lines of the patch that the first one grows to.
    static let longLineCount = 60

    /// The id of the tool call of the tests.
    static let toolCallID = "growing-edit"

    /// The path of the file of each patch.
    static let path = "Sources/Growing.swift"

    /// A patch of one file that adds `count` lines.
    ///
    /// - Parameter count: The number of added lines.
    /// - Returns: The patch text.
    static func patch(adding count: Int) -> String {
      let added = (1...count).map { "+let line\($0) = \($0)" }.joined(separator: "\n")
      return """
        diff --git a/\(path) b/\(path)
        --- a/\(path)
        +++ b/\(path)
        @@ -0,0 +1,\(count) @@
        \(added)

        """
    }

    /// The fields of a completed edit whose diff part holds `patch`.
    ///
    /// - Parameter patch: The patch text.
    /// - Returns: The fields, as JSON members.
    /// - Throws: The error of the JSON encode of the patch.
    static func editFields(patch: String) throws -> String {
      let text = try #require(String(data: JSONEncoder().encode(patch), encoding: .utf8))
      return #"""
        "title": "Edit Growing.swift", "kind": "edit", "status": "completed",
        "content": [{"type": "diff", "changes": [], "patch": {"format": "git_patch", "text": \#(text)}}]
        """#
    }

    // MARK: - Tool call

    @Test func aDiffInAToolCallGrowsAndScrollsAsOneWithItsHost() async throws {
      let (session, call) = try await ToolCallViewHostedTests.openCall(
        id: Self.toolCallID, fields: try Self.editFields(patch: Self.patch(adding: Self.shortLineCount)))
      defer { session.close() }
      let recorder = FrameRecorder()
      let harness = DiffHarness.mount(
        ScrollView {
          ToolCallView(entry: call)
            .environment(\.expandedBlocksStore, ToolCallViewHostedTests.makeExpandedStore(for: call))
            .recordFrame(into: recorder)
        },
        size: Self.size)
      defer { harness.close() }
      #expect(await settle(until: { harness.hostingView.scrollsAsOne }))
      let shortHeight = try #require(recorder.frame?.height)

      try await session.sendUpdate(
        WireBlockJSON.makeToolCallUpdate(
          id: Self.toolCallID, fields: try Self.editFields(patch: Self.patch(adding: Self.longLineCount))))

      #expect(await settle(until: { (recorder.frame?.height ?? 0) > shortHeight }))
      #expect(harness.hostingView.scrollsAsOne)
    }

    // MARK: - Inspector

    /// A patch that an inspector shows in a preview row.
    @Observable final class InspectedPatch {
      /// The patch text.
      var patch: String

      /// Makes the object of `patch`.
      ///
      /// - Parameter patch: The patch text.
      init(_ patch: String) {
        self.patch = patch
      }
    }

    /// The id of the inspection of ``InspectedPatch``.
    static let inspectionID = "patch"

    /// The group and the field part of the scheme id of the preview row.
    static let fieldID = "changes"

    /// The inspection of a patch: one preview row of the EditorKit preview
    /// that ``DiffView`` shows.
    static var inspection: Inspection<InspectedPatch> {
      Inspection(id: inspectionID) {
        FieldGroup("Changes") {
          Field("Changes") { DiffView.previewSource(of: $0.patch, file: nil) }
            .identifier(fieldID)
        }
        .identifier(fieldID)
      }
    }

    @Test func aDiffInAnInspectorGrowsAndScrollsAsOneWithItsPanel() async throws {
      let object = InspectedPatch(Self.patch(adding: Self.shortLineCount))
      let harness = DiffHarness.mount(
        ScrollView {
          InspectorView(object, Self.inspection)
        }
        .inspectorScrolling(.host),
        size: Self.size)
      defer { harness.close() }
      let row = InspectorRowID.field(view: Self.inspectionID, object: object, group: Self.fieldID, field: Self.fieldID)
      #expect(await settle(until: { harness.hostingView.scrollsAsOne }))
      let shortHeight = try #require(harness.inspectorDriver.frame(of: row)?.height)

      object.patch = Self.patch(adding: Self.longLineCount)

      #expect(await settle(until: { (harness.inspectorDriver.frame(of: row)?.height ?? 0) > shortHeight }))
      #expect(harness.hostingView.scrollsAsOne)
    }
  }
#endif
