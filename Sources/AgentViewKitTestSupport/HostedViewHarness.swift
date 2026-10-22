import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A value copy of one accessibility element.
public struct AccessibilityElementSnapshot: Equatable, Sendable {
  /// The accessibility role, such as `AXStaticText` or `AXButton`.
  public let role: String?
  /// The label of the element. For an element with no label, this is the
  /// title, and for static text with no title, this is the text value.
  public let label: String?
  /// The accessibility value as text, or `nil` when the element has no
  /// value.
  public let value: String?
  /// The accessibility identifier, or `nil` when the element has none.
  public let identifier: String?
  /// Whether the element takes user actions. A disabled control gives
  /// `false`.
  public let isEnabled: Bool
  /// A copy of each element in `accessibilityLinkedUIElements()`. The copy
  /// of a linked element has no linked elements, so that a cycle of links
  /// stops.
  public let linkedElements: [AccessibilityElementSnapshot]

  /// Makes a snapshot.
  ///
  /// - Parameters:
  ///   - role: The accessibility role.
  ///   - label: The label.
  ///   - value: The value as text.
  ///   - identifier: The accessibility identifier.
  ///   - isEnabled: Whether the element takes user actions.
  ///   - linkedElements: The copies of the linked elements.
  public init(
    role: String?,
    label: String?,
    value: String?,
    identifier: String?,
    isEnabled: Bool = true,
    linkedElements: [AccessibilityElementSnapshot] = []
  ) {
    self.role = role
    self.label = label
    self.value = value
    self.identifier = identifier
    self.isEnabled = isEnabled
    self.linkedElements = linkedElements
  }
}

/// The errors of ``HostedViewHarness``.
public enum HostedViewHarnessError: Error, Equatable {
  /// No accessibility element has the identifier.
  case noElement(identifier: String)
  /// The element did not do the press action.
  case pressFailed(identifier: String)
  /// The element did not do the increment action.
  case incrementFailed(identifier: String)
  /// The harness has no key code for the key.
  case unsupportedKey(String)
  /// No view of the window is under the point, in window coordinates.
  case noView(at: CGPoint)
}

/// The fixed values of ``HostedViewHarness``.
///
/// A generic type cannot hold a stored static property, so the values are
/// in this separate type.
private enum HarnessConstants {
  /// The default width of the content, in points.
  static let defaultWidth: CGFloat = 480

  /// The default height of the content, in points.
  static let defaultHeight: CGFloat = 320

  /// The x and y coordinate of a window that is outside each screen.
  static let offScreenCoordinate: CGFloat = -20_000

  /// The origin that puts the window outside each screen.
  static let offScreenOrigin = NSPoint(x: offScreenCoordinate, y: offScreenCoordinate)

  /// The largest depth of the accessibility tree that the harness reads.
  /// The limit stops a cycle of parent and child links.
  static let maximumDepth = 64

  /// The virtual key codes of the special keys, keyed by their character.
  static let specialKeyCodes: [Character: Int] = [
    KeyEquivalent.return.character: kVK_Return,
    KeyEquivalent.tab.character: kVK_Tab,
    KeyEquivalent.space.character: kVK_Space,
    KeyEquivalent.delete.character: kVK_Delete,
    KeyEquivalent.escape.character: kVK_Escape,
    KeyEquivalent.leftArrow.character: kVK_LeftArrow,
    KeyEquivalent.rightArrow.character: kVK_RightArrow,
    KeyEquivalent.downArrow.character: kVK_DownArrow,
    KeyEquivalent.upArrow.character: kVK_UpArrow,
  ]

  /// The key code that the harness sends with a printable character.
  /// SwiftUI reads the characters of the event, not its key code.
  static let printableKeyCode = UInt16(kVK_ANSI_A)
}

