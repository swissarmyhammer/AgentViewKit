import Foundation
import FoundationModels

/// A tool that gives the current time in a time zone.
///
/// The FoundationModels tab of the demo app gives this tool to its session
/// (``FoundationModelsDemoSession``).
nonisolated struct ClockTool: Tool {
  /// The arguments of the tool.
  @Generable struct Arguments {
    /// The identifier of the time zone.
    @Guide(description: "The identifier of the time zone, for example UTC or Europe/Paris.")
    var timeZone: String
  }

  /// The time zone of the answer when the identifier of the arguments names
  /// no zone.
  static let fallbackTimeZone = TimeZone.gmt

  let name = "clock"
  let description = "Gives the current time in a time zone."

  /// The clock that gives the current time.
  private let clock: @Sendable () -> Date

  /// Makes the tool.
  ///
  /// - Parameter clock: The clock that gives the current time. The default
  ///   is the system clock.
  init(clock: @escaping @Sendable () -> Date = Date.init) {
    self.clock = clock
  }

  func call(arguments: Arguments) async -> String {
    let zone = TimeZone(identifier: arguments.timeZone) ?? Self.fallbackTimeZone
    let time = clock().formatted(Date.ISO8601FormatStyle(timeZone: zone))
    return "The time in \(zone.identifier) is \(time)."
  }
}

/// A tool that counts the words of a text.
///
/// The FoundationModels tab of the demo app gives this tool to its session
/// (``FoundationModelsDemoSession``).
nonisolated struct WordCountTool: Tool {
  /// The arguments of the tool.
  @Generable struct Arguments {
    /// The text to count.
    @Guide(description: "The text whose words the tool counts.")
    var text: String
  }

  let name = "wordCount"
  let description = "Counts the words of a text."

  func call(arguments: Arguments) async -> String {
    let count = arguments.text.split(whereSeparator: \.isWhitespace).count
    let unit = count == 1 ? "word" : "words"
    return "The text has \(count) \(unit)."
  }
}
