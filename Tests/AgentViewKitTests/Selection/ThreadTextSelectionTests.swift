@testable import AgentViewKit
import Foundation
import Testing

/// The one text selection of a thread (Docs/decisions/text-selection.md):
/// a claim clears the previous owner, and only the previous owner.
@MainActor @Suite struct ThreadTextSelectionTests {
  /// A text area of the tests that counts the clears of its selection.
  final class Area {
    /// The number of clears.
    var clears = 0

    /// Claims the selection of `selection` for this area.
    func claim(in selection: ThreadTextSelection) {
      selection.claim(self) { [weak self] in self?.clears += 1 }
    }
  }

  @Test func claimByASecondAreaClearsTheFirstArea() {
    let selection = ThreadTextSelection()
    let first = Area()
    let second = Area()
    first.claim(in: selection)
    second.claim(in: selection)
    #expect(first.clears == 1)
    #expect(second.clears == 0)
  }

  @Test func secondClaimBySameAreaClearsNothing() {
    let selection = ThreadTextSelection()
    let area = Area()
    area.claim(in: selection)
    area.claim(in: selection)
    #expect(area.clears == 0)
  }

  @Test func areaWithNoSelectionGetsNoClear() {
    let selection = ThreadTextSelection()
    let first = Area()
    let second = Area()
    let bystander = Area()
    first.claim(in: selection)
    second.claim(in: selection)
    #expect(bystander.clears == 0)
    #expect(first.clears == 1)
  }

  @Test func eachNewOwnerClearsOnlyThePreviousOwner() {
    let selection = ThreadTextSelection()
    let first = Area()
    let second = Area()
    let third = Area()
    first.claim(in: selection)
    second.claim(in: selection)
    third.claim(in: selection)
    #expect(first.clears == 1)
    #expect(second.clears == 1)
    #expect(third.clears == 0)
  }

  @Test func firstClaimClearsNothing() {
    let selection = ThreadTextSelection()
    let area = Area()
    area.claim(in: selection)
    #expect(area.clears == 0)
  }

  @Test func releasedOwnerGetsNoClear() {
    let selection = ThreadTextSelection()
    let first = Area()
    let second = Area()
    first.claim(in: selection)
    selection.release(first)
    second.claim(in: selection)
    #expect(first.clears == 0)
  }

  @Test func releaseOfAnAreaThatIsNotTheOwnerKeepsTheOwner() {
    let selection = ThreadTextSelection()
    let first = Area()
    let second = Area()
    let third = Area()
    first.claim(in: selection)
    selection.release(second)
    third.claim(in: selection)
    #expect(first.clears == 1)
  }

  @Test func areaThatGoesAwayGetsNoClear() {
    let selection = ThreadTextSelection()
    var clears = 0
    do {
      let gone = Area()
      selection.claim(gone) { clears += 1 }
    }
    Area().claim(in: selection)
    #expect(clears == 0)
  }
}