/// Mounts a SwiftUI view in an off-screen window, so that a test can read
/// and use its accessibility elements.
///
/// The harness puts the view in an `NSHostingView`, which is the content view
/// of an `NSWindow` that is not on a screen. The window is borderless by
/// default, and a test can ask for a titled window. The harness never
/// orders the window in, and the test process has the `.prohibited`
/// activation policy. Thus a test shows no window and does not take the focus
/// from the user (AVK-12). A `swift test` process needs no
/// application bundle for this. The test calls ``render()`` after a change on
/// the main actor, or ``render(when:)`` after a change that comes from
/// asynchronous work, so that SwiftUI updates the view. The test calls
/// ``close()`` at the end. The actions of the harness, such as
/// ``press(identifier:)`` and ``type(_:)``, call ``render()`` themselves.
///
/// The test rule:
/// - A test does not wait on a clock. It has no sleep, no poll, no time
///   limit and no run of the run loop for a time. The one run loop pass of
///   the harness is the pass before a key event, which does not wait.
/// - A change on the main actor: call ``render()``, then read the tree.
/// - A change that comes from asynchronous work: wait for its event with
///   ``render(when:)`` or ``ObservationWait/until(_:)``, then check the
///   result with an expectation. The wait is not a check.
/// - A hosted test holds ``HostedTestLock``, and a wait has no time limit.
///   Thus each wait of a hosted test must be for an event that is certain to
///   come.
public final class HostedViewHarness<Content: View> {
  /// The default size of the content.
  public static var defaultSize: CGSize {
    CGSize(width: HarnessConstants.defaultWidth, height: HarnessConstants.defaultHeight)
  }

  /// The off-screen window.
  public let window: NSWindow

  /// The hosting view that shows the content.
  public let hostingView: NSHostingView<Content>

  /// Mounts `content` and lays it out.
  ///
  /// A test that needs the title bar and the toolbar of a window, for
  /// example a `NavigationSplitView` with toolbar items, gives a titled
  /// `styleMask` with `.fullSizeContentView`. The content then fills the
  /// window under the title bar, and the safe area of the hosting view holds
  /// the height of the title bar and the toolbar.
  ///
  /// - Parameters:
  ///   - content: The view to mount.
  ///   - size: The size of the content.
  ///   - styleMask: The style of the window. The default is a borderless
  ///     window.
  public init(
    _ content: Content, size: CGSize = HostedViewHarness.defaultSize,
    styleMask: NSWindow.StyleMask = .borderless
  ) {
    Self.prepareApplication()
    let frame = NSRect(origin: .zero, size: size)
    hostingView = NSHostingView(rootView: content)
    hostingView.frame = frame
    // A borderless window keeps its off-screen origin. AppKit can move a
    // titled window onto a screen. The harness never orders the window in,
    // of any style, so the window never shows and never takes the focus
    // (AVK-12).
    window = KeyableWindow(
      contentRect: frame, styleMask: styleMask, backing: .buffered, defer: false)
    // ARC owns the window. The default value would release it a second time.
    window.isReleasedWhenClosed = false
    window.colorSpace = .sRGB
    window.contentView = hostingView
    window.setFrameOrigin(HarnessConstants.offScreenOrigin)
    hostingView.layoutSubtreeIfNeeded()
    selectFirstKeyView()
  }

  /// Mounts the view that `content` builds.
  ///
  /// - Parameters:
  ///   - size: The size of the content.
  ///   - content: The builder of the view to mount.
  public convenience init(
    size: CGSize = HostedViewHarness.defaultSize,
    @ViewBuilder content: () -> Content
  ) {
    self.init(content(), size: size)
  }

  /// Makes SwiftUI update the view now, with no run loop turn and no clock.
  ///
  /// The pass lays out the hosting view and its subviews, and then displays
  /// the window. The layout pass of the hosting view applies each pending
  /// change of the observed values to the view graph, so the accessibility
  /// tree shows the change when the function returns.
  ///
  /// Result of the check in `HostedViewHarnessRenderTests`: after a change
  /// of an `@Observable` model, this pass alone, with no run loop turn, puts
  /// the new text in the accessibility tree. After the press action
  /// (`accessibilityPerformPress`) of a button, the action has run, and this
  /// pass alone puts its result in the accessibility tree. Thus a test that
  /// changes a model on the main actor calls this function and reads the
  /// tree at once. A change that comes from asynchronous work, such as a
  /// frame of an agent, is not there yet: use ``render(when:)`` for it.
  public func render() {
    hostingView.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
  }

  /// Waits until `condition` is `true`, and then makes SwiftUI update the
  /// view with ``render()``.
  ///
  /// Use this function after an action that starts asynchronous work, for
  /// example a request to the scripted agent. The wait is
  /// ``ObservationWait/until(_:)``: it has no clock and no time limit, and it
  /// does not poll. Thus `condition` must read observable model values that
  /// are certain to change, such as the transcript of a `SessionModel`. Do
  /// not read the accessibility tree in `condition`: the tree is not
  /// observable, so the wait does not see its changes.
  ///
  /// - Parameter condition: The condition on the model values to wait for.
  public func render(when condition: @MainActor () -> Bool) async {
    await ObservationWait.until(condition)
    render()
  }

