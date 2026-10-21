import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The content of a ``ConversationEmptyState``: a title, an SF Symbol and a
/// Markdown text.
struct ConversationEmptyContent: Equatable, Sendable {
  /// The title above the text, or `nil` for no title.
  var title: String?

  /// The name of the SF Symbol before the title, or `nil` for no symbol.
  var systemImage: String?

  /// The Markdown text.
  var markdown: String

  /// The content that shows when the host gives no content.
  static var standard: ConversationEmptyContent {
    ConversationEmptyContent(
      title: String(localized: "No Messages", bundle: .module),
      systemImage: SharedSymbol.conversation,
      markdown: String(localized: "Send a message to start the conversation.", bundle: .module)
    )
  }
}

extension EnvironmentValues {
  /// The content of each ``ConversationEmptyState`` in this subtree that the
  /// host made with no content, or `nil` for the standard content.
  ///
  /// Set the value with
  /// ``SwiftUI/View/conversationEmptyState(title:systemImage:markdown:)``.
  @Entry var conversationEmptyContent: ConversationEmptyContent? = nil
}

extension View {
  /// Sets the content of the empty state of each ``ConversationView`` in this
  /// subtree that shows the default ``ConversationEmptyState``.
  ///
  /// The modifier sets the empty state of the drop-in ``AgentThreadView``
  /// also, with no custom `emptyState` slot:
  ///
  /// ```swift
  /// AgentThreadView(session: session)
  ///   .conversationEmptyState(title: "Welcome", markdown: "Ask about the **code**.")
  /// ```
  ///
  /// - Parameters:
  ///   - title: The title above the text, or `nil` for no title.
  ///   - systemImage: The name of the SF Symbol before the title, or `nil`
  ///     for no symbol.
  ///   - markdown: The Markdown text. The text shows the same as the text of
  ///     an agent message.
  /// - Returns: A view that gives the content to its subtree.
  public func conversationEmptyState(
    title: String? = nil, systemImage: String? = nil, markdown: String
  ) -> some View {
    environment(
      \.conversationEmptyContent,
      ConversationEmptyContent(title: title, systemImage: systemImage, markdown: markdown))
  }
}

/// The empty state of a ``ConversationView``: the view that shows while the
/// transcript has no entry.
///
/// The view shows an optional title with an optional SF Symbol, and a
/// Markdown text below it. The text renders through ``ResponseView``, the
/// same as the text of an agent message, so headings, lists, links, math and
/// code blocks show, and the EditorKit theme applies.
///
/// - ``init()`` shows the content of
///   ``SwiftUI/View/conversationEmptyState(title:systemImage:markdown:)``.
///   With no such content, it shows the standard title and text.
/// - ``init(title:systemImage:markdown:)`` shows the content that the host
///   gives. The content of the environment does not apply.
///
/// The view is one accessibility container with the identifier
/// ``ConversationLayout/emptyStateIdentifier``. VoiceOver reads the title as
/// a heading, and then each paragraph of the text. Long text scrolls.
public struct ConversationEmptyState: View {
  /// The content that the host gave to the initializer, or `nil` to use the
  /// content of the environment.
  let content: ConversationEmptyContent?

  @Environment(\.conversationEmptyContent) private var environmentContent
  @Environment(\.agentTheme) private var theme

  /// Makes the empty state that shows the content of
  /// ``SwiftUI/View/conversationEmptyState(title:systemImage:markdown:)``,
  /// or the standard content when the environment has none.
  public init() {
    self.content = nil
  }

  /// Makes an empty state that shows Markdown text that the host gives.
  ///
  /// - Parameters:
  ///   - title: The title above the text, or `nil` for no title.
  ///   - systemImage: The name of the SF Symbol before the title, or `nil`
  ///     for no symbol.
  ///   - markdown: The Markdown text. The text shows the same as the text of
  ///     an agent message.
  public init(title: String? = nil, systemImage: String? = nil, markdown: String) {
    self.content = ConversationEmptyContent(
      title: title, systemImage: systemImage, markdown: markdown)
  }

  public var body: some View {
    let shown = content ?? environmentContent ?? .standard
    ScrollView {
      VStack(alignment: .leading, spacing: theme.spacing.m) {
        ConversationEmptyHeader(title: shown.title, systemImage: shown.systemImage)
        ResponseView(id: ConversationLayout.emptyStateIdentifier, markdown: shown.markdown)
      }
      .padding(theme.spacing.l)
    }
    .defaultScrollAnchor(.center, for: .alignment)
    .scrollBounceBehavior(.basedOnSize)
    .contentContainer(identifier: ConversationLayout.emptyStateIdentifier)
  }
}

/// The title and the SF Symbol of a ``ConversationEmptyState``.
///
/// With no title and no symbol, the header shows nothing.
///
/// The symbol has the `.secondary` style. It does not use the accent of the
/// EditorKit theme: in content, the accent marks only a link, the selection
/// or the current item (D113 answer 5).
private struct ConversationEmptyHeader: View {
  /// The title, or `nil` for no title.
  let title: String?

  /// The name of the SF Symbol, or `nil` for no symbol.
  let systemImage: String?

  @Environment(\.agentTheme) private var theme
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    if title != nil || systemImage != nil {
      HStack(alignment: .firstTextBaseline, spacing: theme.spacing.s) {
        if let systemImage {
          Image(systemName: systemImage)
            .foregroundStyle(.secondary)
            .fontWeight(theme.symbolWeight)
            .accessibilityHidden(true)
        }
        if let title {
          Text(title)
            .font(editorTheme.proseFont.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(ConversationLayout.emptyStateTitleIdentifier)
        }
      }
    }
  }
}

#Preview("Empty conversation") {
  ConversationEmptyState()
}
