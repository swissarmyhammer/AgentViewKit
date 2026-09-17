import SwiftUI

/// The review chrome around a diff renderer (plan.md §4.1, §9 C, decision 12).
///
/// The view shows:
///
/// - A list of the files of the patch, with the added and removed line
///   counts. The list is on the left, or on top when the view is narrow. A
///   press on a file selects it.
/// - The renderer that ``SwiftUI/View/diffRenderer(_:)`` installs, with the
///   full patch and the path of the selected file. With no renderer, a
///   "Diff renderer not installed" row shows. The kit does not render diffs.
///   EditorKit supplies the renderer.
/// - An Accept and a Reject button for each hunk of the selected file.
/// - An "Attach to prompt" button. It gives the lines that the renderer
///   selects in the ``SwiftUI/EnvironmentValues/diffLineSelection``, or all
///   the changed lines of the selected file when there is no selection.
///
/// The actions call host functions. When the initializer gets no function,
/// the view uses the ``SwiftUI/EnvironmentValues/diffActions``. A button
/// whose function is `nil` does not show.
public struct DiffView: View, PrefixedAccessibilityIdentifier {
  /// The start of the accessibility identifier of each file row.
  public static let identifierPrefix = "diff-file-"

  /// The accessibility identifier of the view.
  public static let containerIdentifier = "diff-view"

  /// The accessibility identifier of the row that shows when there is no
  /// renderer.
  public static let missingRendererIdentifier = "diff-renderer-missing"

  /// The accessibility identifier of the "Attach to prompt" button.
  public static let attachIdentifier = "diff-attach"

  /// The start of the accessibility identifier of each Accept button.
  static let acceptPrefix = "diff-accept-"

  /// The start of the accessibility identifier of each Reject button.
  static let rejectPrefix = "diff-reject-"

  /// The width of the file list when it is on the left.
  static let fileListWidth: CGFloat = 220

  /// The smallest width of the renderer next to the file list. When the view
  /// is narrower, the file list goes on top.
  static let rendererMinWidth: CGFloat = 320

  /// The patch text.
  let patch: String

  /// The files of the patch.
  let files: [DiffSummary.FileSummary]

  /// The actions of the initializer, or `nil` to use the environment.
  let ownActions: DiffActions?

  /// The path of the file that a person selected, or `nil` for the first
  /// file.
  @State private var selectedPath: String?

  /// The lines that the renderer selects.
  @State private var selection = DiffLineSelection()

  @Environment(\.diffRenderer) private var renderer
  @Environment(\.diffActions) private var environmentActions
  @Environment(\.agentTheme) private var theme

  /// Makes a diff view.
  ///
  /// - Parameters:
  ///   - patch: The unified diff or git patch text.
  ///   - onAccept: The function that accepts a hunk, or `nil`.
  ///   - onReject: The function that rejects a hunk, or `nil`.
  ///   - onAttach: The function that attaches lines to the prompt, or `nil`.
  ///   When all three are `nil`, the view uses the actions of the
  ///   environment.
  public init(
    patch: String,
    onAccept: DiffActions.HunkAction? = nil,
    onReject: DiffActions.HunkAction? = nil,
    onAttach: DiffActions.AttachAction? = nil
  ) {
    self.patch = patch
    files = DiffSummary.parse(gitPatch: patch)
    let hasOwnActions = onAccept != nil || onReject != nil || onAttach != nil
    ownActions =
      hasOwnActions
      ? DiffActions(onAccept: onAccept, onReject: onReject, onAttach: onAttach) : nil
  }

  // MARK: - Identifiers

  /// The accessibility identifier of the Accept button of a hunk.
  ///
  /// - Parameter index: The position of the hunk in the file, from zero.
  /// - Returns: `diff-accept-<index>`.
  public static func acceptIdentifier(for index: Int) -> String {
    AccessibilityIdentifier.make(prefix: acceptPrefix, value: String(index))
  }

  /// The accessibility identifier of the Reject button of a hunk.
  ///
  /// - Parameter index: The position of the hunk in the file, from zero.
  /// - Returns: `diff-reject-<index>`.
  public static func rejectIdentifier(for index: Int) -> String {
    AccessibilityIdentifier.make(prefix: rejectPrefix, value: String(index))
  }

  /// The symbol of a file operation.
  ///
  /// - Parameter operation: The change to the file.
  /// - Returns: The SF Symbol name.
  static func symbolName(for operation: DiffSummary.Operation) -> String {
    switch operation {
    case .added: "plus.square"
    case .deleted: "minus.square"
    case .modified: "pencil"
    case .renamed: "arrow.right.square"
    }
  }

  // MARK: - Body

