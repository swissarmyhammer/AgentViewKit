/// The identifier of a ``PermissionRequest`` (plan.md §3.2).
///
/// The source makes this value. For ACP, the source can use the JSON-RPC id
/// of the `session/request_permission` request.
public typealias PermissionRequestID = Identifier<PermissionRequest>

/// The identifier of a ``PermissionOption`` (plan.md §3.4).
///
/// For ACP, this is the `optionId`. ``PermissionDecision/Outcome/selected(_:)``
/// holds this type.
public typealias PermissionOptionID = Identifier<PermissionOption>

/// A request from the agent for permission to do an operation
/// (plan.md §3.2, §9 E, §12).
///
/// The fields follow the ACP v2 `session/request_permission` request.
/// `AgentThread.pendingPermissions` holds the requests that wait for the
/// user. The user answers with `AgentThreadActions.respond(to:_:)` and a
/// ``PermissionDecision``.
public nonisolated struct PermissionRequest: Sendable, Hashable, Identifiable {
  /// The identifier of the request.
  public var id: PermissionRequestID

  /// The title of the permission prompt.
  public var title: String

  /// The text that tells why the agent needs permission, or `nil`.
  public var description: String?

  /// The operation that needs permission, or `nil` when the source gave no
  /// subject that the kit knows.
  ///
  /// A view shows a generic prompt when the subject is `nil`.
  public var subject: Subject?

  /// The options that the user can select, in order. ACP sends one or more.
  public var options: [PermissionOption]

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// Makes a permission request.
  ///
  /// - Parameters:
  ///   - id: The identifier of the request.
  ///   - title: The title of the permission prompt.
  ///   - description: The text that tells why the agent needs permission.
  ///   - subject: The operation that needs permission.
  ///   - options: The options that the user can select, in order.
  ///   - meta: The `_meta` value of the source.
  public init(
    id: PermissionRequestID,
    title: String,
    description: String? = nil,
    subject: Subject? = nil,
    options: [PermissionOption],
    meta: JSONValue? = nil
  ) {
    self.id = id
    self.title = title
    self.description = description
    self.subject = subject
    self.options = options
    self.meta = meta
  }

  /// The operation that needs permission.
  ///
  /// The cases follow the ACP v2 `RequestPermissionSubject`.
  public enum Subject: Sendable, Hashable {
    /// The agent asks before it runs a tool call.
    ///
    /// - Parameter id: The ``ToolCallRecord/id`` of the tool call.
    case toolCall(id: String)

    /// The agent asks before it runs a command.
    ///
    /// - Parameters:
    ///   - command: The command that runs when the user gives permission.
    ///   - cwd: The absolute working directory of the command.
    ///   - toolCallId: The ``ToolCallRecord/id`` of the related tool call,
    ///     or `nil`.
    ///   - terminalId: The identifier of the related terminal, or `nil`. A
    ///     view links to the ``TerminalRecord`` when this value is present.
    case command(command: String, cwd: String, toolCallId: String?, terminalId: TerminalID?)
  }
}

/// An option that the user can select to answer a ``PermissionRequest``
/// (plan.md §9 E).
///
/// The fields follow the ACP v2 `PermissionOption`. The JSON form is the ACP
/// wire form: `optionId`, `name`, and `kind`.
public nonisolated struct PermissionOption: Sendable, Hashable, Identifiable, Codable {
  /// The identifier of the option.
  public var id: PermissionOptionID

  /// The label of the option.
  public var name: String

  /// The type of the option. A view uses it to select an icon and a style.
  public var kind: Kind

  /// The JSON keys that the struct reads and writes.
  private enum CodingKeys: String, CodingKey {
    case id = "optionId"
    case name
    case kind
  }

  /// Makes a permission option.
  ///
  /// - Parameters:
  ///   - id: The identifier of the option.
  ///   - name: The label of the option.
  ///   - kind: The type of the option.
  public init(id: PermissionOptionID, name: String, kind: Kind) {
    self.id = id
    self.name = name
    self.kind = kind
  }

  /// The type of a permission option.
  ///
  /// The wire values are the ACP v2 `PermissionOptionKind` strings. These
  /// four kinds are the v1 set of `PermissionView` (plan.md §9 E).
  public enum Kind: WireValueEnum, Codable {
    /// The user allows the operation one time.
    case allowOnce

    /// The user allows the operation, and the agent keeps the choice.
    case allowAlways

    /// The user rejects the operation one time.
    case rejectOnce

    /// The user rejects the operation, and the agent keeps the choice.
    case rejectAlways

    /// A kind that the kit does not know, with its wire string.
    case unknown(String)

    /// Each case of the enum, but not ``unknown(_:)``.
    public static let knownCases: [Kind] = [.allowOnce, .allowAlways, .rejectOnce, .rejectAlways]

    /// The ACP wire string of the case.
    public var wireValue: String {
      switch self {
      case .allowOnce: "allow_once"
      case .allowAlways: "allow_always"
      case .rejectOnce: "reject_once"
      case .rejectAlways: "reject_always"
      case .unknown(let wireValue): wireValue
      }
    }
  }
}
