import Testing

@testable import AgentViewKit

/// The text selection region of the editor of one response (task ^t9416x5).
///
/// A response whose editor holds the selection of the thread keeps its
/// editor when its row scrolls far away, so a copy still copies the
/// selection.
@MainActor @Suite struct ResponseSelectionClaimTests {
  /// A text area of a test. The thread keeps a weak reference to the area
  /// that holds the selection, so each test keeps that area alive.
  final class Area {}

  /// A production change that fails this test: the claim does not record
  /// that the editor of the response holds the selection.
  @Test func aClaimHoldsTheSelection() throws {
    let claim = try #require(ResponseSelectionClaim().forwarding(to: ThreadTextSelection()))

    claim.claim(Area()) {}

    #expect(claim.holdsSelection)
  }

  /// A production change that fails this test: the claim does not forward
  /// to the thread, so a claim of a different area of the thread does not
  /// clear the selection of the response.
  @Test func aClaimOfADifferentAreaClearsTheSelectionOfTheResponse() throws {
    let thread = ThreadTextSelection()
    let claim = try #require(ResponseSelectionClaim().forwarding(to: thread))
    var isCleared = false
    let response = Area()
    claim.claim(response) { isCleared = true }

    withExtendedLifetime(response) { thread.claim(Area()) {} }

    #expect(isCleared)
  }

  /// A production change that fails this test: the claim still holds the
  /// selection after a different area of the thread took it, so the row
  /// keeps its editor.
  @Test func aClaimOfADifferentAreaEndsTheHold() throws {
    let thread = ThreadTextSelection()
    let claim = try #require(ResponseSelectionClaim().forwarding(to: thread))
    let response = Area()
    claim.claim(response) {}

    withExtendedLifetime(response) { thread.claim(Area()) {} }

    #expect(!claim.holdsSelection)
  }

  /// A production change that fails this test: the claim still holds the
  /// selection after its editor went away.
  @Test func aReleaseEndsTheHold() throws {
    let claim = try #require(ResponseSelectionClaim().forwarding(to: ThreadTextSelection()))
    let area = Area()
    claim.claim(area) {}

    claim.release(area)

    #expect(!claim.holdsSelection)
  }

  /// A production change that fails this test: the claim gives the editor a
  /// region of its own outside a thread, so the editor of a response that a
  /// host shows alone takes part in a region with no other area.
  @Test func aClaimWithNoThreadGivesNoRegion() {
    #expect(ResponseSelectionClaim().forwarding(to: nil) == nil)
  }
}
