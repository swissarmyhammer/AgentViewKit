import AgentViewKit
import Foundation
import PackageFileSupport
import Testing

@Suite struct StructuredCatalogTests {
  // MARK: - Fixtures

  private static let approval = ApprovalPayload(
    id: "approval-1",
    title: "Delete the build folder",
    description: "The agent wants to delete `.build`.",
    options: ["Allow", "Deny"]
  )

  private static let plan = PlanPayload(
    id: "plan-1",
    entries: [
      PlanEntry(content: "Read the file", priority: .high, status: .completed),
      PlanEntry(content: "Write the test", priority: .medium, status: .inProgress),
      PlanEntry(content: "Ship it", priority: .unknown("urgent"), status: .unknown("blocked")),
    ]
  )

  private static let citation = CitationPayload(
    sources: [
      CitationSource(
        id: "source-1",
        title: "Swift Book",
        url: URL(string: "https://docs.swift.org/book")!,
        snippet: "Swift is a language.",
        iconURL: URL(string: "https://docs.swift.org/favicon.ico")!
      ),
      CitationSource(
        id: "source-2",
        title: "No icon",
        url: URL(string: "https://example.com")!,
        snippet: ""
      ),
    ],
    markers: [
      CitationMarker(sourceID: "source-1", paragraphIndex: 0, offset: 12),
      CitationMarker(sourceID: "source-2", paragraphIndex: 3, offset: 0),
    ]
  )

  private static let artifact = ArtifactPayload(
    id: "artifact-1",
    title: "Report",
    type: "public.plain-text",
    url: URL(string: "file:///tmp/report.txt")!,
    inlineText: "The report text."
  )

  private static let authorization = AuthorizationPayload(
    id: "auth-1",
    serverName: "GitHub",
    scopes: ["repo", "read:user"],
    authorizationURL: URL(string: "https://github.com/login/oauth/authorize")!,
    elicitationId: "elicitation-7"
  )

  private static let usage = UsagePayload(
    ContextUsage(
      used: 1_200,
      size: 8_000,
      cost: .init(amount: 0.25, currency: "USD"),
      input: .init(total: 900, cached: 100),
      output: .init(total: 300, reasoning: 50),
      quota: .belowLimit(approaching: true)
    )
  )

  /// One value of each payload that the standard catalog registers.
  private static let samples: [any StructuredPayload] = [
    approval, plan, citation, artifact, authorization, usage,
  ]

  // MARK: - Round trip

  /// Encodes `payload` to JSON and decodes it again as the same type.
  private static func roundTrip<Payload: StructuredPayload>(_ payload: Payload) throws -> Payload {
    let data = try JSONEncoder().encode(payload)
    return try JSONDecoder().decode(Payload.self, from: data)
  }

  @Test func approvalRoundTrips() throws {
    #expect(try Self.roundTrip(Self.approval) == Self.approval)
  }

  @Test func planRoundTripsWithUnknownWireValues() throws {
    #expect(try Self.roundTrip(Self.plan) == Self.plan)
  }

  @Test func planEntryUsesTheWireStrings() throws {
    let value = try JSONValue(json: String(decoding: try JSONEncoder().encode(Self.plan), as: UTF8.self))
    guard case .object(let object) = value, case .array(let entries) = object["entries"],
      case .object(let second) = entries[1]
    else {
      Issue.record("The plan payload is not an object with an entry array.")
      return
    }

    #expect(second["status"] == .string("in_progress"))
    #expect(second["priority"] == .string("medium"))
  }

  @Test func citationRoundTrips() throws {
    #expect(try Self.roundTrip(Self.citation) == Self.citation)
  }

  @Test func artifactRoundTrips() throws {
    #expect(try Self.roundTrip(Self.artifact) == Self.artifact)
  }

  @Test func artifactWithoutOptionalFieldsRoundTrips() throws {
    let artifact = ArtifactPayload(id: "a", title: "b", type: "public.data")

    #expect(try Self.roundTrip(artifact) == artifact)
  }

