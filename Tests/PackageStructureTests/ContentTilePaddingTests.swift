import Foundation
import PackageFileSupport
import Testing

/// Holds the padding of each content tile to the tile tokens of the theme
/// (card ^ey6v778).
///
/// A content tile is a view that shows one block of content, with a border
/// or with none: a card, a banner, a request card, a tool call, terminal
/// output, a code block, a diff, an artifact. Each tile takes its padding
/// from `.contentTile()`, its header-to-body gap from `ContentTileStack`, and
/// the space to its neighbours from the tile margin. All three are the tile
/// tokens of `\.editorStyle` (`editorStyle.tile`). So a tile file gives no
/// padding of its own: each `.padding(` call in it reads a tile token and
/// holds no number literal.
///
/// The scan reads each Swift file of the kit as text, one line at a time,
/// with the comments and the string literals blanked. It reads the code
/// above the previews of a file only: a preview pads its canvas, not a tile.
/// The files of ``nonTileFiles`` are not tiles, so the scan skips them.
@Suite struct ContentTilePaddingTests {
  /// The files of the kit that are not tiles, relative to the package root,
  /// each with the reason. Each other file of the kit is a tile file.
  static let nonTileFiles = [
    KitSourceFiles.kitFile("Activity/ActivityTimeline.swift"): "A list of activity rows.",
    KitSourceFiles.kitFile("Attachments/AttachmentActions.swift"): "Action buttons; the padding is a preview sample.",
    KitSourceFiles.kitFile("Attachments/AttachmentChip.swift"): "A small chip.",
    KitSourceFiles.kitFile("Citations/SourcesView.swift"): "A list of source rows.",
    KitSourceFiles.kitFile("Connections/AgentInfoHeader.swift"): "The glass header of the thread: a bar.",
    KitSourceFiles.kitFile("Connections/ConnectionRow.swift"): "A list row.",
    KitSourceFiles.kitFile("Diff/DiffFileChip.swift"): "A small chip.",
    KitSourceFiles.kitFile("Elicitation/ElicitationTabChip.swift"): "A small chip.",
    KitSourceFiles.kitFile("Input/AgentOneLineField.swift"): "A text field.",
    KitSourceFiles.kitFile("Input/EditorKitPromptEditor.swift"): "The prompt editor of the composer.",
    KitSourceFiles.kitFile("Input/PromptInputView.swift"): "The composer: a bar.",
    KitSourceFiles.kitFile("Items/ToolCallLocationChips.swift"): "Small chips.",
    KitSourceFiles.kitFile("Sessions/PendingRequestCountBadge.swift"): "A small badge.",
    KitSourceFiles.kitFile("Sessions/SessionListView.swift"): "A list of sessions.",
    KitSourceFiles.kitFile("Status/TaskListView.swift"): "A list of plan rows.",
    KitSourceFiles.kitFile("Thread/AgentThreadView.swift"): "The bars of the thread.",
    KitSourceFiles.kitFile("Thread/ConversationEmptyState.swift"): "The empty state of the list.",
    KitSourceFiles.kitFile("Thread/ConversationView.swift"): "The list of the transcript.",
  ]

  /// The text that starts a preview.
  static let previewMacro = "#Preview"

  /// The comment that starts the previews of a file, with their samples.
  static let previewsMark = "// MARK: - Previews"

  /// The text that starts a padding call.
  static let paddingCall = ".padding("

  /// The text that names a tile token: `editorStyle.tile.padding`,
  /// `editorStyle.tile.gap` or `editorStyle.tile.margin`.
  static let tileToken = "tile."

  /// Tells whether code holds a number literal, such as `8`, `-2` or `.5`.
  ///
  /// The code splits into words at each character that is not a letter, a
  /// digit or `_`. A word that starts with a digit is a number literal. A
  /// digit inside a name, such as the `2` of `x2`, does not start a word.
  ///
  /// - Parameter code: The code to read.
  /// - Returns: `true` when a word of `code` starts with a digit.
  static func holdsNumberLiteral(_ code: Substring) -> Bool {
    code.split { !($0.isLetter || $0.isNumber || $0 == "_") }.contains { $0.first?.isNumber == true }
  }

