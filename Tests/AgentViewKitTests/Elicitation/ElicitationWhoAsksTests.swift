import AgentViewKit
import SwiftUI
import Testing

/// Tests of the "who asks" text of ``ElicitationHeader``: the visible text of
/// ``ElicitationHeader/whoAsks(agentPath:source:rootLabel:)`` and the label of
/// ``ElicitationHeader/whoAsksAccessibilityLabel(agentPath:source:rootLabel:)``.
///
/// The functions take the raw values of a `PendingElicitation`, so these
/// tests need no session and no window.
@Suite struct ElicitationWhoAsksTests {
  /// The root label of the rows that do not set their own.
  nonisolated static let root = "root"

  /// One row of the table: the values of a request and the two texts.
  struct Row: Sendable, CustomTestStringConvertible {
    /// The agent path of the request.
    let agentPath: [String]
    /// The source of the request, or `nil`.
    let source: String?
    /// The root label of the deck.
    var rootLabel = ElicitationWhoAsksTests.root
    /// The visible text, or `nil` for no line.
    let visible: String?
    /// The accessibility label, or `nil` for no line.
    let accessibility: String?

    var testDescription: String {
      "\(agentPath) from \(source ?? "nil") under \(rootLabel)"
    }
  }

  /// The rows of the table of the design (card 39, section 2).
  nonisolated static let rows: [Row] = [
    Row(agentPath: [], source: nil, visible: nil, accessibility: nil),
    Row(agentPath: [], source: "runCode", visible: "root · runCode", accessibility: "Asked by root, from runCode"),
    Row(agentPath: ["reviewer"], source: nil, visible: "root › reviewer", accessibility: "Asked by root, reviewer"),
    Row(
      agentPath: ["planner", "reviewer"], source: "runCode",
      visible: "root › planner › reviewer · runCode",
      accessibility: "Asked by root, planner, reviewer, from runCode"),
    Row(agentPath: ["a", "b", "c"], source: nil, visible: "root › a › b › c", accessibility: "Asked by root, a, b, c"),
    Row(
      agentPath: ["a", "b", "c", "d"], source: nil, visible: "root › … › c › d",
      accessibility: "Asked by root, a, b, c, d"),
    Row(
      agentPath: ["a", "b", "c", "d", "e"], source: "runCode", visible: "root › … › d › e · runCode",
      accessibility: "Asked by root, a, b, c, d, e, from runCode"),
    Row(
      agentPath: ["reviewer"], source: nil, rootLabel: "Claude", visible: "Claude › reviewer",
      accessibility: "Asked by Claude, reviewer"),
  ]

  @Test(arguments: rows) func theVisibleTextFollowsTheTable(row: Row) {
    let text = ElicitationHeader.whoAsks(agentPath: row.agentPath, source: row.source, rootLabel: row.rootLabel)

    #expect(text == row.visible)
  }

  @Test(arguments: rows) func theAccessibilityLabelFollowsTheTable(row: Row) {
    let label = ElicitationHeader.whoAsksAccessibilityLabel(
      agentPath: row.agentPath, source: row.source, rootLabel: row.rootLabel)

    #expect(label == row.accessibility)
  }

  @Test func theDefaultRootLabelIsRoot() {
    #expect(EnvironmentValues().elicitationRootAgentLabel == Self.root)
  }

  @Test func theWhoAsksIdentifierHasTheDocumentedForm() {
    #expect(ElicitationView.whoAsksIdentifier == "elicitation-who-asks")
  }

  @Test func theTitleNamesTheServer() {
    #expect(ElicitationHeader.title(server: "The agent") == "The agent asks for input")
  }
}
