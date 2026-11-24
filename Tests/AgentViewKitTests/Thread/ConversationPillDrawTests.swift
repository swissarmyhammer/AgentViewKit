#if DEBUG
  import AgentViewKitTestSupport
  import AppKit
  import EditorCommands
  import EditorCommandsUI
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// The hidden Scroll to Bottom pill draws nothing over a thread that is
  /// pinned to the bottom (task ^ctzmqh3).
  ///
  /// The test draws the thread into a bitmap (`cacheDisplay(in:to:)`), and
  /// reads the pixels in the frame of the pill. The background of the
  /// thread is clear in the bitmap, so each pixel that a view draws has an
  /// alpha above zero. The thread is in a borderless window that is never
  /// ordered in, as in ``AnswerTextHitTests``: no window shows, and no
  /// window takes the focus.
  @MainActor @Suite struct ConversationPillDrawTests {
    /// A session with a short transcript: one prompt and one answer.
    ///
    /// - Returns: The session model.
    static func shortSession() -> SessionModel {
      .preview(transcript: [.user("Read the file."), .agent(AnswerTextHitTests.answer)])
    }

    /// A thread of `session` with the default composer, `anchors` and
    /// `system`, laid out one time in a window that is never ordered in
    /// (``AnswerTextHitTests/mount(_:)``).
    ///
    /// - Parameters:
    ///   - session: The session model of the thread.
    ///   - anchors: The manager of the scroll position of the thread.
    ///   - system: The command system of the thread.
    /// - Returns: The host of the thread: the content view of the window.
    static func mountThread(_ session: SessionModel, anchors: ScrollAnchorManager, system: CommandSystem)
      throws -> NSView
    {
      let window = AnswerTextHitTests.mount(
        AgentThreadView(session: session, anchors: anchors) { DefaultThreadComposer() }.commandSystem(system))
      return try #require(window.contentView)
    }

    /// The center of the pill in the window of a thread (top left, y
    /// down), or `nil` when the pill has no live control scope.
    ///
    /// The hidden pill has a scale of zero around its center, so its
    /// control scope has no area, and its origin is the center of the pill.
    ///
    /// - Parameter system: The command system of the thread.
    /// - Returns: The center.
    static func pillCenter(in system: CommandSystem) -> CGPoint? {
      let segment = AgentScopeKind.control(ScrollToBottomPill.identifier)
      return system.geometry.livePaths.first { $0.segments.last == segment }
        .flatMap(system.geometry.rect(of:))
        .map { CGPoint(x: $0.midX, y: $0.midY) }
    }

    /// The frame of the shown pill around the center of the pill.
    ///
    /// The hidden pill keeps the size of the shown pill
    /// (``ConversationPillMountTests/aPinnedPillHasTheSizeOfTheShownPill()``).
    ///
    /// - Parameter center: The center of the pill in the window.
    /// - Returns: The frame, in the window (top left, y down).
    static func pillFrame(around center: CGPoint) -> CGRect {
      let size = StyleViewHost.fittingSize(of: ConversationPill(anchors: ScrollAnchorManager()))
      return CGRect(
        x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    /// The number of pixels that a view draws in the frame of its pill.
    ///
    /// - Parameters:
    ///   - view: The host of the thread. Its frame is the frame of the
    ///     window.
    ///   - system: The command system of the thread.
    /// - Returns: The number of pixels with an alpha above zero.
    static func drawnPixelsOfThePill(of view: NSView, system: CommandSystem) throws -> Int {
      let center = try #require(pillCenter(in: system), "\(system.geometry.livePaths)")
      let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
      view.cacheDisplay(in: view.bounds, to: bitmap)
      let scale = CGFloat(bitmap.pixelsWide) / view.bounds.width
      let pixels = CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        .intersection(pillFrame(around: center).applying(CGAffineTransform(scaleX: scale, y: scale)).integral)
      var count = 0
      for x in Int(pixels.minX)..<Int(pixels.maxX) {
        for y in Int(pixels.minY)..<Int(pixels.maxY) where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0 {
          count += 1
        }
      }
      return count
    }

    /// A production change that fails this test: the pill hides its
    /// button with an opacity or a scale inside the glass container of the
    /// floating controls. The container draws the label of a glass button
    /// itself, and it does not apply the opacity or the scale of the views
    /// between it and the button. Thus the gray label "Scroll to Bottom" of
    /// the disabled button showed above the composer of each short thread.
    @Test func aPinnedPillDrawsNothingAboveTheComposer() throws {
      let system = CommandSystem()
      let anchors = ScrollAnchorManager()
      let hosting = try Self.mountThread(Self.shortSession(), anchors: anchors, system: system)
      try #require(anchors.isPinnedToBottom)

      let drawn = try Self.drawnPixelsOfThePill(of: hosting, system: system)

      #expect(drawn == 0)
    }

    /// A production change that fails this test: the pill hides its button
    /// also while the list is not pinned, such as with a glass container
    /// that draws no label. The test also shows that the frame that the
    /// tests read holds the label of the pill.
    @Test func anUnpinnedPillDrawsItsLabel() throws {
      let system = CommandSystem()
      let anchors = ScrollAnchorManager()
      let session = Self.shortSession()
      let hosting = try Self.mountThread(session, anchors: anchors, system: system)
      ConversationPillMountTests.unpin(anchors, rowKeys: session.transcript.map(\.rowKey))
      hosting.layoutSubtreeIfNeeded()
      try #require(!anchors.isPinnedToBottom)

      let drawn = try Self.drawnPixelsOfThePill(of: hosting, system: system)

      #expect(drawn > 0)
    }
  }
#endif
