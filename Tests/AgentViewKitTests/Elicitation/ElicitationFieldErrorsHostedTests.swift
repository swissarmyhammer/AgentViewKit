import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Hosted tests of when ``ElicitationView`` shows and announces the errors of
/// its fields.
///
/// A field whose default is not empty and not valid shows its errors at once.
/// Another field shows its errors only after the user changes its answer, or
/// after a submit attempt with a form that is not complete. Each error that
/// appears is announced.
@Suite(.serialized, .hostedSerially) @MainActor struct ElicitationFieldErrorsHostedTests {
  /// The JSON text of a property schema of a one-line text field.
  static let nameProperty = #"{"type": "string", "title": "Name", "maxLength": 40}"#

  /// The JSON text of a property schema of a number field whose default is
  /// above its maximum.
  static let invalidCountProperty =
    #"{"type": "integer", "title": "Count", "minimum": 1, "maximum": 9, "default": 12}"#

  /// The message of a required field with no answer.
  static let requiredMessage = "This field is necessary."

  /// The message of a number above the maximum of ``invalidCountProperty``.
  static let aboveMaximumMessage = "The value must be 9 or less."

  /// The accessibility identifier of the button of the custom footer, which
  /// calls the submit function of the footer context in each state.
  static let attemptIdentifier = "custom-footer-attempt"

  /// The params of a request with the one required text field `name`.
  static var requiredNameParams: String {
    ElicitationViewHostedTests.makeFormParams(properties: ["name": nameProperty], required: ["name"])
  }

  /// The params of a request with the required text field `name` and the
  /// required single-choice field `color`.
  static var requiredNameAndColorParams: String {
    ElicitationViewHostedTests.makeFormParams(
      properties: ["name": nameProperty, "color": ElicitationViewHostedTests.colorProperty],
      required: ["name", "color"])
  }

  /// The errors element of the field named `name`, or `nil` when the field
  /// shows no error.
  ///
  /// - Parameters:
  ///   - name: The property name of the field.
  ///   - harness: The harness of the form.
  /// - Returns: The snapshot of the errors element.
  static func errors(
    of name: String, in harness: HostedViewHarness<AnyView>
  ) -> AccessibilityElementSnapshot? {
    harness.element(identifier: ElicitationFieldView.errorsIdentifier(for: name))
  }

  /// Shows a form with `announcer` as the announcer of the form.
  ///
  /// - Parameters:
  ///   - params: The JSON text of the params of the request.
  ///   - announcer: The announcer that records each announcement.
  /// - Returns: The mounted form.
  /// - Throws: The error of ``ElicitationViewHostedTests/mount(_:reporter:content:)``.
  static func mount(
    _ params: String, announcer: RecordingAnnouncer
  ) async throws -> ElicitationViewHostedTests.Mounted {
    try await ElicitationViewHostedTests.mount(params) { form in
      form.environment(\.announcer, announcer)
    }
  }

  /// Shows a form whose custom footer has a button that calls the submit
  /// function of the footer context, also when the form is not complete.
  /// The layout shows each field inline.
  ///
  /// - Parameters:
  ///   - params: The JSON text of the params of the request.
  ///   - announcer: The announcer that records each announcement.
  /// - Returns: The mounted form.
  /// - Throws: The error of ``ElicitationViewHostedTests/mount(_:reporter:content:)``.
  static func mountWithAttemptFooter(
    _ params: String, announcer: RecordingAnnouncer
  ) async throws -> ElicitationViewHostedTests.Mounted {
    try await ElicitationViewHostedTests.mount(params) { form in
      form
        .elicitationLayout(tabThreshold: ElicitationViewHostedTests.inlineTabThreshold)
        .elicitationFooter { footer in
          Button("Try") { footer.submit() }
            .accessibilityIdentifier(attemptIdentifier)
        }
        .environment(\.announcer, announcer)
    }
  }

  /// Types `text` in the first text input of the form, then deletes each
  /// typed character.
  ///
  /// - Parameters:
  ///   - text: The text to type.
  ///   - harness: The harness of the form.
  /// - Throws: An issue when the form has no text input, or the error of a
  ///   key.
  static func typeAndClear(_ text: String, in harness: HostedViewHarness<AnyView>) throws {
    try #require(harness.focusFirstEditableTextView())
    harness.type(text)
    for _ in text {
      try harness.sendKey(.delete)
    }
  }

  // MARK: - First show

  @Test func aNewFormShowsNoErrorUnderARequiredEmptyField() async throws {
    let announcer = RecordingAnnouncer()
    let mounted = try await Self.mount(Self.requiredNameParams, announcer: announcer)
    defer { mounted.close() }

    #expect(Self.errors(of: "name", in: mounted.harness) == nil)
    #expect(announcer.announcements.isEmpty)
  }

