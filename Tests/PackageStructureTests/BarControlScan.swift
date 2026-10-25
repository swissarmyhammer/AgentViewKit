import Foundation
import RegexBuilder

/// One call of a control type in a file that ``BarControlScan`` read: a
/// `Button`, a `Picker` or a `Toggle`, with the modifiers of its chain.
struct BarControlCall: Equatable, CustomStringConvertible {
  /// The file of the call, relative to the base of the scan.
  let file: String

  /// The line of the name of the control type. The first line is line 1.
  let line: Int

  /// The names of the modifiers that the expression of the control calls, in
  /// chain order, such as `buttonStyle` and `accessibilityIdentifier`.
  let modifiers: [String]

  var description: String { "\(file):\(line)" }
}

/// Finds the calls of the control types in the code of a Swift file, and the
/// modifier chain of each call.
///
/// The scan reads code with each comment and each string literal blanked
/// (``ThreadBottomBarStructureTests/code(of:)``), so a bracket in a literal
/// does not move the scan. A call is the name of a control type as a whole
/// word, then `(` or `{`. The expression of the call is that name, its
/// argument list and its trailing closures, labeled ones too, such as
/// `label: { … }`. The chain is each `.name` member that follows the
/// expression, each with its own argument list and closures.
enum BarControlScan {
  /// The brackets that open a group: an argument list, a closure or a
  /// subscript.
  static let openingBrackets: Set<Character> = ["(", "{", "["]

  /// The brackets that close a group.
  static let closingBrackets: Set<Character> = [")", "}", "]"]

  /// The pattern of a call of a control type, `Button`, `Picker` or
  /// `Toggle`: the name as a whole word, then `(` or `{`.
  static var controlCallPattern: Regex<Substring> {
    Regex {
      ChoiceOf {
        WordPattern.wholeWord("Button")
        WordPattern.wholeWord("Picker")
        WordPattern.wholeWord("Toggle")
      }
      ZeroOrMore(.whitespace)
      Lookahead(CharacterClass.anyOf("({"))
    }
  }

  /// The pattern of the label of a trailing closure, such as `label:`, up to
  /// the opening brace of the closure.
  static var trailingClosureLabelPattern: Regex<Substring> {
    Regex {
      ZeroOrMore(.whitespace)
      OneOrMore(.word)
      ":"
      ZeroOrMore(.whitespace)
      Lookahead("{")
    }
  }

  /// The pattern of one member of a modifier chain: white space, `.` and the
  /// name, which the pattern captures.
  static var memberPattern: Regex<(Substring, Substring)> {
    Regex {
      ZeroOrMore(.whitespace)
      "."
      Capture(OneOrMore(.word))
    }
  }

  /// Finds each call of a control type in `code`.
  ///
  /// - Parameters:
  ///   - code: The code of a file, with each comment and each string literal
  ///     blanked.
  ///   - file: The file of the code, for the result.
  /// - Returns: The calls, in source order.
  static func controlCalls(in code: String, file: String) -> [BarControlCall] {
    code.matches(of: controlCallPattern).map { match in
      BarControlCall(
        file: file, line: line(of: match.range.lowerBound, in: code),
        modifiers: modifierNames(after: expressionEnd(from: match.range.upperBound, in: code), in: code))
    }
  }

  /// The line of `index` in `code`.
  ///
  /// - Parameters:
  ///   - index: A position in `code`.
  ///   - code: The text.
  /// - Returns: The line number. The first line is line 1.
  static func line(of index: String.Index, in code: String) -> Int {
    code[..<index].count { $0 == "\n" } + 1
  }

  /// The end of an expression that starts at `start`: the position after its
  /// last group and after its last labeled trailing closure.
  ///
  /// - Parameters:
  ///   - start: The position after the name of the expression.
  ///   - code: The blanked code.
  /// - Returns: The position after the expression.
  static func expressionEnd(from start: String.Index, in code: String) -> String.Index {
    var cursor = start
    while true {
      let next = code[cursor...].firstIndex { !$0.isWhitespace } ?? code.endIndex
      if next < code.endIndex, openingBrackets.contains(code[next]), let close = closingIndex(of: next, in: code) {
        cursor = code.index(after: close)
      } else if let label = code[cursor...].prefixMatch(of: trailingClosureLabelPattern) {
        cursor = label.range.upperBound
      } else {
        return cursor
      }
    }
  }

  /// The names of the members of the modifier chain that starts at `start`.
  ///
  /// - Parameters:
  ///   - start: The position after an expression.
  ///   - code: The blanked code.
  /// - Returns: The names, in chain order.
  static func modifierNames(after start: String.Index, in code: String) -> [String] {
    var names: [String] = []
    var cursor = start
    while let member = code[cursor...].prefixMatch(of: memberPattern) {
      names.append(String(member.output.1))
      cursor = expressionEnd(from: member.range.upperBound, in: code)
    }
    return names
  }

  /// The position of the bracket that closes the group that opens at `open`.
  ///
  /// The code has no literal and no comment, so each bracket in it is a
  /// bracket of the code, and the kinds of bracket nest in order.
  ///
  /// - Parameters:
  ///   - open: The position of an opening bracket.
  ///   - code: The blanked code.
  /// - Returns: The position of the closing bracket, or `nil` when the group
  ///   does not close.
  static func closingIndex(of open: String.Index, in code: String) -> String.Index? {
    var depth = 0
    for index in code[open...].indices {
      if openingBrackets.contains(code[index]) {
        depth += 1
      } else if closingBrackets.contains(code[index]) {
        depth -= 1
        if depth == 0 { return index }
      }
    }
    return nil
  }
}
