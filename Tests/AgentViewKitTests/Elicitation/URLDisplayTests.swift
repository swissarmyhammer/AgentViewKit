import AgentViewKit
import Foundation
import Testing

/// Tests of ``URLDisplay``.
@Suite struct URLDisplayTests {
  /// The text of each run of `text` that has the strongly emphasized
  /// presentation intent.
  static func boldRuns(_ text: AttributedString) -> [String] {
    text.runs.compactMap { run in
      guard run.inlinePresentationIntent == .stronglyEmphasized else { return nil }
      return String(text[run.range].characters)
    }
  }

  /// Makes a URL from a literal.
  static func url(_ string: String) throws -> URL {
    try #require(URL(string: string))
  }

  // MARK: - Highlight

  @Test func theHighlightIsTheFullURLWithTheHostInBold() throws {
    let url = try Self.url("https://login.example.com:8443/path?q=1#top")
    let text = URLDisplay.highlighted(url)

    #expect(String(text.characters) == url.absoluteString)
    #expect(Self.boldRuns(text) == ["login.example.com"])
  }

  @Test func theHighlightFindsTheHostAfterTheUserInfo() throws {
    let url = try Self.url("https://example.com@evil.test/login")
    let text = URLDisplay.highlighted(url)

    #expect(String(text.characters) == url.absoluteString)
    #expect(Self.boldRuns(text) == ["evil.test"])
  }

  @Test func aURLWithNoHostHasNoBoldText() throws {
    let url = try Self.url("mailto:someone@example.com")
    let text = URLDisplay.highlighted(url)

    #expect(String(text.characters) == url.absoluteString)
    #expect(Self.boldRuns(text).isEmpty)
  }

  // MARK: - Warning

  @Test func anASCIIHostHasNoWarning() throws {
    #expect(URLDisplay.warning(for: try Self.url("https://example.com/continue")) == nil)
    #expect(URLDisplay.warning(forHost: "a-1.example.co.uk") == nil)
  }

  @Test func aPunycodeHostHasAWarning() throws {
    let warning = URLDisplay.warning(for: try Self.url("https://xn--pple-43d.com/login"))

    #expect(warning?.contains("Punycode") == true)
    #expect(URLDisplay.warning(forHost: "login.XN--pple-43d.com")?.contains("Punycode") == true)
  }

  @Test func aHostWithLettersOfTwoScriptsHasAWarning() {
    // The first letter is the Cyrillic small letter a.
    let warning = URLDisplay.warning(forHost: "\u{0430}pple.com")

    #expect(warning?.contains("more than one alphabet") == true)
  }

  @Test func aHostWithLettersOfOneScriptHasNoWarning() {
    #expect(URLDisplay.warning(forHost: "пример.рф") == nil)
    #expect(URLDisplay.warning(forHost: "bücher.de") == nil)
  }

  @Test func aURLWithNoHostHasNoWarning() throws {
    #expect(URLDisplay.warning(for: try Self.url("mailto:someone@example.com")) == nil)
  }
}