  /// Whether the test process has the keyboard focus of the user.
  ///
  /// The process has the focus when it is the active application, when AppKit
  /// gives it a key window, or when the harness window is the key window. A
  /// test of the AVK-12 rule expects `false`.
  ///
  /// The property reads `NSApplication.keyWindow`, the window that AppKit
  /// sends key events to. It does not read the `isKeyWindow` value of each
  /// window in `NSApplication.windows`: AppKit makes private windows whose
  /// class overrides `isKeyWindow`. For example, a timer of
  /// `NSTextInputContext` makes `NSCampoLightweightUIHostWindow` for the
  /// Writing Tools affordance of a focused text view. That window has no size
  /// and is never visible, and the application has no key window, but its
  /// `isKeyWindow` is `true`. A check of each window then fails at times that
  /// the tests do not control (^y2wzhsz).
  public var processHasFocus: Bool {
    let application = NSApplication.shared
    return application.isActive || application.keyWindow != nil || window.isKeyWindow
  }

  /// Closes the window.
  public func close() {
    window.close()
  }

  // MARK: - Accessibility

  /// A copy of each accessibility element under the hosting view, in depth
  /// first order. The hosting view itself is not in the list.
  ///
  /// - Returns: The flattened list of element copies.
  public func accessibilityElements() -> [AccessibilityElementSnapshot] {
    liveElements().map { Self.snapshot(of: $0, includingLinks: true) }
  }

  /// A copy of each accessibility element under the hosting view, in depth
  /// first order of the navigation order of each element: the order that
  /// VoiceOver reads. The hosting view itself is not in the list.
  ///
  /// The navigation order can differ from the order of
  /// ``accessibilityElements()``. For example, SwiftUI puts a top bar after
  /// its content in the children of an element, but VoiceOver reads the bar
  /// first. A test of the reading order uses this function.
  ///
  /// - Returns: The flattened list of element copies.
  public func accessibilityElementsInNavigationOrder() -> [AccessibilityElementSnapshot] {
    Self.descendants(of: hostingView, reading: Self.navigationChildren(of:)).map {
      Self.snapshot(of: $0, includingLinks: true)
    }
  }

  /// A copy of the first accessibility element with `identifier`.
  ///
  /// - Parameter identifier: The accessibility identifier to find.
  /// - Returns: The copy, or `nil` when no element has `identifier`.
  public func element(identifier: String) -> AccessibilityElementSnapshot? {
    liveElement(identifier: identifier).map { Self.snapshot(of: $0, includingLinks: true) }
  }

  /// A copy of each accessibility element under the first element with
  /// `identifier`, in depth first order.
  ///
  /// A test uses this function to learn that two elements are in one
  /// container, for example the controls in one group of floating controls.
  /// The element with `identifier` itself is not in the list.
  ///
  /// - Parameter identifier: The accessibility identifier of the container.
  /// - Returns: The flattened list of element copies, or an empty list when
  ///   no element has `identifier`.
  public func elements(under identifier: String) -> [AccessibilityElementSnapshot] {
    guard let container = liveElement(identifier: identifier) else { return [] }
    return Self.descendants(of: container).map { Self.snapshot(of: $0, includingLinks: true) }
  }

  /// Whether an accessibility element under the hosting view has the label
  /// `label`.
  ///
  /// The label must be equal to `label`. A label that only contains `label`
  /// does not match.
  ///
  /// - Parameter label: The accessibility label to find.
  /// - Returns: `true` when an element has the label `label`.
  public func hasElement(label: String) -> Bool {
    accessibilityElements().contains { $0.label == label }
  }

  /// The frame of the first accessibility element with `identifier`.
  ///
  /// The frame is the area that the element has on the screen now, in
  /// screen points. The y axis goes up. The frame of a row in a scroll view
  /// moves when the view scrolls, so a test can compare it with the frame of
  /// the scroll view to learn if the row is in view.
  ///
  /// - Parameter identifier: The accessibility identifier to find.
  /// - Returns: The frame, or `nil` when no element has `identifier`.
  public func frame(identifier: String) -> CGRect? {
    liveElement(identifier: identifier).map(Self.frame(of:))
  }

