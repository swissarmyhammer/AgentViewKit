import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests that the view values that SwiftUI compares have no padding byte
/// (task ^4zzf5cw).
///
/// Until the compare layout of a view type is ready, SwiftUI compares the
/// bytes of the old and the new view value, and it does not call `==` (task
/// ^fzn2beh). A padding byte has no defined value, so two equal values can
/// have different bytes there, and the view then evaluates its body again.
/// Each test lists each stored field of a type. See ``StoredLayout`` for why
/// the check proves that the type has no padding byte.
@Suite @MainActor struct ViewValueLayoutTests {
  // MARK: - AgentTheme

  @Test func theThemeHasNoPaddingByte() {
    StoredLayout<AgentTheme>(\.spacing, \.radii, \.materialLevel, \.symbolWeight, \.density)
      .expectNoPaddingByte()
  }

  @Test func theSpacingStepsHaveNoPaddingByte() {
    StoredLayout<AgentTheme.Spacing>(\.xs, \.s, \.m, \.l).expectNoPaddingByte()
  }

  @Test func theCornerRadiiHaveNoPaddingByte() {
    StoredLayout<AgentTheme.Radii>(\.s, \.m, \.l).expectNoPaddingByte()
  }

  /// `Font.Weight` is a SwiftUI type, so the test cannot name its stored
  /// field. Its mirror shows each stored field.
  @Test func theSymbolWeightIsOneFloatValue() {
    let fieldTypes = Mirror(reflecting: Font.Weight.regular).children.map { type(of: $0.value) }
    #expect(fieldTypes.count == 1)
    #expect(fieldTypes.allSatisfy { $0 == CGFloat.self })
    #expect(MemoryLayout<Font.Weight>.size == MemoryLayout<CGFloat>.size)
  }

  // MARK: - ToolCallBody

  /// `renderer` is the one stored field of a function type.
  @Test func theToolCallBodyHasNoPaddingByte() {
    StoredLayout<ToolCallBody>(\.entry, \.renderer, \.registrationID, \.theme)
      .expectNoPaddingByte(functionFieldCount: 1)
  }

  // MARK: - ParagraphView

  @Test func theParagraphViewHasNoPaddingByte() {
    StoredLayout<ParagraphView>(\.messageID, \.paragraph, \.citations, \.readingGroupID)
      .expectNoPaddingByte()
  }

  @Test func theParagraphHasNoPaddingByte() {
    StoredLayout<ParagraphSplitter.Paragraph>(\.id, \.text).expectNoPaddingByte()
  }

  @Test func theParagraphIDHasNoPaddingByte() {
    StoredLayout<ParagraphSplitter.Paragraph.ID>(\.index, \.textHash).expectNoPaddingByte()
  }

  // MARK: - ItemRow

  /// The one stored field of `ItemRow` is private, so the test compares the
  /// sizes. Each case of `TranscriptEntry` holds one object reference.
  @Test func theItemRowIsOneObjectReference() {
    #expect(MemoryLayout<ItemRow>.size == MemoryLayout<TranscriptEntry>.size)
    #expect(MemoryLayout<TranscriptEntry>.size == MemoryLayout<AnyObject>.size)
  }
}
