import AppKit
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
  ///   - linkedElements: The copies of the linked elements.
  public init(
    role: String?,
    label: String?,
    value: String?,
    identifier: String?,
    linkedElements: [AccessibilityElementSnapshot] = []
  ) {
    self.role = role
    self.label = label
    self.value = value
    self.identifier = identifier
    self.linkedElements = linkedElements
  }
}

/// The errors of ``HostedViewHarness``.
public enum HostedViewHarnessError: Error, Equatable {
  /// No accessibility element has the identifier.
  case noElement(identifier: String)
  /// The element did not do the press action.
  case pressFailed(identifier: String)
  /// The harness has no key code for the key.
  case unsupportedKey(String)
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
  public static var defaultPumpDuration: TimeInterval { 0.05 }

  /// The default size of the content.
  public static var defaultSize: CGSize { CGSize(width: 480, height: 320) }

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
    window.setFrameOrigin(Self.offScreenOrigin)
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
  /// - Parameter identifier: The accessibility identifier of the element.
  /// - Throws: ``HostedViewHarnessError/noElement(identifier:)`` when no
  ///   element has `identifier`, and
  ///   ``HostedViewHarnessError/pressFailed(identifier:)`` when the element
  ///   does not do the action.
  public func press(identifier: String) throws {
    guard let element = liveElement(identifier: identifier) else {
      throw HostedViewHarnessError.noElement(identifier: identifier)
    }
    guard Self.performPress(on: element) else {
      throw HostedViewHarnessError.pressFailed(identifier: identifier)
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
      postKey(characters: String(character), keyCode: 0, modifiers: [])
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
  public func sendKey(_ key: KeyEquivalent, modifiers: EventModifiers = []) throws {
    let characters = String(key.character)
    guard let keyCode = Self.keyCode(for: key) else {
      throw HostedViewHarnessError.unsupportedKey(characters)
    }
    postKey(characters: characters, keyCode: keyCode, modifiers: Self.modifierFlags(for: modifiers))
    pump()
  }

  // MARK: - Private

  /// The origin that puts the window outside each screen.
  private static var offScreenOrigin: NSPoint { NSPoint(x: -20_000, y: -20_000) }

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

  /// The largest depth of the accessibility tree that the harness reads.
  /// The limit stops a cycle of parent and child links.
  private static var maximumDepth: Int { 64 }

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
    guard depth < maximumDepth else { return }
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
    let children: [Any]? = (element as AnyObject).accessibilityChildren?() ?? nil
    return (children ?? []).compactMap { $0 as? NSObject }
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
    let identifier: String? = (element as AnyObject).accessibilityIdentifier?()
    return nonEmpty(identifier)
  }

  /// Does the press action of `element`.
  ///
  /// - Parameter element: The element.
  /// - Returns: `true` when the element did the action.
  private static func performPress(on element: NSObject) -> Bool {
    (element as AnyObject).accessibilityPerformPress?() ?? false
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
    let label: String? = object.accessibilityLabel?() ?? nil
    let title: String? = object.accessibilityTitle?() ?? nil
    let links =
      includingLinks
      ? linkedElements(of: element).map { snapshot(of: $0, includingLinks: false) }
      : []
    return AccessibilityElementSnapshot(
      role: role?.rawValue,
      label: nonEmpty(label) ?? nonEmpty(title) ?? (role == .staticText ? value : nil),
      value: value,
      identifier: identifier(of: element),
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

  /// The virtual key codes of the special keys, keyed by their character.
  private static var specialKeyCodes: [Character: UInt16] {
    [
      KeyEquivalent.return.character: 36,
      KeyEquivalent.tab.character: 48,
      KeyEquivalent.space.character: 49,
      KeyEquivalent.delete.character: 51,
      KeyEquivalent.escape.character: 53,
      KeyEquivalent.leftArrow.character: 123,
      KeyEquivalent.rightArrow.character: 124,
      KeyEquivalent.downArrow.character: 125,
      KeyEquivalent.upArrow.character: 126,
    ]
  }

  /// The virtual key code of `key`.
  ///
  /// - Parameter key: The key.
  /// - Returns: The code of a special key, zero for a printable character,
  ///   or `nil` for another special key.
  private static func keyCode(for key: KeyEquivalent) -> UInt16? {
    if let code = specialKeyCodes[key.character] {
      return code
    }
    let isFunctionKey = key.character.unicodeScalars.contains {
      (0xF700...0xF8FF).contains($0.value) || $0.properties.generalCategory == .control
    }
    return isFunctionKey ? nil : 0
  }

  /// The AppKit flags of SwiftUI `modifiers`.
  ///
  /// - Parameter modifiers: The SwiftUI modifiers.
  /// - Returns: The AppKit flags.
  private static func modifierFlags(for modifiers: EventModifiers) -> NSEvent.ModifierFlags {
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
