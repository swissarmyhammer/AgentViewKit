import Foundation
import Testing

@testable import AgentViewKit

/// Tests that the kit finds its user text in its own string catalog (task
/// ^jnw13v0).
///
/// The kit target holds `Resources/Localizable.xcstrings`, and each
/// localized string of the kit names `bundle: .module`. Thus a host app gets
/// the text of the kit from the kit bundle, and not from its main bundle.
/// `Bundle.module` is internal to the kit, so the suite reaches it through
/// `@testable import`.
///
/// Each lookup has a default value that is not the English text. A lookup
/// that does not find the key in the catalog gives the default value, so the
/// English text comes only from the catalog.
@Suite struct StringCatalogTests {
  /// The table of the compiled catalog.
  static let table = "Localizable"
  /// The localization of the source strings.
  static let sourceLocalization = "en"
  /// A key of the kit without an argument: the title of a message action.
  static let plainKey: StaticString = "Copy Thread"
  /// A key of the kit with two integer arguments: the VoiceOver label of the
  /// header of the request deck.
  static let formatKey: StaticString = "Request %lld of %lld"
  /// The value that a lookup gives when the table has no entry for the key.
  static let missingValue = "<no catalog entry>"

  @Test func theKitBundleHasTheCompiledCatalog() {
    let url = Bundle.module.url(
      forResource: Self.table, withExtension: "strings", subdirectory: nil,
      localization: Self.sourceLocalization)

    #expect(url != nil)
  }

  @Test func theCatalogHasAnEntryForAPlainKey() {
    let key = Self.plainKey.description

    let text = Bundle.module.localizedString(forKey: key, value: Self.missingValue, table: Self.table)

    #expect(text == key)
  }

  /// The English value of a key with more than one argument numbers each
  /// argument, as Xcode writes it.
  @Test func theCatalogHasAnEntryForAFormatKey() {
    let text = Bundle.module.localizedString(
      forKey: Self.formatKey.description, value: Self.missingValue, table: Self.table)

    #expect(text == "Request %1$lld of %2$lld")
  }

  @Test func aLocalizedStringOfTheKitBundleGivesTheEnglishText() {
    let text = String(
      localized: Self.plainKey, defaultValue: String.LocalizationValue(Self.missingValue),
      bundle: .module)

    #expect(text == "Copy Thread")
  }

  @Test func aLocalizedStringWithArgumentsGivesTheEnglishText() {
    let position = 2
    let count = 5

    let text = String(
      localized: Self.formatKey, defaultValue: "<no catalog entry> \(position) \(count)",
      bundle: .module)

    #expect(text == "Request 2 of 5")
  }
}
