#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Hosted tests of ``ConversationEmptyState`` and of the
  /// ``SwiftUI/View/conversationEmptyState(title:systemImage:markdown:)``
  /// modifier.
  @Suite(.serialized, .hostedSerially) @MainActor struct ConversationEmptyStateHostedTests {
    /// The size of the host window. It is tall enough for each block of
    /// ``welcomeMarkdown``.
    static let hostSize = CGSize(width: 480, height: 640)

    /// The heading of ``welcomeMarkdown``.
    static let heading = "Welcome"

    /// The two list items of ``welcomeMarkdown``.
    static let listItems = ["Ask about the code", "Attach a file"]

    /// The text of the link of ``welcomeMarkdown``.
    static let linkText = "the guide"

    /// The address of the link of ``welcomeMarkdown``.
    static let linkAddress = "https://example.com/guide"

    /// The Markdown that the host gives: a heading, a list, a link and a code
    /// block.
    static let welcomeMarkdown = """
      # \(heading)

      - \(listItems[0])
      - \(listItems[1])

      Read [\(linkText)](\(linkAddress)).

      ```swift
      let answer = 42
      ```
      """

    /// The title of the tests that give a title.
    static let title = "Start here"

    /// The Markdown of the tests that give the content in the environment.
    static let environmentMarkdown = "Hello from the environment."

    /// The title of the default empty state.
    static let defaultTitle = "No Messages"

    /// The text of the default empty state.
    static let defaultMessage = "Send a message to start the conversation."

    /// The code of the code block of ``welcomeMarkdown``.
    static let code = "let answer = 42"

    /// Whether the Markdown text of the empty state holds `text`.
    ///
    /// The text shows in an EditorKit text view (D185), whose value is the
    /// Markdown.
    static func shows(_ text: String, in harness: HostedViewHarness<some View>) -> Bool {
      harness.element(identifier: ConversationLayout.emptyStateTextIdentifier)?.value?.contains(text) == true
    }

    // MARK: - Host Markdown

    @Test func theHostMarkdownShowsWhileTheTranscriptIsEmpty() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let view = ConversationView(session: session.model) {
        ConversationEmptyState(markdown: Self.welcomeMarkdown)
      }
      let harness = HostedViewHarness(view, size: Self.hostSize)
      defer { harness.close() }
      harness.render()

      #expect(harness.element(identifier: ConversationLayout.emptyStateIdentifier) != nil)
      #expect(Self.shows(Self.heading, in: harness))
      #expect(Self.listItems.allSatisfy { Self.shows($0, in: harness) })
      #expect(Self.shows(Self.linkText, in: harness))
      #expect(Self.shows(Self.code, in: harness))
    }

    @Test func theHostMarkdownGoesAwayAfterTheFirstEntry() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let view = ConversationView(session: session.model) {
        ConversationEmptyState(markdown: Self.welcomeMarkdown)
      }
      let harness = HostedViewHarness(view, size: Self.hostSize)
      defer { harness.close() }
      harness.render()
      #expect(Self.shows(Self.heading, in: harness))

      let insertedKey = try await ConversationViewHostedTests.insertMessage(into: session)
      harness.render()

      #expect(harness.element(identifier: ConversationLayout.listIdentifier) != nil)
      #expect(harness.element(identifier: ConversationLayout.emptyStateIdentifier) == nil)
      #expect(!Self.shows(Self.heading, in: harness))
      #expect(harness.element(identifier: ItemRow.identifier(for: insertedKey)) != nil)
    }

    @Test func aTitleShowsAboveTheHostMarkdown() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let view = ConversationView(session: session.model) {
        ConversationEmptyState(title: Self.title, markdown: Self.welcomeMarkdown)
      }
      let harness = HostedViewHarness(view, size: Self.hostSize)
      defer { harness.close() }
      harness.render()

      let title = try #require(harness.frame(identifier: ConversationLayout.emptyStateTitleIdentifier))
      let text = try #require(harness.frame(identifier: ConversationLayout.emptyStateTextIdentifier))
      #expect(harness.element(identifier: ConversationLayout.emptyStateTitleIdentifier)?.label == Self.title)
      // The y axis of a screen frame goes up, so the higher view has the larger y.
      #expect(title.minY >= text.maxY)
    }

    @Test func hostMarkdownWithNoTitleShowsNoTitle() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let view = ConversationView(session: session.model) {
        ConversationEmptyState(markdown: Self.welcomeMarkdown)
      }
      let harness = HostedViewHarness(view, size: Self.hostSize)
      defer { harness.close() }
      harness.render()

      #expect(harness.element(identifier: ConversationLayout.emptyStateTitleIdentifier) == nil)
    }

    // MARK: - Default

    @Test func theDefaultEmptyStateShowsTheDefaultText() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(ConversationView(session: session.model), size: Self.hostSize)
      defer { harness.close() }
      harness.render()

      #expect(harness.element(identifier: ConversationLayout.emptyStateTitleIdentifier)?.label == Self.defaultTitle)
      #expect(Self.shows(Self.defaultMessage, in: harness))
    }

    // MARK: - Environment

    @Test func theModifierSetsTheEmptyStateOfTheDropInThread() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let view = AgentThreadView(session: session.model)
        .conversationEmptyState(title: Self.title, markdown: Self.environmentMarkdown)
      let harness = HostedViewHarness(view, size: Self.hostSize)
      defer { harness.close() }
      harness.render()

      #expect(harness.element(identifier: ConversationLayout.emptyStateIdentifier) != nil)
      #expect(harness.element(identifier: ConversationLayout.emptyStateTitleIdentifier)?.label == Self.title)
      #expect(Self.shows(Self.environmentMarkdown, in: harness))
      #expect(!Self.shows(Self.defaultMessage, in: harness))
    }

    @Test func anExplicitMarkdownWinsOverTheModifier() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let view = ConversationView(session: session.model) {
        ConversationEmptyState(markdown: Self.welcomeMarkdown)
      }
      .conversationEmptyState(markdown: Self.environmentMarkdown)
      let harness = HostedViewHarness(view, size: Self.hostSize)
      defer { harness.close() }
      harness.render()

      #expect(Self.shows(Self.heading, in: harness))
      #expect(!Self.shows(Self.environmentMarkdown, in: harness))
    }
  }
#endif
