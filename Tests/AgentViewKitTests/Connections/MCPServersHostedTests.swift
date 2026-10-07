import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACPClient
import SwiftUI
import Testing

/// ``ConnectionsView`` over the `mcpServers` of a `SessionModel`.
///
/// The scripted agent reports two MCP servers with `_mcp_server_status`
/// session updates, then changes the status of one server. The view reads
/// the list of the client model directly. No test sets a kit store.
@Suite(.serialized, .hostedSerially) @MainActor struct MCPServersHostedTests {
  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The name of the HTTP server. The agent reports it first.
  static let webName = "web"

  /// The name of the stdio server. The agent reports it second.
  static let filesName = "files"

  /// The reason of the failed status of the stdio server.
  static let failureReason = "The server process exited with code 1."

  /// The number of servers that the agent reports.
  static let serverCount = 2

  /// The wire value of the stdio transport.
  static let stdioTransport = "stdio"

  /// The wire value of the HTTP transport.
  static let httpTransport = "http"

  /// Makes the JSON text of one `_mcp_server_status` session update.
  ///
  /// - Parameters:
  ///   - name: The name of the server.
  ///   - transport: The wire value of the transport: `stdio` or `http`.
  ///   - status: The wire value of the status.
  ///   - reason: The reason of a `failed` status, or `nil` for no reason.
  /// - Returns: The JSON text of the update.
  static func makeStatusUpdate(
    name: String, transport: String, status: String, reason: String? = nil
  ) -> String {
    let reasonMember = reason.map { #","reason":"\#($0)""# } ?? ""
    return #"""
      {"sessionUpdate":"_mcp_server_status","name":"\#(name)","transport":"\#(transport)",\#
      "origin":"client","status":"\#(status)"\#(reasonMember)}
      """#
  }

  /// Opens a scripted session whose agent reports the HTTP server `web` as
  /// connecting, then the stdio server `files` as connected.
  ///
  /// - Returns: The session, with two items in `mcpServers`.
  /// - Throws: The error of `initialize`, of `session/new` or of the
  ///   transport.
  static func openSessionWithTwoServers() async throws -> ScriptedSession {
    let session = try await ScriptedSession.open()
    try await session.sendUpdate(makeStatusUpdate(name: webName, transport: httpTransport, status: "connecting"))
    try await session.sendUpdate(makeStatusUpdate(name: filesName, transport: stdioTransport, status: "connected"))
    let model = session.model
    let reported = await waitUntil { model.mcpServers.count == serverCount }
    #expect(reported, "The model did not get the two servers.")
    return session
  }

  /// Shows a ``ConnectionsView`` with only the session model in the
  /// environment.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The harness.
  static func mount(session: ScriptedSession) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: ConnectionsViewHostedTests.listSize) {
      ConnectionsView()
        .environment(\.sessionModel, session.model)
    }
    harness.pump()
    return harness
  }

  /// The accessibility identifiers of the rows, in the order of the view.
  ///
  /// - Parameter harness: The harness of the view.
  /// - Returns: The row identifiers.
  static func rowIdentifiers(in harness: HostedViewHarness<some View>) -> [String] {
    harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(ConnectionRow.identifierPrefix)
    }
  }

  /// The status chip in the row of a server.
  ///
  /// The harness gives the elements in depth-first order. Thus the chip of
  /// a row comes after the row element and before the next row element.
  ///
  /// - Parameters:
  ///   - name: The name of the server.
  ///   - harness: The harness of the view.
  /// - Returns: The chip, or `nil` when the row or its chip is absent.
  static func chip(inRowOf name: String, in harness: HostedViewHarness<some View>)
    -> AccessibilityElementSnapshot?
  {
    let elements = harness.accessibilityElements()
    let rowIdentifier = ConnectionRow.identifier(for: name)
    return elements.firstIndex { $0.identifier == rowIdentifier }.flatMap { rowIndex in
      let rest = elements[(rowIndex + 1)...]
      let end =
        rest.firstIndex { $0.identifier?.hasPrefix(ConnectionRow.identifierPrefix) == true }
        ?? rest.endIndex
      return rest[..<end].first { $0.identifier?.hasPrefix(ConnectionStatusChip.identifierPrefix) == true }
    }
  }

  @Test func theViewShowsTheServersOfTheClientModel() async throws {
    let session = try await Self.openSessionWithTwoServers()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    #expect(harness.element(identifier: ConnectionsView.emptyIdentifier) == nil)
    #expect(
      Set(Self.rowIdentifiers(in: harness)) == [
        ConnectionRow.identifier(for: Self.webName), ConnectionRow.identifier(for: Self.filesName),
      ])
  }

  @Test func aFailedStatusShowsInTheChipOfItsRowWithTheReason() async throws {
    let session = try await Self.openSessionWithTwoServers()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }
    let connected = ConnectionStatusChip.identifier(for: .connected)
    #expect(Self.chip(inRowOf: Self.filesName, in: harness)?.identifier == connected)

    try await session.sendUpdate(
      Self.makeStatusUpdate(
        name: Self.filesName, transport: Self.stdioTransport, status: "failed", reason: Self.failureReason))
    let failed = ConnectionStatusChip.identifier(for: .failed(reason: nil))
    await harness.pump(until: Self.waitTimeout) {
      Self.chip(inRowOf: Self.filesName, in: harness)?.identifier == failed
    }

    let chip = try #require(Self.chip(inRowOf: Self.filesName, in: harness))
    #expect(chip.identifier == failed)
    #expect(chip.label == "Failed")
    #expect(chip.value == Self.failureReason)
    let webChip = Self.chip(inRowOf: Self.webName, in: harness)
    #expect(webChip?.identifier == ConnectionStatusChip.identifier(for: .connecting))
  }

  @Test func theRowsShowTheNamesAndTheTransportsInTheOrderOfTheList() async throws {
    let session = try await Self.openSessionWithTwoServers()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }
    let names = [Self.webName, Self.filesName]

    #expect(session.model.mcpServers.map(\.name) == names)
    #expect(Self.rowIdentifiers(in: harness) == names.map(ConnectionRow.identifier(for:)))
    #expect(names.map { harness.element(identifier: ConnectionRow.identifier(for: $0))?.label } == names)
    let transports = names.map { harness.element(identifier: ConnectionRow.transportIdentifier(for: $0))?.label }
    #expect(transports == ["HTTP", "stdio"])
  }
}
