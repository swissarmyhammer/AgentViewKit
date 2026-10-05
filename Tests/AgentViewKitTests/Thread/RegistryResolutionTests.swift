import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers

/// The item kinds that have a typed override modifier.
enum OverrideKind: String, CaseIterable, Sendable {
  case userMessage
  case assistantMessage
  case reasoning
  case toolCall
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
    case .userMessage: userMessageView { _ in EmptyView() }
    case .assistantMessage: assistantMessageView { _ in EmptyView() }
    case .reasoning: reasoningView { _ in EmptyView() }
    case .toolCall: toolCallView { _ in EmptyView() }
    case .error: errorView { _ in EmptyView() }
    case .unknownItem: unknownItemView { _ in EmptyView() }
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
  @Environment(\.errorViewOverride) private var error
  @Environment(\.unknownItemViewOverride) private var unknownItem

  /// The names of the kinds that have an override, sorted.
  private var setKinds: [String] {
    let flags: [(OverrideKind, Bool)] = [
      (.userMessage, userMessage != nil),
      (.assistantMessage, assistantMessage != nil),
      (.reasoning, reasoning != nil),
      (.toolCall, toolCall != nil),
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

  @Test func typedModifierPassesTheRecord() {
    let record = ThreadError(id: "e1", kind: .unknown(message: "x"))
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
