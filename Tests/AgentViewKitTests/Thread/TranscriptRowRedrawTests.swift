#if DEBUG
  import AppKit
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// A row whose content does not change draws nothing again when only the
  /// offset of the list changes (card ^9ync5h3, #perf).
  ///
  /// Each test shows a ``MovingThread`` of ``rowCount`` rows of one kind
  /// with a frame of the surface shape: a terminal, an error and an answer
  /// with a code block. It moves the offset in ``stepCount`` steps, at rest
  /// or in a live scroll, where the rows show their static forms. After
  /// each step, the test draws each layer that needs display
  /// (``PendingLayerDraws``). A layer that stays in the tree is drawn again
  /// at most at one step: the step where its row crosses an edge of the
  /// list. A layer that the list draws again at each step is the cost of a
  /// flick: in the static form, it draws the text of the row again on each
  /// frame.
  @MainActor @Suite struct TranscriptRowRedrawTests {
    /// The number of rows in the transcript: more than the rows in view.
    static let rowCount = 50

    /// The number of steps of the offset.
    static let stepCount = 30

    /// The distance of one step, in points. It has a fraction, as a step of
    /// a flick has.
    static let stepDistance: CGFloat = 2.3

    /// The largest number of steps at which one layer is drawn again.
    static let largestDrawsOfOneLayer = 1

    /// A row kind and whether the rows move.
    struct Case: Sendable, CustomTestStringConvertible {
      /// The name of the row kind.
      let kind: String

      /// Whether the rows move in a live scroll.
      let isMoving: Bool

      var testDescription: String {
        "\(kind)\(isMoving ? ", moving" : ", at rest")"
      }
    }

    /// Each row kind, at rest and while the rows move.
    nonisolated static let cases: [Case] = ["terminal", "error", "code block"].flatMap { kind in
      [false, true].map { Case(kind: kind, isMoving: $0) }
    }

    /// One transcript item of the row kind `kind`.
    ///
    /// - Parameter kind: The name of the row kind.
    /// - Returns: The item.
    static func item(of kind: String) -> PreviewTranscriptItem {
      switch kind {
      case "terminal":
        .terminal(command: "swift build", output: "Building for debugging\nBuild complete.", exitCode: 0)
      case "error":
        .error(code: .internalError, message: "The agent stopped before it sent an answer.")
      default:
        .agent("The parser reads each line.\n\n```swift\nlet tokens = lexer.tokens(of: line)\n```")
      }
    }

    /// The most steps at which one layer that stays in the tree is drawn
    /// again, over ``stepCount`` steps.
    ///
    /// - Parameters:
    ///   - thread: The list.
    ///   - isLive: Whether the steps are steps of a live scroll.
    /// - Returns: The count.
    static func mostDrawsOfOneLayer(in thread: MovingThread, isLive: Bool) throws -> Int {
      let root = try #require(thread.hosting.layer)
      var known = Set(PendingLayerDraws.drawPending(in: root).keys)
      var draws: [ObjectIdentifier: Int] = [:]
      for _ in 0..<stepCount {
        thread.step(by: stepDistance, isLive: isLive)
        let layers = PendingLayerDraws.drawPending(in: root)
        for (layer, needed) in layers where needed && known.contains(layer) {
          draws[layer, default: .zero] += 1
        }
        known.formUnion(layers.keys)
      }
      return draws.values.max() ?? .zero
    }

    /// A production change that fails this test: a view of the frame of a
    /// row, such as a concentric surface shape, takes a new shape at each
    /// position of the row in the window, so the list draws the row again
    /// at each frame of a scroll.
    @Test(arguments: cases) func aRowIsNotDrawnAgainWhenOnlyTheOffsetChanges(_ testCase: Case) async throws {
      let session = SessionModel.preview(transcript: Array(repeating: Self.item(of: testCase.kind), count: Self.rowCount))
      let thread = try MovingThread(session: session)
      thread.showEachRowAtRest()
      if testCase.isMoving {
        thread.startMoving()
      }

      let draws = try Self.mostDrawsOfOneLayer(in: thread, isLive: testCase.isMoving)

      #expect(draws <= Self.largestDrawsOfOneLayer, "a layer is drawn again at \(draws) of \(Self.stepCount) steps")
    }
  }
#endif