  @Test func authorizationRoundTrips() throws {
    #expect(try Self.roundTrip(Self.authorization) == Self.authorization)
  }

  @Test func usageRoundTrips() throws {
    #expect(try Self.roundTrip(Self.usage) == Self.usage)
  }

  @Test func usageWithLimitReachedAndNoPartsRoundTrips() throws {
    let usage = UsagePayload(ContextUsage(used: 1, size: 2, quota: .limitReached))

    #expect(try Self.roundTrip(usage) == usage)
    #expect(try Self.roundTrip(UsagePayload(ContextUsage(used: 1, size: 2))).usage == ContextUsage(used: 1, size: 2))
  }

  @Test func usageKeepsEveryContextUsageField() {
    #expect(Self.usage.usage == ContextUsage(
      used: 1_200,
      size: 8_000,
      cost: .init(amount: 0.25, currency: "USD"),
      input: .init(total: 900, cached: 100),
      output: .init(total: 300, reasoning: 50),
      quota: .belowLimit(approaching: true)
    ))
  }

  @Test func anUnknownQuotaStatusThrows() {
    let json = #"{"used":1,"size":2,"quota":{"status":"somethingNew"}}"#

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(UsagePayload.self, from: Data(json.utf8))
    }
  }

  // MARK: - Catalog decode

  @Test func schemaNamesAreTheFullTypeNames() {
    #expect(ApprovalPayload.schemaName == "AgentViewKit.ApprovalPayload")
    #expect(PlanPayload.schemaName == "AgentViewKit.PlanPayload")
    #expect(CitationPayload.schemaName == "AgentViewKit.CitationPayload")
    #expect(ArtifactPayload.schemaName == "AgentViewKit.ArtifactPayload")
    #expect(AuthorizationPayload.schemaName == "AgentViewKit.AuthorizationPayload")
    #expect(UsagePayload.schemaName == "AgentViewKit.UsagePayload")
  }

  @Test func theStandardCatalogRegistersEveryPayload() {
    let expected = Self.samples.map { type(of: $0).schemaName }

    #expect(StructuredCatalog.standard.schemaNames == expected.sorted())
  }

  @Test func decodeReturnsTheTypedPayloadForEveryRegisteredName() throws {
    for sample in Self.samples {
      let name = type(of: sample).schemaName
      let content = try sample.jsonValue()

      let decoded = try StructuredCatalog.standard.decode(schemaName: name, content: content)

      #expect(decoded.map { $0.isEqual(to: sample) } == true, "\(name) did not decode to the same value.")
    }
  }

  @Test func decodeOfAnUnknownNameReturnsNil() throws {
    let decoded = try StructuredCatalog.standard.decode(
      schemaName: "AgentViewKit.Chart",
      content: .object(["anything": .null])
    )

    #expect(decoded == nil)
  }

  @Test func decodeOfAnUnknownNameNeverThrows() {
    #expect(throws: Never.self) {
      _ = try StructuredCatalog.standard.decode(schemaName: "", content: .string("not an object"))
    }
  }

  @Test func decodeOfBadContentForAKnownNameThrows() {
    #expect(throws: DecodingError.self) {
      _ = try StructuredCatalog.standard.decode(
        schemaName: ApprovalPayload.schemaName,
        content: .object(["id": .number(3)])
      )
    }
  }

  @Test func anEmptyCatalogKnowsNoName() throws {
    let catalog = StructuredCatalog(payloadTypes: [])

    #expect(catalog.schemaNames.isEmpty)
    #expect(try catalog.decode(schemaName: ApprovalPayload.schemaName, content: .object([:])) == nil)
  }

  @Test func registerAddsAName() throws {
    var catalog = StructuredCatalog(payloadTypes: [])
    catalog.register(ApprovalPayload.self)

    #expect(catalog.schemaNames == [ApprovalPayload.schemaName])
    let decoded = try catalog.decode(
      schemaName: ApprovalPayload.schemaName,
      content: try Self.approval.jsonValue()
    )
    #expect(decoded as? ApprovalPayload == Self.approval)
  }

  // MARK: - Catalog document

  /// The catalog document, relative to the package root.
  private static let documentPath = "Sources/AgentViewKit/Catalog/catalog.md"

  /// The stored property names of each type that the document describes,
  /// keyed by the heading of the section of that type.
  private static let documentedTypes: [String: [String]] = {
    var result: [String: [String]] = [:]
    for sample in samples {
      result[type(of: sample).schemaName] = labels(of: sample)
    }
    result["CitationSource"] = labels(of: citation.sources[0])
    result["CitationMarker"] = labels(of: citation.markers[0])
    result["PlanEntry"] = labels(of: plan.entries[0])
    result["ContextUsage.Cost"] = labels(of: ContextUsage.Cost(amount: 0, currency: ""))
    result["ContextUsage.Input"] = labels(of: ContextUsage.Input(total: 0, cached: 0))
    result["ContextUsage.Output"] = labels(of: ContextUsage.Output(total: 0, reasoning: 0))
    return result
  }()

  /// The stored property names of `value`, in declaration order.
  private static func labels(of value: Any) -> [String] {
    Mirror(reflecting: value).children.compactMap(\.label)
  }

  @Test func theDocumentNamesEveryRegisteredSchemaName() throws {
    let sections = try CatalogDocument.sections(in: PackageFiles.text(of: Self.documentPath))
    let documentedNames = Set(sections.keys.filter { $0.hasPrefix("AgentViewKit.") })

    #expect(documentedNames == Set(StructuredCatalog.standard.schemaNames))
  }

  @Test func theDocumentListsEveryStoredPropertyOfEveryType() throws {
    let sections = try CatalogDocument.sections(in: PackageFiles.text(of: Self.documentPath))

    #expect(Set(sections.keys) == Set(Self.documentedTypes.keys))
    for (heading, properties) in Self.documentedTypes {
      #expect(
        sections[heading] == properties,
        "The fields of `\(heading)` in catalog.md are \(sections[heading] ?? []), not \(properties)."
      )
    }
  }
}