  public var body: some View {
    let file = files.first { $0.path == selectedPath } ?? files.first
    let actions = ownActions ?? environmentActions
    return ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: theme.spacing.m) {
        fileList(selected: file)
          .frame(width: Self.fileListWidth)
        detail(file: file, actions: actions)
          .frame(minWidth: Self.rendererMinWidth, alignment: .leading)
      }
      VStack(alignment: .leading, spacing: theme.spacing.m) {
        fileList(selected: file)
        detail(file: file, actions: actions)
      }
    }
    .onChange(of: selectedPath) {
      selection.lines = []
    }
    .contentContainer(identifier: Self.containerIdentifier)
  }

  /// The list of the files, with their counts.
  ///
  /// - Parameter selected: The file that the renderer shows.
  /// - Returns: The list view.
  private func fileList(selected: DiffSummary.FileSummary?) -> some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      ForEach(files) { file in
        fileRow(file, isSelected: file.path == selected?.path)
      }
    }
  }

  /// One file row: a button that selects the file.
  ///
  /// - Parameters:
  ///   - file: The file.
  ///   - isSelected: `true` when the renderer shows the file.
  /// - Returns: The row view.
  private func fileRow(_ file: DiffSummary.FileSummary, isSelected: Bool) -> some View {
    Button {
      selectedPath = file.path
    } label: {
      HStack(spacing: theme.spacing.s) {
        Image(systemName: Self.symbolName(for: file.operation))
          .fontWeight(theme.symbolWeight)
          .foregroundStyle(.secondary)
        Text(URL(fileURLWithPath: file.path).lastPathComponent)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer(minLength: theme.spacing.s)
        Text(verbatim: "+\(file.added)")
          .foregroundStyle(theme.statusColors.completed)
        Text(verbatim: "\u{2212}\(file.removed)")
          .foregroundStyle(theme.statusColors.failed)
      }
      .font(.caption)
      .monospacedDigit()
      .padding(.horizontal, theme.spacing.s)
      .padding(.vertical, theme.spacing.xs)
      .background(
        isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
        in: RoundedRectangle(cornerRadius: theme.radii.s))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(file.path)
    .accessibilityLabel(file.accessibilityLabel)
    .accessibilityValue(file.path)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier(Self.identifier(for: file.path))
  }

  /// The renderer, the hunk actions, and the attach button.
  ///
  /// - Parameters:
  ///   - file: The selected file, or `nil` when the patch has no file.
  ///   - actions: The host functions of the actions.
  /// - Returns: The detail view.
  private func detail(file: DiffSummary.FileSummary?, actions: DiffActions) -> some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      rendered(file: file)
      if let file {
        ForEach(Array(file.hunks.enumerated()), id: \.offset) { index, hunk in
          hunkRow(hunk, index: index, file: file, actions: actions)
        }
        if let onAttach = actions.onAttach {
          Button {
            let lines = selection.lines.isEmpty ? file.changedLines : selection.lines
            onAttach(DiffAttachment(file: file.path, lines: lines))
          } label: {
            Label(String(localized: "Attach to prompt"), systemImage: "paperclip")
          }
          .accessibilityIdentifier(Self.attachIdentifier)
        }
      }
    }
    .environment(\.diffLineSelection, selection)
  }

  /// The installed renderer, or the row that tells that there is none.
  ///
  /// - Parameter file: The selected file.
  /// - Returns: The rendered diff.
  @ViewBuilder
  private func rendered(file: DiffSummary.FileSummary?) -> some View {
    if let renderer {
      renderer(patch, file?.path)
    } else {
      let text = String(localized: "Diff renderer not installed")
      Label(text, systemImage: "doc.text.magnifyingglass")
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier(Self.missingRendererIdentifier)
    }
  }

  /// The header of one hunk with its Accept and Reject buttons.
  ///
  /// - Parameters:
  ///   - hunk: The hunk.
  ///   - index: The position of the hunk in the file.
  ///   - file: The file of the hunk.
  ///   - actions: The host functions of the actions.
  /// - Returns: The row view, or no view when there is no hunk action.
  @ViewBuilder
  private func hunkRow(
    _ hunk: DiffSummary.Hunk, index: Int, file: DiffSummary.FileSummary, actions: DiffActions
  ) -> some View {
    if actions.onAccept != nil || actions.onReject != nil {
      HStack(spacing: theme.spacing.s) {
        Text(verbatim: hunk.header)
          .font(theme.codeFont)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
        Spacer(minLength: theme.spacing.s)
        if let onAccept = actions.onAccept {
          Button(String(localized: "Accept")) {
            onAccept(file.path, index)
          }
          .accessibilityLabel(String(localized: "Accept hunk \(index + 1)"))
          .accessibilityIdentifier(Self.acceptIdentifier(for: index))
        }
        if let onReject = actions.onReject {
          Button(String(localized: "Reject")) {
            onReject(file.path, index)
          }
          .accessibilityLabel(String(localized: "Reject hunk \(index + 1)"))
          .accessibilityIdentifier(Self.rejectIdentifier(for: index))
        }
      }
      .controlSize(.small)
    }
  }
}
