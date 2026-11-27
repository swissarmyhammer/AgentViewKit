import AgentViewKitTestSupport
import AppKit
import EditorStyle
import EditorTheme
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The modules of the status line that take a tap are accessibility
/// elements also with no crumbs, and the glass of the header is one
/// container element (^y43c2hw).
///
/// VoiceOver presses a module through its element, and a UI test finds the
/// frame of each module and of the glass. Each test reads the accessibility
/// tree of a view in a window that is never ordered in (``ControlProbe``),
/// so no test shows a window or takes the focus. IntegrationTests
/// (`StatusLineModuleAccessibilityHostedTests`) does the same checks in a
/// hosted window.
@MainActor @Suite struct StatusLineModuleAccessibilityTests {
  /// The working folder of the session of the tests.
  static let cwd = "/Users/me/code/Kit"

  /// The home folder that the `directory` module shows as `~`.
  static let homeFolder = "/Users/me"

  /// The title of the session: not the name of the folder, so that the
  /// line shows the `directory` and the `session` module.
  static let sessionTitle = "Review"

  /// The data of the line of a root session: a working folder and a title.
  static let input = StatusLineInput(cwd: cwd, homeFolder: homeFolder, sessionTitle: sessionTitle)

  /// The rendered line of ``input`` with the default definition.
  static var rendering: StatusLineRendering {
    StatusLineRenderer.render(StatusLines.defaultDefinition, input: input)
  }

  /// The accessibility identifier of the `directory` module.
  static let directoryIdentifier = StatusLineView.identifier(for: .directory)

  /// The selector of the value description of an element: SwiftUI puts the
  /// value of a container element there, and VoiceOver reads it.
  static let valueDescriptionSelector = "accessibilityValueDescription"

  /// The largest difference, in points, between two edges that a frame
  /// test counts as the same edge. Layout rounds an edge to a pixel.
  static let edgeTolerance: CGFloat = 0.5

  /// The largest difference, in points, between the frame of a module
  /// element and the frame of its text.
  static let textFrameTolerance: CGFloat = 1

  /// A short working folder, whose `directory` module shows one form.
  static let shortCwd = "/Users/me/Kit"

  /// The data of a line that shows the `directory` module of ``shortCwd``.
  static let shortInput = StatusLineInput(cwd: shortCwd, homeFolder: homeFolder, sessionTitle: sessionTitle)

  /// A definition whose line shows only the `directory` module.
  static var directoryOnlyDefinition: StatusLineDefinition {
    get throws {
      var definition = StatusLines.defaultDefinition
      definition.format = try StatusLineFormat(parsing: "$directory")
      return definition
    }
  }

  /// The line of a root session that shows only the `directory` module of
  /// ``shortCwd``.
  static var directoryOnlyLine: some View {
    get throws {
      StatusLineContent(
        input: shortInput, definition: try directoryOnlyDefinition, path: [], rootTitle: nil, select: { _ in })
    }
  }

  /// The width of the text of the `directory` module of ``shortInput``, in
  /// the font of the line.
  static var directoryTextWidth: CGFloat {
    get throws {
      let rendering = StatusLineRenderer.render(try directoryOnlyDefinition, input: shortInput)
      let piece = try #require(rendering.pieces.first { $0.module == .directory })
      return NSHostingView(rootView: StatusLinePieceProbe(piece: piece)).fittingSize.width
    }
  }

  /// The text of one part of the line in the font of the line, as
  /// ``StatusLineContent`` draws it, with no element and no frame of its own.
  struct StatusLinePieceProbe: View {
    /// The part of the line.
    let piece: StatusLinePiece

    @Environment(\.editorTheme) private var editorTheme

    var body: some View {
      StatusLinePieceText(piece: piece)
        .font(editorTheme.font(for: .ui, style: StatusLineContent.textStyle))
        .lineLimit(1)
    }
  }

  /// The modules that the status line action of the tests got, in order.
  @MainActor final class ActionLog {
    /// The module of each run of the action.
    var modules: [StatusLineModuleID] = []
  }

  /// The line of a root session, with no crumbs, whose status line action
  /// records each module in `log`.
  ///
  /// - Parameter log: The log of the action.
  /// - Returns: The line.
  static func rootLine(log: ActionLog = ActionLog()) -> some View {
    StatusLineContent(
      input: input, definition: StatusLines.defaultDefinition, path: [], rootTitle: nil, select: { _ in }
    )
    .statusLineActions { module, _ in log.modules.append(module) }
  }

  /// The header of a root session with ``cwd``.
  static var header: some View {
    ThreadStatusHeader(
      session: .preview(cwd: AbsolutePath(rawValue: cwd)), connection: .preview(), sessionTitle: sessionTitle,
      contextMenuPath: nil, select: { _ in }
    )
    .statusLineHomeFolder(URL(filePath: homeFolder, directoryHint: .isDirectory))
  }

  /// A production change that fails this test: the line of a root session
  /// is one element with no child again (`.ignore`), so the module has no
  /// element.
  @Test func theDirectoryModuleIsAButtonInsideTheLine() async {
    let roles = await ControlProbe.read(StatusLineView.identifier, in: Self.rootLine()) { line in
      accessibilitySubtree(of: line).dropFirst()
        .filter { accessibilityIdentifier(of: $0) == Self.directoryIdentifier }
        .map(accessibilityRole(of:))
    }

    #expect(roles == [NSAccessibility.Role.button.rawValue])
  }