/// Parses the type sections of the catalog document.
///
/// A section starts with a level 2 heading that holds a type name in
/// backticks. The first cell of each body row of the first table in the
/// section is a field name in backticks.
private enum CatalogDocument {
  /// The prefix of a section heading.
  private static let headingPrefix = "## "

  /// The number of lines from the header row to the first body row: the
  /// header row and the separator row.
  private static let linesBeforeBody = 2

  /// The field names of each section, keyed by the heading text.
  ///
  /// - Parameter text: The Markdown text.
  /// - Returns: The field names of each section, in file order.
  static func sections(in text: String) -> [String: [String]] {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespaces) }
    var result: [String: [String]] = [:]
    for (index, line) in lines.enumerated() where line.hasPrefix(headingPrefix) {
      let heading = unquoted(line.dropFirst(headingPrefix.count))
      let rest = lines[(index + 1)...].prefix { !$0.hasPrefix(headingPrefix) }
      guard let tableStart = rest.firstIndex(where: { $0.hasPrefix("|") }) else {
        result[heading] = []
        continue
      }
      let bodyStart = tableStart + linesBeforeBody
      guard bodyStart <= rest.endIndex else {
        result[heading] = []
        continue
      }
      result[heading] = rest[bodyStart...]
        .prefix { $0.hasPrefix("|") }
        .map { row in
          unquoted(row.split(separator: "|", omittingEmptySubsequences: false).dropFirst().first ?? "")
        }
    }
    return result
  }

  /// The text without surrounding white space and backticks.
  private static func unquoted(_ text: Substring) -> String {
    text.trimmingCharacters(in: CharacterSet.whitespaces.union(["`"]))
  }
}
