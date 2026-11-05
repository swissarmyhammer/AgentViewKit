import Foundation

/// The custom ACP status of a tool call whose result is lost (plan.md §3.8,
/// §5, §9 C).
///
/// ACP has no lost status: an agent sends the custom status
/// ``lostWireValue`` when the result of a call is lost. The kit shows that
/// status as EditorKit's lost status (`EditorSymbol.Status.lost`), with its
/// own symbol and label, and each other unknown status as EditorKit's unknown
/// status, with its wire string as the detail (`EditorStatus`).
public nonisolated enum ToolStatusSymbol {
  /// The wire value of the custom status of a call whose result is lost.
  public static let lostWireValue = "_lost"
}
