import AgentViewKitTestSupport
import Foundation
import SwiftUI

extension HostedViewHarness {
  /// Pumps the run loop until `condition` is true, or until `timeout` goes
  /// by.
  ///
  /// The function does not fail at the timeout. The test then checks the
  /// condition with an expectation, so that a timeout shows as a failure.
  ///
  /// Do not use this function in a new test. It waits on a clock and polls.
  /// Use ``HostedViewHarness/render(when:)`` with a condition on observable
  /// model values that are certain to change. The function stays only until
  /// no test uses it.
  ///
  /// - Parameters:
  ///   - timeout: The longest time to wait, in seconds.
  ///   - condition: The condition to wait for.
  func pump(until timeout: TimeInterval, _ condition: () -> Bool) async {
    let deadline = Date(timeIntervalSinceNow: timeout)
    while !condition(), Date() < deadline {
      pump()
      await Task.yield()
    }
  }
}
