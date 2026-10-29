import Foundation
import Testing

/// Holds that a kit view carries no outer padding or margin, and that each
/// space of a kit view is a value of the style of the theme (^rgsq3k4).
///
/// The user rule of 2026-10-29: a control has no padding and no margin
/// around it by default. The space between two controls is the concern of
/// the layout that contains them, through a modifier or a wrapper that reads
/// the theme. Inside a control, such as the inset of the text in a chip, a
/// padding is right.
///
/// Two scans read the code of the kit and of its style library, with the
/// comments and the string literals blanked, above the previews of each file
/// (a preview pads its canvas, not a view):
///
/// - The outer scan (``OuterSpacingScanner``) finds a view that pads its own
///   root, or a list that insets the content of its own scroll view.
/// - The literal scan finds each space that is a number and not a value of
///   `\.editorStyle`: a padding, a margin or a stack spacing with a number
///   other than 0, a padding with the length of the system
///   (`.padding()`, `.padding(.horizontal)`), and a constant whose name ends
///   with `Padding`, `Spacing`, `Inset` or `Margin` and whose value is a
///   number other than 0. The scan reads one line at a time.
@Suite struct OuterPaddingTests {
  /// The lines that the literal scan allows, as `<file>: <trimmed line>`,
  /// each with the reason. An entry is only for an inset inside the surface
  /// of a control that no style token can give. No line of the kit needs
  /// one now.
  static let allowedLiterals: [String: String] = [:]

  /// The edges of a padding: a padding that names only edges takes the
  /// length of the system.
  static let edgeNames = ["top", "bottom", "leading", "trailing", "horizontal", "vertical", "all"]

  /// The suffixes of the name of a constant that holds a space.
  static let spaceNameSuffixes = ["Padding", "Spacing", "Inset", "Margin", "padding", "spacing", "inset", "margin"]

  /// The pattern of a spacing call, such as `.padding(`, with the text after
  /// it on the line as its capture.
  ///
  /// A `Regex` is not `Sendable`, so each read makes the value again.
  static var spacingCallPattern: Regex<(Substring, Substring)> {
    #/\.\s*(?:padding|safeAreaPadding|contentMargins)\s*\((.*)/#
  }

  /// The pattern of a stack spacing argument, with the value after it as its
  /// capture, up to the next `,` or `)`.
  ///
  /// A `Regex` is not `Sendable`, so each read makes the value again.
  static var spacingArgumentPattern: Regex<(Substring, Substring)> {
    #/\bspacing\s*:\s*([^,)]*)/#
  }

  /// The pattern of a constant with its name and its value as captures, such
  /// as `static let horizontalPadding: CGFloat = 6`.
  ///
  /// A `Regex` is not `Sendable`, so each read makes the value again.
  static var constantPattern: Regex<(Substring, Substring, Substring)> {
    #/\b(?:let|var)\s+(\w+)\s*(?::\s*[\w.]+\s*)?=\s*(.*)/#
  }

  /// Tells whether code holds a number literal other than 0, such as `8`,
  /// `-2` or `.5`.
  ///
  /// The code splits into words as in
  /// ``ContentTilePaddingTests/holdsNumberLiteral(_:)``. A word that starts
  /// with a digit and holds a digit other than 0 is a number other than 0.
  ///
  /// - Parameter code: The code to read.
  /// - Returns: `true` when a word of `code` is a number other than 0.
  static func holdsNonZeroNumber(_ code: Substring) -> Bool {
    code.split { !($0.isLetter || $0.isNumber || $0 == "_") }.contains { word in
      word.first?.isNumber == true && word.contains { $0.isNumber && $0 != "0" }
    }
  }

  /// Tells whether the arguments of a padding name only edges, or nothing,
  /// so that the padding takes the length of the system.
  ///
  /// - Parameter arguments: The text after the `(` of the call.
  /// - Returns: `true` for `)`, `.horizontal)` or `[.top, .bottom])`.
  static func takesSystemLength(_ arguments: Substring) -> Bool {
    guard let close = arguments.firstIndex(of: ")") else { return false }
    let names = arguments[..<close].split { " [],.".contains($0) }
    return names.allSatisfy { edgeNames.contains(String($0)) }
  }