  @Test func aDefaultThatIsNotValidShowsItsErrorOnFirstShow() async throws {
    let params = ElicitationViewHostedTests.makeFormParams(properties: ["count": Self.invalidCountProperty])
    let mounted = try await Self.mount(params, announcer: RecordingAnnouncer())
    defer { mounted.close() }

    #expect(Self.errors(of: "count", in: mounted.harness)?.label?.contains(Self.aboveMaximumMessage) == true)
  }

  @Test func theErrorOfADefaultThatIsNotValidIsAnnouncedOnFirstShow() async throws {
    let announcer = RecordingAnnouncer()
    let params = ElicitationViewHostedTests.makeFormParams(properties: ["count": Self.invalidCountProperty])
    let mounted = try await Self.mount(params, announcer: announcer)
    defer { mounted.close() }

    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(message: "“Count”: \(Self.aboveMaximumMessage)", priority: .medium)
      ])
  }

  @Test func aDefaultThatIsNotValidShowsNoErrorUnderARequiredEmptyField() async throws {
    let params = ElicitationViewHostedTests.makeFormParams(
      properties: ["name": Self.nameProperty, "count": Self.invalidCountProperty], required: ["name"])
    let mounted = try await Self.mountWithAttemptFooter(params, announcer: RecordingAnnouncer())
    defer { mounted.close() }
    try #require(Self.errors(of: "count", in: mounted.harness) != nil)

    #expect(Self.errors(of: "name", in: mounted.harness) == nil)
  }

  @Test func aValidDefaultShowsNoErrorOnFirstShow() async throws {
    let announcer = RecordingAnnouncer()
    let params = ElicitationViewHostedTests.makeFormParams(
      properties: ["count": ElicitationViewHostedTests.countProperty])
    let mounted = try await Self.mount(params, announcer: announcer)
    defer { mounted.close() }

    #expect(Self.errors(of: "count", in: mounted.harness) == nil)
    #expect(announcer.announcements.isEmpty)
  }

  @Test func aNewFormKeepsSubmitDisabledWhileARequiredFieldIsEmpty() async throws {
    let mounted = try await Self.mount(Self.requiredNameParams, announcer: RecordingAnnouncer())
    defer { mounted.close() }

    let submit = try #require(mounted.harness.element(identifier: ElicitationView.submitIdentifier))
    #expect(!submit.isEnabled)
  }

  // MARK: - Edit

  @Test func anEditThatClearsARequiredFieldShowsItsError() async throws {
    let mounted = try await Self.mount(Self.requiredNameParams, announcer: RecordingAnnouncer())
    defer { mounted.close() }
    let harness = mounted.harness

    try Self.typeAndClear("A", in: harness)

    #expect(Self.errors(of: "name", in: harness)?.label?.contains(Self.requiredMessage) == true)
  }

  @Test func theErrorThatAnEditShowsIsAnnounced() async throws {
    let announcer = RecordingAnnouncer()
    let mounted = try await Self.mount(Self.requiredNameParams, announcer: announcer)
    defer { mounted.close() }

    try Self.typeAndClear("A", in: mounted.harness)

    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(message: "“Name”: \(Self.requiredMessage)", priority: .medium)
      ])
  }

  @Test func anEditOfOneFieldShowsNoErrorUnderAnotherField() async throws {
    let mounted = try await Self.mountWithAttemptFooter(
      Self.requiredNameAndColorParams, announcer: RecordingAnnouncer())
    defer { mounted.close() }
    let harness = mounted.harness

    try Self.typeAndClear("A", in: harness)

    #expect(Self.errors(of: "name", in: harness) != nil)
    #expect(Self.errors(of: "color", in: harness) == nil)
  }

  // MARK: - Submit attempt

  @Test func aSubmitAttemptShowsTheErrorOfEachFieldThatIsNotValid() async throws {
    let mounted = try await Self.mountWithAttemptFooter(
      Self.requiredNameAndColorParams, announcer: RecordingAnnouncer())
    defer { mounted.close() }
    let harness = mounted.harness
    try #require(Self.errors(of: "name", in: harness) == nil)

    try harness.press(identifier: Self.attemptIdentifier)

    #expect(Self.errors(of: "name", in: harness)?.label?.contains(Self.requiredMessage) == true)
    #expect(Self.errors(of: "color", in: harness)?.label?.contains(Self.requiredMessage) == true)
    #expect(mounted.session.model.pendingElicitations.count == 1)
  }

  @Test func aSubmitAttemptAnnouncesTheErrorOfEachFieldThatIsNotValid() async throws {
    let announcer = RecordingAnnouncer()
    let mounted = try await Self.mountWithAttemptFooter(Self.requiredNameAndColorParams, announcer: announcer)
    defer { mounted.close() }

    try mounted.harness.press(identifier: Self.attemptIdentifier)

    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(
          message: "“Color”: \(Self.requiredMessage) “Name”: \(Self.requiredMessage)", priority: .high)
      ])
  }
}
