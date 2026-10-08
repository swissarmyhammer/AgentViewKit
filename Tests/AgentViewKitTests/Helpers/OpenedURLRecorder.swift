import Foundation
import SwiftUI
import Synchronization

/// Records each URL that an `OpenURLAction` gets.
///
/// The action handler can run off the main actor, so the list uses a lock.
/// `WireContentBlockViewHostedTests` and `SourcesViewHostedTests` use it.
nonisolated final class OpenedURLRecorder: Sendable {
  /// The opened URLs, in order, behind a lock.
  private let storage = Mutex<[URL]>([])

  /// The opened URLs, in order.
  var urls: [URL] { storage.withLock { $0 } }

  /// Records a URL and tells SwiftUI that the action handled it.
  ///
  /// - Parameter url: The URL to open.
  /// - Returns: `.handled`.
  func open(_ url: URL) -> OpenURLAction.Result {
    storage.withLock { $0.append(url) }
    return .handled
  }
}
