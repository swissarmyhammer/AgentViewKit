import Testing

/// A lock that lets only one hosted test run at a time.
///
/// A test that holds the lock keeps it until its body returns or throws.
/// The other tests wait in the sequence that they asked for the lock.
actor HostedTestLock {
  /// The lock that all hosted tests of this process use.
  static let shared = HostedTestLock()

  /// Whether a test holds the lock.
  private var isHeld = false

  /// The tests that wait for the lock, in the sequence that they asked.
  private var waiters: [CheckedContinuation<Void, Never>] = []

  /// Waits until the lock is free, then holds it.
  func acquire() async {
    guard isHeld else {
      isHeld = true
      return
    }
    await withCheckedContinuation { waiters.append($0) }
  }

  /// Gives the lock to the next waiting test, or makes the lock free when no
  /// test waits.
  func release() {
    guard !waiters.isEmpty else {
      isHeld = false
      return
    }
    waiters.removeFirst().resume()
  }

  /// Runs `body` while this caller holds the lock.
  ///
  /// - Parameter body: The work to run.
  /// - Throws: The error that `body` throws.
  nonisolated func run(_ body: @Sendable () async throws -> Void) async throws {
    await acquire()
    do {
      try await body()
    } catch {
      await release()
      throw error
    }
    await release()
  }
}

/// A trait that runs each test of a suite while the test holds
/// ``HostedTestLock/shared``.
///
/// `swift test` runs suites in parallel. A hosted test mounts a view in a
/// window, makes that window the key window, and runs the main run loop.
/// When two hosted tests run at the same time, one window takes the key
/// status from the other, and a run loop pass of one test runs the main actor
/// work of the other test. Then a test that needs the focus, such as a
/// completion list test, fails on some runs. With this trait, hosted tests
/// run one at a time, and the other tests still run in parallel.
struct HostedSerialTrait: SuiteTrait, TestTrait, TestScoping {
  /// The trait applies to each test in the suite and in its child suites.
  var isRecursive: Bool { true }

  /// Runs `function` while the test holds the lock.
  ///
  /// - Parameters:
  ///   - test: The test to run.
  ///   - testCase: The test case to run.
  ///   - function: The body of the test.
  /// - Throws: The error that `function` throws.
  func provideScope(
    for test: Test,
    testCase: Test.Case?,
    performing function: @Sendable () async throws -> Void
  ) async throws {
    try await HostedTestLock.shared.run(function)
  }
}

extension Trait where Self == HostedSerialTrait {
  /// Runs each test of the suite while no other hosted test runs.
  static var hostedSerially: Self { Self() }
}
