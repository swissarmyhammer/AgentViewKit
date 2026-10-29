import Foundation

/// Finds the outer spacing of the views of one Swift file (^rgsq3k4).
///
/// TEMPORARY (EditorKit ^ny8zhz5): the scanner moves to EditorKit's style
/// rules; delete this copy when it lands.
///
/// A view carries no padding or margin of its own around it: the containing
/// layout spaces it (EditorKit `style.md`, the user rule of 2026-10-29). The
/// scanner reads the code of a file, with the comments and the string
/// literals blanked, and finds the spacing modifier (``spacingModifiers``)
/// that a view applies to itself:
///
/// - **The end of a body.** A spacing modifier on the root of the `body` of
///   a view type, with no surface modifier (``surfaceModifiers``) after it
///   at the same place. A surface after the padding makes the padding the
///   inset of that surface, which is inner padding. A root is the view that
///   the body gives, through the branches of an `if` or a `switch`, a
///   `Group`, and a view property of the type that the body names alone on
///   its line.
/// - **The content of a scroll view.** A spacing modifier on the root of the
///   content of a `ScrollView`: the list then insets its own content, and
///   the host gives that space with a content margin.
///
/// The scanner reads the braces and the parentheses of the code, not its
/// syntax tree: a modifier inside an argument or a closure of another view
/// is the layout of that view, and does not count.
enum OuterSpacingScanner {
  /// The modifiers that give space around a view: the SwiftUI ones, and the
  /// scroll content margin of the style library (`scrollContentMargins`),
  /// which is for the layout that holds a list, not for the list itself.
  static let spacingModifiers: Set<String> = ["padding", "safeAreaPadding", "contentMargins", "scrollContentMargins"]

  /// The modifiers that draw a surface or an edge around the view before
  /// them. A spacing modifier before one of them is the inset of the surface.
  static let surfaceModifiers: Set<String> = [
    "background", "overlay", "border", "clipShape", "glassEffect", "floatingGlass", "selectableSurface",
    "selectionSurface", "surfaceBackground", "inlineFill", "inlineEdge", "contentTile", "scopeFocusRing",
  ]

  /// The view modifier types of the kit that draw a surface, which a view
  /// applies with `.modifier(_:)`, such as `.modifier(DeckSurface())`.
  static let surfaceModifierTypes: Set<String> = ["DeckSurface"]

  /// The name of the modifier that applies a view modifier type.
  static let modifierCall = "modifier"

  /// The views whose content is the root of the view around them.
  static let transparentContainers: Set<String> = ["Group", "ScrollView", "ScrollViewReader"]

  /// The keywords whose braces hold a branch of the root.
  static let branchKeywords: Set<String> = ["if", "else", "switch", "guard"]

  /// The word that starts a return, which a computed view property can
  /// put before its root.
  static let returnKeyword = "return"

  /// The pattern of a view type: `struct`, a name, and a type list that
  /// names `View`, up to the `{` of the type.
  ///
  /// A `Regex` is not `Sendable`, so each read makes the value again.
  static var viewStructPattern: Regex<Substring> {
    #/\bstruct\s+\w+[^{:]*:[^{]*?\bView\b[^{]*\{/#
  }

  /// The pattern of a view property, such as `var body: some View {`, with
  /// the name of the property as its capture.
  ///
  /// A `Regex` is not `Sendable`, so each read makes the value again.
  static var viewPropertyPattern: Regex<(Substring, Substring)> {
    #/\bvar\s+(\w+)\s*:\s*some\s+View\s*\{/#
  }

  /// The pattern of a scroll view with its content closure, such as
  /// `ScrollView {` or `ScrollView(.horizontal) {`.
  ///
  /// A `Regex` is not `Sendable`, so each read makes the value again.
  static var scrollViewPattern: Regex<Substring> {
    #/\bScrollView\s*(?:\([^)]*\))?\s*\{/#
  }

  /// One brace block of the code: the offsets of its `{` and of its `}`.
  struct Block: Equatable {
    /// The offset of the `{`.
    let open: Int