  /// Tells whether one line of code gives a space as a number.
  ///
  /// - Parameter line: One line of code, with the comments and the string
  ///   literals blanked.
  /// - Returns: `true` when the line holds a spacing call with a number
  ///   other than 0 or with the length of the system, a stack spacing with a
  ///   number other than 0, or a space constant with a number other than 0.
  static func givesSpaceAsNumber(_ line: Substring) -> Bool {
    if let call = line.firstMatch(of: spacingCallPattern) {
      let arguments = call.output.1
      if holdsNonZeroNumber(arguments) || takesSystemLength(arguments) { return true }
    }
    if line.matches(of: spacingArgumentPattern).contains(where: { holdsNonZeroNumber($0.output.1) }) { return true }
    guard let constant = line.firstMatch(of: constantPattern) else { return false }
    let name = constant.output.1
    return spaceNameSuffixes.contains { name.hasSuffix($0) } && holdsNonZeroNumber(constant.output.2)
  }

  /// Finds the lines of a file that give a space as a number, above its
  /// previews.
  ///
  /// - Parameters:
  ///   - source: The text of a Swift file.
  ///   - file: The file name to write into each result.
  /// - Returns: `<file>:<line>` for each line, in line order.
  static func spaceLiterals(in source: String, file: String) -> [String] {
    let lines = ContentTilePaddingTests.codeLines(of: source)
      .prefix(ContentTilePaddingTests.lineCountAbovePreviews(in: source))
    return lines.enumerated().compactMap { offset, line in
      givesSpaceAsNumber(line) ? "\(file):\(offset + 1)" : nil
    }
  }

  /// Finds the outer spacing of the views of a file, above its previews.
  ///
  /// - Parameters:
  ///   - source: The text of a Swift file.
  ///   - file: The file name to write into each result.
  /// - Returns: `<file>:<line>` for each modifier, in line order.
  static func outerSpacing(in source: String, file: String) -> [String] {
    let previews = ContentTilePaddingTests.lineCountAbovePreviews(in: source)
    return OuterSpacingScanner.outerSpacingLines(inCode: ContentTilePaddingTests.code(of: source))
      .filter { $0 <= previews }
      .map { "\(file):\($0)" }
  }

  /// The text of the line of a hit.
  ///
  /// - Parameters:
  ///   - hit: `<file>:<line>`.
  ///   - files: The files of the kit, each with its text.
  /// - Returns: `<file>: <trimmed line>`, or `hit` when the line is not in
  ///   `files`.
  static func lineText(of hit: String, in files: [(path: String, text: String)]) -> String {
    let parts = hit.split(separator: ":")
    guard parts.count == 2, let number = Int(parts[1]),
      let text = files.first(where: { $0.path == parts[0] })?.text
    else { return hit }
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    return "\(parts[0]): \(lines[number - 1].trimmingCharacters(in: .whitespaces))"
  }

  /// The literal hits of the kit, each as `<file>: <trimmed line>`.
  ///
  /// - Returns: The hits, in the order of the files, then in line order.
  /// - Throws: The error of the scan when a directory cannot be read.
  static func kitSpaceLiterals() throws -> [String] {
    let files = try ContentTilePaddingTests.libraryFileTexts()
    return files.flatMap { Self.spaceLiterals(in: $0.text, file: $0.path) }.map { lineText(of: $0, in: files) }
  }

  @Test func theOuterScanFindsThePaddingAtTheEndOfABody() {
    let source = """
      struct Banner: View {
        var body: some View {
          if isShown {
            VStack {
              Text("A").padding(8)
            }
            .padding(editorStyle.tile.margin)
          }
        }
      }
      """

    #expect(Self.outerSpacing(in: source, file: "A.swift") == ["A.swift:7"])
  }

