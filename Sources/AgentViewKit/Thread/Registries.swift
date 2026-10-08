import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Keyed registry

/// A table of view functions, keyed by a value (plan.md §3.6).
///
/// A registration for a key replaces the prior registration for the same
/// key. Thus the last writer wins. The three keyed registries of the kit use
/// this table.
public struct KeyedViewRegistry<Key: Hashable & Sendable, Value>: Sendable {
  /// A function that makes the view of one value.
  public typealias Renderer = @MainActor (Value) -> AnyView

  /// The renderers, keyed by their key.
  private var renderers: [Key: Renderer] = [:]

  /// Makes an empty registry.
  public init() {}

  /// The keys that have a registration, in no specified order.
  public var keys: some Collection<Key> {
    renderers.keys
  }

  /// Registers the renderer of `key`. The renderer replaces the prior
  /// renderer of `key`.
  ///
  /// - Parameters:
  ///   - key: The key of the renderer.
  ///   - renderer: The function that makes the view.
  public mutating func register(_ key: Key, _ renderer: @escaping Renderer) {
    renderers[key] = renderer
  }

  /// The renderer of `key`, or `nil` when `key` has no registration.
  ///
  /// - Parameter key: The key to find.
  /// - Returns: The last renderer that was registered for `key`.
  public func renderer(for key: Key) -> Renderer? {
    renderers[key]
  }
}

extension View {
  /// Adds one registration to a keyed registry of the environment.
  ///
  /// A modifier near the content applies after a modifier farther out, so
  /// the inner registration wins.
  ///
  /// - Parameters:
  ///   - registry: The environment key of the registry.
  ///   - key: The key of the registration.
  ///   - content: The function that makes the view.
  /// - Returns: A view that gives the registration to its subtree.
  fileprivate func register<Key: Hashable & Sendable, Value, Content: View>(
    in registry: WritableKeyPath<EnvironmentValues, KeyedViewRegistry<Key, Value>>,
    _ key: Key,
    _ content: @escaping @MainActor (Value) -> Content
  ) -> some View {
    transformEnvironment(registry) { registry in
      registry.register(key) { value in AnyView(content(value)) }
    }
  }
}

// MARK: - Content block registry

/// The views of the ACP content blocks, keyed by the kind of the block
/// (plan.md §3.6).
///
/// Register a view with ``SwiftUI/View/contentBlockView(for:_:)``. The view
/// function gets the ACP `ContentBlock` value as the transcript entry holds
/// it. A kind with no registration resolves to `nil`, and the caller shows
/// the default view of the kind.
public typealias ContentBlockRegistry = KeyedViewRegistry<
  FoundationModelsACP.ContentBlock.Kind, FoundationModelsACP.ContentBlock
>

extension KeyedViewRegistry
where Key == FoundationModelsACP.ContentBlock.Kind, Value == FoundationModelsACP.ContentBlock {
  /// The view function of a block kind.
  ///
  /// - Parameter kind: The block kind to find.
  /// - Returns: The innermost registration for `kind`, or `nil`.
  public func resolve(kind: FoundationModelsACP.ContentBlock.Kind) -> Renderer? {
    renderer(for: kind)
  }
}

// MARK: - Attachment registry

/// The views of attached files, keyed by uniform type (plan.md §3.6).
///
/// Register a view with ``SwiftUI/View/attachmentView(for:_:)``. The view
/// function gets the URL of the file.
public typealias AttachmentRegistry = KeyedViewRegistry<UTType, URL>