    /// The offset of the `}`, or the end of the code when the block does
    /// not close.
    let close: Int

    /// Whether the block holds `offset`.
    ///
    /// - Parameter offset: An offset in the code.
    /// - Returns: `true` when `offset` is between the braces.
    func contains(_ offset: Int) -> Bool {
      open < offset && offset < close
    }
  }

  /// One spacing modifier that the walk of a block found, with the block
  /// that it is in, so that a surface after it in the same block clears it.
  struct Hit {
    /// The offset of the `{` of the innermost block of the modifier.
    let scope: Int

    /// The offset of the `.` of the modifier.
    let offset: Int
  }

  /// Finds the outer spacing of each view type of a file.
  ///
  /// - Parameter code: The code of a Swift file, with the comments and the
  ///   string literals blanked.
  /// - Returns: The line of each spacing modifier that a view applies to
  ///   itself, in line order. The first line is line 1.
  static func outerSpacingLines(inCode code: String) -> [Int] {
    let bytes = Array(code.utf8)
    let properties = matchedBlocks(of: viewPropertyPattern, in: code, bytes: bytes)
    let scrollViews = matchedBlocks(of: scrollViewPattern, in: code, bytes: bytes).map(\.block)
    let offsets = matchedBlocks(of: viewStructPattern, in: code, bytes: bytes).flatMap { type in
      let owned = Dictionary(
        properties.filter { type.block.contains($0.block.open) }.map { (String(code[$0.name]), $0.block) },
        uniquingKeysWith: { first, _ in first })
      let walk = RootWalk(bytes: bytes, properties: owned)
      let bodyHits = owned["body"].map { walk.hits(in: $0, visited: ["body"]) } ?? []
      let scrollHits = scrollViews.filter { type.block.contains($0.open) }.flatMap { walk.hits(in: $0, visited: []) }
      return bodyHits + scrollHits
    }
    return Set(offsets.map { line(of: $0, in: bytes) }).sorted()
  }

  /// Finds the block that follows each match of a pattern that ends with `{`.
  ///
  /// - Parameters:
  ///   - pattern: The pattern. Its match ends with the `{` of the block.
  ///   - code: The code.
  ///   - bytes: The UTF-8 bytes of `code`.
  /// - Returns: The range of each match and its block, in code order.
  static func matchedBlocks<Output>(
    of pattern: Regex<Output>, in code: String, bytes: [UInt8]
  ) -> [(name: Range<String.Index>, block: Block)] {
    code.matches(of: pattern).map { match in
      let open = code.utf8.distance(from: code.utf8.startIndex, to: match.range.upperBound) - 1
      return (name: nameRange(of: match.range, in: code), block: Block(open: open, close: closingBrace(of: open, in: bytes)))
    }
  }

  /// The range of the name in a match of ``viewPropertyPattern``: the word
  /// after `var`. Another pattern gives the whole match.
  ///
  /// - Parameters:
  ///   - range: The range of the match.
  ///   - code: The code.
  /// - Returns: The range of the name.
  static func nameRange(of range: Range<String.Index>, in code: String) -> Range<String.Index> {
    guard let name = code[range].firstMatch(of: #/\bvar\s+(\w+)/#) else { return range }
    return name.output.1.startIndex..<name.output.1.endIndex
  }

  /// Finds the `}` that closes a `{`.
  ///
  /// - Parameters:
  ///   - open: The offset of the `{`.
  ///   - bytes: The bytes of the code.
  /// - Returns: The offset of the `}`, or the end of the code when the
  ///   brace does not close.
  static func closingBrace(of open: Int, in bytes: [UInt8]) -> Int {
    var depth = 0
    for offset in open..<bytes.count {
      switch bytes[offset] {
      case UInt8(ascii: "{"): depth += 1
      case UInt8(ascii: "}"):
        depth -= 1
        if depth == 0 { return offset }
      default: break
      }
    }
    return bytes.count
  }

  /// The line of an offset of the code.
  ///
  /// - Parameters:
  ///   - offset: The offset.
  ///   - bytes: The bytes of the code.
  /// - Returns: The line number. The first line is line 1.
  static func line(of offset: Int, in bytes: [UInt8]) -> Int {
    bytes[..<offset].count { $0 == UInt8(ascii: "\n") } + 1
  }
}

/// The walk of one block of the code that finds the spacing modifiers on the
/// root of the block (``OuterSpacingScanner``).
struct RootWalk {
  /// The bytes of the code.
  let bytes: [UInt8]