  /// Mounts `content`, makes one ``render()`` pass, and gives the height of
  /// the first accessibility element with `identifier`. The harness closes
  /// before the function returns.
  ///
  /// A test uses this function to compare the height of one element in two
  /// environments, for example with and without an EditorKit theme.
  ///
  /// - Parameters:
  ///   - content: The view to mount, with its environment.
  ///   - identifier: The accessibility identifier of the element to measure.
  ///   - size: The size of the content.
  /// - Returns: The height of the frame of the element, in points.
  /// - Throws: ``HostedViewHarnessError/noElement(identifier:)`` when no
  ///   element has `identifier`.
  public static func frameHeight(
    of content: Content, identifier: String, size: CGSize = HostedViewHarness.defaultSize
  ) throws -> CGFloat {
    let harness = HostedViewHarness(content, size: size)
    defer { harness.close() }
    harness.render()
    guard let frame = harness.frame(identifier: identifier) else {
      throw HostedViewHarnessError.noElement(identifier: identifier)
    }
    return frame.height
  }

  /// Does the press action of the element with `identifier`, then makes a
  /// ``render()`` pass.
  ///
  /// Do not use this function on a segment of a segmented `Picker`. The
  /// AppKit segmented control does the press, but it reports a failure, and
  /// it can stop the test process after the test, as a stepper does. Then the
  /// process exits before the other tests run.
  ///
  /// - Parameter identifier: The accessibility identifier of the element.
  /// - Throws: ``HostedViewHarnessError/noElement(identifier:)`` when no
  ///   element has `identifier`, and
  ///   ``HostedViewHarnessError/pressFailed(identifier:)`` when the element
  ///   does not do the action.
  public func press(identifier: String) throws {
    try perform(
      on: identifier, action: Self.performPress, failure: HostedViewHarnessError.pressFailed)
  }

  /// Does the increment action of the element with `identifier`, then makes
  /// a ``render()`` pass.
  ///
  /// A slider does the increment action. Do not use this function on a
  /// stepper: an AppKit stepper shows the increment with a blocking
  /// animation on a background thread, and that animation can stop the main
  /// run loop of the test process after the test. Then the process exits
  /// before the other tests run.
  ///
  /// - Parameter identifier: The accessibility identifier of the element.
  /// - Throws: ``HostedViewHarnessError/noElement(identifier:)`` when no
  ///   element has `identifier`, and
  ///   ``HostedViewHarnessError/incrementFailed(identifier:)`` when the
  ///   element does not do the action.
  public func increment(identifier: String) throws {
    try perform(
      on: identifier, action: Self.performIncrement,
      failure: HostedViewHarnessError.incrementFailed)
  }

  /// Does `action` on the element with `identifier`, then makes a
  /// ``render()`` pass.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the element.
  ///   - action: The function that does the action and tells whether the
  ///     element did it.
  ///   - failure: The function that makes the error for an element that did
  ///     not do the action.
  /// - Throws: ``HostedViewHarnessError/noElement(identifier:)`` when no
  ///   element has `identifier`, and the error of `failure` when the element
  ///   does not do the action.
  private func perform(
    on identifier: String,
    action: (NSObject) -> Bool,
    failure: (String) -> HostedViewHarnessError
  ) throws {
    guard let element = liveElement(identifier: identifier) else {
      throw HostedViewHarnessError.noElement(identifier: identifier)
    }
    guard action(element) else {
      throw failure(identifier)
    }
    render()
  }

  // MARK: - Keyboard

  /// Sends a key-down and a key-up event for each character of `text` to
  /// the window, then makes a ``render()`` pass.
  ///
  /// The events go to the first responder of the window, as typed keys do.
  ///
  /// - Parameter text: The text to type.
  public func type(_ text: String) {
    for character in text {
      postKey(characters: String(character), keyCode: HarnessConstants.printableKeyCode, modifiers: [])
    }
    render()
  }

  /// Sends a key-down and a key-up event for `key` with `modifiers` to the
  /// window, then makes a ``render()`` pass.
  ///
  /// - Parameters:
  ///   - key: The key to send.
  ///   - modifiers: The modifier keys to hold.
  /// - Throws: ``HostedViewHarnessError/unsupportedKey(_:)`` for a special
  ///   key that the harness has no key code for.
  public func sendKey(_ key: KeyEquivalent, modifiers: SwiftUI.EventModifiers = []) throws {
    let characters = String(key.character)
    guard let keyCode = Self.keyCode(for: key) else {
      throw HostedViewHarnessError.unsupportedKey(characters)
    }
    postKey(characters: characters, keyCode: keyCode, modifiers: Self.modifierFlags(for: modifiers))
    render()
  }

