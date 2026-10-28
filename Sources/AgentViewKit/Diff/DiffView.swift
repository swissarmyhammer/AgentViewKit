import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import SwiftUI

/// The review chrome around a diff renderer (plan.md §4.1, §9 C, decision 12).
///
/// The view shows:
///
/// - A chip for each file of the patch, with the added and removed line
///   counts, in rows that wrap. The chips stand above the detail, and the
///   detail takes the full width of the tile. On its own, the diff is a
///   content tile, with the tile padding (`.contentTile()`); in a tool call,
///   the call is the tile, and the diff pads nothing (``DiffPlace``). A press
///   on a chip selects its file. The view shows the chip of a patch with one
///   file too, so its name and counts stay visible. The counts use the
///   `diffAddedText` and `diffRemovedText` roles of the EditorKit theme in the
///   environment.
/// - The renderer of the ``SwiftUI/EnvironmentValues/diffRenderer``, with the
///   full patch and the path of the selected file. The default renderer is
///   the EditorKit diff view, in the ``SwiftUI/EnvironmentValues/diffLayout``.
///   The kit does not render diffs itself. A host replaces the renderer with
///   ``SwiftUI/View/diffRenderer(_:)``.
/// - An Accept and a Reject button for each hunk of the selected file.
/// - An "Attach to prompt" button. It gives the lines that the renderer
///   selects in the ``SwiftUI/EnvironmentValues/diffLineSelection``, or all
///   the changed lines of the selected file when there is no selection.
///
/// The actions call host functions. When the initializer gets no function,
/// the view uses the ``SwiftUI/EnvironmentValues/diffActions``. A button
/// whose function is `nil` does not show.
///
/// A structured ACP diff with no `git_patch` text has no lines to render. The
/// view then shows the file of each change with its operation, and a note.
/// See ``init(diff:onAccept:onReject:onAttach:)``.
public struct DiffView: View {
  /// The accessibility identifier of the view.
  public static let containerIdentifier = "diff-view"

  /// The accessibility identifier of the detail: the renderer, the hunk
  /// actions and the attach button, or the note of a diff with no patch text.
  public static let detailIdentifier = "diff-detail"

  /// The accessibility identifier of the "Attach to prompt" button.
  public static let attachIdentifier = "diff-attach"

  /// The accessibility identifier of the note of a diff with no patch text.
  public static let noPatchIdentifier = "diff-no-patch"

  /// The start of the accessibility identifier of each Accept button.
  static let acceptPrefix = "diff-accept-"

  /// The start of the accessibility identifier of each Reject button.
  static let rejectPrefix = "diff-reject-"

  /// The symbol of each Accept button.
  static let acceptSymbol = SharedSymbol.accept

  /// The symbol of each Reject button.
  static let rejectSymbol = SharedSymbol.reject

  /// The patch text, or `nil` for a structured diff with no patch text.
  let patch: String?

