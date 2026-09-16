import EditorSwiftUI
import SwiftUI

/// The output of a shell command or a job, as a text block (plan.md §9 F).
///
/// Use this view for command output that arrives as text with a command
/// label. An agent-owned terminal uses `TerminalView`. The output of an
/// `execute` tool call that has no terminal id comes to this view.
///
/// The view has three parts:
///
/// - A header with the command in the code font and a Copy button. The Copy
///   button writes the full output to the pasteboard of the environment. See
///   `EnvironmentValues.pasteboard`.
/// - The output in a read-only EditorKit editor that grows to the height of
///   its text. When the output has more rows than the row limit, the editor
///   shows only the last rows, and a Show All button shows all rows.
/// - A footer with the exit code, tinted by ``ExitOutcome``. When the exit
///   code is `nil`, the view shows no footer.
public struct CommandOutputView: View {
  /// The accessibility identifier of the view.
  public static let identifier = "command-output"

  /// The accessibility identifier of the Copy button.
  public static let copyIdentifier = "command-output-copy"

  /// The accessibility identifier of the text that tells how many rows show.
  public static let capIdentifier = "command-output-cap"

  /// The accessibility identifier of the Show All button.
  public static let showAllIdentifier = "command-output-show-all"

  /// The accessibility identifier of the footer with the exit code.
  public static let footerIdentifier = "command-output-exit"

  /// The number of rows that the view shows before the user selects Show
  /// All, when the host gives no row limit.
  public static let defaultRowLimit = 200

  /// The exit code of a command that completed.
  static let successExitCode = 0

  /// The result of a command, from its exit code.
  public enum ExitOutcome: Equatable, Sendable {
    /// The command completed. Its exit code is zero.
    case success
    /// The command failed. Its exit code is not zero.
    case failure

    /// Makes the outcome of `exitCode`.
    ///
    /// - Parameter exitCode: The exit code of the command, or `nil` when
    ///   the command has no exit code.
    /// - Returns: `nil` when `exitCode` is `nil`.
    public init?(exitCode: Int?) {
      guard let exitCode else { return nil }
      self = exitCode == CommandOutputView.successExitCode ? .success : .failure
    }

    /// The text that VoiceOver reads as the value of the footer.
    public var label: String {
      switch self {
      case .success: String(localized: "Succeeded")
      case .failure: String(localized: "Failed")
      }
    }

    /// The SF Symbol name of the footer.
    var symbolName: String {
      switch self {
      case .success: "checkmark.circle.fill"
      case .failure: "xmark.octagon.fill"
      }
    }
  }

  /// The rows of an output that the view shows.
  ///
  /// A row is the text between two newline characters. A newline at the end
  /// of the output does not start a row.
  public struct VisibleRows: Equatable, Sendable {
    /// The text of the rows that show.
    public let text: String
    /// The number of rows in the output.
    public let totalCount: Int
    /// The number of rows at the start of the output that do not show.
    public let hiddenCount: Int

    /// The number of rows that show.
    public var visibleCount: Int { totalCount - hiddenCount }

    /// Whether some rows do not show.
    public var isCapped: Bool { hiddenCount > 0 }

    /// Makes the last rows of `output`.
    ///
    /// - Parameters:
    ///   - output: The full output.
    ///   - limit: The largest number of rows that show. A value below one
    ///     shows one row.
    public init(output: String, limit: Int) {
      var rows = output.split(separator: "\n", omittingEmptySubsequences: false)
      if rows.count > 1, rows.last?.isEmpty == true {
        rows.removeLast()
      }
      let visible = max(limit, 1)
      totalCount = output.isEmpty ? 0 : rows.count
      hiddenCount = max(totalCount - visible, 0)
      text = hiddenCount == 0 ? output : rows.suffix(visible).joined(separator: "\n")
    }
  }