  /// Sends a key-down event for `key` with `modifiers` straight to the
  /// `keyDown(with:)` method of `view`, then makes a ``render()`` pass.
  ///
  /// The event does not go through the window, so SwiftUI key press
  /// handlers do not see it. Use this function to test the key handling of
  /// an AppKit text view.
  ///
  /// - Parameters:
  ///   - key: The key to send.
  ///   - modifiers: The modifier keys to hold.
  ///   - view: The view that gets the event.
  /// - Throws: ``HostedViewHarnessError/unsupportedKey(_:)`` for a special
  ///   key that the harness has no key code for.
  public func sendKeyDown(
    _ key: KeyEquivalent, modifiers: SwiftUI.EventModifiers = [], to view: NSView
  ) throws {
    let characters = String(key.character)
    guard let keyCode = Self.keyCode(for: key),
      let event = keyEvent(
        .keyDown, characters: characters, keyCode: keyCode, modifiers: Self.modifierFlags(for: modifiers))
    else {
      throw HostedViewHarnessError.unsupportedKey(characters)
    }
    view.keyDown(with: event)
    render()
  }

  // MARK: - Mouse

  /// Sends a mouse-down and a mouse-up event at `point` to the view under
  /// the point, then makes a ``render()`` pass.
  ///
  /// The window is never on the screen, so `NSWindow.sendEvent(_:)` drops a
  /// mouse event (AVK-12). The harness finds the view under the point with
  /// a hit test, as the window does, and sends each event straight to that
  /// view.
  ///
  /// - Parameter point: The point in the coordinates of the window.
  /// - Throws: ``HostedViewHarnessError/noView(at:)`` when no view of the
  ///   hosting view is under `point`.
  public func click(at point: NSPoint) throws {
    let location = hostingView.superview?.convert(point, from: nil) ?? point
    guard let target = hostingView.hitTest(location) else {
      throw HostedViewHarnessError.noView(at: point)
    }
    if let down = mouseEvent(.leftMouseDown, at: point) {
      target.mouseDown(with: down)
    }
    if let up = mouseEvent(.leftMouseUp, at: point) {
      target.mouseUp(with: up)
    }
    render()
  }

  // MARK: - Private

  /// The application attribute that an assistive client sets to ask for the
  /// full accessibility tree.
  private static var enhancedUserInterfaceAttribute: String { "AXEnhancedUserInterface" }

  /// The selector of the attribute setter that an assistive client calls.
  ///
  /// The Swift form of this setter is deprecated. The `NSAccessibility`
  /// protocol has no replacement for an attribute without a name in the
  /// protocol, so the harness sends the selector.
  private static var setAttributeSelector: Selector {
    NSSelectorFromString("accessibilitySetValue:forAttribute:")
  }

