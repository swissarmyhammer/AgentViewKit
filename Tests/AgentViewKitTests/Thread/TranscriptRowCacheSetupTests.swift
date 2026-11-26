import EditorTheme
import Foundation
import Testing

@testable import AgentViewKit

/// The values of the environment of the rows that set the height cache of a
/// thread (``TranscriptRowCacheSetup``, card ^9ync5h3). A change of one value
/// makes a new cache.
@MainActor @Suite struct TranscriptRowCacheSetupTests {
  /// One identity, which stands for a store or a session.
  nonisolated static let first = ObjectIdentifier(NSObject.self)

  /// A second identity.
  nonisolated static let second = ObjectIdentifier(NSString.self)

  /// A setup with the system faces, the first store, the first session and
  /// the default look.
  nonisolated static let base = TranscriptRowCacheSetup(
    faces: [.system], expandedBlocks: first, session: first,
    hasDefaultLook: true)

  /// The setups that differ from ``base`` in one value each: the faces, the
  /// store, the session and the look.
  nonisolated static let changed: [TranscriptRowCacheSetup] = [
    TranscriptRowCacheSetup(
      faces: [.monospaced], expandedBlocks: base.expandedBlocks, session: base.session,
      hasDefaultLook: base.hasDefaultLook),
    TranscriptRowCacheSetup(
      faces: base.faces, expandedBlocks: second, session: base.session,
      hasDefaultLook: base.hasDefaultLook),
    TranscriptRowCacheSetup(
      faces: base.faces, expandedBlocks: base.expandedBlocks, session: second,
      hasDefaultLook: base.hasDefaultLook),
    TranscriptRowCacheSetup(
      faces: base.faces, expandedBlocks: base.expandedBlocks, session: base.session, hasDefaultLook: false),
  ]

  /// A production change that fails this test: the comparison ignores one
  /// value, so a change of that value keeps the old cache.
  @Test(arguments: changed) func aChangeOfOneValueGivesAnotherSetup(setup: TranscriptRowCacheSetup) {
    #expect(setup != Self.base)
  }

  /// A production change that fails this test: two setups with the same
  /// values differ, so each evaluation of the rows makes a new cache.
  @Test func theSameValuesGiveTheSameSetup() {
    let copy = TranscriptRowCacheSetup(
      faces: Self.base.faces, expandedBlocks: Self.base.expandedBlocks, session: Self.base.session,
      hasDefaultLook: Self.base.hasDefaultLook)

    #expect(copy == Self.base)
  }
}
