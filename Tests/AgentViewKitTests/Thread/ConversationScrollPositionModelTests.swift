import Observation
import SwiftUI
import Synchronization
import Testing

@testable import AgentViewKit

/// The changes that the scroll position model of a ``ConversationView``
/// tells its observers (card ^9ync5h3).
///
/// The scroll view writes the position back through its binding while it
/// applies a scroll request, inside the update of SwiftUI. If that write
/// tells a change, the change evaluates ``ConversationScrollPositionBinding``
/// again at once, in the same update, and that evaluation gives the scroll
/// view a new request. In a hosted window the two did not stop, and the main
/// thread was in a loop (`TranscriptSearchStepHostedTests`,
/// `SessionTranscriptViewHostedTests`).
@MainActor @Suite struct ConversationScrollPositionModelTests {
  /// The id of the row of the scroll request of the tests.
  static let rowID = "row"

  /// A production change that fails this test: a write of the scroll view
  /// through the binding of the model tells a change, as the setter of an
  /// `@Observable` property does.
  @Test func aWriteOfTheScrollViewTellsNoChange() {
    let model = ConversationScrollPosition()
    let binding = model.binding

    let changes = Self.changes(of: model) { _ in binding.wrappedValue.scrollTo(id: Self.rowID) }

    #expect(changes == 0)
  }

  /// A production change that fails this test: the binding of the model
  /// does not keep a write of the scroll view, so the list reads an old
  /// position.
  @Test func theListReadsAWriteOfTheScrollView() {
    let model = ConversationScrollPosition()

    model.binding.wrappedValue.scrollTo(id: Self.rowID)

    #expect(model.value.viewID(type: String.self) == Self.rowID)
  }

  /// A production change that fails this test: a write of the list does not
  /// tell a change, so the scroll view does not get the request.
  @Test func aWriteOfTheListTellsAChange() {
    let model = ConversationScrollPosition()

    let changes = Self.changes(of: model) { $0.value.scrollTo(id: Self.rowID) }

    #expect(changes == 1)
  }

  /// A production change that fails this test: a write of the list of the
  /// position that the model holds tells a change.
  @Test func aWriteOfTheListOfTheEqualPositionTellsNoChange() {
    let model = ConversationScrollPosition()
    model.value.scrollTo(id: Self.rowID)

    let changes = Self.changes(of: model) { $0.value = $0.value }

    #expect(changes == 0)
  }

  /// The number of the changes of the position that the model tells while
  /// `write` runs, to an observer that reads the binding of the model, as
  /// ``ConversationScrollPositionBinding`` does in its body.
  ///
  /// - Parameters:
  ///   - model: The model of the position.
  ///   - write: The write to the model.
  /// - Returns: The number of the changes.
  private static func changes(
    of model: ConversationScrollPosition, during write: (ConversationScrollPosition) -> Void
  ) -> Int {
    let changes = Mutex(0)
    withObservationTracking {
      _ = model.binding
    } onChange: {
      changes.withLock { $0 += 1 }
    }
    write(model)
    return changes.withLock { $0 }
  }
}