  /// Keeps the test process out of the focus, and makes SwiftUI build its
  /// accessibility tree in this process.
  ///
  /// The `.prohibited` activation policy stops the process from becoming the
  /// active application, so a test does not take the focus from the user.
  /// The harness sets the policy before it makes the first window (AVK-12).
  ///
  /// SwiftUI builds the tree only after an assistive client connects. Before
  /// that, `NSHostingView.accessibilityChildren()` is empty. The harness sets
  /// the `AXEnhancedUserInterface` attribute on the application, as an
  /// assistive client does. Then SwiftUI builds the tree for each hosting
  /// view. The call needs no accessibility permission.
  private static func prepareApplication() {
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)
    _ = application.perform(
      setAttributeSelector, with: NSNumber(value: true), with: enhancedUserInterfaceAttribute)
  }

  /// Gives the first key view of the hosting view the keyboard focus.
  ///
  /// A key window gives its first key view the keyboard focus. This window
  /// never becomes the key window, so the harness does the same step. Then a
  /// focusable view, such as a request card, gets Esc (AVK-12).
  private func selectFirstKeyView() {
    window.selectKeyView(following: hostingView)
  }

  /// The live accessibility elements under the hosting view, in depth first
  /// order.
  ///
  /// - Returns: The flattened list of live elements.
  private func liveElements() -> [NSObject] {
    Self.descendants(of: hostingView)
  }

  /// The live accessibility elements under `root`, in depth first order.
  /// `root` itself is not in the list.
  ///
  /// - Parameters:
  ///   - root: The element whose subtree the function reads.
  ///   - read: The read of the children of an element, in the order of the
  ///     walk. The default read gives the `accessibilityChildren` order.
  /// - Returns: The flattened list of live elements.
  private static func descendants(
    of root: NSObject, reading read: @MainActor (NSObject) -> [NSObject] = children(of:)
  ) -> [NSObject] {
    var result: [NSObject] = []
    for child in read(root) {
      collect(child, depth: 0, reading: read, into: &result)
    }
    return result
  }

  /// The first live element with `identifier`.
  ///
  /// - Parameter identifier: The identifier to find.
  /// - Returns: The element, or `nil`.
  private func liveElement(identifier: String) -> NSObject? {
    liveElements().first { Self.identifier(of: $0) == identifier }
  }

  /// Adds `element` and each element under it to `result`.
  ///
  /// - Parameters:
  ///   - element: The element to add.
  ///   - depth: The depth of `element` under the hosting view.
  ///   - read: The read of the children of an element, in the order of the
  ///     walk.
  ///   - result: The list to add to.
  private static func collect(
    _ element: NSObject, depth: Int, reading read: @MainActor (NSObject) -> [NSObject],
    into result: inout [NSObject]
  ) {
    guard depth < HarnessConstants.maximumDepth else { return }
    result.append(element)
    for child in read(element) {
      collect(child, depth: depth + 1, reading: read, into: &result)
    }
  }

  // MARK: - Element reads
  //
  // A SwiftUI accessibility node answers each `NSAccessibilityProtocol`
  // selector, but it declares only `NSAccessibilityElementProtocol`. A cast
  // to `NSAccessibilityProtocol` fails for the node. The reads below send
  // the selectors through Objective-C dynamic lookup, so that they work for
  // a SwiftUI node and for an `NSView`. An element that does not answer a
  // selector gives `nil`.

  /// The accessibility children of `element`.
  ///
  /// - Parameter element: The parent element.
  /// - Returns: The children that are Objective-C objects.
  private static func children(of element: NSObject) -> [NSObject] {
    let children: [Any]? =
      (element as AnyObject).accessibilityChildren?() ?? nil
      ?? legacyAttribute(NSAccessibility.Attribute.children.rawValue, of: element) as? [Any]
    return (children ?? []).compactMap { $0 as? NSObject }
  }

  /// The selector of the getter of the children in navigation order.
  ///
  /// The typed Swift form of this getter traps when an element is not an
  /// `NSAccessibilityElementProtocol` value, so the harness sends the
  /// selector.
  private static var navigationOrderSelector: Selector {
    NSSelectorFromString("accessibilityChildrenInNavigationOrder")
  }

  /// The accessibility children of `element` in navigation order: the order
  /// that VoiceOver reads them in.
  ///
  /// SwiftUI gives this order from the places of the views. For example, a
  /// top bar (`.safeAreaBar(edge: .top)`) comes after its content in
  /// ``children(of:)``, but before it in navigation order.
  ///
  /// - Parameter element: The parent element.
  /// - Returns: The children in navigation order, or ``children(of:)`` when
  ///   the element gives no navigation order.
  private static func navigationChildren(of element: NSObject) -> [NSObject] {
    guard element.responds(to: navigationOrderSelector),
      let ordered = element.perform(navigationOrderSelector)?.takeUnretainedValue() as? [Any]
    else {
      return children(of: element)
    }
    return ordered.compactMap { $0 as? NSObject }
  }

  /// The selector of the attribute getter of the informal accessibility
  /// protocol.
  ///
  /// The Swift form of this getter is deprecated. The row and cell elements
  /// of an `NSOutlineView`, which a SwiftUI `List` uses, answer only this
  /// getter, so the harness sends the selector.
  private static var attributeValueSelector: Selector {
    NSSelectorFromString("accessibilityAttributeValue:")
  }

  /// The value of the attribute `name` of `element`, read with the getter of
  /// the informal accessibility protocol.
  ///
  /// - Parameters:
  ///   - name: The name of the attribute, such as `AXChildren`.
  ///   - element: The element.
  /// - Returns: The value, or `nil` when the element does not answer the
  ///   getter or has no value.
  private static func legacyAttribute(_ name: String, of element: NSObject) -> Any? {
    guard element.responds(to: attributeValueSelector) else { return nil }
    return element.perform(attributeValueSelector, with: name)?.takeUnretainedValue()
  }

  /// The elements that `element` links to.
  ///
  /// - Parameter element: The element.
  /// - Returns: The linked elements that are Objective-C objects.
  private static func linkedElements(of element: NSObject) -> [NSObject] {
    let linked: [Any]? = (element as AnyObject).accessibilityLinkedUIElements?() ?? nil
    return (linked ?? []).compactMap { $0 as? NSObject }
  }

  /// The accessibility identifier of `element`.
  ///
  /// - Parameter element: The element.
  /// - Returns: The identifier, or `nil` when it is missing or empty.
  private static func identifier(of element: NSObject) -> String? {
    attributeText(identifierSelector, of: element)
  }

  /// The text that a getter of `element` returns.
  ///
  /// - Parameters:
  ///   - selector: The selector of the getter.
  ///   - element: The element.
  /// - Returns: The ``text(of:)`` form of the object that
  ///   ``objectAttribute(_:of:)`` returns.
  private static func attributeText(_ selector: Selector, of element: NSObject) -> String? {
    text(of: objectAttribute(selector, of: element))
  }

  /// The selector of the accessibility label getter.
  private static var labelSelector: Selector { NSSelectorFromString("accessibilityLabel") }

  /// The selector of the accessibility title getter.
  private static var titleSelector: Selector { NSSelectorFromString("accessibilityTitle") }

  /// The selector of the accessibility identifier getter.
  private static var identifierSelector: Selector {
    NSSelectorFromString("accessibilityIdentifier")
  }

  /// The object that a getter of `element` returns, with no cast.
  ///
  /// A text getter of some elements, such as the menu button of a SwiftUI
  /// `Menu`, returns an attributed string. A read through a typed `String`
  /// getter then stops the process. This function returns the object as it
  /// is, so that ``text(of:)`` can convert it.
  ///
  /// - Parameters:
  ///   - selector: The selector of the getter.
  ///   - element: The element.
  /// - Returns: The object, or `nil` when the element does not answer the
  ///   getter or returns `nil`.
  private static func objectAttribute(_ selector: Selector, of element: NSObject) -> Any? {
    guard element.responds(to: selector) else { return nil }
    return element.perform(selector)?.takeUnretainedValue()
  }

  /// The accessibility frame of `element`, in screen points.
  ///
  /// - Parameter element: The element.
  /// - Returns: The frame, or `CGRect.zero` when the element does not answer
  ///   the getter.
  private static func frame(of element: NSObject) -> CGRect {
    (element as AnyObject).accessibilityFrame?() ?? .zero
  }

  /// Does the press action of `element`.
  ///
  /// - Parameter element: The element.
  /// - Returns: `true` when the element did the action.
  private static func performPress(on element: NSObject) -> Bool {
    (element as AnyObject).accessibilityPerformPress?() ?? false
  }

  /// Does the increment action of `element`.
  ///
  /// - Parameter element: The element.
  /// - Returns: `true` when the element did the action.
  private static func performIncrement(on element: NSObject) -> Bool {
    (element as AnyObject).accessibilityPerformIncrement?() ?? false
  }

  /// A value copy of `element`.
  ///
  /// - Parameters:
  ///   - element: The live element.
  ///   - includingLinks: Whether to copy the linked elements.
  /// - Returns: The copy.
  private static func snapshot(of element: NSObject, includingLinks: Bool)
    -> AccessibilityElementSnapshot
  {
    let object = element as AnyObject
    let role: NSAccessibility.Role? = object.accessibilityRole?() ?? nil
    let value = text(of: object.accessibilityValue?() ?? nil)
    let label = attributeText(labelSelector, of: element)
    let title = attributeText(titleSelector, of: element)
    let isEnabled: Bool = object.isAccessibilityEnabled?() ?? true
    let links =
      includingLinks
      ? linkedElements(of: element).map { snapshot(of: $0, includingLinks: false) }
      : []
    return AccessibilityElementSnapshot(
      role: role?.rawValue,
      label: nonEmpty(label) ?? nonEmpty(title) ?? (role == .staticText ? value : nil),
      value: value,
      identifier: identifier(of: element),
      isEnabled: isEnabled,
      linkedElements: links
    )
  }

  /// `string`, or `nil` when it is empty.
  ///
  /// - Parameter string: The string to check.
  /// - Returns: `string` when it has a character, otherwise `nil`.
  private static func nonEmpty(_ string: String?) -> String? {
    guard let string, !string.isEmpty else { return nil }
    return string
  }

  /// The text form of an accessibility value.
  ///
  /// - Parameter value: The value.
  /// - Returns: The string, an attributed string's text, or a number's
  ///   description. `nil` for an empty or missing value.
  private static func text(of value: Any?) -> String? {
    switch value {
    case let string as String:
      nonEmpty(string)
    case let attributed as NSAttributedString:
      nonEmpty(attributed.string)
    case let number as NSNumber:
      number.stringValue
    default:
      nil
    }
  }

  /// Makes a key-down and a key-up event and sends them to the window.
  ///
  /// - Parameters:
  ///   - characters: The characters of the key.
  ///   - keyCode: The virtual key code.
  ///   - modifiers: The modifier flags.
  private func postKey(characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
    settleFocus()
    for type in [NSEvent.EventType.keyDown, .keyUp] {
      if let event = keyEvent(type, characters: characters, keyCode: keyCode, modifiers: modifiers) {
        window.sendEvent(event)
      }
    }
  }

  /// Lets SwiftUI apply a pending focus change, with one pass of the main
  /// run loop that does not wait.
  ///
  /// SwiftUI applies a focus request, for example an `@FocusState` value that
  /// `onAppear` sets, in a later turn of the run loop. Before that turn, an
  /// `onKeyPress` handler does not get a key event. The pass handles only the
  /// sources that are ready now, and it returns at once, because its limit
  /// date is in the past. It has no clock and does not wait. This function is
  /// the one run loop pass of the harness (AVK-12).
  private func settleFocus() {
    RunLoop.main.run(mode: .default, before: .distantPast)
  }

  /// Makes a key event for the window.
  ///
  /// - Parameters:
  ///   - type: The type of the event, key-down or key-up.
  ///   - characters: The characters of the key.
  ///   - keyCode: The virtual key code.
  ///   - modifiers: The modifier flags.
  /// - Returns: The event, or `nil` when AppKit cannot make it.
  private func keyEvent(
    _ type: NSEvent.EventType, characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags
  ) -> NSEvent? {
    NSEvent.keyEvent(
      with: type,
      location: .zero,
      modifierFlags: modifiers,
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: window.windowNumber,
      context: nil,
      characters: characters,
      charactersIgnoringModifiers: characters,
      isARepeat: false,
      keyCode: keyCode
    )
  }

  /// Makes a mouse event of one click for the window.
  ///
  /// - Parameters:
  ///   - type: The type of the event, mouse-down or mouse-up.
  ///   - point: The point in the coordinates of the window.
  /// - Returns: The event, or `nil` when AppKit cannot make it.
  private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint) -> NSEvent? {
    NSEvent.mouseEvent(
      with: type,
      location: point,
      modifierFlags: [],
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: window.windowNumber,
      context: nil,
      eventNumber: 0,
      clickCount: 1,
      pressure: 1
    )
  }

  /// The virtual key code of `key`.
  ///
  /// A function key, such as Home or F1, has a character in the Unicode
  /// private use area. The harness sends only the function keys in
  /// `HarnessConstants.specialKeyCodes`.
  ///
  /// - Parameter key: The key.
  /// - Returns: The code of a special key, the printable key code for a
  ///   printable character, or `nil` for another special key.
  private static func keyCode(for key: KeyEquivalent) -> UInt16? {
    if let code = HarnessConstants.specialKeyCodes[key.character] {
      return UInt16(code)
    }
    let isFunctionKey = key.character.unicodeScalars.contains {
      [.privateUse, .control].contains($0.properties.generalCategory)
    }
    return isFunctionKey ? nil : HarnessConstants.printableKeyCode
  }

  /// The AppKit flags of SwiftUI `modifiers`.
  ///
  /// - Parameter modifiers: The SwiftUI modifiers.
  /// - Returns: The AppKit flags.
  private static func modifierFlags(for modifiers: SwiftUI.EventModifiers) -> NSEvent.ModifierFlags {
    var flags: NSEvent.ModifierFlags = []
    if modifiers.contains(.command) { flags.insert(.command) }
    if modifiers.contains(.shift) { flags.insert(.shift) }
    if modifiers.contains(.option) { flags.insert(.option) }
    if modifiers.contains(.control) { flags.insert(.control) }
    if modifiers.contains(.capsLock) { flags.insert(.capsLock) }
    return flags
  }
}

/// A window that can be the key window with no title bar, so that SwiftUI
/// gives the focus to the hosted view.
private final class KeyableWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}
