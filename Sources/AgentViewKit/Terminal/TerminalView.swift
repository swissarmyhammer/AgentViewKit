import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACPClient
import SwiftUI

/// A terminal that the agent owns, with its output (plan.md §3.8
/// "Terminal view", §9 C).
///
/// The view shows a `TerminalEntry` of a `SessionModel`. It reads the entry
/// object, so a change to the object updates the view. The view shows the
/// computed `text` of the entry: a chunk adds text, and an `output` snapshot
/// replaces it. The kit does not decode the output. The view has these parts:
///
/// - A header with the command in the code font and the working directory.
/// - The output in a read-only EditorKit editor that grows to the height of
///   its text. ``ANSIText`` removes the escape sequences: the editor shows the
///   text with no escape sequences, and the SGR colors as EditorKit color
///   runs (`EditorModel.setColorRuns(_:)`). When the output has more rows
///   than the row limit, the editor shows only the last rows, and a Show All
///   button shows all rows.
/// - A footer. While the command runs, the footer shows a progress
///   indicator. After the command exits, the footer shows the exit code or
///   the signal.
///
/// The colors come from the terminal palette of the EditorKit theme
/// (`Theme.terminalPalette`): the 16 ANSI colors, the text color of output
/// with no SGR color, and the fill of the block.
public struct TerminalView: View {
  /// The accessibility identifier of the view.
  public static let identifier = "terminal"

  /// The accessibility identifier of the command in the header.
  public static let commandIdentifier = "terminal-command"

  /// The accessibility identifier of the working directory in the header.
  public static let cwdIdentifier = "terminal-cwd"

  /// The accessibility identifier of the progress indicator.
  public static let progressIdentifier = "terminal-progress"

  /// The accessibility identifier of the footer with the exit status.
  public static let footerIdentifier = "terminal-exit"

  /// The accessibility identifier of the text that tells how many rows show.
  public static let capIdentifier = "terminal-cap"

  /// The accessibility identifier of the Show All button.
  public static let showAllIdentifier = "terminal-show-all"

  /// The number of rows that the view shows before the user selects Show
  /// All, when the host gives no row limit.
  public static let defaultRowLimit = CommandOutputView.defaultRowLimit

  /// The exit status of a terminal, as the footer shows it.
  public enum ExitSummary: Equatable, Sendable {
    /// The process exited with a code.
    case code(Int)
    /// A signal stopped the process.
    case signal(String)
    /// The process exited, but the source gave no code and no signal.
    case unknown

    /// Makes the summary of an exit. A signal has priority over a code.
    ///
    /// - Parameters:
    ///   - code: The exit code of the process, or `nil` when it is not known.
    ///   - signal: The name of the signal that stopped the process, or `nil`.
    public init(code: Int?, signal: String?) {
      if let signal {
        self = .signal(signal)
      } else if let code {
        self = .code(code)
      } else {
        self = .unknown
      }
    }

    /// The text of the footer.
    public var label: String {
      switch self {
      case .code(let code): String(localized: "Exit code \(code)", bundle: .module)
      case .signal(let signal): String(localized: "Stopped by \(signal)", bundle: .module)
      case .unknown: String(localized: "Exited", bundle: .module)
      }
    }

    /// The outcome of the command, or `nil` when it is not known.
    ///
    /// A signal is a failure.
    public var outcome: CommandOutputView.ExitOutcome? {
      switch self {
      case .code(let code): CommandOutputView.ExitOutcome(exitCode: code)
      case .signal: .failure
      case .unknown: nil
      }
    }

    /// The SF Symbol name of the footer.
    var symbolName: String {
      switch self {
      case .code: outcome?.symbolName ?? ItemStatus.unknown.systemImage
      case .signal: SharedSymbol.signal
      case .unknown: ItemStatus.unknown.systemImage
      }
    }
  }

  /// The terminal entry to show.
  let entry: TerminalEntry
  /// The number of rows that show before the user selects Show All.
  let rowLimit: Int
  /// The model that the host gives, or `nil` when the view keeps its own.
  let suppliedModel: EditorModel?

