import EditorSwiftUI
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The text that the kit renders from its Stencil templates: the Markdown
/// export, the copy text and the plan steps of the inspector.
///
/// Each site keeps its text for the English locale of the United States
/// (characterization), and an edit of its template changes the text with no
/// change of code.
@Suite @MainActor struct TemplateTextTests {
  /// The locale of the texts of the tests.
  static let locale = Locale(identifier: "en_US")

  /// A user message and an agent message with two texts.
  static let messages = [
    ThreadExporter.MessageText(role: .user, texts: ["Read the README."]),
    ThreadExporter.MessageText(role: .assistant, texts: ["Run `swift build`.", "Done."]),
  ]

  /// Two steps of a plan.
  static let steps = [
    PlanEntry(content: "Write the tests", priority: .high, status: .inProgress),
    PlanEntry(content: "Ship", priority: .low, status: .pending),
  ]

  // MARK: - The Markdown export

  @Test func theMarkdownOfMessagesHasASectionForEachMessage() {
    let markdown = ThreadExporter.markdown(of: Self.messages, templates: .bundled, locale: Self.locale)

    #expect(markdown == "## User\n\nRead the README.\n\n## Assistant\n\nRun `swift build`.\n\nDone.\n")
  }

  @Test func theMarkdownOfNoMessageIsEmpty() {
    #expect(ThreadExporter.markdown(of: [], templates: .bundled, locale: Self.locale).isEmpty)
  }

  @Test func theMarkdownOfAMessageContentPutsABlankLineBetweenTwoTexts() {
    #expect(ThreadExporter.markdown(ofTexts: ["Shown.", "Also."], templates: .bundled) == "Shown.\n\nAlso.")
  }

  @Test func anEditOfTheExportTemplateChangesTheExport() throws {
    let copy = try TemplateFolderCopy(editing: .threadMarkdown, replacing: "## ", with: "### ")
    defer { copy.remove() }

    let markdown = ThreadExporter.markdown(of: Self.messages, templates: copy.templates, locale: Self.locale)

    #expect(markdown == "### User\n\nRead the README.\n\n### Assistant\n\nRun `swift build`.\n\nDone.\n")
  }

  @Test func anEditOfTheMessageTemplateChangesTheMessageMarkdown() throws {
    let copy = try TemplateFolderCopy(editing: .messageMarkdown, replacing: "{{ text }}", with: "> {{ text }}")
    defer { copy.remove() }

    #expect(ThreadExporter.markdown(ofTexts: ["Shown.", "Also."], templates: copy.templates) == "> Shown.\n\n> Also.")
  }

  // MARK: - The copy text

  @Test func theCopyTextHasARoleLineThenTheTextsOfEachMessage() {
    let text = AgentCommandTarget.plainText(of: Self.messages, templates: .bundled, locale: Self.locale)

    #expect(text == "User:\nRead the README.\n\nAssistant:\nRun `swift build`.\nDone.")
  }

  @Test func theCopyTextOfNoMessageIsEmpty() {
    #expect(AgentCommandTarget.plainText(of: [], templates: .bundled, locale: Self.locale).isEmpty)
  }

  @Test func anEditOfTheCopyTemplateChangesTheCopyText() throws {
    let copy = try TemplateFolderCopy(editing: .copyText, replacing: "{{ message.heading }}", with: "[{{ message.heading }}]")
    defer { copy.remove() }

    let text = AgentCommandTarget.plainText(of: Self.messages, templates: copy.templates, locale: Self.locale)

    #expect(text == "[User:]\nRead the README.\n\n[Assistant:]\nRun `swift build`.\nDone.")
  }

  // MARK: - The plan steps

  @Test func thePlanStepsAreOneStepOnEachLine() {
    let text = InspectionText.steps(of: Self.steps, templates: .bundled, locale: Self.locale)

    #expect(text == "In progress: Write the tests\nPending: Ship")
  }

  @Test func aPlanWithNoStepHasNoText() {
    #expect(InspectionText.steps(of: [], templates: .bundled, locale: Self.locale).isEmpty)
  }

  @Test func anEditOfTheStepsTemplateChangesTheSteps() throws {
    let copy = try TemplateFolderCopy(editing: .planSteps, replacing: "{{ step }}", with: "- {{ step }}")
    defer { copy.remove() }

    let text = InspectionText.steps(of: Self.steps, templates: copy.templates, locale: Self.locale)

    #expect(text == "- In progress: Write the tests\n- Pending: Ship")
  }
}
