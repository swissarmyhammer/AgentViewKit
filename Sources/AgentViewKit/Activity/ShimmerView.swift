import SwiftUI

/// A label with a highlight that moves across it (plan.md §5, §9 B).
///
/// Streaming text and reasoning use this view to show that the agent works.
/// When Reduce Motion is on, the view shows a static label (plan.md §6).
///
/// VoiceOver reads the text as the label. In a `DEBUG` build, the
/// accessibility value is ``animatingValue`` or ``staticValue``, so that a
/// test can see the motion state.
public struct ShimmerView: View {
  /// The accessibility identifier of the view.
  public static let identifier = "shimmer"

  /// The accessibility value, in a `DEBUG` build, while the highlight moves.
  public static let animatingValue = "animating"

  /// The accessibility value, in a `DEBUG` build, while the label is static.
  public static let staticValue = "static"

  /// The time for one pass of the highlight, in seconds.
  static let period: TimeInterval = 1.6

  /// The half width of the highlight, as a fraction of the label width.
  static let highlightHalfWidth = 0.2

  /// The start of the gradient, as a fraction of the label width.
  static let gradientStart = 0.0

  /// The end of the gradient, as a fraction of the label width.
  static let gradientEnd = 1.0

  /// The text of the label.
  let text: String

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Makes a shimmering label.
  ///
  /// - Parameter text: The text of the label.
  public init(text: String) {
    self.text = text
  }

  /// The center of the highlight at a time, as a fraction of the label
  /// width.
  ///
  /// The center moves from one half width before the label to one half width
  /// after it, one time in each ``period``.
  ///
  /// - Parameter date: The time.
  /// - Returns: The center, from `gradientStart - highlightHalfWidth` to
  ///   `gradientEnd + highlightHalfWidth`.
  static func highlightCenter(at date: Date) -> Double {
    let elapsed = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
    let fraction = elapsed / period
    let first = gradientStart - highlightHalfWidth
    let last = gradientEnd + highlightHalfWidth
    return first + fraction * (last - first)
  }

  /// Limits a location to the gradient.
  ///
  /// The Swift 6.4 standard library has no public `Comparable.clamped(to:)`
  /// for a value. SwiftUI has one, but its access level is `package`. Thus
  /// this function uses `min` and `max`. Use the standard function when a
  /// supported Swift version makes it public.
  ///
  /// - Parameter location: A location, as a fraction of the label width.
  /// - Returns: The location, from ``gradientStart`` to ``gradientEnd``.
  static func clamped(_ location: Double) -> Double {
    min(max(location, gradientStart), gradientEnd)
  }

  /// The gradient that puts the highlight at a center.
  ///
  /// - Parameter center: The center of the highlight, as a fraction of the
  ///   label width.
  /// - Returns: A gradient with the secondary color and a primary color
  ///   highlight.
  static func gradient(center: Double) -> LinearGradient {
    LinearGradient(
      stops: [
        Gradient.Stop(color: .secondary, location: gradientStart),
        Gradient.Stop(color: .secondary, location: clamped(center - highlightHalfWidth)),
        Gradient.Stop(color: .primary, location: clamped(center)),
        Gradient.Stop(color: .secondary, location: clamped(center + highlightHalfWidth)),
        Gradient.Stop(color: .secondary, location: gradientEnd),
      ],
      startPoint: .leading,
      endPoint: .trailing
    )
  }

  public var body: some View {
    label
      .accessibilityElement(children: .combine)
      #if DEBUG
        .accessibilityValue(Text(reduceMotion ? Self.staticValue : Self.animatingValue))
      #endif
      .accessibilityIdentifier(Self.identifier)
  }

  /// The static label, or the label with the moving highlight.
  @ViewBuilder private var label: some View {
    if reduceMotion {
      Text(text)
        .foregroundStyle(.secondary)
    } else {
      TimelineView(.animation) { context in
        Text(text)
          .foregroundStyle(Self.gradient(center: Self.highlightCenter(at: context.date)))
      }
    }
  }
}
