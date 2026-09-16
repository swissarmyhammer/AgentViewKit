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

// MARK: - Structured item registry

/// A structured value and its schema name (plan.md §3.6).
///
/// A structured thread item and a structured content block give the same
/// value. Thus one registration shows a schema name in both places.
public nonisolated struct StructuredItemContent: Sendable, Hashable {
  /// The schema name of the value, such as `AgentViewKit.Chart`.
  public var schemaName: String

  /// The value.
  public var payload: JSONValue

  /// Makes structured content.
  ///
  /// - Parameters:
  ///   - schemaName: The schema name of the value.
  ///   - payload: The value.
  public init(schemaName: String, payload: JSONValue) {
    self.schemaName = schemaName
    self.payload = payload
  }

  /// Makes structured content from the current values of a record.
  ///
  /// - Parameter record: The structured thread item.
  @MainActor
  public init(record: StructuredRecord) {
    self.init(schemaName: record.schemaName, payload: record.payload)
  }

  /// Makes structured content from a structured content block.
  ///
  /// - Parameter block: The content block.
  /// - Returns: `nil` when the block is not
  ///   ``ContentBlock/Content/structured(schemaName:payload:)``.
  public init?(block: ContentBlock) {
    guard case .structured(let schemaName, let payload) = block.content else { return nil }
    self.init(schemaName: schemaName, payload: payload)
  }
}

/// The views of structured values, keyed by schema name (plan.md §3.6).
///
/// Register a view with ``SwiftUI/View/structuredItem(_:_:)``. A name with
/// no registration resolves to `nil`, and the caller shows the JSON view.
public typealias StructuredItemRegistry = KeyedViewRegistry<String, StructuredItemContent>

extension KeyedViewRegistry where Key == String, Value == StructuredItemContent {
  /// The view function of a schema name.
  ///
  /// - Parameter schemaName: The schema name to find.
  /// - Returns: The innermost registration for `schemaName`, or `nil`.
  public func resolve(schemaName: String) -> Renderer? {
    renderer(for: schemaName)
  }
}

// MARK: - Content block registry

/// The views of content blocks, keyed by block kind (plan.md §3.6).
///
/// Register a view with ``SwiftUI/View/contentBlockView(for:_:)``. A kind
/// with no registration resolves to `nil`, and the caller shows the default
/// view of the kind.
public typealias ContentBlockRegistry = KeyedViewRegistry<ContentBlock.Kind, ContentBlock>

extension KeyedViewRegistry where Key == ContentBlock.Kind, Value == ContentBlock {
  /// The view function of a block kind.
  ///
  /// - Parameter kind: The block kind to find.
  /// - Returns: The innermost registration for `kind`, or `nil`.
  public func resolve(kind: ContentBlock.Kind) -> Renderer? {
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

// MARK: - Environment

extension EnvironmentValues {
  /// The structured item views that the thread view reads.
  @Entry public var structuredItemRegistry = StructuredItemRegistry()

  /// The content block views that the message views read.
  @Entry public var contentBlockRegistry = ContentBlockRegistry()

  /// The attachment views that the attachment views read.
  @Entry public var attachmentRegistry = AttachmentRegistry()
}

extension View {
  /// Replaces the view of each structured value with `schemaName` in this
  /// view.
  ///
  /// The registration applies to a structured thread item and to a
  /// structured content block in a message. An inner registration for the
  /// same name wins.
  ///
  /// - Parameters:
  ///   - schemaName: The schema name, such as `AgentViewKit.Chart`.
  ///   - content: The function that makes the view of a value.
  /// - Returns: A view that gives the registration to its subtree.
  public func structuredItem<Content: View>(
    _ schemaName: String,
    @ViewBuilder _ content: @escaping @MainActor (StructuredItemContent) -> Content
  ) -> some View {
    register(in: \.structuredItemRegistry, schemaName, content)
  }

  /// Replaces the view of each content block of `kind` in this view.
  ///
  /// - Parameters:
  ///   - kind: The block kind, such as ``ContentBlock/Kind/resourceLink``.
  ///   - content: The function that makes the view of a block.
  /// - Returns: A view that gives the registration to its subtree.
  public func contentBlockView<Content: View>(
    for kind: ContentBlock.Kind,
    @ViewBuilder _ content: @escaping @MainActor (ContentBlock) -> Content
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
}
