import SwiftUI

/// The composer of the host in a read-only thread
/// (``SwiftUI/View/threadComposer(placeholder:onSubmit:)``, TestudoApp D212):
/// the placeholder of the host, and the closure of the host that gets each
/// prompt in place of the session.
///
/// The closure is in a struct, not in the environment value itself: an
/// environment value that holds a closure can invalidate its dependents on
/// each update.
struct ThreadComposerRoute {
  /// The text that the editor of the composer shows while the prompt is
  /// empty.
  let placeholder: String

  /// The closure of the host that gets the text of each prompt.
  let onSubmit: @MainActor (String) async -> Void

  /// Gives the text of a submission to the host, as the submit hook of the
  /// composer (``SwiftUI/View/onComposerSubmit(_:)``).
  ///
  /// A text that is not blank goes to the host closure one time. When the
  /// closure returns, the result tells the composer that the host took the
  /// prompt (``ComposerSubmitResult/consumed``): the composer sends nothing to
  /// the read-only session, and it clears its text. A blank text does not go
  /// to the host, and the composer keeps it (``ComposerSubmitResult/cancel``).
  ///
  /// - Parameter submission: The prompt that the user submits.
  /// - Returns: ``ComposerSubmitResult/consumed`` after the host closure ran,
  ///   or ``ComposerSubmitResult/cancel`` for a blank text.
  @MainActor func submit(_ submission: ComposerSubmission) async -> ComposerSubmitResult {
    guard
      let text = PromptInputView<EditorKitPromptEditor, DefaultPromptAccessory>.message(
        from: submission.attributedText)
    else { return .cancel }
    await onSubmit(text)
    return .consumed
  }
}

extension EnvironmentValues {
  /// The composer of the host for the read-only threads in this view, or
  /// `nil`. Set it with ``SwiftUI/View/threadComposer(placeholder:onSubmit:)``.
  @Entry var threadComposerRoute: ThreadComposerRoute? = nil

  /// The text that the editor of a ``PromptInputView`` shows while the prompt
  /// is empty, or `nil` for the placeholder of the kit.
  @Entry var promptPlaceholder: String? = nil
}

/// The composer of the host in a read-only thread.
extension View {
  /// Shows the composer in the read-only threads in this view, and gives each
  /// prompt of it to `onSubmit` in place of the session (TestudoApp D212).
  ///
  /// A read-only session (`SessionModel.isReadOnly`) cannot get a prompt, so
  /// a thread view of it shows no composer slot. With this modifier, the
  /// thread view of a read-only session shows its composer slot, such as the
  /// ``DefaultThreadComposer``. The editor shows `placeholder` while the
  /// prompt is empty. A submit of a text that is not blank calls `onSubmit`
  /// one time with the plain text, and sends nothing to the session. When
  /// `onSubmit` returns, the composer clears its text and its draft. A blank
  /// text does not submit.
  ///
  /// While `onSubmit` runs, the text stays in the composer, the composer
  /// takes no second submit, the field is disabled, and the accessory shows
  /// that a send is in progress, as for the hook of
  /// ``SwiftUI/View/onComposerSubmit(_:)``. Thus the host can turn the tab
  /// into a live session in `onSubmit`, and the prompt goes out one time.
  ///
  /// Each action of the composer is a command (TestudoApp D108): the thread
  /// scope of the read-only session registers Send Message, Focus Composer
  /// and Mention…, as for a live thread, so the menus, the palette and the
  /// keys run them. Send Message submits the composer, with the same guard
  /// as the Return key: it is not available for a blank text and while
  /// `onSubmit` runs. Stop, Approve, Reject and Fork from Here stay absent.
  /// The scope reads the value of this modifier from the environment, so
  /// apply the modifier above a scope of the host
  /// (``SwiftUI/View/agentCommandScope(session:)``) that holds the thread.
  ///
  /// The modifier sets an environment value that ``AgentThreadView`` reads.
  /// Thus it chains with the other modifiers of the thread, such as
  /// ``SwiftUI/View/threadHeader(_:)`` and
  /// ``SwiftUI/View/threadUnavailable(_:)``, in each order. A thread of a
  /// live session does not read it: its composer keeps the placeholder of
  /// the kit and sends each prompt to the session. The host gives the text
  /// of the placeholder and its strings.
  ///
  /// ```swift
  /// AgentThreadView(session: external)
  ///   .threadHeader(title, action: continueCommand)
  ///   .threadComposer(placeholder: "Message to continue in Testudo") { text in
  ///     await continueInTestudo(sending: text)
  ///   }
  /// ```
  ///
  /// - Parameters:
  ///   - placeholder: The text that the editor shows while the prompt is
  ///     empty.
  ///   - onSubmit: The closure of the host that gets the plain text of each
  ///     prompt.
  /// - Returns: A view whose read-only threads show the composer.
  public func threadComposer(
    placeholder: String, onSubmit: @escaping @MainActor (String) async -> Void
  ) -> some View {
    environment(\.threadComposerRoute, ThreadComposerRoute(placeholder: placeholder, onSubmit: onSubmit))
  }
}

/// Gives the composer of the host to the composer slot of a read-only
/// thread: the placeholder and the submit hook of the host.
///
/// The modifier changes only the environment of the slot, and keeps the
/// identity of the composer. So a composer whose session becomes live while
/// the host closure runs keeps its state, and takes no second submit.
struct ThreadComposerRouting: ViewModifier {
  /// The composer of the host, or `nil` to keep the environment of the slot.
  let route: ThreadComposerRoute?

  func body(content: Content) -> some View {
    content
      .transformEnvironment(\.promptPlaceholder) { placeholder in
        if let route { placeholder = route.placeholder }
      }
      .transformEnvironment(\.composerSubmitHook) { hook in
        if let route { hook = route.submit }
      }
  }
}
