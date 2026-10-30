import AgentViewKitTestSupport
import FoundationModelsACP
import SwiftUI
import Testing

@testable import AgentViewKit

/// Checks that each tick of the minimap shows the status of a tool call with a
/// shape, and not with color only.
@Suite @MainActor struct ThreadMinimapTickMarkTests {
  /// The rectangle of one tick slot in the tests: the width of the rail, and a
  /// height that shows each shape.
  static let slot = CGRect(x: 0, y: 0, width: ThreadMinimapView.railWidth, height: 10)

  @Test(arguments: [
    (FoundationModelsACP.ToolCallStatus.pending, ThreadMinimapView.TickMark.live),
    (.inProgress, .live),
    (.completed, .plain),
    (.failed, .failure),
    (.unknown(ToolStatusSymbol.lostWireValue), .failure),
    (.cancelled, .cancelled),
    (.unknown("paused"), .plain),
  ])
  func eachToolCallStatusHasItsMark(status: FoundationModelsACP.ToolCallStatus, expected: ThreadMinimapView.TickMark)
  {
    #expect(ThreadMinimapView.tickMark(for: status) == expected)
  }

  @Test func eachMarkDrawsADifferentShape() {
    let marks = ThreadMinimapView.TickMark.allCases

    let shapes = marks.map { $0.path(in: Self.slot).description }

    NameChecks.expectDistinctNames(shapes)
  }

  @Test func eachMarkStaysInsideItsSlot() {
    for mark in ThreadMinimapView.TickMark.allCases {
      #expect(Self.slot.contains(mark.path(in: Self.slot).boundingRect), "\(mark)")
    }
  }
}
