import AppKit
import EditorTestSupport
import Testing

extension NSPasteboard {
  /// Runs `action`, then expects that it copied `expected` to this pasteboard
  /// one time.
  ///
  /// A copy of the kit (`Pasteboard.copyText(_:)`) clears the pasteboard and
  /// writes one string, so each copy adds one to `changeCount`. The
  /// pasteboard is one of `NSPasteboard.withIsolated(_:)`.
  ///
  /// - Parameters:
  ///   - expected: The text that the one copy writes.
  ///   - sourceLocation: The place of the caller, for the report of a failure.
  ///   - action: The action that copies.
  /// - Throws: The error of `action`.
  func expectOneCopy(
    of expected: String, sourceLocation: SourceLocation = #_sourceLocation, by action: () throws -> Void
  ) rethrows {
    let changeCount = self.changeCount

    try action()

    #expect(self.changeCount == changeCount + 1, "One copy", sourceLocation: sourceLocation)
    #expect(string(forType: .string) == expected, sourceLocation: sourceLocation)
  }
}
