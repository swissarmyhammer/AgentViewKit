import AppKit
import ObjectiveC

/// Counts the text layouts of SwiftUI `Text` on the main thread, by text
/// (card ^9ync5h3).
///
/// SwiftUI lays out a `Text` with TextKit 2: each new measure of a `Text`
/// calls `ensureLayout(for:)` on an `NSTextLayoutManager` that holds the
/// string of the `Text`. A measure that SwiftUI takes from its cache makes no
/// such call. The probe replaces that method one time in the process with a
/// block that records the call, and then calls the old method. The probe
/// counts only the calls on the main thread of a layout manager with no text
/// view: an EditorKit editor has a text view, and the height worker of a
/// thread lays out off the main thread.
///
/// Tests run at the same time in one process, so a test watches a part of a
/// text of its own (``watch(_:)``), and counts only the layouts of the texts
/// that hold it (``layouts(ofTextContaining:)``). The record keeps each
/// layout manager of a watched text, so a new manager never takes the
/// identity of an old one.
@MainActor enum TextLayoutProbe {
  /// The selector of the method that the probe counts.
  static let selectorName = "ensureLayoutForRange:"

  /// The text of each layout that the probe counted, in the order of the
  /// layouts, with the layout manager that made it.
  private static var records: [Record] = []

  /// Whether the probe replaced the method.
  private static var isInstalled = false

  /// The parts of the texts whose layouts the probe records.
  private static var watched: Set<String> = []

  /// One counted layout.
  struct Record {
    /// The layout manager of the layout.
    let manager: NSTextLayoutManager

    /// The text of the layout manager.
    let text: String
  }

  /// Records from now on the layouts of the texts that hold `fragment`,
  /// and installs the probe.
  ///
  /// - Parameter fragment: A part of the text, which only the texts of the
  ///   test hold.
  static func watch(_ fragment: String) {
    install()
    watched.insert(fragment)
  }

  /// Replaces the method one time in the process. Later calls do nothing.
  private static func install() {
    guard !isInstalled else { return }
    isInstalled = true
    let selector = NSSelectorFromString(selectorName)
    guard let method = class_getInstanceMethod(NSTextLayoutManager.self, selector) else {
      preconditionFailure("NSTextLayoutManager has no \(selectorName)")
    }
    typealias Implementation = @convention(c) (AnyObject, Selector, AnyObject) -> Void
    let old = unsafeBitCast(method_getImplementation(method), to: Implementation.self)
    let block: @convention(block) (AnyObject, AnyObject) -> Void = { manager, range in
      if Thread.isMainThread, let manager = manager as? NSTextLayoutManager {
        MainActor.assumeIsolated { note(manager) }
      }
      old(manager, selector, range)
    }
    method_setImplementation(method, imp_implementationWithBlock(block))
  }

  /// Records a layout of a manager with no text view and with a watched
  /// text.
  ///
  /// - Parameter manager: The layout manager.
  private static func note(_ manager: NSTextLayoutManager) {
    guard manager.textContainer?.textView == nil else { return }
    let storage = manager.textContentManager as? NSTextContentStorage
    let text = storage?.attributedString?.string ?? ""
    guard watched.contains(where: text.contains) else { return }
    records.append(Record(manager: manager, text: text))
  }

  /// The counted layouts of the texts that hold `fragment`.
  ///
  /// - Parameter fragment: A part of the text, which only the texts of the
  ///   test hold.
  /// - Returns: The layouts, in their order.
  static func layouts(ofTextContaining fragment: String) -> [Record] {
    records.filter { $0.text.contains(fragment) }
  }

  /// The number of the layouts of the texts that hold `fragment` that are
  /// not the first layout of their layout manager: the layouts that
  /// measured a text again.
  ///
  /// - Parameter fragment: A part of the text, which only the texts of the
  ///   test hold.
  /// - Returns: The number of the layouts again.
  static func repeatedLayouts(ofTextContaining fragment: String) -> Int {
    let layouts = layouts(ofTextContaining: fragment)
    return layouts.count - Set(layouts.map { ObjectIdentifier($0.manager) }).count
  }
}
