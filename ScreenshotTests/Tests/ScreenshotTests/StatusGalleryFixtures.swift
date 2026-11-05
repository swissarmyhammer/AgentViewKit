@testable import AgentViewKit
import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The status images of the review gallery (^0cqh945): each view of the kit
/// that shows a status, in each status, drawn with EditorKit's status token
/// (`EditorStatus`).
///
/// The tool calls, the plan and the compactions are the real rows of the
/// kit. The send state of a user message, the status of an MCP server and the
/// state of a connection are the `EditorStatusLabel` that their row and
/// their inspector row draw, because a code-built session model holds no
/// user message in another send state, no server and no connection state.
@MainActor
enum StatusGalleryFixtures {
  /// The width of the status image, in points.
  static let width: CGFloat = 520

  /// The height of the status image, in points.
  static let height: CGFloat = 1260

  /// The size of the status image.
  static let size = CGSize(width: width, height: height)

  /// The accessibility identifier of each status label of the image.
  static let labelIdentifier = "gallery-status"

  /// The reason of the failed MCP server and the failed connection.
  static let failureReason = "The server process exited with code 1."

  /// The id of each compaction of the image.
  static let compactionID = CompactionId(rawValue: "gallery-compaction")

  /// The summary that each compaction keeps.
  static let compactionSummary = "The user asked why the build fails."

  /// Each status of a compaction: each status of the ACP standard and a
  /// status that the kit does not know.
  static let compactionStatuses: [CompactionStatus] = [
    .inProgress, .completed, .failed, .cancelled, .unknown(PreviewFixtures.unknownWireValue),
  ]

  /// Each send state of a user message.
  static let sendStates: [SendState] = [.pending, .sent, .failed]

  /// Each status of an MCP server, with a reason for the failed status.
  static let serverStatuses: [MCPServerStatus] = [
    .notReported, .connecting, .connected, .failed(reason: failureReason), .closed,
  ]

  /// Each state of a connection, with an error for the failed state.
  static let connectionStates: [ConnectionState] = [
    .disconnected, .connecting, .connected, .failed(ConnectionError.closed),
  ]

  /// The tool call row of each status of ``PreviewFixtures/toolCallStatuses``.
  static var toolCalls: [ToolCallEntry] {
    PreviewFixtures.toolCallStatuses.compactMap { status in
      PreviewFixtures.entry(
        .toolCall(title: "Read Package.swift (\(status.wireValue))", kind: .read, status: status),
        as: ToolCallEntry.self)
    }
  }

  /// A plan with one step in each status of
  /// ``PreviewFixtures/planEntryStatuses``.
  static var plan: PlanTranscriptEntry? {
    let steps = PreviewFixtures.planEntryStatuses.map { status in
      PlanEntry(content: "Step \(status.wireValue)", priority: .medium, status: status)
    }
    return PreviewFixtures.entry(.plan(steps), as: PlanTranscriptEntry.self)
  }

  /// The compaction row of each status of ``compactionStatuses``.
  static var compactions: [CompactionEntry] {
    compactionStatuses.compactMap { status in
      let update = CompactionUpdate(
        compactionId: compactionID, status: status,
        summary: .value([.text(TextContent(text: compactionSummary))]))
      return PreviewFixtures.entry(.update(.compactionUpdate(update)), as: CompactionEntry.self)
    }
  }

  /// The image: a section for each view that shows a status.
  static var gallery: some View {
    StatusGallery()
  }
}

/// The sections of the status image, one for each view that shows a status.
private struct StatusGallery: View {
  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.l) {
      section("Tool calls") {
        // Each entry comes from a session of its own, so two entries can
        // share an id: the position is the identity of the row.
        ForEach(Array(StatusGalleryFixtures.toolCalls.enumerated()), id: \.offset) {
          ToolCallView(entry: $0.element)
        }
      }
      section("Plan") {
        if let plan = StatusGalleryFixtures.plan { TaskListView(entry: plan) }
      }
      section("Compactions") {
        ForEach(Array(StatusGalleryFixtures.compactions.enumerated()), id: \.offset) {
          CompactionEntryView(entry: $0.element)
        }
      }
      section("Unreported compaction, send states, MCP servers and connections") {
        labels([EditorStatus(SessionEntry.Compaction.unreportedStatus)])
        labels(StatusGalleryFixtures.sendStates.map(EditorStatus.init))
        labels(StatusGalleryFixtures.serverStatuses.map(EditorStatus.init))
        labels(StatusGalleryFixtures.connectionStates.map(EditorStatus.init))
      }
    }
    .padding(editorStyle.tile.margin)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  /// One section: a caption, then its views.
  ///
  /// - Parameters:
  ///   - title: The caption of the section.
  ///   - content: The views of the section.
  /// - Returns: The section.
  private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.s) {
      Text(title).font(editorTheme.font(for: .ui, style: .headline))
      content()
    }
  }

  /// One line of status labels, each the ``StatusCaption`` that its row
  /// draws.
  ///
  /// - Parameter statuses: The statuses of the line.
  /// - Returns: The line.
  private func labels(_ statuses: [EditorStatus]) -> some View {
    HStack(spacing: editorStyle.spacing.m) {
      ForEach(statuses, id: \.self) {
        StatusCaption(status: $0, identifier: StatusGalleryFixtures.labelIdentifier)
      }
    }
  }
}