  /// Whether the user selected Show All.
  @State private var showsAll = false
  /// The model that the view keeps when the host gives no model.
  @State private var ownModel = OwnModelSlot()

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  /// Makes the view of a terminal entry of a `SessionModel` (plan.md §3.8
  /// "Terminal view").
  ///
  /// The view shows the computed `text` of the entry.
  ///
  /// - Parameters:
  ///   - entry: The terminal entry to show.
  ///   - rowLimit: The number of rows that show before the user selects Show
  ///     All.
  ///   - model: The model of the editor, or `nil` to keep an own model. The
  ///     view makes the model read-only and sets its text.
  public init(
    entry: TerminalEntry,
    rowLimit: Int = TerminalView.defaultRowLimit,
    model: EditorModel? = nil
  ) {
    self.entry = entry
    self.rowLimit = rowLimit
    self.suppliedModel = model
  }

  /// The exit status of the command, or `nil` while it runs.
  private var exitSummary: ExitSummary? {
    entry.exitStatus.map { ExitSummary(code: $0.exitCode, signal: $0.signal) }
  }

  /// The rows of the output that show, with no escape sequences, and their
  /// color runs.
  ///
  /// The view reads the computed `text` of the entry, which the client model
  /// decoded, so the kit does not decode it.
  private var output: TerminalOutput {
    TerminalOutput(
      output: entry.text, palette: editorTheme.terminalPalette,
      limit: showsAll ? Int.max : rowLimit)
  }

  public var body: some View {
    let output = output
    let rows = output.rows
    let model = suppliedModel ?? ownModel.model(text: rows.text)
    ContentTileStack {
      header
    } body: {
      if rows.isCapped {
        capRow(rows)
      }
      EditorView(model: model)
        .editorSizingMode(.intrinsic)
      footer
    }
    .contentTile()
    .terminalBlockFrame()
    .accessibilityElement(children: .contain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityIdentifier(Self.identifier)
    .onChange(of: output, initial: true) {
      model.syncReadOnly(to: rows.text, colorRuns: output.colorRuns)
    }
  }

  /// The label that VoiceOver reads for the view.
  var accessibilityLabel: String {
    if let command = entry.command {
      String(localized: "Terminal, \(command)", bundle: .module)
    } else {
      String(localized: "Terminal", bundle: .module)
    }
  }

  /// The row with the command and the working directory.
  private var header: some View {
    HStack(spacing: editorStyle.spacing.s) {
      Image(systemName: SharedSymbol.terminal)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text(entry.command ?? String(localized: "Terminal", bundle: .module))
        .font(editorTheme.codeFont)
        .foregroundStyle(entry.command == nil ? .secondary : .primary)
        .lineLimit(1)
        .truncationMode(.middle)
        .accessibilityIdentifier(Self.commandIdentifier)
      Spacer(minLength: editorStyle.spacing.s)
      if let cwd = entry.cwd?.rawValue {
        Text(cwd)
          .font(editorTheme.font(for: .ui, style: .caption))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.head)
          .help(cwd)
          .accessibilityLabel(String(localized: "Working directory \(cwd)", bundle: .module))
          .accessibilityIdentifier(Self.cwdIdentifier)
      }
    }
    .editorBlockHeader()
  }

  /// The row that tells how many rows show, with the Show All button.
  ///
  /// - Parameter rows: The rows that show.
  /// - Returns: The row.
  private func capRow(_ rows: CommandOutputView.VisibleRows) -> some View {
    OutputCapRow(
      rows: rows, capIdentifier: Self.capIdentifier,
      showAllIdentifier: Self.showAllIdentifier
    ) {
      showsAll = true
    }
  }

  /// The footer: a progress indicator while the command runs, and the exit
  /// status after it exits.
  @ViewBuilder private var footer: some View {
    if let summary = exitSummary {
      OutputExitLabel(
        text: summary.label, symbolName: summary.symbolName, outcome: summary.outcome,
        identifier: Self.footerIdentifier)
    } else {
      HStack(spacing: editorStyle.spacing.s) {
        ProgressView()
          .controlSize(.mini)
          .accessibilityLabel(String(localized: "Running", bundle: .module))
          .accessibilityIdentifier(Self.progressIdentifier)
        Text(String(localized: "Running", bundle: .module))
          .font(editorTheme.font(for: .ui, style: .caption))
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

#Preview("Terminal") {
  if let entry = PreviewFixtures.entry(
    .terminal(command: "swift test", output: "Build complete!\nAll tests passed.", exitCode: 0), as: TerminalEntry.self)
  {
    TerminalView(entry: entry)
  }
}
