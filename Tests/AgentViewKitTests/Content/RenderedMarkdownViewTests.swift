@testable import AgentViewKit
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import Foundation
import Testing

/// The read-only EditorKit view of static Markdown (AVK-9.1, D185).
@MainActor @Suite struct RenderedMarkdownViewTests {
  @Test func theModelIsReadOnlyAndRendered() {
    let model = RenderedMarkdownView.makeModel("Some **bold** text.")

    #expect(model.isReadOnly)
    #expect(model.presentation == .rendered)
    #expect(model.text == "Some **bold** text.")
  }

  @Test func aNewTextReplacesTheTextOfTheModel() {
    let model = RenderedMarkdownView.makeModel("# Old")

    RenderedMarkdownView.sync(model, to: "# New\n\nA line.")

    #expect(model.text == "# New\n\nA line.")
    #expect(model.isReadOnly)
  }

  @Test func theAttachmentMarkdownShowsTheRenderedView() {
    let content = AttachmentTextContent(text: "# Notes", type: AttachmentTextContent.markdown, filename: nil)

    #expect(String(describing: type(of: content.body)).contains("RenderedMarkdownView"))
  }

  @Test func theEmptyStateShowsTheRenderedView() {
    let content = ConversationEmptyState(markdown: "Ask about the **code**.")

    #expect(String(describing: type(of: content.body)).contains("RenderedMarkdownView"))
  }

  // MARK: - Images (AVK-9.6)

  @Test func imagesLoadFromTheFolderOfTheSession() {
    let session = SessionModel.preview(cwd: AbsolutePath(rawValue: "/tmp/project"))

    #expect(RenderedMarkdownView.imageFolder(of: session) == URL(filePath: "/tmp/project", directoryHint: .isDirectory))
  }

  @Test func withNoSessionNoFolderGivesImages() {
    #expect(RenderedMarkdownView.imageFolder(of: nil) == nil)
  }
}