  /// The command that made the output, or `nil`.
  let command: String?
  /// The full output.
  let output: String
  /// The exit code of the command, or `nil`.
  let exitCode: Int?
  /// The number of rows that show before the user selects Show All.
  let rowLimit: Int
  /// The model that the host gives, or `nil` when the view keeps its own.
  let suppliedModel: EditorModel?

  /// Whether the user selected Show All.
  @State private var showsAll = false
  /// The model that the view keeps when the host gives no model.
  @State private var ownModel = OwnModelSlot()

  @Environment(\.agentTheme) private var theme
  @Environment(\.pasteboard) private var pasteboard

  /// Makes the view.
  ///
  /// - Parameters:
  ///   - command: The command that made the output, or `nil`.
  ///   - output: The full output.
  ///   - exitCode: The exit code of the command, or `nil` when the command
  ///     has no exit code yet.
  ///   - rowLimit: The number of rows that show before the user selects
  ///     Show All.
  ///   - model: The model of the editor, or `nil` to keep an own model. The
  ///     view makes the model read-only and sets its text.
  public init(
    command: String?,
    output: String,
    exitCode: Int?,
    rowLimit: Int = CommandOutputView.defaultRowLimit,
    model: EditorModel? = nil
  ) {
    self.command = command
    self.output = output
    self.exitCode = exitCode
    self.rowLimit = rowLimit
    self.suppliedModel = model
  }

  public var body: some View {
    let rows = VisibleRows(output: output, limit: showsAll ? Int.max : rowLimit)
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
      if let exitCode, let outcome = ExitOutcome(exitCode: exitCode) {
        Divider()
        footer(exitCode: exitCode, outcome: outcome)
      }
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
    if let exitCode {
      String(localized: "Command output, exit \(exitCode)")
    } else {
      String(localized: "Command output")
    }
  }

  /// The row with the command and the Copy button.
  private var header: some View {
    HStack(spacing: theme.spacing.s) {
      Text(command ?? String(localized: "Output"))
        .font(theme.codeFont)
        .foregroundStyle(command == nil ? .secondary : .primary)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: theme.spacing.s)
      Button(String(localized: "Copy output"), systemImage: "doc.on.doc") {
        pasteboard.copyText(output)
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
      .help(String(localized: "Copy output"))
      .accessibilityIdentifier(Self.copyIdentifier)
    }
    .padding(.horizontal, theme.spacing.m)
    .padding(.vertical, theme.spacing.xs)
    .background(AgentTheme.EditorSystemColors.barBackground)
  }

  /// The row that tells how many rows show, with the Show All button.
  ///
  /// - Parameter rows: The rows that show.
  /// - Returns: The row.
  private func capRow(_ rows: VisibleRows) -> some View {
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

  /// The row with the exit code.
  ///
  /// - Parameters:
  ///   - exitCode: The exit code of the command.
  ///   - outcome: The outcome of `exitCode`.
  /// - Returns: The row.
  private func footer(exitCode: Int, outcome: ExitOutcome) -> some View {
    let text = String(localized: "Exit code \(exitCode)")
    return Label(text, systemImage: outcome.symbolName)
      .font(.caption)
      .fontWeight(theme.symbolWeight)
      .foregroundStyle(theme.statusColors.color(for: outcome))
      .padding(.horizontal, theme.spacing.m)
      .padding(.vertical, theme.spacing.xs)
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(text)
      .accessibilityValue(outcome.label)
      // An element with no role does not give its value. The trait gives the
      // static text role.
      .accessibilityAddTraits(.isStaticText)
      .accessibilityIdentifier(Self.footerIdentifier)
  }
}

extension AgentTheme.StatusColors {
  /// The color of a command with `outcome`.
  ///
  /// - Parameter outcome: The outcome of the command.
  /// - Returns: ``completed`` for a command that completed, and ``failed``
  ///   for a command that failed.
  public func color(for outcome: CommandOutputView.ExitOutcome) -> Color {
    switch outcome {
    case .success: completed
    case .failure: failed
    }
  }
}
