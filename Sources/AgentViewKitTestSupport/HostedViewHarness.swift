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
}

/// The fixed values of ``HostedViewHarness``.
///
/// A generic type cannot hold a stored static property, so the values are
/// in this separate type.
private enum HarnessConstants {
  /// The default time that ``HostedViewHarness/pump(for:)`` runs the run
  /// loop, in seconds.
  static let defaultPumpDuration: TimeInterval = 0.05

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
/// of an `NSWindow` that is not on a screen. A `swift test` process needs no
/// application bundle for this. The test calls ``pump(for:)`` after a change,
/// so that SwiftUI can update the view, and calls ``close()`` at the end.
public final class HostedViewHarness<Content: View> {
  /// The default time that ``pump(for:)`` runs the run loop.
  public static var defaultPumpDuration: TimeInterval { HarnessConstants.defaultPumpDuration }

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
  /// - Parameters:
  ///   - content: The view to mount.
  ///   - size: The size of the content.
  public init(_ content: Content, size: CGSize = HostedViewHarness.defaultSize) {
    Self.enableAccessibilityTree()
    let frame = NSRect(origin: .zero, size: size)
    hostingView = NSHostingView(rootView: content)
    hostingView.frame = frame
    window = KeyableWindow(
      contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
    // ARC owns the window. The default value would release it a second time.
    window.isReleasedWhenClosed = false
    window.contentView = hostingView
    window.setFrameOrigin(HarnessConstants.offScreenOrigin)
    window.makeKeyAndOrderFront(nil)
    hostingView.layoutSubtreeIfNeeded()
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

  /// Runs the main run loop for `duration`, so that SwiftUI can update the
  /// view.
  ///
  /// - Parameter duration: The time to run the run loop, in seconds.
  public func pump(for duration: TimeInterval = HostedViewHarness.defaultPumpDuration) {
    let deadline = Date(timeIntervalSinceNow: duration)
    while Date() < deadline {
      RunLoop.main.run(mode: .default, before: deadline)
    }
    hostingView.layoutSubtreeIfNeeded()
  }

  /// Removes the window from the screen list and closes it.
  public func close() {
    window.orderOut(nil)
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

  /// A copy of the first accessibility element with `identifier`.
  ///
  /// - Parameter identifier: The accessibility identifier to find.
  /// - Returns: The copy, or `nil` when no element has `identifier`.
  public func element(identifier: String) -> AccessibilityElementSnapshot? {
    liveElement(identifier: identifier).map { Self.snapshot(of: $0, includingLinks: true) }
  }

  /// Does the press action of the element with `identifier`, then pumps the
  /// run loop.
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

  /// Does the increment action of the element with `identifier`, then pumps
  /// the run loop.
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

  /// Does `action` on the element with `identifier`, then pumps the run
  /// loop.
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
    pump()
  }

  // MARK: - Keyboard

  /// Sends a key-down and a key-up event for each character of `text` to
  /// the window, then pumps the run loop.
  ///
  /// The events go to the first responder of the window, as typed keys do.
  ///
  /// - Parameter text: The text to type.
  public func type(_ text: String) {
    for character in text {
      postKey(characters: String(character), keyCode: HarnessConstants.printableKeyCode, modifiers: [])
    }
    pump()
  }

  /// Sends a key-down and a key-up event for `key` with `modifiers` to the
  /// window, then pumps the run loop.
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
    pump()
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

  /// Makes SwiftUI build its accessibility tree in this process.
  ///
  /// SwiftUI builds the tree only after an assistive client connects. Before
  /// that, `NSHostingView.accessibilityChildren()` is empty. The harness sets
  /// the `AXEnhancedUserInterface` attribute on the application, as an
  /// assistive client does. Then SwiftUI builds the tree for each hosting
  /// view. The call needs no accessibility permission.
  private static func enableAccessibilityTree() {
    let application = NSApplication.shared
    application.setActivationPolicy(.accessory)
    _ = application.perform(
      setAttributeSelector, with: NSNumber(value: true), with: enhancedUserInterfaceAttribute)
  }

  /// The live accessibility elements under the hosting view, in depth first
  /// order.
  ///
  /// - Returns: The flattened list of live elements.
  private func liveElements() -> [NSObject] {
    var result: [NSObject] = []
    for child in Self.children(of: hostingView) {
      Self.collect(child, depth: 0, into: &result)
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
  ///   - result: The list to add to.
  private static func collect(_ element: NSObject, depth: Int, into result: inout [NSObject]) {
    guard depth < HarnessConstants.maximumDepth else { return }
    result.append(element)
    for child in children(of: element) {
      collect(child, depth: depth + 1, into: &result)
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
    text(of: objectAttribute(identifierSelector, of: element))
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
    let label = text(of: objectAttribute(labelSelector, of: element))
    let title = text(of: objectAttribute(titleSelector, of: element))
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
    for type in [NSEvent.EventType.keyDown, .keyUp] {
      let event = NSEvent.keyEvent(
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
      if let event {
        window.sendEvent(event)
      }
    }
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

/// A window that can be the key window with a title bar or not, so that
/// SwiftUI gives the focus to the hosted view.
private final class KeyableWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}
