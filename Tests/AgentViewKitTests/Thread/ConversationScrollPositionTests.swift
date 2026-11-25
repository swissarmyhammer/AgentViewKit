import SwiftUI
import Testing

@testable import AgentViewKit

/// The scroll position that the list of a ``ConversationView`` gets for each
/// scroll target of its ``ScrollAnchorManager`` (task ^48x2jb7).
@Suite @MainActor struct ConversationScrollPositionTests {
  /// The row key of the item of these tests.
  static let rowKey = "row-1"

  /// A scroll position after a scroll to the item of these tests, as after a
  /// jump to a row.
  static func positionAtTheItem() -> ScrollPosition {
    var position = ScrollPosition(idType: String.self)
    position.scrollTo(id: rowKey, anchor: .top)
    return position
  }

  @Test func aScrollToTheBottomHoldsNoID() {
    var position = Self.positionAtTheItem()
    ConversationLayout.scroll(&position, to: .bottom)
    #expect(position.viewID == nil)
  }

  @Test func aScrollToTheBottomHoldsTheBottomEdge() {
    var position = Self.positionAtTheItem()
    ConversationLayout.scroll(&position, to: .bottom)
    #expect(position.edge == .bottom)
  }

  @Test func aScrollToAnItemHoldsTheRowKeyOfTheItem() {
    var position = ScrollPosition(idType: String.self)
    ConversationLayout.scroll(&position, to: .item(Self.rowKey))
    #expect(position.viewID(type: String.self) == Self.rowKey)
  }
}
