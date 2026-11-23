import AgentViewKitTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests for the composer of the host in a read-only thread (TestudoApp
/// D212, design sections 5.3 and 5.4): `threadComposer(placeholder:onSubmit:)`.
///
/// The slot tests lay out a thread view in an `NSHostingView` with no window,
/// with a probe in the composer slot. The probe keeps the placeholder and the
/// submit hook that the slot gives to the composer. The submit tests call
/// that hook directly. No test shows a window or takes the focus.
@MainActor @Suite struct ThreadComposerTests {
  /// The placeholder of the host.
  static let placeholder = "Message to continue in Testudo"

  /// The prompt that the user sends.
  static let prompt = "Run the tests again."

  /// The texts that the host closure got, in order.
  @MainActor final class HostRecord {
    /// Each text that the host closure got.
    var texts: [String] = []

    /// The host closure, which keeps each text.
    ///
    /// - Parameter text: The text of the prompt.
    func take(_ text: String) async {
      texts.append(text)
    }
  }

  /// What the composer slot gave to the probe.
  @MainActor final class SlotRecord {
    /// Whether the slot showed the probe.
    var isShown = false

    /// The placeholder that the slot gave, or `nil`.
    var placeholder: String?

    /// The submit hook that the slot gave, or `nil`.
    var hook: ComposerSubmitHook?
  }

  /// A view in the composer slot that keeps what the slot gives to it.
  struct ComposerProbe: View {
    /// The record that gets what the slot gives.
    let record: SlotRecord

    /// The placeholder of the environment.
    @Environment(\.promptPlaceholder) private var placeholder

    /// The submit hook of the environment.
    @Environment(\.composerSubmitHook) private var hook

    var body: some View {
      Color.clear
        .onChange(of: placeholder, initial: true) {
          record.isShown = true
          record.placeholder = placeholder
          record.hook = hook
        }
    }
  }

  /// Lays out a thread of `session` with a probe in the composer slot.
  ///
  /// - Parameters:
  ///   - session: The session model of the thread.
  ///   - host: The record of the host closure, or `nil` for no composer of
  ///     the host.
  /// - Returns: What the slot gave to the probe.
  static func layOut(_ session: SessionModel, host: HostRecord?) -> SlotRecord {
    let record = SlotRecord()
    let thread = AgentThreadView(session: session) { ComposerProbe(record: record) }
    let view: AnyView =
      if let host {
        AnyView(thread.threadComposer(placeholder: placeholder, onSubmit: host.take))
      } else {
        AnyView(thread)
      }
    StyleViewHost.layOut(
      view.frame(width: ThreadSlotChainTests.width, height: ThreadSlotChainTests.height))
    return record
  }

  /// The route of a host composer whose closure keeps each text in `host`.
  ///
  /// - Parameter host: The record of the host closure.
  /// - Returns: The route.
  static func route(to host: HostRecord) -> ThreadComposerRoute {
    ThreadComposerRoute(placeholder: placeholder, onSubmit: host.take)
  }

  // MARK: - Slot

  /// A production change that fails this test: the thread shows no
  /// composer slot for a read-only session with the composer of the host.
  @Test func aReadOnlyThreadWithTheHostComposerShowsTheComposer() {
    let record = Self.layOut(ReadOnlyThreadTests.readOnlyModel(), host: HostRecord())

    #expect(record.isShown)
  }

  /// A production change that fails this test: the thread shows the
  /// composer slot for a read-only session with no composer of the host
  /// (TestudoApp D208 (i)).
  @Test func aReadOnlyThreadWithNoHostComposerShowsNoComposer() {
    let record = Self.layOut(ReadOnlyThreadTests.readOnlyModel(), host: nil)

    #expect(!record.isShown)
  }

  /// A production change that fails this test: the slot does not give the
  /// placeholder of the host to the composer.
  @Test func theComposerOfAReadOnlyThreadGetsThePlaceholderOfTheHost() {
    let record = Self.layOut(ReadOnlyThreadTests.readOnlyModel(), host: HostRecord())

    #expect(record.placeholder == Self.placeholder)
  }

  /// A production change that fails this test: the composer of the host
  /// changes the placeholder of a live thread.
  @Test func aLiveThreadKeepsItsOwnPlaceholder() throws {
    let record = Self.layOut(ThreadSlotChainTests.session(), host: HostRecord())
    // The slot showed the probe, so the record can show a placeholder.
    try #require(record.isShown)

    #expect(record.placeholder == nil)
  }

  /// A production change that fails this test: the composer of the host
  /// takes the prompts of a live thread.
  @Test func aLiveThreadKeepsItsOwnSubmit() throws {
    let record = Self.layOut(ThreadSlotChainTests.session(), host: HostRecord())
    // The slot showed the probe, so the record can show a hook.
    try #require(record.isShown)

    #expect(record.hook == nil)
  }

  /// A production change that fails this test: the composer modifier, or
  /// the header modifier, returns a view that drops the value of the other
  /// in this order.
  ///
  /// - Parameter composerFirst: Whether the composer modifier is nearest to
  ///   the thread.
  @Test(arguments: [true, false])
  func theThreadShowsTheHeaderAndTheComposerInEachOrder(composerFirst: Bool) {
    let header = SlotProbeRecord()
    let record = SlotRecord()
    let thread = AgentThreadView(session: ReadOnlyThreadTests.readOnlyModel()) {
      ComposerProbe(record: record)
    }
    let view: AnyView =
      if composerFirst {
        AnyView(
          thread.threadComposer(placeholder: Self.placeholder) { _ in }
            .threadHeader { SlotProbe(record: header) })
      } else {
        AnyView(
          thread.threadHeader { SlotProbe(record: header) }
            .threadComposer(placeholder: Self.placeholder) { _ in })
      }

    StyleViewHost.layOut(
      view.frame(width: ThreadSlotChainTests.width, height: ThreadSlotChainTests.height))

    #expect(header.isShown && record.placeholder == Self.placeholder)
  }

  // MARK: - Submit

  /// A production change that fails this test: the slot of a read-only
  /// thread does not route a submit to the closure of the host.
  @Test func aSubmitInAReadOnlyThreadCallsTheHostOneTimeWithTheText() async throws {
    let host = HostRecord()
    let record = Self.layOut(ReadOnlyThreadTests.readOnlyModel(), host: host)
    let hook = try #require(record.hook)

    _ = await hook(ComposerSubmission(AttributedString(Self.prompt), fileRoot: nil))

    #expect(host.texts == [Self.prompt])
  }

  /// A production change that fails this test: the route does not tell the
  /// composer that the host took the prompt, so the composer sends the
  /// prompt to the session or keeps the text.
  @Test func aSubmitToTheHostConsumesThePrompt() async {
    let result = await Self.route(to: HostRecord())
      .submit(ComposerSubmission(AttributedString(Self.prompt), fileRoot: nil))

    #expect(result.isConsumed)
  }

  /// A production change that fails this test: after the host took the
  /// prompt, the composer keeps the text.
  @Test func aSubmitToTheHostClearsTheText() async throws {
    let composer = try ComposerSubmitFixture()
    let result = await Self.route(to: HostRecord())
      .submit(ComposerSubmission(composer.text, fileRoot: nil))

    _ = composer.apply(result)

    #expect(composer.text.characters.isEmpty)
  }

  /// A production change that fails this test: the route calls the host
  /// with a blank text.
  @Test func aBlankTextDoesNotCallTheHost() async {
    let host = HostRecord()

    _ = await Self.route(to: host).submit(ComposerSubmission(AttributedString("  \n"), fileRoot: nil))

    #expect(host.texts.isEmpty)
  }

  /// A production change that fails this test: the route clears a blank
  /// text or sends it.
  @Test func aBlankTextIsCancelled() async {
    let result = await Self.route(to: HostRecord())
      .submit(ComposerSubmission(AttributedString("  \n"), fileRoot: nil))

    #expect(result.isCancelled)
  }

  // MARK: - Placeholder

  /// A production change that fails this test: the composer does not show
  /// the placeholder of the environment.
  @Test func thePromptInputShowsThePlaceholderOfTheEnvironment() {
    let shown = PromptInputView<EditorKitPromptEditor, DefaultPromptAccessory>.placeholder(
      host: Self.placeholder)

    #expect(shown == Self.placeholder)
  }

  /// A production change that fails this test: with no placeholder in the
  /// environment, the composer does not show the placeholder of the kit.
  @Test func thePromptInputShowsThePlaceholderOfTheKitWithNoHostPlaceholder() {
    typealias Input = PromptInputView<EditorKitPromptEditor, DefaultPromptAccessory>

    #expect(Input.placeholder(host: nil) == Input.placeholder)
  }

  // MARK: - Accessory

  /// A production change that fails this test: the accessory of a
  /// read-only session shows the mode picker, whose change the model
  /// refuses.
  @Test func theAccessoryOfAReadOnlySessionShowsNoModePicker() {
    #expect(!DefaultPromptAccessory.showsModePicker(for: ReadOnlyThreadTests.readOnlyModel()))
  }

  /// A production change that fails this test: the accessory of a live
  /// session hides the mode picker.
  @Test func theAccessoryOfALiveSessionShowsTheModePicker() {
    #expect(DefaultPromptAccessory.showsModePicker(for: ThreadSlotChainTests.session()))
  }
}
