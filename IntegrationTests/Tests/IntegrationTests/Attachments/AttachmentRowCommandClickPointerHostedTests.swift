@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import SwiftUI
import Testing

/// A command of a host row that records each run, as the Add to Selection and
/// Extend Selection commands of a host's chat row run on a bound click.
nonisolated struct RowClickRecorder: Command {
  let id: CommandID

  /// The log that gets the id of each run.
  let log: SubjectLog<CommandID>

  var title: String { id.rawValue }

  func availability(in context: CommandContext) -> Availability { .available }

  func run(in context: CommandContext) -> Bool {
    log.record(id)
    return true
  }
}

/// The window of one test: a host row that binds the Command-click and the
/// Shift-click to commands of its own (`.commandClick(_:segment:command:)`),
/// as TestudoApp binds a chat row, and that holds three files: two location
/// chips, then an attachment chip.
///
/// The row holds a caption beside the files, so the row reaches past each
/// file, as a chat row does. The selection starts with the first file, which
/// is the anchor of an extend. The transcript order of the files is the order
/// of the views in the row.
@MainActor private struct RowBed {
  /// The file names, in transcript order: two location chips, then the
  /// attachment chip.
  static let names = ["first.bin", "second.bin", "third.bin"]

  /// The scope of the window.
  static let window = FocusSegment(kind: "rowClickWindow")

  /// The scope of the row, which the bindings of the row run at.
  static let row = FocusSegment(kind: "rowClickRow")

  /// The command that the Command-click of the row runs.
  static let addCommand: CommandID = "host.rowAddToSelection"

  /// The command that the Shift-click of the row runs.
  static let extendCommand: CommandID = "host.rowExtendSelection"

  /// The accessibility identifier of the caption of the row.
  static let captionIdentifier = "row-caption"

  /// The width of the window, which holds the caption and the chips of the
  /// row on one line each.
  static let windowWidth: CGFloat = 600

  /// The height of the window, which holds the caption and the files of the
  /// row.
  static let windowHeight: CGFloat = 300

  /// The size of the window.
  static let size = CGSize(width: windowWidth, height: windowHeight)

  /// The folder of the files.
  let directory: TemporaryFolder

  /// The files, in transcript order.
  let files: [AgentViewKit.Attachment]

  /// The first file, which the selection starts with: the anchor of an
  /// extend.
  let anchor: AgentViewKit.Attachment

  /// The last file, the file of the attachment chip that the tests click.
  let clicked: AgentViewKit.Attachment

  /// The inspector selection of the window.
  let selection: InspectorSelection

  /// The id of each run of a command of the row, in order.
  let rowRuns: SubjectLog<CommandID>

  /// The harness that shows the window.
  let harness: HostedViewHarness<AnyView>

  /// Writes the files, mounts the row and waits for the beacons of the
  /// window and the row.
  init() async throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    let files = try Self.names.map { try AttachmentFixtures.attachment(named: $0, in: directory) }
    let anchor = try #require(files.first)
    let clicked = try #require(files.last)
    let selection = InspectorSelection(attachments: [anchor])
    let rowRuns = SubjectLog<CommandID>()
    let system = CommandSystem()
    for command in [Self.addCommand, Self.extendCommand] {
      let definition = CommandDefinition(id: command, title: .static(command.rawValue)) { [rowRuns] _ in
        RowClickRecorder(id: command, log: rowRuns)
      }
      system.registry.register(definition, at: .root(Self.window))
    }
    self.directory = directory
    self.files = files
    self.anchor = anchor
    self.clicked = clicked
    self.selection = selection
    self.rowRuns = rowRuns
    let window = FocusPath.root(Self.window)
    harness = try await CommandWindow(
      system: system, size: Self.size, beacons: [window, window.appending(Self.row)]
    ) {
      Self.row(locationFiles: files.dropLast(), clicked: clicked)
        .commandScope(segment: Self.window)
        .environment(\.inspectorSelection, selection)
        .environment(\.transcriptFileOrder, TranscriptFileOrder())
    }.harness
  }

  /// The row: a caption over the location chips of the first files and the
  /// attachment view of the clicked file, in the scope of the row, with the
  /// bound clicks of the row around that scope.
  ///
  /// - Parameters:
  ///   - locationFiles: The files of the location chips, in transcript order.
  ///   - clicked: The file of the attachment view, the last in transcript
  ///     order.
  /// - Returns: The row.
  private static func row(
    locationFiles: ArraySlice<AgentViewKit.Attachment>, clicked: AgentViewKit.Attachment
  ) -> some View {
    let locations = locationFiles.enumerated().map { index, file in
      ToolCallLocationChips.Location(
        path: file.url.path(percentEncoded: false), line: nil, identifier: "row-location-\(index)")
    }
    return VStack(alignment: .leading) {
      Text(captionIdentifier).accessibilityIdentifier(captionIdentifier)
      ToolCallLocationChips(locations: locations)
      AttachmentView(clicked)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .commandScope(segment: row)
    .commandClick(.command, segment: row, command: addCommand)
    .commandClick(.shift, segment: row, command: extendCommand)
  }

  /// Clicks the attachment chip with `modifiers` held, through the event
  /// queue.
  ///
  /// - Parameter modifiers: The held modifier keys.
  /// - Throws: The error of the click.
  func clickChip(with modifiers: EventModifiers) async throws {
    try await harness.sendClick(identifier: AttachmentView.identifier(for: .chip), modifiers: modifiers)
  }

  /// Closes the harness and removes the files.
  func close() {
    harness.close()
    directory.remove()
  }
}

/// A Command-click and a Shift-click on a file inside a host row that binds
/// both clicks (`.commandClick`) change the file selection of the kit, and
/// run no command of the row (card ^se9sxxe).
///
/// EditorKit takes a bound click in the window before any gesture sees it, so
/// the test clicks through the event queue: the hit test is the behaviour
/// under test. The click orders the window in behind every window and off the
/// screen, and the window stays not key.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentRowCommandClickPointerHostedTests {
  @Test func aCommandClickOnTheCaptionRunsTheCommandOfTheRow() async throws {
    let bed = try await RowBed()
    defer { bed.close() }

    try await bed.harness.sendClick(identifier: RowBed.captionIdentifier, modifiers: .command)

    #expect(bed.rowRuns.subjects == [RowBed.addCommand])
  }

  @Test func aCommandClickOnTheFileAddsItToTheSelection() async throws {
    let bed = try await RowBed()
    defer { bed.close() }

    try await bed.clickChip(with: .command)

    #expect(bed.selection.attachments == [bed.anchor, bed.clicked])
  }

  @Test func aCommandClickOnTheFileRunsNoCommandOfTheRow() async throws {
    let bed = try await RowBed()
    defer { bed.close() }

    try await bed.clickChip(with: .command)

    #expect(bed.rowRuns.subjects.isEmpty)
  }

  @Test func aShiftClickOnTheFileExtendsTheSelectionInTranscriptOrder() async throws {
    let bed = try await RowBed()
    defer { bed.close() }

    try await bed.clickChip(with: .shift)

    #expect(bed.selection.attachments == bed.files)
  }

  @Test func aShiftClickOnTheFileRunsNoCommandOfTheRow() async throws {
    let bed = try await RowBed()
    defer { bed.close() }

    try await bed.clickChip(with: .shift)

    #expect(bed.rowRuns.subjects.isEmpty)
  }
}
