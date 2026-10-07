import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACPClient
import SwiftUI
import Testing
import UniformTypeIdentifiers

/// The transcript entry cases that have a typed override modifier.
enum OverrideKind: String, CaseIterable, Sendable {
  case userMessage
  case assistantMessage
  case reasoning
  case toolCall
  case terminal
  case plan
  case error
  case unknownItem
  case compactionEntry

  /// The accessibility identifier of the marker that the override of this
  /// kind shows for the entry of `id`.
  ///
  /// - Parameter id: The identity of the entry.
  /// - Returns: `<kind>-<row key>`.
  func markerIdentifier(for id: TranscriptEntry.ID) -> String {
    "\(rawValue)-\(id.rowKey)"
  }
}

extension View {
  /// Applies the typed override modifier of `kind`. The override shows a
  /// marker with ``OverrideKind/markerIdentifier(for:)`` of its entry.
  ///
  /// - Parameter kind: The kind to override.
  /// - Returns: The view with the override.
  @ViewBuilder
  func applyOverride(_ kind: OverrideKind) -> some View {
    switch kind {
    case .userMessage: userMessageView { entry in marker(kind.markerIdentifier(for: entry.id)) }
    case .assistantMessage: assistantMessageView { entry in marker(kind.markerIdentifier(for: entry.id)) }
    case .reasoning: reasoningView { entry in marker(kind.markerIdentifier(for: entry.id)) }
    case .toolCall: toolCallView { entry in marker(kind.markerIdentifier(for: entry.id)) }
    case .terminal: terminalView { entry in marker(kind.markerIdentifier(for: entry.id)) }
    case .plan: planView { entry in marker(kind.markerIdentifier(for: entry.id)) }
    case .error: errorView { entry in marker(kind.markerIdentifier(for: entry.id)) }
    case .unknownItem: unknownItemView { entry in marker(kind.markerIdentifier(for: entry.id)) }
    case .compactionEntry: compactionEntryView { entry in marker(kind.markerIdentifier(for: entry.id)) }
    }
  }
}

/// Shows the names of the item view overrides that the environment has.
struct OverrideKeysReader: View {
  /// The accessibility identifier of the text.
  static let identifier = "override-keys"

  @Environment(\.userMessageViewOverride) private var userMessage
  @Environment(\.assistantMessageViewOverride) private var assistantMessage
  @Environment(\.reasoningViewOverride) private var reasoning
  @Environment(\.toolCallViewOverride) private var toolCall
  @Environment(\.terminalViewOverride) private var terminal
  @Environment(\.planViewOverride) private var plan
  @Environment(\.errorViewOverride) private var error
  @Environment(\.unknownItemViewOverride) private var unknownItem
  @Environment(\.compactionEntryViewOverride) private var compactionEntry

  /// The names of the kinds that have an override, sorted.
  private var setKinds: [String] {
    let flags: [(OverrideKind, Bool)] = [
      (.userMessage, userMessage != nil),
      (.assistantMessage, assistantMessage != nil),
      (.reasoning, reasoning != nil),
      (.toolCall, toolCall != nil),
      (.terminal, terminal != nil),
      (.plan, plan != nil),
      (.error, error != nil),
      (.unknownItem, unknownItem != nil),
      (.compactionEntry, compactionEntry != nil),
    ]
    return flags.filter(\.1).map(\.0.rawValue).sorted()
  }

  var body: some View {
    Text("keys:" + setKinds.joined(separator: ","))
      .accessibilityIdentifier(Self.identifier)
  }
}

/// Shows the view that the content block registry resolves for a kind.
struct ContentBlockRegistryReader: View {
  /// The block to resolve.
  let block: ContentBlock

  @Environment(\.contentBlockRegistry) private var registry

  var body: some View {
    if let renderer = registry.resolve(kind: block.kind) {
      renderer(block)
    } else {
      Text("none").accessibilityIdentifier("none")
    }
  }
}

/// Shows the view that the attachment registry resolves for a type.
struct AttachmentRegistryReader: View {
  /// The type to resolve.
  let type: UTType

  @Environment(\.attachmentRegistry) private var registry

  var body: some View {
    if let renderer = registry.resolve(type: type) {
      renderer(URL(filePath: "/tmp/file"))
    } else {
      Text("none").accessibilityIdentifier("none")
    }
  }
}

/// Shows whether the tool call registry resolves a tool name.
struct ToolCallRegistryReader: View {
  /// The accessibility identifier of the text.
  static let identifier = "tool-call-registry"

  /// The tool name to resolve, or `nil` for a call with no name.
  let name: String?

  @Environment(\.toolCallRegistry) private var registry

  var body: some View {
    Text(registry.resolve(name: name) == nil ? "none" : "found")
      .accessibilityIdentifier(Self.identifier)
  }
}