  /// The view properties of the type of the block, by name.
  let properties: [String: OuterSpacingScanner.Block]

  /// The state of the walk at one offset.
  private struct State {
    /// The braces that are open, each with whether it holds the root.
    var braces: [(open: Int, holdsRoot: Bool)] = []

    /// The count of open parentheses and brackets.
    var parentheses = 0

    /// Whether the offset is on the root of the block.
    var isRoot: Bool {
      parentheses == 0 && braces.allSatisfy(\.holdsRoot)
    }
  }

  /// Finds the spacing modifiers on the root of a block that no surface
  /// modifier follows.
  ///
  /// - Parameters:
  ///   - block: The block, such as the `body` of a view or the content of a
  ///     scroll view.
  ///   - visited: The view properties that the walk read already, so that a
  ///     property that names itself ends the walk.
  /// - Returns: The offset of the `.` of each modifier.
  func hits(in block: OuterSpacingScanner.Block, visited: Set<String>) -> [Int] {
    var state = State()
    var found: [OuterSpacingScanner.Hit] = []
    for offset in (block.open + 1)..<block.close {
      let scope = state.braces.last?.open ?? block.open
      switch bytes[offset] {
      case UInt8(ascii: "{"):
        state.braces.append((offset, state.parentheses == 0 && holdsRoot(braceAt: offset)))
      case UInt8(ascii: "}"):
        _ = state.braces.popLast()
      case UInt8(ascii: "("), UInt8(ascii: "["):
        state.parentheses += 1
      case UInt8(ascii: ")"), UInt8(ascii: "]"):
        state.parentheses -= 1
      case UInt8(ascii: ".") where state.isRoot:
        note(modifierAt: offset, scope: scope, in: &found)
      case UInt8(ascii: "\n") where state.isRoot:
        found += namedProperty(after: offset, visited: visited).map { OuterSpacingScanner.Hit(scope: scope, offset: $0) }
      default:
        break
      }
    }
    return found.map(\.offset)
  }

  /// Notes the modifier at a `.` on the root: a spacing modifier adds a hit,
  /// and a surface modifier clears the hits before it in the same block.
  ///
  /// - Parameters:
  ///   - offset: The offset of the `.`.
  ///   - scope: The offset of the `{` of the innermost block.
  ///   - found: The hits of the walk.
  private func note(modifierAt offset: Int, scope: Int, in found: inout [OuterSpacingScanner.Hit]) {
    guard let name = modifierName(at: offset) else { return }
    if OuterSpacingScanner.spacingModifiers.contains(name) {
      found.append(OuterSpacingScanner.Hit(scope: scope, offset: offset))
    } else if OuterSpacingScanner.surfaceModifiers.contains(name) || appliesSurfaceType(name, at: offset) {
      found.removeAll { $0.scope == scope }
    }
  }

  /// Whether the modifier at a `.` is `.modifier(_:)` with a surface type of
  /// the kit (``OuterSpacingScanner/surfaceModifierTypes``).
  ///
  /// - Parameters:
  ///   - name: The name of the modifier.
  ///   - offset: The offset of the `.`.
  /// - Returns: `true` for a call such as `.modifier(DeckSurface())`.
  private func appliesSurfaceType(_ name: String, at offset: Int) -> Bool {
    guard name == OuterSpacingScanner.modifierCall else { return false }
    let start = offset + 1 + name.utf8.count + 1
    guard start < bytes.count else { return false }
    let end = bytes[start...].firstIndex { !Self.isWordByte($0) } ?? bytes.count
    return OuterSpacingScanner.surfaceModifierTypes.contains(String(decoding: bytes[start..<end], as: UTF8.self))
  }