  /// The lines of a source above its previews: the lines before the first
  /// line that starts a preview or the previews mark.
  ///
  /// - Parameter source: The text of a Swift file.
  /// - Returns: The number of lines above the previews.
  static func lineCountAbovePreviews(in source: String) -> Int {
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
    return lines.firstIndex { line in
      let text = line.trimmingCharacters(in: .whitespaces)
      return text.hasPrefix(previewMacro) || text == previewsMark
    } ?? lines.count
  }

  /// Tells whether one line of code gives a tile a padding of its own.
  ///
  /// - Parameter line: One line of code, with the comments and the string
  ///   literals blanked.
  /// - Returns: `true` when the line holds a `.padding(` call whose
  ///   arguments on the line name no tile token or hold a number literal.
  static func isOwnPadding(_ line: Substring) -> Bool {
    guard let call = line.range(of: paddingCall) else { return false }
    let arguments = line[call.upperBound...]
    return !arguments.contains(tileToken) || holdsNumberLiteral(arguments)
  }

  /// Finds the padding calls of a tile file that do not read a tile token.
  ///
  /// - Parameters:
  ///   - source: The text of a Swift file.
  ///   - file: The file name to write into each result.
  /// - Returns: `<file>:<line>` for each padding call above the previews
  ///   that gives a padding of its own, in line order.
  static func ownPaddings(in source: String, file: String) -> [String] {
    let code = String(
      decoding: SwiftLiteralLexer.blankingCommentsAndLiterals(in: Array(source.utf8)), as: UTF8.self)
    let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
      .prefix(lineCountAbovePreviews(in: source))
    return lines.enumerated().compactMap { offset, line in
      isOwnPadding(line) ? "\(file):\(offset + 1)" : nil
    }
  }

  @Test func theScanFindsEachPaddingOfATileThatReadsNoTileToken() {
    let source = """
      .padding()
      .padding(8)
      .padding(.horizontal, editorStyle.spacing.m)
      .padding(isEmpty ? 0 : editorStyle.tile.margin)
      .padding(editorStyle.tile.padding)
      .padding(.top, editorStyle.tile.gap)
      .contentTile()
      .padding(.leading, editorStyle.tile.padding) // .padding(4)
      """

    let found = Self.ownPaddings(in: source, file: "A.swift")

    #expect(found == ["A.swift:1", "A.swift:2", "A.swift:3", "A.swift:4"])
  }

  @Test func theScanSkipsThePreviewsOfAFile() {
    let source = """
      .padding(editorStyle.tile.padding)
      // MARK: - Previews
      .padding()
      """
    let previewSource = """
      .padding(editorStyle.tile.padding)
      #Preview("A tile") {
        Tile().padding()
      }
      """

    #expect(Self.ownPaddings(in: source, file: "A.swift").isEmpty)
    #expect(Self.ownPaddings(in: previewSource, file: "B.swift").isEmpty)
  }

  @Test func noTileFileGivesAPaddingOfItsOwn() throws {
    let files = try PackageFiles.swiftFileTexts(
      below: PackageFiles.file(KitSourceFiles.kitPath), relativeTo: PackageFiles.root)
    let found = files.filter { Self.nonTileFiles[$0.path] == nil }.flatMap { file in
      Self.ownPaddings(in: file.text, file: file.path)
    }

    #expect(found.isEmpty, "Pad a tile with .contentTile() or a tile token of \\.editorStyle: \(found)")
  }

  @Test func eachFileOfTheNonTileListIsInTheKit() throws {
    let files = Set(
      try PackageFiles.swiftFileTexts(
        below: PackageFiles.file(KitSourceFiles.kitPath), relativeTo: PackageFiles.root
      ).map(\.path))

    let missing = Self.nonTileFiles.keys.filter { !files.contains($0) }.sorted()

    #expect(missing.isEmpty, "Remove the files that are not in the kit: \(missing)")
  }
}
