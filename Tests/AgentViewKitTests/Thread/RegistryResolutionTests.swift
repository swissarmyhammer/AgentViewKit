import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers

/// The item kinds that have a typed override modifier.
enum OverrideKind: String, CaseIterable, Sendable {
  case systemPrompt
  case userMessage
  case assistantMessage
  case reasoning
  case toolCall
  case structuredItem
  case compaction
  case error
  case unknownItem
}

extension View {
  /// Applies the typed override modifier of `kind` with an empty view.
  ///
  /// - Parameter kind: The kind to override.
  /// - Returns: The view with the override.
  @ViewBuilder
  func applyOverride(_ kind: OverrideKind) -> some View {
    switch kind {
    case .systemPrompt: systemPromptView { _ in EmptyView() }
    case .userMessage: userMessageView { _ in EmptyView() }
    case .assistantMessage: assistantMessageView { _ in EmptyView() }
    case .reasoning: reasoningView { _ in EmptyView() }
    case .toolCall: toolCallView { _ in EmptyView() }
    case .structuredItem: structuredItemView { _ in EmptyView() }
    case .compaction: compactionView { _ in EmptyView() }
    case .error: errorView { _ in EmptyView() }
    case .unknownItem: unknownItemView { _ in EmptyView() }
    }
  }
}

/// Shows the names of the item view overrides that the environment has.
struct OverrideKeysReader: View {
  /// The accessibility identifier of the text.
  static let identifier = "override-keys"

  @Environment(\.systemPromptViewOverride) private var systemPrompt
  @Environment(\.userMessageViewOverride) private var userMessage
  @Environment(\.assistantMessageViewOverride) private var assistantMessage
  @Environment(\.reasoningViewOverride) private var reasoning
  @Environment(\.toolCallViewOverride) private var toolCall
  @Environment(\.structuredItemViewOverride) private var structuredItem
  @Environment(\.compactionViewOverride) private var compaction
  @Environment(\.errorViewOverride) private var error
  @Environment(\.unknownItemViewOverride) private var unknownItem

  /// The names of the kinds that have an override, sorted.
  private var setKinds: [String] {
    let flags: [(OverrideKind, Bool)] = [
      (.systemPrompt, systemPrompt != nil),
      (.userMessage, userMessage != nil),
      (.assistantMessage, assistantMessage != nil),
      (.reasoning, reasoning != nil),
      (.toolCall, toolCall != nil),
      (.structuredItem, structuredItem != nil),
      (.compaction, compaction != nil),
      (.error, error != nil),
      (.unknownItem, unknownItem != nil),
    ]
    return flags.filter(\.1).map(\.0.rawValue).sorted()
  }

  var body: some View {
    Text("keys:" + setKinds.joined(separator: ","))
      .accessibilityIdentifier(Self.identifier)
  }
}

/// Shows the view that the structured item registry resolves for a name.
struct StructuredRegistryReader: View {
  /// The schema name to resolve.
  let schemaName: String

  @Environment(\.structuredItemRegistry) private var registry

  var body: some View {
    if let renderer = registry.resolve(schemaName: schemaName) {
      renderer(StructuredItemContent(schemaName: schemaName, payload: .null))
    } else {
      Text("none").accessibilityIdentifier("none")
    }
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

/// Shows a text with an accessibility identifier.
///
/// - Parameter identifier: The text and the identifier.
/// - Returns: The text view.
@MainActor
func marker(_ identifier: String) -> some View {
  Text(identifier).accessibilityIdentifier(identifier)
}

@Suite(.serialized) @MainActor struct RegistryResolutionTests {
  /// Mounts `content`, pumps the run loop, and gives the harness.
  static func mount<Content: View>(_ content: Content) -> HostedViewHarness<Content> {
    let harness = HostedViewHarness(content)
    harness.pump()
    return harness
  }

  // MARK: - Structured item registry

  @Test func structuredRegistryLastWriterWins() {
    var registry = StructuredItemRegistry()
    var calls: [String] = []
    registry.register("x") { _ in
      calls.append("first")
      return AnyView(EmptyView())
    }
    registry.register("x") { _ in
      calls.append("second")
      return AnyView(EmptyView())
    }
    let renderer = registry.resolve(schemaName: "x")
    _ = renderer?(StructuredItemContent(schemaName: "x", payload: .null))
    #expect(calls == ["second"])
  }

  @Test func structuredRegistryUnknownNameIsNil() {
    var registry = StructuredItemRegistry()
    registry.register("x") { _ in AnyView(EmptyView()) }
    #expect(registry.resolve(schemaName: "y") == nil)
  }

  @Test func innerStructuredItemWinsOverOuter() {
    let harness = Self.mount(
      StructuredRegistryReader(schemaName: "x")
        .structuredItem("x") { _ in marker("inner") }
        .structuredItem("x") { _ in marker("outer") }
    )
    defer { harness.close() }
    #expect(harness.element(identifier: "inner") != nil)
    #expect(harness.element(identifier: "outer") == nil)
  }

  @Test func outerStructuredItemStaysForOtherNames() {
    let harness = Self.mount(
      StructuredRegistryReader(schemaName: "y")
        .structuredItem("x") { _ in marker("inner") }
        .structuredItem("y") { _ in marker("outer") }
    )
    defer { harness.close() }
    #expect(harness.element(identifier: "outer") != nil)
    #expect(harness.element(identifier: "inner") == nil)
  }

  @Test func structuredContentComesFromRecordAndBlock() {
    let record = StructuredRecord(id: "r", schemaName: "x", payload: .bool(true))
    #expect(
      StructuredItemContent(record: record)
        == StructuredItemContent(schemaName: "x", payload: .bool(true)))
    let block = ContentBlock(content: .structured(schemaName: "x", payload: .bool(true)))
    #expect(
      StructuredItemContent(block: block)
        == StructuredItemContent(schemaName: "x", payload: .bool(true)))
    #expect(StructuredItemContent(block: ContentBlock(text: "t")) == nil)
  }

  // MARK: - Content block registry

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

  @Test func typedModifierPassesTheRecord() {
    let record = ThreadError(id: "e1", kind: .timeout)
    let harness = Self.mount(
      ErrorOverrideReader(record: record)
        .errorView { error in marker("error-" + error.id) }
    )
    defer { harness.close() }
    #expect(harness.element(identifier: "error-e1") != nil)
  }
}

/// Shows the error override for a record.
struct ErrorOverrideReader: View {
  /// The record to show.
  let record: ThreadError

  @Environment(\.errorViewOverride) private var override

  var body: some View {
    if let override {
      override(record)
    } else {
      Text("none").accessibilityIdentifier("none")
    }
  }
}