  /// The name of the modifier that starts at a `.`, such as `padding` for
  /// `.padding(`.
  ///
  /// The `.` starts a modifier when white space, `)`, `}` or `]` stands
  /// before it, and `(` or `{` follows the name. A `.` right after a name,
  /// such as the `.` of `editorStyle.tile`, is a member, not a modifier.
  ///
  /// - Parameter offset: The offset of the `.`.
  /// - Returns: The name, or `nil` when the `.` does not start a modifier.
  func modifierName(at offset: Int) -> String? {
    guard offset > 0, Self.startsModifier(after: bytes[offset - 1]) else { return nil }
    let start = offset + 1
    let end = bytes[start...].firstIndex { !Self.isWordByte($0) } ?? bytes.count
    let next = bytes[end...].first { $0 != UInt8(ascii: " ") }
    guard end > start, next == UInt8(ascii: "(") || next == UInt8(ascii: "{") else { return nil }
    return String(decoding: bytes[start..<end], as: UTF8.self)
  }

  /// The hits of the view property that the line after a line break names
  /// alone, such as `bannerStack`.
  ///
  /// - Parameters:
  ///   - offset: The offset of the line break.
  ///   - visited: The view properties that the walk read already.
  /// - Returns: The hits of the root of the property, or none when the line
  ///   names no view property of the type.
  private func namedProperty(after offset: Int, visited: Set<String>) -> [Int] {
    let end = bytes[(offset + 1)...].firstIndex(of: UInt8(ascii: "\n")) ?? bytes.count
    let name = String(decoding: bytes[(offset + 1)..<end], as: UTF8.self).trimmingCharacters(in: .whitespaces)
    guard !visited.contains(name), let property = properties[name] else { return [] }
    return hits(in: property, visited: visited.union([name]))
  }

  /// Whether the `{` at an offset holds the root of its block: the brace of
  /// a branch keyword (``OuterSpacingScanner/branchKeywords``) or of a
  /// transparent container (``OuterSpacingScanner/transparentContainers``).
  ///
  /// - Parameter offset: The offset of the `{`.
  /// - Returns: `true` when the content of the brace is on the root.
  func holdsRoot(braceAt offset: Int) -> Bool {
    let start = (bytes[..<offset].lastIndex(of: UInt8(ascii: "\n")) ?? -1) + 1
    var prefix = Substring(String(decoding: bytes[start..<offset], as: UTF8.self))
    prefix = prefix.drop { $0 == " " || $0 == "}" }
    if prefix.hasPrefix(OuterSpacingScanner.returnKeyword + " ") {
      prefix = prefix.dropFirst(OuterSpacingScanner.returnKeyword.count + 1)
    }
    let word = prefix.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
    let rest = prefix.dropFirst(word.count).trimmingCharacters(in: .whitespaces)
    if OuterSpacingScanner.branchKeywords.contains(String(word)) { return true }
    return OuterSpacingScanner.transparentContainers.contains(String(word)) && (rest.isEmpty || rest.hasPrefix("("))
  }

  /// Whether a byte before a `.` makes the `.` the start of a modifier:
  /// white space, `)`, `}` or `]`.
  ///
  /// - Parameter byte: The byte before the `.`.
  /// - Returns: `true` when a modifier can start after the byte.
  static func startsModifier(after byte: UInt8) -> Bool {
    [UInt8(ascii: " "), UInt8(ascii: "\n"), UInt8(ascii: ")"), UInt8(ascii: "}"), UInt8(ascii: "]")].contains(byte)
  }

  /// Whether a byte is part of a word: a letter, a digit or `_`.
  ///
  /// - Parameter byte: The byte.
  /// - Returns: `true` for a word byte.
  static func isWordByte(_ byte: UInt8) -> Bool {
    let scalar = Unicode.Scalar(byte)
    return scalar == "_" || (scalar.isASCII && (scalar.properties.isAlphabetic || ("0"..."9").contains(scalar)))
  }
}
