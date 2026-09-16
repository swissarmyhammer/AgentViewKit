import AgentViewKit
import AgentViewKitRouter
import Foundation
import FoundationModels
import FoundationModelsRouter
import Testing

/// The id of each segment that the tests make.
private let segmentID = "segment-1"

/// One value of each catalog payload.
private enum Samples {
  static let approval = ApprovalPayload(
    id: "approval-1", title: "Delete the build folder", description: "The agent wants to delete `.build`.",
    options: ["Allow", "Deny"])

  static let plan = PlanPayload(
    id: "plan-1",
    entries: [
      PlanEntry(content: "Read the file", priority: .high, status: .completed),
      PlanEntry(content: "Ship it", priority: .unknown("urgent"), status: .unknown("blocked")),
    ])

  static let citation = CitationPayload(
    sources: [
      CitationSource(
        id: "source-1", title: "Swift Book", url: URL(string: "https://docs.swift.org/book")!,
        snippet: "Swift is a language.")
    ],
    markers: [CitationMarker(sourceID: "source-1", paragraphIndex: 0, offset: 12)])

  static let artifact = ArtifactPayload(
    id: "artifact-1", title: "Report", type: "public.plain-text",
    url: URL(string: "file:///tmp/report.txt")!, inlineText: "The report text.")

  static let authorization = AuthorizationPayload(
    id: "auth-1", serverName: "GitHub", scopes: ["repo"],
    authorizationURL: URL(string: "https://github.com/login/oauth/authorize")!, elicitationId: "elicitation-7"
  )

  static let usage = UsagePayload(
    ContextUsage(
      used: 1_200, size: 8_000, cost: .init(amount: 0.25, currency: "USD"),
      input: .init(total: 900, cached: 100), output: .init(total: 300, reasoning: 50),
      quota: .belowLimit(approaching: true)))
}

/// Sends a payload through a structured segment and back.
///
/// - Parameter payload: The payload.
/// - Returns: The segment that the structured segment gives back.
private func roundTrip<Payload: StructuredPayload>(_ payload: Payload) throws -> CatalogSegment<Payload>? {
  let segment = try payload.routerSegment(id: segmentID).structuredSegment()
  #expect(segment.schemaName == Payload.schemaName)
  #expect(segment.id == segmentID)
  return try CatalogSegment<Payload>(structuredSegment: segment)
}

/// Sends a payload through the persisted form of a Router segment and back.
///
/// The Router records a structured segment as `SegmentPayload.structure`
/// with its id, its schema name, and its JSON body.
///
/// - Parameter payload: The payload.
/// - Returns: The segment that the persisted form gives back.
private func persistedRoundTrip<Payload: StructuredPayload>(_ payload: Payload) throws -> CatalogSegment<
  Payload
>? {
  let segment = try payload.routerSegment(id: segmentID).structuredSegment()
  let recorded = SegmentPayload.structure(
    id: segment.id, schemaName: segment.schemaName, contentJSON: segment.content.jsonString)
  let line = try JSONEncoder().encode(recorded)
  guard
    case .structure(let id, let schemaName, let contentJSON) = try JSONDecoder().decode(
      SegmentPayload.self, from: line)
  else { return nil }
  let restored = Transcript.StructuredSegment(
    id: id, schemaName: schemaName, content: try GeneratedContent(json: contentJSON))
  return try CatalogSegment<Payload>(structuredSegment: restored)
}

/// Round trips for each catalog payload.
@Suite struct CatalogRouterTests {
  @Test func approvalRoundTrips() throws {
    #expect(try roundTrip(Samples.approval)?.content == Samples.approval)
    #expect(try persistedRoundTrip(Samples.approval)?.content == Samples.approval)
  }

  @Test func planRoundTrips() throws {
    #expect(try roundTrip(Samples.plan)?.content == Samples.plan)
    #expect(try persistedRoundTrip(Samples.plan)?.content == Samples.plan)
  }

  @Test func citationRoundTrips() throws {
    #expect(try roundTrip(Samples.citation)?.content == Samples.citation)
    #expect(try persistedRoundTrip(Samples.citation)?.content == Samples.citation)
  }

  @Test func artifactRoundTrips() throws {
    #expect(try roundTrip(Samples.artifact)?.content == Samples.artifact)
    #expect(try persistedRoundTrip(Samples.artifact)?.content == Samples.artifact)
  }

  @Test func authorizationRoundTrips() throws {
    #expect(try roundTrip(Samples.authorization)?.content == Samples.authorization)
    #expect(try persistedRoundTrip(Samples.authorization)?.content == Samples.authorization)
  }

  @Test func usageRoundTrips() throws {
    #expect(try roundTrip(Samples.usage)?.content == Samples.usage)
    #expect(try persistedRoundTrip(Samples.usage)?.content == Samples.usage)
  }

  @Test func eachSegmentTypeUsesTheCatalogName() {
    #expect(ApprovalSegment.schemaName == "AgentViewKit.ApprovalPayload")
    #expect(PlanSegment.schemaName == "AgentViewKit.PlanPayload")
    #expect(CitationSegment.schemaName == "AgentViewKit.CitationPayload")
    #expect(ArtifactSegment.schemaName == "AgentViewKit.ArtifactPayload")
    #expect(AuthorizationSegment.schemaName == "AgentViewKit.AuthorizationPayload")
    #expect(UsageSegment.schemaName == "AgentViewKit.UsagePayload")
  }

  @Test func aSegmentOfAnotherTypeGivesNil() throws {
    let segment = try Samples.approval.routerSegment(id: segmentID).structuredSegment()
    #expect(try PlanSegment(structuredSegment: segment) == nil)
  }

  @Test func aBodyThatDoesNotDecodeThrows() throws {
    let segment = Transcript.StructuredSegment(
      id: segmentID, schemaName: PlanSegment.schemaName, content: try GeneratedContent(json: #"{"id": 1}"#))
    #expect(throws: DecodingError.self) {
      try PlanSegment(structuredSegment: segment)
    }
  }
}
