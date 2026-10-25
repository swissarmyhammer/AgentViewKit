import EditorComplete
import SwiftUI

extension EnvironmentValues {
  /// The prefix-completion routes of the EditorKit editor of a composer
  /// (``SwiftUI/View/composerCompletions(_:)``). Empty by default: no route
  /// completions.
  @Entry var composerCompletionRoutes: [PrefixCompletionRoute] = []
}

extension View {
  /// Sets the prefix-completion routes of the EditorKit editor of each
  /// composer below this view.
  ///
  /// A route binds a sigil to a provider of the host, for example `@` to the
  /// files of a project, `^` to tasks, `#` to tags and `/` to commands. The
  /// composer does the rest: typing in a token that a sigil opens asks the
  /// provider of that route, and the popup lists its rows at the caret, above
  /// the field. Return and Tab accept the selected row, as one entry of the
  /// window undo stack. An empty list, the default, gives no route
  /// completions.
  ///
  /// ```swift
  /// AgentThreadView(session: session, connection: connection)
  ///   .composerCompletions([
  ///     PrefixCompletionRoute("@", provider: FileMentionProvider(index: files)),
  ///     PrefixCompletionRoute("^", provider: tasks),
  ///     PrefixCompletionRoute("#", body: .tagName, provider: tags),
  ///     PrefixCompletionRoute("/", anchor: .lineStart, provider: commands),
  ///   ])
  /// ```
  ///
  /// A route takes its sigil from the completion of the kit. A `/` route
  /// replaces the slash commands of the agent
  /// (``SlashCommandSource``), and an `@` route replaces the file references
  /// of ``SwiftUI/EnvironmentValues/promptFileRoot``
  /// (``FileReferenceSource``). A row that an `@` route inserts is plain
  /// text, not a file chip.
  ///
  /// - Parameter routes: The routes, in declaration order. EditorKit drops a
  ///   route whose sigil an earlier route uses.
  /// - Returns: A view with the routes in its environment.
  public func composerCompletions(_ routes: [PrefixCompletionRoute]) -> some View {
    environment(\.composerCompletionRoutes, routes)
  }
}
