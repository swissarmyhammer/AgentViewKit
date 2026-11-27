import AgentViewKit
import AppKit
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The data of the tests of the status line modules as accessibility
/// elements (^y43c2hw).
///
/// The unit tests (`StatusLineModuleAccessibilityTests`) and the hosted tests
/// of the IntegrationTests package
/// (`StatusLineModuleAccessibilityHostedTests`) use these fixtures, and keep
/// no copy of their own.
public enum StatusLineModuleFixtures {
  /// The working folder of the session of the tests.
  public static let cwd = "/Users/me/code/Kit"

  /// A short working folder, whose `directory` module shows one form.
  public static let shortCwd = "/Users/me/Kit"

  /// The home folder that the `directory` module shows as `~`.
  public static let homeFolder = "/Users/me"

  /// ``homeFolder`` as a folder URL, for `statusLineHomeFolder(_:)`.
  public static let homeFolderURL = URL(filePath: homeFolder, directoryHint: .isDirectory)

  /// The title of the session: not the name of the folder, so that the
  /// line shows the `directory` and the `session` module.
  public static let sessionTitle = "Review"

  /// The accessibility identifier of the `directory` module.
  public static let directoryIdentifier = StatusLineView.identifier(for: .directory)

  /// The largest difference, in points, between the frame of a module
  /// element and the frame of its text.
  public static let textFrameTolerance: CGFloat = 1

  /// The data of a line of a root session with a working folder and
  /// ``sessionTitle``.
  ///
  /// - Parameter folder: The working folder of the session.
  /// - Returns: The data of the line.
  public static func input(folder: String) -> StatusLineInput {
    StatusLineInput(cwd: folder, homeFolder: homeFolder, sessionTitle: sessionTitle)
  }

  /// A definition whose line shows only the `directory` module.
  public static var directoryOnlyDefinition: StatusLineDefinition {
    get throws {
      var definition = StatusLines.defaultDefinition
      definition.format = try StatusLineFormat(parsing: "$directory")
      return definition
    }
  }

  /// The header of a root session, with no crumbs, with ``sessionTitle``
  /// and ``homeFolder``, whose status line action records each module in
  /// `log`.
  ///
  /// - Parameters:
  ///   - folder: The working folder of the session.
  ///   - log: The log of the action.
  ///   - definition: The status line definition.
  /// - Returns: The header.
  @MainActor public static func header(
    folder: String = cwd, log: StatusLineActionLog = StatusLineActionLog(),
    definition: StatusLineDefinition = StatusLines.defaultDefinition
  ) -> some View {
    ThreadStatusHeader(
      session: .preview(cwd: AbsolutePath(rawValue: folder)), connection: .preview(), sessionTitle: sessionTitle,
      contextMenuPath: nil, select: { _ in }
    )
    .statusLine(definition)
    .statusLineHomeFolder(homeFolderURL)
    .statusLineActions { module, _ in log.record(module) }
  }

  /// The width of the text of the `directory` module of a line that shows
  /// only that module, in the font of the line.
  ///
  /// - Parameter folder: The working folder of the session.
  /// - Returns: The width of the text, in points.
  /// - Throws: An error when the line has no `directory` part.
  public static func directoryTextWidth(folder: String) throws -> CGFloat {
    let rendering = StatusLineRenderer.render(try directoryOnlyDefinition, input: input(folder: folder))
    let piece = try #require(rendering.pieces.first { $0.module == .directory })
    return NSHostingView(rootView: PieceTextProbe(piece: piece)).fittingSize.width
  }

  /// The text of one part of the line in the font of the line, as
  /// ``StatusLineContent`` draws it, with no element and no frame of its own.
  private struct PieceTextProbe: View {
    /// The part of the line.
    let piece: StatusLinePiece

    @Environment(\.editorTheme) private var editorTheme

    var body: some View {
      StatusLinePieceText(piece: piece)
        .font(editorTheme.font(for: .ui, style: StatusLineContent.textStyle))
        .lineLimit(1)
    }
  }
}

/// The modules that the status line action of a test got, in order.
///
/// The unit tests and the hosted tests of the status line modules share this
/// log.
@MainActor public final class StatusLineActionLog {
  /// The module of each run of the action.
  public private(set) var modules: [StatusLineModuleID] = []

  /// Makes an empty log.
  public init() {}

  /// Records one run of the action.
  ///
  /// - Parameter module: The module of the run.
  public func record(_ module: StatusLineModuleID) {
    modules.append(module)
  }
}
