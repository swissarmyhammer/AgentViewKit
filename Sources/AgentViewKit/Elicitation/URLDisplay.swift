import Foundation

/// The functions that show a URL so that the user can check it before it
/// opens (plan.md §13.3, §13.4).
///
/// ``highlighted(_:)`` gives the full URL with the host in bold, so that
/// the user can find the site. ``warning(for:)`` gives a warning when the
/// host can look like a different host.
public nonisolated enum URLDisplay {
  /// The start of each host label that is Punycode.
  static let punycodePrefix = "xn--"

  /// The script of a letter, for the mixed-script check.
  enum Script: Hashable {
    case latin
    case greek
    case cyrillic
    case armenian
    case hebrew
    case arabic
    case cherokee
    /// A letter of a script that the table does not name. Each such letter
    /// is in its own group, keyed by its Unicode block start.
    case other(UInt32)
  }

  /// The scalar values of a range of letters.
  typealias ScalarRange = ClosedRange<UInt32>

  /// The Unicode ranges of the scripts that have letters that look like
  /// Latin letters.
  enum Ranges {
    /// The ASCII capital letters, `A` to `Z`.
    static let asciiUppercase: ScalarRange = 0x0041...0x005A
    /// The ASCII small letters, `a` to `z`.
    static let asciiLowercase: ScalarRange = 0x0061...0x007A
    /// The letters of the Latin-1 Supplement and Latin Extended-A and -B
    /// blocks.
    static let latinExtended: ScalarRange = 0x00C0...0x024F
    /// The Greek and Coptic block.
    static let greek: ScalarRange = 0x0370...0x03FF
    /// The Cyrillic and Cyrillic Supplement blocks.
    static let cyrillic: ScalarRange = 0x0400...0x052F
    /// The Armenian block.
    static let armenian: ScalarRange = 0x0530...0x058F
    /// The Hebrew block.
    static let hebrew: ScalarRange = 0x0590...0x05FF
    /// The Arabic block.
    static let arabic: ScalarRange = 0x0600...0x06FF
    /// The Cherokee block.
    static let cherokee: ScalarRange = 0x13A0...0x13FF
    /// The Latin Extended Additional block.
    static let latinExtendedAdditional: ScalarRange = 0x1E00...0x1EFF
  }

  /// The script of each range in ``Ranges``.
  static let scriptRanges: [(range: ScalarRange, script: Script)] = [
    (Ranges.asciiUppercase, .latin),
    (Ranges.asciiLowercase, .latin),
    (Ranges.latinExtended, .latin),
    (Ranges.greek, .greek),
    (Ranges.cyrillic, .cyrillic),
    (Ranges.armenian, .armenian),
    (Ranges.hebrew, .hebrew),
    (Ranges.arabic, .arabic),
    (Ranges.cherokee, .cherokee),
    (Ranges.latinExtendedAdditional, .latin),
  ]

  /// The size of the block that ``Script/other(_:)`` uses as a key.
  static let otherBlockSize: UInt32 = 0x80

  /// The full URL with the host in bold.
  ///
  /// - Parameter url: The URL to show.
  /// - Returns: The absolute string of `url`. The characters of the host
  ///   have the `stronglyEmphasized` presentation intent. When `url` has no
  ///   host, no character is bold.
  public static func highlighted(_ url: URL) -> AttributedString {
    let text = url.absoluteString
    guard let hostRange = URLComponents(string: text)?.rangeOfHost, !hostRange.isEmpty else {
      return AttributedString(text)
    }
    var host = AttributedString(text[hostRange])
    host.inlinePresentationIntent = .stronglyEmphasized
    var result = AttributedString(text[..<hostRange.lowerBound])
    result.append(host)
    result.append(AttributedString(text[hostRange.upperBound...]))
    return result
  }

  /// The warning for a URL whose host can look like a different host.
  ///
  /// - Parameter url: The URL to check.
  /// - Returns: The text of the warning, or `nil` when the host is safe to
  ///   show or `url` has no host.
  public static func warning(for url: URL) -> String? {
    guard let host = url.host(percentEncoded: false) else { return nil }
    return warning(forHost: host)
  }

  /// The warning for a host that can look like a different host.
  ///
  /// - Parameter host: The host to check.
  /// - Returns: A Punycode warning when a label of `host` starts with
  ///   `xn--`, a mixed-script warning when `host` has letters of more than
  ///   one script, else `nil`.
  public static func warning(forHost host: String) -> String? {
    let labels = host.lowercased().split(separator: ".")
    if labels.contains(where: { $0.hasPrefix(punycodePrefix) }) {
      return "The address \(host) uses encoded international characters (Punycode). "
        + "Make sure that it is the site that you expect."
    }
    if scripts(in: host).count > 1 {
      return "The address \(host) has letters from more than one alphabet. "
        + "Make sure that it is the site that you expect."
    }
    return nil
  }

  /// The scripts of the letters of `text`.
  ///
  /// - Parameter text: The text to check.
  /// - Returns: One script for each group of letters. Digits and marks are
  ///   not letters.
  static func scripts(in text: String) -> Set<Script> {
    Set(text.unicodeScalars.filter(\.properties.isAlphabetic).map { script(of: $0.value) })
  }

  /// The script of the letter with the scalar value `value`.
  ///
  /// - Parameter value: The scalar value of a letter.
  /// - Returns: The script from ``scriptRanges``, else
  ///   ``Script/other(_:)`` with the start of the block of `value`.
  static func script(of value: UInt32) -> Script {
    scriptRanges.first { $0.range.contains(value) }?.script
      ?? .other(value - value % otherBlockSize)
  }
}
