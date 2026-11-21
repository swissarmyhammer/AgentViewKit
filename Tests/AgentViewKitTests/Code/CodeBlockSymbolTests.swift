import AppKit
import Testing

@testable import AgentViewKit

/// Tests for the symbol of the header of ``CodeBlockView``: one SF Symbol,
/// the same for each language, in the symbol column (user decision,
/// 2026-11-21).
///
/// The tests read values only, with no view, so no test shows a window or
/// takes the focus.
@MainActor struct CodeBlockSymbolTests {
  @Test func theCodeBlockSymbolExistsOnThisMacOS() {
    #expect(NSImage(systemSymbolName: AgentSymbol.codeBlock, accessibilityDescription: nil) != nil)
  }

  @Test func theVoiceOverLabelOfACodeBlockNamesItsLanguage() {
    let block = CodeBlockView(code: "let x = 1", language: "swift")

    #expect(block.accessibilityLabel == "swift code block")
  }

  @Test func theVoiceOverLabelOfACodeBlockWithNoLanguageIsPlainText() {
    let block = CodeBlockView(code: "let x = 1", language: nil)

    #expect(block.accessibilityLabel == "plain text code block")
  }
}