  /// The files of the patch, or of the structured changes.
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
  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

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
    self.init(
      patch: patch, files: DiffSummary.parse(gitPatch: patch),
      actions: Self.ownActions(onAccept: onAccept, onReject: onReject, onAttach: onAttach))
  }

  /// Makes the diff view of an ACP diff (plan.md §3.8 "Tool call view").
  ///
  /// A diff with `git_patch` text shows that patch, as
  /// ``init(patch:onAccept:onReject:onAttach:)`` does. A diff with no
  /// `git_patch` text shows the file of each structured change, with its
  /// operation, and a note that the agent sent no patch text. See
  /// ``DiffSummary/files(of:)``. Such a diff has no hunks, so it shows no
  /// renderer and no action.
  ///
  /// - Parameters:
  ///   - diff: The ACP diff.
  ///   - onAccept: The function that accepts a hunk, or `nil`.
  ///   - onReject: The function that rejects a hunk, or `nil`.
  ///   - onAttach: The function that attaches lines to the prompt, or `nil`.
  ///   When all three are `nil`, the view uses the actions of the
  ///   environment.
  public init(
    diff: FoundationModelsACP.Diff,
    onAccept: DiffActions.HunkAction? = nil,
    onReject: DiffActions.HunkAction? = nil,
    onAttach: DiffActions.AttachAction? = nil
  ) {
    self.init(
      patch: DiffSummary.gitPatchText(of: diff), files: DiffSummary.files(of: diff),
      actions: Self.ownActions(onAccept: onAccept, onReject: onReject, onAttach: onAttach))
  }

  /// Makes a diff view from its parts.
  ///
  /// - Parameters:
  ///   - patch: The patch text, or `nil` for a diff with no patch text.
  ///   - files: The files of the diff.
  ///   - actions: The actions of the initializer, or `nil`.
  private init(patch: String?, files: [DiffSummary.FileSummary], actions: DiffActions?) {
    self.patch = patch
    self.files = files
    ownActions = actions
  }

  /// The actions of an initializer.
  ///
  /// - Parameters:
  ///   - onAccept: The function that accepts a hunk, or `nil`.
  ///   - onReject: The function that rejects a hunk, or `nil`.
  ///   - onAttach: The function that attaches lines to the prompt, or `nil`.
  /// - Returns: The actions, or `nil` when all three are `nil`.
  private static func ownActions(
    onAccept: DiffActions.HunkAction?,
    onReject: DiffActions.HunkAction?,
    onAttach: DiffActions.AttachAction?
  ) -> DiffActions? {
    guard onAccept != nil || onReject != nil || onAttach != nil else { return nil }
    return DiffActions(onAccept: onAccept, onReject: onReject, onAttach: onAttach)
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

  // MARK: - Body

  public var body: some View {
    let file = files.first { $0.path == selectedPath } ?? files.first
    let actions = ownActions ?? environmentActions
    return ContentTileStack {
      fileChips(selected: file)
    } body: {
      detail(file: file, actions: actions)
    }
    .modifier(DiffPlaceTile())
    .onChange(of: selectedPath) {
      selection.lines = []
    }
    .contentContainer(identifier: Self.containerIdentifier)
  }

  /// The chips of the files, with their counts, in rows that wrap.
  ///
  /// - Parameter selected: The file that the renderer shows.
  /// - Returns: The chips view.
  private func fileChips(selected: DiffSummary.FileSummary?) -> some View {
    ChipFlowLayout(spacing: editorStyle.spacing.xs) {
      ForEach(files) { file in
        DiffFileChip(file: file, hasPatch: patch != nil, isSelected: file.path == selected?.path) {
          selectedPath = file.path
        }
      }
    }
  }

  /// The renderer, the hunk actions, and the attach button, or the note of a
  /// diff with no patch text.
  ///
  /// - Parameters:
  ///   - file: The selected file, or `nil` when the patch has no file.
  ///   - actions: The host functions of the actions.
  /// - Returns: The detail view.
  private func detail(file: DiffSummary.FileSummary?, actions: DiffActions) -> some View {
    VStack(alignment: .leading, spacing: editorStyle.tile.gap) {
      if let patch {
        rendered(patch: patch, file: file)
        if let file {
          ForEach(Array(file.hunks.enumerated()), id: \.offset) { index, hunk in
            hunkRow(hunk, index: index, file: file, actions: actions)
          }
          attachButton(file: file, actions: actions)
        }
      } else {
        Text("The agent sent no patch text for these changes.", bundle: .module)
          .font(editorTheme.font(for: .ui, style: .caption))
          .foregroundStyle(.secondary)
          .accessibilityIdentifier(Self.noPatchIdentifier)
      }
    }
    .environment(\.diffLineSelection, selection)
    .contentContainer(identifier: Self.detailIdentifier)
  }

  /// The "Attach to prompt" button of the selected file.
  ///
  /// - Parameters:
  ///   - file: The selected file.
  ///   - actions: The host functions of the actions.
  /// - Returns: The button, or no view when there is no attach action.
  @ViewBuilder
  private func attachButton(file: DiffSummary.FileSummary, actions: DiffActions) -> some View {
    if let onAttach = actions.onAttach {
      Button {
        let lines = selection.lines.isEmpty ? file.changedLines : selection.lines
        onAttach(DiffAttachment(file: file.path, lines: lines))
      } label: {
        Label(
          String(localized: "Attach to prompt", bundle: .module), systemImage: SharedSymbol.attach)
      }
      .accessibilityIdentifier(Self.attachIdentifier)
    }
  }

  /// The renderer of the environment, or the EditorKit renderer when the
  /// environment has none, with the selected file.
  ///
  /// - Parameters:
  ///   - patch: The patch text.
  ///   - file: The selected file.
  /// - Returns: The rendered diff.
  @ViewBuilder
  private func rendered(patch: String, file: DiffSummary.FileSummary?) -> some View {
    if let renderer {
      renderer(patch, file?.path)
    } else {
      EditorKitDiffRenderer(patch: patch, file: file?.path)
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
      HStack(spacing: editorStyle.spacing.s) {
        Text(verbatim: hunk.header)
          .font(editorTheme.codeFont)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
        Spacer(minLength: editorStyle.spacing.s)
        if let onAccept = actions.onAccept {
          Button(String(localized: "Accept", bundle: .module), systemImage: Self.acceptSymbol) {
            onAccept(file.path, index)
          }
          .accessibilityLabel(String(localized: "Accept hunk \(index + 1)", bundle: .module))
          .accessibilityIdentifier(Self.acceptIdentifier(for: index))
        }
        if let onReject = actions.onReject {
          Button(String(localized: "Reject", bundle: .module), systemImage: Self.rejectSymbol) {
            onReject(file.path, index)
          }
          .accessibilityLabel(String(localized: "Reject hunk \(index + 1)", bundle: .module))
          .accessibilityIdentifier(Self.rejectIdentifier(for: index))
        }
      }
      .controlSize(.small)
    }
  }
}

#Preview("Diff") {
  DiffView(patch: PreviewFixtures.smallPatch)
}
