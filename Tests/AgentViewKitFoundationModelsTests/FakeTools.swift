import Foundation
import FoundationModels

/// A tool that gives a fixed text for a path.
nonisolated struct FakeReadTool: Tool {
  /// The name of the tool.
  static let toolName = "readFile"

  /// The text that the tool gives.
  static let output = "The file text."

  let name = FakeReadTool.toolName
  let description = "Reads a file."

  /// The arguments of the tool.
  @Generable struct Arguments {
    /// The path of the file.
    var path: String
  }

  func call(arguments: Arguments) async throws -> String {
    Self.output
  }
}

/// A tool that always throws.
nonisolated struct FakeFailingTool: Tool {
  /// The error that the tool throws.
  struct Failure: Error {}

  let name = FakeReadTool.toolName
  let description = "Reads a file, and fails."

  func call(arguments: FakeReadTool.Arguments) async throws -> String {
    throw Failure()
  }
}

/// A clock that moves one second forward at each read.
final class TickingClock {
  /// The time that the next read gives.
  private var next = Date(timeIntervalSince1970: 0)

  /// Gives the time, and moves the clock one second forward.
  ///
  /// - Returns: The time before the move.
  func now() -> Date {
    defer { next.addTimeInterval(1) }
    return next
  }
}