/// Shows a text with an accessibility identifier.
///
/// - Parameter identifier: The text and the identifier.
/// - Returns: The text view.
@MainActor
func marker(_ identifier: String) -> some View {
  Text(identifier).accessibilityIdentifier(identifier)
}

@Suite(.serialized, .hostedSerially) @MainActor struct RegistryResolutionTests {
  /// Mounts `content`, pumps the run loop, and gives the harness.
  static func mount<Content: View>(_ content: Content) -> HostedViewHarness<Content> {
    let harness = HostedViewHarness(content)
    harness.pump()
    return harness
  }

  // MARK: - Content block registry

  @Test func contentBlockRegistryLastWriterWins() {
    var registry = ContentBlockRegistry()
    var calls: [String] = []
    registry.register(.text) { _ in
      calls.append("first")
      return AnyView(EmptyView())
    }
    registry.register(.text) { _ in
      calls.append("second")
      return AnyView(EmptyView())
    }
    let renderer = registry.resolve(kind: .text)
    _ = renderer?(ContentBlock(text: "t"))
    #expect(calls == ["second"])
  }

  @Test func contentBlockViewResolvesByKind() {
    let link = ContentBlock(content: .resourceLink(ResourceLink(name: "n", uri: "u")))
    let harness = Self.mount(
      ContentBlockRegistryReader(block: link)
        .contentBlockView(for: .resourceLink) { _ in marker("link") }
    )
    defer { harness.close() }
    #expect(harness.element(identifier: "link") != nil)
  }

  @Test func contentBlockViewWithNoRegistrationIsNil() {
    let harness = Self.mount(
      ContentBlockRegistryReader(block: ContentBlock(text: "t"))
        .contentBlockView(for: .resourceLink) { _ in marker("link") }
    )
    defer { harness.close() }
    #expect(harness.element(identifier: "none") != nil)
  }

  @Test func innerContentBlockViewWinsOverOuter() {
    let harness = Self.mount(
      ContentBlockRegistryReader(block: ContentBlock(text: "t"))
        .contentBlockView(for: .text) { _ in marker("inner") }
        .contentBlockView(for: .text) { _ in marker("outer") }
    )
    defer { harness.close() }
    #expect(harness.element(identifier: "inner") != nil)
    #expect(harness.element(identifier: "outer") == nil)
  }

  // MARK: - Attachment registry

  @Test func attachmentResolveWalksToSourceCode() {
    var registry = AttachmentRegistry()
    registry.register(.sourceCode) { _ in AnyView(EmptyView()) }
    #expect(registry.resolve(type: .swiftSource) != nil)
  }

  @Test func attachmentResolveWithNoRegistrationIsNil() {
    var registry = AttachmentRegistry()
    registry.register(.sourceCode) { _ in AnyView(EmptyView()) }
    #expect(registry.resolve(type: .data) == nil)
  }

  @Test func attachmentResolvePicksTheNearestSupertype() {
    var registry = AttachmentRegistry()
    var calls: [String] = []
    registry.register(.text) { _ in
      calls.append("text")
      return AnyView(EmptyView())
    }
    registry.register(.sourceCode) { _ in
      calls.append("sourceCode")
      return AnyView(EmptyView())
    }
    registry.register(.plainText) { _ in
      calls.append("plainText")
      return AnyView(EmptyView())
    }
    _ = registry.resolve(type: .swiftSource)?(URL(filePath: "/tmp/a.swift"))
    _ = registry.resolve(type: .utf8PlainText)?(URL(filePath: "/tmp/a.txt"))
    _ = registry.resolve(type: .html)?(URL(filePath: "/tmp/a.html"))
    #expect(calls == ["sourceCode", "plainText", "text"])
  }

  @Test func attachmentResolvePrefersTheExactType() {
    var registry = AttachmentRegistry()
    var calls: [String] = []
    registry.register(.sourceCode) { _ in
      calls.append("sourceCode")
      return AnyView(EmptyView())
    }
    registry.register(.swiftSource) { _ in
      calls.append("swiftSource")
      return AnyView(EmptyView())
    }
    _ = registry.resolve(type: .swiftSource)?(URL(filePath: "/tmp/a.swift"))
    #expect(calls == ["swiftSource"])
  }

  @Test func attachmentViewResolvesThroughTheEnvironment() {
    let harness = Self.mount(
      AttachmentRegistryReader(type: .swiftSource)
        .attachmentView(for: .sourceCode) { _ in marker("code") }
    )
    defer { harness.close() }
    #expect(harness.element(identifier: "code") != nil)
  }

  @Test func attachmentViewWithNoConformingRegistrationIsNil() {
    let harness = Self.mount(
      AttachmentRegistryReader(type: .data)
        .attachmentView(for: .sourceCode) { _ in marker("code") }
    )
    defer { harness.close() }
    #expect(harness.element(identifier: "none") != nil)
  }