extension KeyedViewRegistry where Key == UTType, Value == URL {
  /// The view function of a uniform type.
  ///
  /// The function uses the registration of `type` if there is one.
  /// Otherwise, it uses the registration of the nearest supertype that
  /// `type` conforms to. A nearer supertype conforms to each farther one,
  /// so it has more supertypes. When two registered supertypes are not
  /// related, the type with more supertypes wins, then the type with the
  /// lower identifier.
  ///
  /// - Parameter type: The type of the file.
  /// - Returns: The nearest registration, or `nil` when no registered type
  ///   is a supertype of `type`. The caller then shows the generic file chip.
  public func resolve(type: UTType) -> Renderer? {
    if let exact = renderer(for: type) { return exact }
    let nearest = keys
      .filter { type.conforms(to: $0) }
      .min { lhs, rhs in
        let lhsDepth = lhs.supertypes.count
        let rhsDepth = rhs.supertypes.count
        if lhsDepth != rhsDepth { return lhsDepth > rhsDepth }
        return lhs.identifier < rhs.identifier
      }
    return nearest.flatMap { renderer(for: $0) }
  }
}

// MARK: - Tool call registry

/// The body views of tool calls, keyed by the program name of the tool
/// (plan.md §3.8 "Tool call view").
///
/// Register a view with ``SwiftUI/View/toolCallView(named:_:)``. The view
/// function gets the `ToolCallEntry` of the call. ``ToolCallView`` shows the
/// registered view in place of its default body, and keeps its row with the
/// `title` as the label. A call with no name, or with a name that has no
/// registration, shows the default body.
public typealias ToolCallRegistry = KeyedViewRegistry<String, ToolCallEntry>

extension KeyedViewRegistry where Key == String, Value == ToolCallEntry {
  /// The view function of a tool name.
  ///
  /// - Parameter name: The program name of the tool, or `nil` for a call
  ///   with no name.
  /// - Returns: The innermost registration for `name`, or `nil` when `name`
  ///   is `nil` or has no registration.
  public func resolve(name: String?) -> Renderer? {
    name.flatMap { renderer(for: $0) }
  }
}

// MARK: - Environment

extension EnvironmentValues {
  /// The views of the ACP content blocks that ``ContentBlockView`` reads.
  @Entry public var contentBlockRegistry = ContentBlockRegistry()

  /// The attachment views that the attachment views read.
  @Entry public var attachmentRegistry = AttachmentRegistry()

  /// The tool call body views that ``ToolCallView`` reads.
  @Entry public var toolCallRegistry = ToolCallRegistry()
}

extension View {
  /// Replaces the view of each ACP content block of `kind` in this view.
  ///
  /// The function gets the ACP `ContentBlock` value that the transcript entry
  /// holds, such as a block of an agent message or of a tool call.
  ///
  /// - Parameters:
  ///   - kind: The block kind, such as `.resourceLink`.
  ///   - content: The function that makes the view of a block.
  /// - Returns: A view that gives the registration to its subtree.
  public func contentBlockView<Content: View>(
    for kind: FoundationModelsACP.ContentBlock.Kind,
    @ViewBuilder _ content: @escaping @MainActor (FoundationModelsACP.ContentBlock) -> Content
  ) -> some View {
    register(in: \.contentBlockRegistry, kind, content)
  }

  /// Replaces the view of each attached file of `type`, or of a subtype of
  /// `type`, in this view.
  ///
  /// - Parameters:
  ///   - type: The uniform type, such as `.pdf`.
  ///   - content: The function that makes the view of a file URL.
  /// - Returns: A view that gives the registration to its subtree.
  public func attachmentView<Content: View>(
    for type: UTType,
    @ViewBuilder _ content: @escaping @MainActor (URL) -> Content
  ) -> some View {
    register(in: \.attachmentRegistry, type, content)
  }

  /// Replaces the body of each tool call with the program name `name` in
  /// this view.
  ///
  /// The row of the call stays: it shows the `title` of the call as its
  /// label, with the kind symbol and the status. The registered view shows
  /// when the call is expanded.
  ///
  /// - Parameters:
  ///   - name: The program name of the tool, such as `read_file`.
  ///   - content: The function that makes the body of a call.
  /// - Returns: A view that gives the registration to its subtree.
  public func toolCallView<Content: View>(
    named name: String,
    @ViewBuilder _ content: @escaping @MainActor (ToolCallEntry) -> Content
  ) -> some View {
    register(in: \.toolCallRegistry, name, content)
  }
}
