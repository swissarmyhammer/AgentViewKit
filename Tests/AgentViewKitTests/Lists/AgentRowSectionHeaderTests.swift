import AppKit
import EditorCommands
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The secondary text of the header of a section of an ``AgentRowList``
/// (``AgentRowSection/detail``, TestudoApp D212).
@MainActor @Suite struct AgentRowSectionHeaderTests {
  /// The scope of the list of the tests.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "headerList"), rowKind: "headerRow")

  /// The size of the hosting view of the tests that read the accessibility
  /// tree.
  static let hostSize = CGSize(width: 320, height: 200)

  /// The accessibility role of a heading.
  static let headingRole = "AXHeading"

  /// A section with a detail, as the index shows it while it reads the files
  /// of a folder.
  static let reading = AgentRowSection(
    id: "other", title: "Other Agents", items: ["first", "second"],
    detail: "Reading 1,240 of 4,427")

  /// A section with no detail.
  static let recent = AgentRowSection(id: "recent", title: "Recent", items: ["third"])

  /// A production change that fails this test: `entries(of:id:)` drops the
  /// detail of the section from its header entry.
  @Test func theHeaderEntryCarriesTheDetailOfItsSection() {
    let entries = AgentRowListEntry.entries(of: [Self.reading], id: \.self)

    #expect(entries.first.map(Self.headerDetail(of:)) == .some(.some("Reading 1,240 of 4,427")))
  }

  /// A production change that fails this test: a section with no detail
  /// gives its header a detail.
  @Test func aSectionWithNoDetailGivesAHeaderWithNoDetail() {
    let entries = AgentRowListEntry.entries(of: [Self.recent], id: \.self)

    #expect(entries.first.map(Self.headerDetail(of:)) == .some(.some(nil)))
  }

  /// A production change that fails this test: the header reads the title
  /// alone, or reads the title and the detail as two elements.
  @Test func theHeaderReadsItsTitleAndItsDetail() async {
    let label = await Self.headerLabel(of: Self.reading)

    #expect(label == "Other Agents, Reading 1,240 of 4,427")
  }

  /// A production change that fails this test: a header with no detail
  /// reads more than its title.
  @Test func aHeaderWithNoDetailReadsItsTitle() async {
    let label = await Self.headerLabel(of: Self.recent)

    #expect(label == "Recent")
  }

  /// A production change that fails this test: the one element of a header
  /// with a detail loses the trait of a heading.
  @Test func aHeaderWithADetailIsAHeading() async {
    let role = await Self.headerRole(of: Self.reading)

    #expect(role == Self.headingRole)
  }

  /// The detail of a header entry.
  ///
  /// - Parameter entry: An entry of a list.
  /// - Returns: The detail of a header entry (which can be `nil`), or `nil`
  ///   for a row entry.
  static func headerDetail(of entry: AgentRowListEntry<String>) -> String?? {
    switch entry {
    case .header(_, _, let detail): .some(detail)
    case .row: nil
    }
  }

  /// The accessibility label of the header of `section`.
  ///
  /// - Parameter section: The section of the list.
  /// - Returns: The label, or `nil` when no single element has the
  ///   identifier of the header, or the element has no label.
  static func headerLabel(of section: AgentRowSection<String>) async -> String? {
    await headerElement(of: section, read: accessibilityLabel(of:))
  }

  /// The accessibility role of the header of `section`.
  ///
  /// - Parameter section: The section of the list.
  /// - Returns: The role, or `nil` when no single element has the identifier
  ///   of the header, or the element has no role.
  static func headerRole(of section: AgentRowSection<String>) async -> String? {
    await headerElement(of: section, read: accessibilityRole(of:))
  }

  /// Reads the header element of `section` from a hosting view with no
  /// window, so the test shows no window and takes no focus.
  ///
  /// - Parameters:
  ///   - section: The section of the list. The list holds this section only.
  ///   - read: The read of the element.
  /// - Returns: The result of `read`, or `nil` when no single element has the
  ///   identifier of the header.
  static func headerElement(
    of section: AgentRowSection<String>, read: @escaping @MainActor (NSObject) -> String?
  ) async -> String? {
    let list = AgentRowList(sections: [section], id: \.self, scope: scope) { id in
      Text(verbatim: id)
    }
    let hosting = NSHostingView(
      rootView: list.frame(width: hostSize.width, height: hostSize.height))
    hosting.frame = NSRect(origin: .zero, size: hostSize)
    hosting.layoutSubtreeIfNeeded()
    return await withAccessibilityTree {
      let elements = accessibilityElements(
        identifiedAs: AgentRowSectionHeader.identifier(for: section.id), under: hosting,
        includingScrollAreas: true)
      return elements.count == 1 ? elements.first.flatMap(read) : nil
    }
  }
}