  // MARK: - Tool call registry

  @Test(arguments: [
    ("read_file", true),
    ("write_file", false),
    (nil, false),
  ] as [(String?, Bool)])
  func toolCallRegistryResolvesOnlyTheRegisteredName(name: String?, resolves: Bool) {
    var registry = ToolCallRegistry()
    registry.register("read_file") { _ in AnyView(EmptyView()) }
    #expect((registry.resolve(name: name) != nil) == resolves)
  }

  @Test(arguments: [
    ("read_file", "found"),
    ("write_file", "none"),
  ])
  func toolCallViewNamedRegistersOnlyItsNameInTheEnvironment(name: String, expected: String) {
    let harness = Self.mount(
      ToolCallRegistryReader(name: name)
        .toolCallView(named: "read_file") { _ in marker("read") }
    )
    defer { harness.close() }
    #expect(harness.element(identifier: ToolCallRegistryReader.identifier)?.label == expected)
  }

  // MARK: - Typed item modifiers

  @Test func noModifierSetsNoKey() {
    let harness = Self.mount(OverrideKeysReader())
    defer { harness.close() }
    #expect(harness.element(identifier: OverrideKeysReader.identifier)?.label == "keys:")
  }

  @Test(arguments: OverrideKind.allCases)
  func typedModifierSetsOnlyItsKey(kind: OverrideKind) {
    let harness = Self.mount(OverrideKeysReader().applyOverride(kind))
    defer { harness.close() }
    #expect(
      harness.element(identifier: OverrideKeysReader.identifier)?.label
        == "keys:" + kind.rawValue)
  }

  #if DEBUG
  // MARK: - Entry rows

  /// The `messageId` of the message and thought entries of the entry row
  /// test.
  static let entryMessageID = "override-m"

  /// The `toolCallId` of the tool call entry of the entry row test.
  static let entryToolCallID = "override-call"

  /// The text of the message, thought and compaction entries of the entry
  /// row test.
  static let entryText = "Override."

  /// The `session/update` value that makes an entry of `kind`.
  ///
  /// - Parameter kind: The entry case.
  /// - Returns: The JSON text of the update, or `nil` for an error entry,
  ///   which the client makes itself.
  static func update(making kind: OverrideKind) -> String? {
    let text = WireBlockJSON.makeText(entryText)
    switch kind {
    case .userMessage:
      return WireBlockJSON.makeChunk("user_message_chunk", messageID: entryMessageID, block: text)
    case .assistantMessage:
      return WireBlockJSON.makeChunk("agent_message_chunk", messageID: entryMessageID, block: text)
    case .reasoning:
      return WireBlockJSON.makeChunk("agent_thought_chunk", messageID: entryMessageID, block: text)
    case .toolCall:
      return WireBlockJSON.makeToolCallUpdate(id: entryToolCallID, fields: #""status": "pending""#)
    case .terminal:
      return SessionEntryRowsHostedTests.terminalUpdate(#""command": "\#(SessionEntryRowsHostedTests.command)""#)
    case .plan:
      return SessionEntryRowsHostedTests.planUpdate(firstStatus: "pending")
    case .unknownItem:
      return #"{"sessionUpdate": "\#(SessionEntryRowsHostedTests.unknownType)"}"#
    case .compactionEntry:
      return WireBlockJSON.makeCompactionSummaryChunk(
        compactionID: CompactionAndNoticeHostedTests.compactionID, block: text)
    case .error:
      return nil
    }
  }

  /// Makes the one entry of `kind` in the transcript of `session`.
  ///
  /// - Parameters:
  ///   - kind: The entry case.
  ///   - session: A scripted session with an empty transcript.
  /// - Returns: The entry.
  /// - Throws: The error of the transport, or an issue when the transcript
  ///   has no entry at the time limit.
  static func makeEntry(_ kind: OverrideKind, in session: ScriptedSession) async throws -> TranscriptEntry {
    if let update = update(making: kind) {
      try await session.sendUpdate(update)
    } else {
      session.model.appendError(code: .invalidParams, message: entryText, data: nil)
    }
    let model = session.model
    _ = await waitUntil { !model.transcript.isEmpty }
    return try #require(model.transcript.first)
  }

  @Test(arguments: OverrideKind.allCases)
  func theOverrideOfEachEntryCaseShowsInTheRowOfTheEntry(kind: OverrideKind) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let entry = try await Self.makeEntry(kind, in: session)

    let harness = Self.mount(ItemRow(entry: entry).applyOverride(kind))
    defer { harness.close() }

    #expect(harness.element(identifier: kind.markerIdentifier(for: entry.id)) != nil)
    #expect(harness.element(identifier: ItemRow.identifier(for: entry.rowKey)) != nil)
  }
  #endif
}
