import SwiftUI
import Testing

@testable import DemoSupport

/// The tests of ``DemoStartPhase``: the state of the start of a demo tab, and
/// the start that each tab runs one time.
@Suite struct DemoStartPhaseTests {
  /// The error of a start that fails.
  enum StartError: Error {
    /// The agent refused the start.
    case refused
  }

  /// The storage of a phase, as the `@State` of a tab holds it.
  final class PhaseStore {
    /// The phase of the start.
    var phase: DemoStartPhase<Int>

    /// The number of times that the start ran its operation.
    var operationCount = 0

    /// Makes the storage of a phase.
    ///
    /// - Parameter phase: The first phase.
    init(phase: DemoStartPhase<Int>) {
      self.phase = phase
    }

    /// A binding to the phase.
    var binding: Binding<DemoStartPhase<Int>> {
      Binding(get: { self.phase }, set: { self.phase = $0 })
    }

    /// The value of a phase that started, or `nil` for each other phase.
    var startedValue: Int? {
      if case .started(let value) = phase { value } else { nil }
    }

    /// The error of a phase that failed, or `nil` for each other phase.
    var failure: (any Error)? {
      if case .failed(let error) = phase { error } else { nil }
    }
  }

  /// The value that a start gives.
  static let startedValue = 7

  @Test func aStartThatRunsKeepsThePhaseThatTheOperationSets() async {
    let store = PhaseStore(phase: .starting)

    await DemoStartPhase.start(store.binding) {
      store.operationCount += 1
      store.phase = .started(Self.startedValue)
    }

    #expect(store.operationCount == 1)
    #expect(store.startedValue == Self.startedValue)
  }

  @Test func aStartWhoseOperationThrowsGivesTheFailedPhaseWithTheError() async {
    let store = PhaseStore(phase: .starting)

    await DemoStartPhase.start(store.binding) {
      throw StartError.refused
    }

    #expect(store.failure as? StartError == .refused)
  }

  @Test func aPhaseThatStartedDoesNotRunTheOperationAgain() async {
    let store = PhaseStore(phase: .started(Self.startedValue))

    await DemoStartPhase.start(store.binding) {
      store.operationCount += 1
    }

    #expect(store.operationCount == 0)
    #expect(store.startedValue == Self.startedValue)
  }

  @Test func aPhaseThatFailedDoesNotRunTheOperationAgain() async {
    let store = PhaseStore(phase: .failed(StartError.refused))

    await DemoStartPhase.start(store.binding) {
      store.operationCount += 1
    }

    #expect(store.operationCount == 0)
    #expect(store.failure as? StartError == .refused)
  }
}
