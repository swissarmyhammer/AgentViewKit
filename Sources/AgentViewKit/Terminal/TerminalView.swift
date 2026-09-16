import EditorSwiftUI
import SwiftUI

/// A terminal that the agent owns, with its output (plan.md §9 C).
///
/// The view shows a ``TerminalRecord``. It reads the record, so a patch on the
/// record updates the view. The view has these parts:
///
/// - A header with the command in the code font and the working directory.
/// - The output in a read-only EditorKit editor that grows to the height of
///   its text. ``ANSIText`` converts the output bytes: the editor shows the
///   text with no escape sequences. When the output has more rows than the
///   row limit, the editor shows only the last rows, and a Show All button
///   shows all rows.
/// - An optional input row. When the host gives a `stdin` closure, a
///   single-line field shows under the output. Return sends the line to the
///   closure and clears the field. The terminal auth flow uses it (plan.md
///   §12).
/// - A footer. While the command runs, the footer shows a progress
///   indicator. After the command exits, the footer shows the exit code or
///   the signal.
///
/// The EditorKit editor does not show the SGR colors of ``ANSIText`` in v1:
/// EditorKit paints a host mark only as a background, and only for an editor
/// with a grammar. The colors stay in the attributed text of ``ANSIText``,
/// so that a later EditorKit release can show them.
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

  /// The accessibility identifier of the input field.
  public static let inputIdentifier = "terminal-input"

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

    /// Makes the summary of `status`. A signal has priority over a code.
    ///
    /// - Parameter status: The exit status of the terminal.
    public init(_ status: TerminalRecord.ExitStatus) {
      if let signal = status.signal {
        self = .signal(signal)
      } else if let code = status.code {
        self = .code(code)
      } else {
        self = .unknown
      }
    }

    /// The text of the footer.
    public var label: String {
      switch self {
      case .code(let code): String(localized: "Exit code \(code)")
      case .signal(let signal): String(localized: "Stopped by \(signal)")
      case .unknown: String(localized: "Exited")
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
      case .code: outcome?.symbolName ?? Self.unknownSymbolName
      case .signal: "bolt.horizontal.circle.fill"
      case .unknown: Self.unknownSymbolName
      }
    }

    /// The SF Symbol name of an exit with no known outcome.
    static let unknownSymbolName = "stop.circle"
  }

  /// The terminal to show.
  let record: TerminalRecord
  /// The number of rows that show before the user selects Show All.
  let rowLimit: Int
  /// The closure that takes a line of input, or `nil` for no input row.
  let stdin: ((String) -> Void)?
  /// The model that the host gives, or `nil` when the view keeps its own.
  let suppliedModel: EditorModel?

  /// Whether the user selected Show All.
  @State private var showsAll = false
  /// The model that the view keeps when the host gives no model.
  @State private var ownModel = OwnModelSlot()
  /// The text in the input field.
  @State private var inputLine = ""

  @Environment(\.agentTheme) private var theme

  /// Makes the view.
  ///
  /// - Parameters:
  ///   - record: The terminal to show.
  ///   - rowLimit: The number of rows that show before the user selects Show
  ///     All.
  ///   - model: The model of the editor, or `nil` to keep an own model. The
  ///     view makes the model read-only and sets its text.
  ///   - stdin: The closure that takes a line of input when the user presses
  ///     Return in the input field, or `nil` to show no input field. The line
  ///     has no newline at the end.
  public init(
    record: TerminalRecord,
    rowLimit: Int = TerminalView.defaultRowLimit,
    model: EditorModel? = nil,
    stdin: ((String) -> Void)? = nil
  ) {
    self.record = record
    self.rowLimit = rowLimit
    self.suppliedModel = model
    self.stdin = stdin
  }

  public var body: some View {
    let output = String(ANSIText.attributed(from: record.output).characters)
    let rows = CommandOutputView.VisibleRows(
      output: output, limit: showsAll ? Int.max : rowLimit)
    let model = suppliedModel ?? ownModel.model(text: rows.text)
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      if rows.isCapped {
        capRow(rows)
        Divider()
      }
      EditorView(model: model)
        .editorSizingMode(.intrinsic)
      if let stdin {
        Divider()
        inputRow(stdin)
      }
      Divider()
      footer
    }
    .background(AgentTheme.EditorSystemColors.background)
    .clipShape(RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous)
        .strokeBorder(.separator)
    )
    .editorTheme(theme.editorTheme)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityIdentifier(Self.identifier)
    .onChange(of: rows.text, initial: true) {
      model.syncReadOnly(to: rows.text)
    }
  }

  /// The label that VoiceOver reads for the view.
  var accessibilityLabel: String {
    if let command = record.command {
      String(localized: "Terminal, \(command)")
    } else {
      String(localized: "Terminal")
    }
  }

  /// The row with the command and the working directory.
  private var header: some View {
    HStack(spacing: theme.spacing.s) {
      Image(systemName: "terminal")
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text(record.command ?? String(localized: "Terminal"))
        .font(theme.codeFont)
        .foregroundStyle(record.command == nil ? .secondary : .primary)
        .lineLimit(1)
        .truncationMode(.middle)
        .accessibilityIdentifier(Self.commandIdentifier)
      Spacer(minLength: theme.spacing.s)
      if let cwd = record.cwd {
        Text(cwd)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.head)
          .help(cwd)
          .accessibilityLabel(String(localized: "Working directory \(cwd)"))
          .accessibilityIdentifier(Self.cwdIdentifier)
      }
    }
    .padding(.horizontal, theme.spacing.m)
    .padding(.vertical, theme.spacing.xs)
    .background(AgentTheme.EditorSystemColors.barBackground)
  }

  /// The row that tells how many rows show, with the Show All button.
  ///
  /// - Parameter rows: The rows that show.
  /// - Returns: The row.
  private func capRow(_ rows: CommandOutputView.VisibleRows) -> some View {
    HStack(spacing: theme.spacing.s) {
      Text(String(localized: "Showing the last \(rows.visibleCount) of \(rows.totalCount) lines"))
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(Self.capIdentifier)
      Spacer(minLength: theme.spacing.s)
      Button(String(localized: "Show all \(rows.totalCount) lines")) {
        showsAll = true
      }
      .buttonStyle(.borderless)
      .font(.caption)
      .accessibilityIdentifier(Self.showAllIdentifier)
    }
    .padding(.horizontal, theme.spacing.m)
    .padding(.vertical, theme.spacing.xs)
  }

  /// The row with the input field.
  ///
  /// - Parameter stdin: The closure that takes a line of input.
  /// - Returns: The row.
  private func inputRow(_ stdin: @escaping (String) -> Void) -> some View {
    HStack(spacing: theme.spacing.s) {
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      TextField(String(localized: "Terminal input"), text: $inputLine)
        .textFieldStyle(.plain)
        .font(theme.codeFont)
        .disabled(record.exitStatus != nil)
        .onSubmit {
          stdin(inputLine)
          inputLine = ""
        }
        .accessibilityIdentifier(Self.inputIdentifier)
    }
    .padding(.horizontal, theme.spacing.m)
    .padding(.vertical, theme.spacing.xs)
  }

  /// The footer: a progress indicator while the command runs, and the exit
  /// status after it exits.
  private var footer: some View {
    Group {
      if let status = record.exitStatus {
        exitRow(ExitSummary(status))
      } else {
        HStack(spacing: theme.spacing.s) {
          ProgressView()
            .controlSize(.mini)
            .accessibilityLabel(String(localized: "Running"))
            .accessibilityIdentifier(Self.progressIdentifier)
          Text(String(localized: "Running"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
      }
    }
    .padding(.horizontal, theme.spacing.m)
    .padding(.vertical, theme.spacing.xs)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// The row with the exit status.
  ///
  /// - Parameter summary: The exit status.
  /// - Returns: The row.
  private func exitRow(_ summary: ExitSummary) -> some View {
    Label(summary.label, systemImage: summary.symbolName)
      .font(.caption)
      .fontWeight(theme.symbolWeight)
      .foregroundStyle(summary.outcome.map(theme.statusColors.color(for:)) ?? Color.secondary)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(summary.label)
      .accessibilityValue(summary.outcome?.label ?? "")
      // An element with no role does not give its value. The trait gives the
      // static text role.
      .accessibilityAddTraits(.isStaticText)
      .accessibilityIdentifier(Self.footerIdentifier)
  }
}