  @Test func theOuterScanSkipsAPaddingThatASurfaceFollows() {
    let source = """
      struct Chip: View {
        var body: some View {
          Text("A")
            .padding(.horizontal, editorStyle.spacing.s)
            .background(.quaternary, in: Capsule())
            .accessibilityHidden(true)
        }
      }
      struct Deck: View {
        var body: some View {
          VStack {
            Text("A")
          }
          .padding(editorStyle.tile.margin)
          .modifier(DeckSurface())
        }
      }
      """

    #expect(Self.outerSpacing(in: source, file: "A.swift").isEmpty)
  }

  @Test func theOuterScanFollowsAPropertyThatTheBodyNames() {
    let source = """
      struct Banner: View {
        var body: some View {
          stack
            .onChange(of: value) {}
        }

        @ViewBuilder private var stack: some View {
          Group {
            Text("A")
          }
          .padding(editorStyle.tile.margin)
        }
      }
      """

    #expect(Self.outerSpacing(in: source, file: "A.swift") == ["A.swift:11"])
  }

  @Test func theOuterScanFindsTheInsetOfTheContentOfAScrollView() {
    let source = """
      struct Timeline: View {
        var body: some View {
          VStack(spacing: 0) {
            ScrollView {
              LazyVStack {
                Text("A")
              }
              .padding(editorStyle.rowPadding)
            }
          }
        }
      }
      """

    #expect(Self.outerSpacing(in: source, file: "A.swift") == ["A.swift:8"])
  }

  @Test func theOuterScanSkipsThePaddingThatAViewGivesToItsChildren() {
    let source = """
      struct Thread: View {
        var body: some View {
          VStack {
            Header()
              .padding(.horizontal, editorStyle.spacing.m)
          }
          .safeAreaBar(edge: .bottom) {
            Controls().padding(editorStyle.spacing.m)
          }
          .overlay(alignment: .bottom) { Pill().padding(editorStyle.spacing.m) }
        }
      }
      struct Style: ViewModifier {
        func body(content: Content) -> some View {
          content.padding(editorStyle.tile.padding)
        }
      }
      """

    #expect(Self.outerSpacing(in: source, file: "A.swift").isEmpty)
  }

  @Test func theLiteralScanFindsEachSpaceThatIsANumber() {
    let source = """
      .padding()
      .padding(.horizontal)
      .padding([.top, .bottom])
      .padding(.horizontal, 2)
      .contentMargins(8, for: .scrollContent)
      VStack(alignment: .leading, spacing: 2) {
      static let horizontalPadding: CGFloat = 6
      .padding(.horizontal, editorStyle.spacing.s)
      .padding(cards.isEmpty ? .zero : editorStyle.tile.margin)
      VStack(spacing: 0) {
      static let sectionSpacing: CGFloat = 0
      static let insetSideCount: CGFloat = 2
      .frame(width: 2)
      """

    let found = Self.spaceLiterals(in: source, file: "A.swift")

    #expect(found == (1...7).map { "A.swift:\($0)" })
  }

  @Test func noKitViewPadsItself() throws {
    let files = try ContentTilePaddingTests.libraryFileTexts()
    let found = files.flatMap { Self.outerSpacing(in: $0.text, file: $0.path) }

    #expect(
      found.isEmpty,
      """
      A view has no padding or margin around it: the containing layout spaces it. Found:
      \(found.map { Self.lineText(of: $0, in: files) }.joined(separator: "\n"))
      """)
  }

  @Test func eachSpaceOfAKitViewIsAValueOfTheStyle() throws {
    let found = try Self.kitSpaceLiterals().filter { Self.allowedLiterals[$0] == nil }

    #expect(
      found.isEmpty,
      """
      Read each space from \\.editorStyle, not from a number or the system length. Found:
      \(found.joined(separator: "\n"))
      """)
  }

  @Test func eachAllowedLiteralIsInTheKit() throws {
    let found = Set(try Self.kitSpaceLiterals())

    let stale = Self.allowedLiterals.keys.filter { !found.contains($0) }.sorted()

    #expect(stale.isEmpty, "Remove the allowed lines that the kit no longer holds: \(stale)")
  }
}
