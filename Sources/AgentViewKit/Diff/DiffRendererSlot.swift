import Observation
import SwiftUI

/// A function that renders a unified diff (plan.md §4.1, decision 12).
///
/// - Parameters:
///   - patch: The full patch text.
///   - file: The path of the file to show, or `nil` when the patch has no
///     file.
/// - Returns: The view of the diff.
public typealias DiffRenderer = @MainActor (_ patch: String, _ file: String?) -> AnyView

/// The host functions that the review actions of a ``DiffView`` call.
///
/// A `nil` function hides the buttons of its action.
public nonisolated struct DiffActions: Sendable {
  /// A function that accepts one hunk.
  ///
  /// - Parameters:
  ///   - file: The path of the file of the hunk.
  ///   - hunkIndex: The position of the hunk in the file, from zero.
  public typealias HunkAction = @MainActor (_ file: String, _ hunkIndex: Int) -> Void

  /// A function that attaches lines of a diff to the prompt.
  ///
  /// - Parameter attachment: The file and the lines to attach.
  public typealias AttachAction = @MainActor (_ attachment: DiffAttachment) -> Void

  /// The function that accepts a hunk.
  public var onAccept: HunkAction?

  /// The function that rejects a hunk.
  public var onReject: HunkAction?

  /// The function that attaches lines to the prompt.
  public var onAttach: AttachAction?

  /// Makes a set of diff actions.
  ///
  /// - Parameters:
  ///   - onAccept: The function that accepts a hunk, or `nil`.
  ///   - onReject: The function that rejects a hunk, or `nil`.
  ///   - onAttach: The function that attaches lines to the prompt, or `nil`.
  public init(
    onAccept: HunkAction? = nil, onReject: HunkAction? = nil, onAttach: AttachAction? = nil
  ) {
    self.onAccept = onAccept
    self.onReject = onReject
    self.onAttach = onAttach
  }

  /// A set with no actions.
  public static let none = DiffActions()
}

/// The lines of a diff that a person attaches to the prompt.
public nonisolated struct DiffAttachment: Sendable, Hashable {
  /// The path of the file of the lines.
  public var file: String

  /// The lines, with their `+` or `-` first character.
  public var lines: [String]

  /// Makes an attachment.
  ///
  /// - Parameters:
  ///   - file: The path of the file of the lines.
  ///   - lines: The lines to attach.
  public init(file: String, lines: [String]) {
    self.file = file
    self.lines = lines
  }
}

/// The lines that a person selects in a diff renderer.
///
/// ``DiffView`` puts one selection in the environment of its renderer. A
/// renderer writes the selected lines to it. The "Attach to prompt" button
/// sends these lines, or all the changed lines of the file when the
/// selection is empty. The view clears the selection when the file changes.
@Observable public final class DiffLineSelection {
  /// The selected lines, with their `+`, `-`, or space first character.
  public var lines: [String] = []

  /// Makes an empty selection.
  public init() {}
}

extension EnvironmentValues {
  /// The function that renders a diff in a ``DiffView``.
  ///
  /// The kit has no default renderer. EditorKit supplies one. When the value
  /// is `nil`, ``DiffView`` shows a "Diff renderer not installed" row.
  @Entry public var diffRenderer: DiffRenderer? = nil

  /// The review actions of each ``DiffView`` that does not have its own.
  @Entry public var diffActions: DiffActions = .none

  /// The line selection of the renderer of the enclosing ``DiffView``.
  @Entry public var diffLineSelection: DiffLineSelection? = nil
}

extension View {
  /// Installs the function that renders the diffs in this view.
  ///
  /// - Parameter renderer: A function that takes the full patch and the path
  ///   of the file to show, and makes the view of that file.
  /// - Returns: A view that gives `renderer` to each ``DiffView`` in it.
  public func diffRenderer<Rendered: View>(
    _ renderer: @escaping @MainActor (_ patch: String, _ file: String?) -> Rendered
  ) -> some View {
    let erased: DiffRenderer = { patch, file in AnyView(renderer(patch, file)) }
    return environment(\.diffRenderer, erased)
  }

  /// Sets the review actions of each ``DiffView`` in this view.
  ///
  /// A ``DiffView`` in a ``ToolCallView`` gets its actions from here.
  ///
  /// - Parameter actions: The host functions of the review actions.
  /// - Returns: A view that gives `actions` to its subtree.
  public func diffActions(_ actions: DiffActions) -> some View {
    environment(\.diffActions, actions)
  }
}