  /// A production change that fails this test: the module has no
  /// accessibility action, so a press of VoiceOver runs no host command.
  @Test func aPressOfTheDirectoryModuleRunsItsActionOneTime() async {
    let log = ActionLog()

    _ = await ControlProbe.read(Self.directoryIdentifier, in: Self.rootLine(log: log)) {
      try? performAccessibilityPress(on: $0)
    }

    #expect(log.modules == [.directory])
  }

  /// A production change that fails this test: the module element does not
  /// give its help as its value.
  @Test func theDirectoryModuleGivesItsHelpAsItsValue() async {
    let value = await ControlProbe.read(Self.directoryIdentifier, in: Self.rootLine(), accessibilityValue(of:))

    #expect(value == Self.rendering.help(of: .directory))
  }

  /// A production change that fails this test: the module element takes the
  /// frame of the full width of the line, and not the frame of its text.
  @Test func theDirectoryModuleIsNarrowerThanTheLine() async {
    let frames = await ControlProbe.read(StatusLineView.identifier, in: Self.rootLine()) { line in
      Self.frames(of: line, andOfTheElementIdentifiedAs: Self.directoryIdentifier)
    }

    let (line, module) = (frames??.outer, frames??.inner)
    #expect(
      module.map { $0.width > 0 && $0.width < (line?.width ?? 0) } == true,
      "line \(String(describing: line)), module \(String(describing: module))")
  }

  /// A production change that fails this test: SwiftUI gives the one module
  /// of the line the frame of the line, so a UI test sees a module where a
  /// tap does nothing.
  @Test func theOneModuleOfALineIsNarrowerThanTheLine() async throws {
    let frames = await ControlProbe.read(StatusLineView.identifier, in: try Self.directoryOnlyLine) { line in
      Self.frames(of: line, andOfTheElementIdentifiedAs: Self.directoryIdentifier)
    }

    let (line, module) = (frames??.outer, frames??.inner)
    #expect(
      module.map { $0.width > 0 && $0.width < (line?.width ?? 0) } == true,
      "line \(String(describing: line)), module \(String(describing: module))")
  }

  /// A production change that fails this test: the one module of the line
  /// has a frame that is not the frame of its text.
  @Test func theOneModuleOfALineHasTheWidthOfItsText() async throws {
    let textWidth = try Self.directoryTextWidth
    let width = await ControlProbe.read(Self.directoryIdentifier, in: try Self.directoryOnlyLine) {
      accessibilityFrame(of: $0)?.width
    }

    #expect(
      width.map { abs(($0 ?? 0) - textWidth) <= Self.textFrameTolerance } == true,
      "module \(String(describing: width)), text \(textWidth)")
  }

  /// A production change that fails this test: the line gives no label, so
  /// VoiceOver does not read the text of the line.
  @Test func theLineKeepsThePlainTextAsItsLabel() async {
    let label = await ControlProbe.read(StatusLineView.identifier, in: Self.rootLine(), accessibilityLabel(of:))

    #expect(label == Self.rendering.plainText)
  }

  /// A production change that fails this test: the container of the line
  /// gives no value, so VoiceOver does not read the full path of the folder.
  @Test func theLineKeepsTheFullPathAsTheValueThatVoiceOverReads() async {
    let value = await ControlProbe.read(StatusLineView.identifier, in: Self.rootLine()) {
      accessibilityString(Self.valueDescriptionSelector, of: $0)
    }

    #expect(value == Self.cwd)
  }

  /// A production change that fails this test: the glass of the header has
  /// no element, or its element does not hold the inset around the text of
  /// the line.
  @Test func theHeaderElementHoldsTheModuleWithTheInsetOfTheLine() async {
    let inset = ThreadStatusHeader.inset(in: EditorStyle.default.spacing)
    let frames = await ControlProbe.read(ThreadStatusHeader.identifier, in: Self.header) { header in
      Self.frames(of: header, andOfTheElementIdentifiedAs: Self.directoryIdentifier)
    }

    let (header, module) = (frames??.outer, frames??.inner)
    let padded = module?.insetBy(dx: Self.edgeTolerance - inset.leading, dy: Self.edgeTolerance - inset.top)
    #expect(
      padded.map { header?.contains($0) == true } == true,
      "header \(String(describing: header)), module \(String(describing: module))")
  }

  /// A production change that fails this test: SwiftUI merges the container
  /// of the glass with the container of the line, so the line has no element
  /// of its own.
  @Test func theLineIsAnElementInsideTheHeader() async {
    let identifiers = await ControlProbe.read(ThreadStatusHeader.identifier, in: Self.header) { header in
      accessibilitySubtree(of: header).dropFirst().compactMap(accessibilityIdentifier(of:))
    }

    #expect(identifiers?.contains(StatusLineView.identifier) == true)
  }

  /// The accessibility frame of a container, and of the first element under
  /// it that has an identifier.
  ///
  /// - Parameters:
  ///   - container: The container element.
  ///   - identifier: The accessibility identifier of the inner element.
  /// - Returns: The two frames, or `nil` when an element or a frame is
  ///   missing.
  static func frames(of container: NSObject, andOfTheElementIdentifiedAs identifier: String)
    -> (outer: CGRect, inner: CGRect)?
  {
    let inner = accessibilitySubtree(of: container).dropFirst().first { accessibilityIdentifier(of: $0) == identifier }
    guard let outerFrame = accessibilityFrame(of: container), let inner, let innerFrame = accessibilityFrame(of: inner)
    else { return nil }
    return (outerFrame, innerFrame)
  }
}
