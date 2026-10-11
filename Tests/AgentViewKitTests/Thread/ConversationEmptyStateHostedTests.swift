#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
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

    /// The accessibility label of the code block of ``welcomeMarkdown``.
    static let codeBlockLabel = "swift code block"

    /// Whether an element of `harness` has the label `label`.
    ///
    /// - Parameters:
    ///   - label: The label to find.
    ///   - harness: The harness that shows the view.
    /// - Returns: `true` when an element has the label.
    static func showsLabel<Content: View>(_ label: String, in harness: HostedViewHarness<Content>) -> Bool {
      harness.accessibilityElements().contains { $0.label == label }
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
      harness.pump()

      #expect(harness.element(identifier: ConversationLayout.emptyStateIdentifier) != nil)
      #expect(Self.showsLabel(Self.heading, in: harness))
      #expect(Self.listItems.allSatisfy { Self.showsLabel($0, in: harness) })
      let link = harness.element(identifier: Self.linkAddress)
      #expect(link?.role == "AXLink")
      #expect(link?.label == Self.linkText)
      #expect(harness.element(identifier: CodeBlockView.identifier)?.label == Self.codeBlockLabel)
    }

    @Test func theHostMarkdownGoesAwayAfterTheFirstEntry() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let view = ConversationView(session: session.model) {
        ConversationEmptyState(markdown: Self.welcomeMarkdown)
      }
      let harness = HostedViewHarness(view, size: Self.hostSize)
      defer { harness.close() }
      harness.pump()
      #expect(Self.showsLabel(Self.heading, in: harness))

      let insertedKey = try await ConversationViewHostedTests.insertMessage(into: session)
      await harness.pump(until: ConversationViewHostedTests.waitTimeout) {
        harness.element(identifier: ConversationLayout.listIdentifier) != nil
      }

      #expect(harness.element(identifier: ConversationLayout.emptyStateIdentifier) == nil)
      #expect(!Self.showsLabel(Self.heading, in: harness))
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
      harness.pump()

      let title = try #require(harness.frame(identifier: ConversationLayout.emptyStateTitleIdentifier))
      let code = try #require(harness.frame(identifier: CodeBlockView.identifier))
      #expect(harness.element(identifier: ConversationLayout.emptyStateTitleIdentifier)?.label == Self.title)
      // The y axis of a screen frame goes up, so the higher view has the larger y.
      #expect(title.minY > code.maxY)
    }

    @Test func hostMarkdownWithNoTitleShowsNoTitle() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let view = ConversationView(session: session.model) {
        ConversationEmptyState(markdown: Self.welcomeMarkdown)
      }
      let harness = HostedViewHarness(view, size: Self.hostSize)
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: ConversationLayout.emptyStateTitleIdentifier) == nil)
    }

    // MARK: - Default

    @Test func theDefaultEmptyStateShowsTheDefaultText() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(ConversationView(session: session.model), size: Self.hostSize)
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: ConversationLayout.emptyStateTitleIdentifier)?.label == Self.defaultTitle)
      #expect(Self.showsLabel(Self.defaultMessage, in: harness))
    }

    // MARK: - Environment

    @Test func theModifierSetsTheEmptyStateOfTheDropInThread() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let view = AgentThreadView(session: session.model)
        .conversationEmptyState(title: Self.title, markdown: Self.environmentMarkdown)
      let harness = HostedViewHarness(view, size: Self.hostSize)
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: ConversationLayout.emptyStateIdentifier) != nil)
      #expect(harness.element(identifier: ConversationLayout.emptyStateTitleIdentifier)?.label == Self.title)
      #expect(Self.showsLabel(Self.environmentMarkdown, in: harness))
      #expect(!Self.showsLabel(Self.defaultMessage, in: harness))
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
      harness.pump()

      #expect(Self.showsLabel(Self.heading, in: harness))
      #expect(!Self.showsLabel(Self.environmentMarkdown, in: harness))
    }
  }
#endif
