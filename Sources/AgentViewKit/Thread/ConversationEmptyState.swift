import EditorCommands
import EditorCommandsUI
import EditorStyle
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
      systemImage: EditorSymbol.action(.conversation).systemImage,
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
/// Markdown text below it. The text shows in the rendered form of EditorKit
/// (``RenderedMarkdownView``, D185), so headings, lists, links, math and
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
///
/// The text has no margin around it (^rgsq3k4): the layout that holds the
/// view gives one, such as `.scrollContentMargins(\.spacing.l)`. The default
/// empty state of ``ConversationView`` has that margin.
public struct ConversationEmptyState: View {
  /// The content that the host gave to the initializer, or `nil` to use the
  /// content of the environment.
  let content: ConversationEmptyContent?

  @Environment(\.conversationEmptyContent) private var environmentContent
  @Environment(\.editorStyle) private var editorStyle

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

  /// The height of the visible area of the scroll view, less its content
  /// margins: the smallest height of the content.
  @State private var visibleHeight: CGFloat = 0

  public var body: some View {
    let shown = content ?? environmentContent ?? .standard
    ScrollView {
      VStack(alignment: .leading, spacing: editorStyle.spacing.m) {
        ConversationEmptyHeader(title: shown.title, systemImage: shown.systemImage)
        RenderedMarkdownView(
          shown.markdown, identifier: ConversationLayout.emptyStateTextIdentifier)
      }
      // The text has a scope of its own, which is no target. A focus request
      // on the scope of the thread gives the first responder to a text view
      // of that scope, or to a focusable view at its center. The read-only
      // text of the empty state is no such view: the focus goes to the
      // composer, or to the scope itself (Testudo, 2026-11-20).
      .commandScope(segment: ConversationEmptyLayout.textSegment)
      .targetable(false)
      // The content fills the visible area, and its shape takes the clicks
      // there. Thus a click on the empty space above or below the text hits
      // the content, not the AppKit scroll view, and a tap gesture of the
      // host fires: EditorKit `.focusesScopeOnClick(.emptySpaceOnly)`
      // focuses the scope of the thread (Testudo, 2026-11-20).
      .frame(maxWidth: .infinity, minHeight: visibleHeight, alignment: .leading)
      .contentShape(Rectangle())
    }
    .onScrollGeometryChange(for: CGFloat.self, of: ConversationEmptyLayout.visibleHeight) {
      _, height in
      visibleHeight = height
    }
    .scrollBounceBehavior(.basedOnSize)
    .contentContainer(identifier: ConversationLayout.emptyStateIdentifier)
  }
}

/// The layout values of a ``ConversationEmptyState``.
enum ConversationEmptyLayout {
  /// The segment of the scope of the title and the text.
  static let textSegment = FocusSegment(kind: "agentEmptyState")

  /// The height of the visible area of a scroll view, less its content
  /// margins: the height that content must have to fill the visible area.
  ///
  /// - Parameter geometry: The geometry of the scroll view.
  /// - Returns: The height, not less than zero.
  static func visibleHeight(of geometry: ScrollGeometry) -> CGFloat {
    max(
      0, geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom)
  }
}

/// The title and the SF Symbol of a ``ConversationEmptyState``.
///
/// With no title and no symbol, the header shows nothing.
///
/// The symbol is a ``DecorativeSymbolImage``: it has the `.secondary` style,
/// not the accent of the EditorKit theme (D113 answer 5).
private struct ConversationEmptyHeader: View {
  /// The title, or `nil` for no title.
  let title: String?

  /// The name of the SF Symbol, or `nil` for no symbol.
  let systemImage: String?

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    if title != nil || systemImage != nil {
      HStack(alignment: .firstTextBaseline, spacing: editorStyle.spacing.s) {
        if let systemImage {
          DecorativeSymbolImage(name: systemImage)
        }
        if let title {
          Text(title)
            .font(editorTheme.uiFont.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(ConversationLayout.emptyStateTitleIdentifier)
        }
      }
    }
  }
}

#Preview("Empty conversation") {
  ConversationEmptyState()
    .scrollContentMargins(\.spacing.l)
}
