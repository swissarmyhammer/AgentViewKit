@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import SwiftUI
import Testing
import UniformTypeIdentifiers

/// Hosted tests of the attachment views, the inspector and the artifact view.
///
/// Each change comes from the test on the main actor: a mount, a press, or a
/// change of the selection. One render pass after the change puts its result
/// in the accessibility tree, so the test reads the tree after that pass. An
/// inspector that is open at the mount shows its split view item after the
/// first render pass.
///
/// The diagnostic lldb samples of a chip press (2026-10-17) show that the
/// render pass does not show the inspector item of the AppKit split view after
/// a change of the selection: the item stays collapsed after the press and
/// after two more render passes. The lldb samples of a chip press and of
/// ``theSelectionOfTheHostOfAThreadViewShowsTheInspectorItemOfTheSplitView()``
/// show that the mount adds a block to the main run loop
/// (`SplitViewCoordinator.updateInspector`, `onNextMainRunLoop`,
/// `CFRunLoopPerformBlock`), and that the render pass after the change adds
/// one more such block. The samples that stop in the blocks show that the two
/// blocks run in `__CFRunLoopDoBlocks`, and that the item is set to not
/// collapsed after both blocks ran. The samples do not show which of the two
/// blocks sets the item. Thus the split view tests wait with
/// ``RunLoopBlockFence/afterPendingBlocks()`` after the render pass that adds
/// the second block, make one more render pass, and then read the split view
/// item and the tree. The doc of the fence gives the proof of the order and
/// its limit.
/// A failure of these tests is treated as a SwiftUI change: investigate it
/// with a new sample (an lldb call stack of the enqueue), and do not run the
/// tests again to find the cause. A change in AgentViewKit can also make these
/// tests fail.
///
/// The state tests check the input to the split view: after a chip press, and
/// after a host selection of a thread view, they check the selection
/// synchronously, and they read the inspector content of the selection in its
/// own harness (``mountInspectorContent(of:)``). Other state tests check the
/// selection that ``AgentThreadView`` gives to its inspector.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentInspectorHostedTests {
  /// The size of a view that shows the attachment and the inspector.
  static let hostSize = CGSize(width: 900, height: 600)

  /// The text that each temporary file holds.
  static let fileText = "let answer = 42\n"

  /// The accessibility identifier of the registered PDF view.
  static let customPDFIdentifier = "custom-pdf-view"

  // MARK: - Default renderers

  @Test func aSwiftFileMountsTheCodeRenderer() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "Main.swift", in: directory)
    let harness = HostedViewHarness(AttachmentView(attachment), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: AttachmentView.identifier(for: .code)) != nil)
    #expect(harness.element(identifier: AttachmentView.identifier(for: .chip)) == nil)
  }

  @Test func aBinaryFileMountsTheChip() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "blob.bin", in: directory)
    let harness = HostedViewHarness(AttachmentView(attachment), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    let chip = try #require(harness.element(identifier: AttachmentView.identifier(for: .chip)))
    #expect(chip.label?.contains("blob.bin") == true)
  }

  @Test func aRegisteredPDFViewWinsOverTheDefault() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "paper.pdf", in: directory)
    let harness = HostedViewHarness(
      AttachmentView(attachment)
        .attachmentView(for: .pdf) { url in
          Text(url.lastPathComponent)
            .accessibilityIdentifier(Self.customPDFIdentifier)
        },
      size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: Self.customPDFIdentifier)?.label == "paper.pdf")
    #expect(harness.element(identifier: AttachmentView.identifier(for: .pdf)) == nil)
  }

  // MARK: - Inspector

  /// A press on a chip selects its attachment, and the inspector content of
  /// that selection shows the name and the five actions.
  ///
  /// The chip selects its attachment in the same step as the press, so the
  /// test requires the selection at once. Then it mounts the inspector
  /// content of the selection in its own harness with one render pass.
  ///
  /// The test checks the input to the AppKit split view.
  /// ``aPressOnAChipShowsTheInspectorItemOfTheSplitView()`` checks the item
  /// that the split view shows.
  @Test func aPressOnAChipSelectsItsAttachmentForTheInspectorContent() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "blob.bin", in: directory)
    let selection = InspectorSelection()
    let harness = Self.mountChip(of: attachment, selection: selection)
    defer { harness.close() }
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier) == nil)

    try Self.pressChip(in: harness, selecting: attachment, in: selection)
    let content = try Self.mountInspectorContent(of: selection)
    defer { content.close() }
    #expect(content.element(identifier: AttachmentInspector.nameIdentifier)?.label == "blob.bin")
    for identifier in AttachmentInspector.actionIdentifiers {
      #expect(content.element(identifier: identifier) != nil, "No action \(identifier).")
    }
  }

  @Test func theInspectorHasTheFiveActionIdentifiers() {
    #expect(
      AttachmentInspector.actionIdentifiers == [
        "inspector-open", "inspector-reveal", "inspector-share", "inspector-save",
        "inspector-quicklook",
      ])
  }

  @Test func aClearedSelectionClosesTheInspector() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "blob.bin", in: directory)
    let selection = InspectorSelection(attachment: attachment)
    let harness = HostedViewHarness(
      Text("host").attachmentInspector(selection: selection), size: Self.hostSize)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier) != nil)

    selection.clear()
    harness.render()

    #expect(selection.attachment == nil)
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier) == nil)
  }

  /// A thread view of a session with a host selection shows no inspector
  /// before the host selects, and the selection of the host then holds the
  /// attachment, whose inspector content shows its name.
  ///
  /// The selection holds the attachment in the same step as the select, so
  /// the test requires the selection at once, with no wait. Then it mounts
  /// the inspector content of the selection in its own harness with one
  /// render pass.
  ///
  /// The test checks the input to the AppKit split view of the thread view.
  /// ``theSelectionOfTheHostOfAThreadViewShowsTheInspectorItemOfTheSplitView()``
  /// checks the item that the split view shows.
  @Test func theSelectionOfTheHostOfAThreadViewGivesItsAttachmentToTheInspectorContent() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "notes.md", in: directory)
    let selection = InspectorSelection()
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mountThreadView(of: session, selection: selection)
    defer { harness.close() }
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier) == nil)

    try Self.withoutAnimation { selection.select(attachment) }

    try #require(selection.attachment == attachment)
    let content = try Self.mountInspectorContent(of: selection)
    defer { content.close() }
    #expect(content.element(identifier: AttachmentInspector.nameIdentifier)?.label == "notes.md")
  }

  /// A press on a chip shows the inspector item of the AppKit split view, and
  /// the item shows the name and the five actions of the attachment.
  ///
  /// The press makes a render pass. In the lldb samples of a chip press, the
  /// mount adds a block of `SplitViewCoordinator.updateInspector` to the main
  /// run loop, and that pass adds one more such block. The samples that stop
  /// in the blocks show that the item is set to not collapsed after both
  /// blocks ran. They do not show which of the two blocks sets the item. The
  /// fence waits until each common-mode block that was added before it ran,
  /// thus it waits for both blocks.
  @Test func aPressOnAChipShowsTheInspectorItemOfTheSplitView() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "blob.bin", in: directory)
    let selection = InspectorSelection()
    let harness = Self.mountChip(of: attachment, selection: selection)
    defer { harness.close() }
    try #require(Self.inspectorItem(in: harness)?.isCollapsed == true)

    try Self.pressChip(in: harness, selecting: attachment, in: selection)
    await RunLoopBlockFence.afterPendingBlocks()
    harness.render()

    try Self.requireInspectorItem(in: harness, showsTheNameOf: "blob.bin")
  }

  /// A host selection of a thread view shows the inspector item of the AppKit
  /// split view of the thread view, and the item shows the name and the five
  /// actions of the attachment.
  ///
  /// The select does not make a render pass, so the test makes one. In the
  /// lldb sample of this test (2026-10-17), that pass adds a block of
  /// `SplitViewCoordinator.updateInspector` to the main run loop with the same
  /// chain as the chip press. The mount also adds such a block, and that block
  /// did not run before the fence. Both blocks ran in `__CFRunLoopDoBlocks`,
  /// and the item was set to not collapsed after both. The sample does not
  /// show which of the two blocks sets the item. The fence waits until each
  /// common-mode block that was added before it ran, thus it waits for both
  /// blocks.
  @Test func theSelectionOfTheHostOfAThreadViewShowsTheInspectorItemOfTheSplitView() async throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let attachment = try Self.attachment(named: "notes.md", in: directory)
    let selection = InspectorSelection()
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mountThreadView(of: session, selection: selection)
    defer { harness.close() }
    try #require(Self.inspectorItem(in: harness)?.isCollapsed == true)

    try Self.withoutAnimation { selection.select(attachment) }
    try #require(selection.attachment == attachment)
    harness.render()
    await RunLoopBlockFence.afterPendingBlocks()
    harness.render()

    try Self.requireInspectorItem(in: harness, showsTheNameOf: "notes.md")
  }

  /// A thread view gives the selection of its host to its inspector, when the
  /// environment has one.
  @Test func aThreadViewGivesTheSelectionOfItsHostToItsInspector() {
    let host = InspectorSelection()
    let own = InspectorSelection()

    #expect(AgentThreadView<DefaultThreadComposer>.inspectorSelection(host: host, own: own) === host)
  }

  /// A thread view gives its own selection to its inspector, when the
  /// environment has no selection.
  @Test func aThreadViewWithNoHostSelectionGivesItsOwnSelectionToItsInspector() {
    let own = InspectorSelection()

    #expect(AgentThreadView<DefaultThreadComposer>.inspectorSelection(host: nil, own: own) === own)
  }

  // MARK: - Artifact

  @Test func anArtifactWithAURLShowsItsBodyAndActions() throws {
    let directory = try TemporaryDirectory()
    defer { directory.remove() }
    let url = try directory.file(named: "plan", contents: Data(Self.fileText.utf8))
    let artifact = ArtifactPayload(
      id: "artifact-1", title: "The plan", type: UTType.swiftSource.identifier, url: url)
    let harness = HostedViewHarness(ArtifactView(artifact: artifact), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: ArtifactView.titleIdentifier)?.label == "The plan")
    #expect(harness.element(identifier: AttachmentView.identifier(for: .code)) != nil)
    for identifier in ArtifactView.actionIdentifiers {
      #expect(harness.element(identifier: identifier) != nil, "No action \(identifier).")
    }
  }

  @Test func anInlineArtifactShowsItsTextAndNoActions() {
    let artifact = ArtifactPayload(
      id: "artifact-2", title: "Notes", type: UTType.plainText.identifier,
      inlineText: "Step one")
    let harness = HostedViewHarness(ArtifactView(artifact: artifact), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: ArtifactView.inlineTextIdentifier) != nil)
    for identifier in ArtifactView.actionIdentifiers {
      #expect(harness.element(identifier: identifier) == nil, "Unexpected action \(identifier).")
    }
  }

  // MARK: - Helpers

  /// Runs `body` in a transaction with no animation.
  ///
  /// The tests make each change that opens the inspector with no animation.
  /// With no animation, the lldb samples show that the mount and the render
  /// pass after the change each add a block of
  /// `SplitViewCoordinator.updateInspector` to the main run loop. The samples
  /// that stop in the blocks show that the inspector item is set to not
  /// collapsed in `__CFRunLoopDoBlocks` after both blocks ran. They do not show
  /// which of the two blocks sets the item. The split view tests show only
  /// that the item is not collapsed after that render pass, the fence and one
  /// more render pass.
  /// No test checks a change that opens the inspector with an animation.
  ///
  /// - Parameter body: The change to make.
  /// - Throws: The error of `body`.
  static func withoutAnimation(_ body: () throws -> Void) throws {
    var transaction = Transaction()
    transaction.disablesAnimations = true
    try withTransaction(transaction, body)
  }

  /// Mounts the view of an attachment with an inspector of `selection`, and
  /// makes one render pass.
  ///
  /// - Parameters:
  ///   - attachment: The attachment that the view shows.
  ///   - selection: The selection that the inspector shows.
  /// - Returns: The harness of the view. The caller closes it.
  static func mountChip(of attachment: AgentViewKit.Attachment, selection: InspectorSelection)
    -> HostedViewHarness<some View>
  {
    let harness = HostedViewHarness(
      AttachmentView(attachment).attachmentInspector(selection: selection), size: hostSize)
    harness.render()
    return harness
  }

  /// Mounts the thread view of a scripted session with `selection` as the
  /// host selection, and makes one render pass.
  ///
  /// - Parameters:
  ///   - session: The scripted session that the thread view shows.
  ///   - selection: The host selection in the environment of the view.
  /// - Returns: The harness of the view. The caller closes it.
  static func mountThreadView(of session: ScriptedSession, selection: InspectorSelection)
    -> HostedViewHarness<some View>
  {
    let harness = HostedViewHarness(
      AgentThreadView(session: session.model, connection: session.connection)
        .environment(\.inspectorSelection, selection),
      size: hostSize)
    harness.render()
    return harness
  }

  /// Presses the chip of `harness` with no animation, and requires that
  /// `selection` then holds `attachment`.
  ///
  /// The chip selects its attachment in the same step as the press, so the
  /// function requires the selection at once.
  ///
  /// - Parameters:
  ///   - harness: The harness that shows the chip.
  ///   - attachment: The attachment of the chip.
  ///   - selection: The selection that the chip writes to.
  /// - Throws: The error of the press, or an issue when `selection` does not
  ///   hold `attachment`.
  static func pressChip<Content: View>(
    in harness: HostedViewHarness<Content>, selecting attachment: AgentViewKit.Attachment,
    in selection: InspectorSelection
  ) throws {
    try withoutAnimation {
      try harness.press(identifier: AttachmentView.identifier(for: .chip))
    }
    try #require(selection.attachment == attachment)
  }

  /// Mounts the inspector content of the attachment that `selection` holds,
  /// as the split view item of the inspector shows it, and makes one render
  /// pass.
  ///
  /// - Parameter selection: The selection whose attachment the content shows.
  /// - Returns: The harness of the content. The caller closes it.
  /// - Throws: An issue when the selection holds no attachment.
  static func mountInspectorContent(of selection: InspectorSelection) throws
    -> HostedViewHarness<AttachmentInspector>
  {
    let attachment = try #require(selection.attachment)
    let harness = HostedViewHarness(AttachmentInspector(attachment), size: hostSize)
    harness.render()
    return harness
  }

  /// The split view item of the inspector in the window of `harness`.
  ///
  /// The inspector is an AppKit split view whose delegate is a split view
  /// controller. The function walks the views under the hosting view for that
  /// split view, and gives its item whose behavior is `.inspector`.
  ///
  /// - Parameter harness: The harness that shows the inspector.
  /// - Returns: The item, or `nil` when the window has no inspector item.
  static func inspectorItem<Content: View>(in harness: HostedViewHarness<Content>)
    -> NSSplitViewItem?
  {
    inspectorItems(in: harness).first
  }

  /// Each split view item of an inspector in the window of `harness`, in
  /// depth first order of the split views.
  ///
  /// Each `inspector(isPresented:content:)` in the window gives one item. A
  /// test counts the items to learn which inspectors the window has.
  ///
  /// - Parameter harness: The harness that shows the views.
  /// - Returns: The items. The list is empty when the window has no inspector.
  static func inspectorItems<Content: View>(in harness: HostedViewHarness<Content>)
    -> [NSSplitViewItem]
  {
    views(under: harness.hostingView)
      .compactMap { ($0 as? NSSplitView)?.delegate as? NSSplitViewController }
      .flatMap(\.splitViewItems)
      .filter { $0.behavior == .inspector }
  }

  /// `view` and each view under it, in depth first order.
  ///
  /// - Parameter view: The view at the top.
  /// - Returns: The views.
  static func views(under view: NSView) -> [NSView] {
    [view] + view.subviews.flatMap(views(under:))
  }

  /// Requires that the split view of `harness` shows the inspector item, and
  /// that the item shows the name and the five actions of the attachment.
  ///
  /// - Parameters:
  ///   - harness: The harness that shows the inspector.
  ///   - name: The file name of the attachment.
  /// - Throws: An issue when the window has no inspector item, or when the
  ///   item is collapsed.
  static func requireInspectorItem<Content: View>(
    in harness: HostedViewHarness<Content>, showsTheNameOf name: String
  ) throws {
    let item = try #require(inspectorItem(in: harness))
    try #require(!item.isCollapsed)
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier)?.label == name)
    for identifier in AttachmentInspector.actionIdentifiers {
      #expect(harness.element(identifier: identifier) != nil, "No action \(identifier).")
    }
  }

  /// Writes a file and makes its attachment.
  ///
  /// - Parameters:
  ///   - name: The file name, with its extension.
  ///   - directory: The directory of the file.
  /// - Returns: The attachment of the file.
  /// - Throws: The error of the write.
  static func attachment(named name: String, in directory: TemporaryDirectory) throws
    -> AgentViewKit.Attachment
  {
    AgentViewKit.Attachment(url: try directory.file(named: name, contents: Data(fileText.utf8)))
  }
}
