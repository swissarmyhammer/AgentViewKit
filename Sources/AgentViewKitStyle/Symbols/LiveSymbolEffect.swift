import EditorStyle
import SwiftUI

/// The symbol effect of a status that goes on, with the Reduce Motion rule of
/// the view kits.
///
/// While `isActive` is `true`, the symbol shows the iterative variable color
/// effect. Under Reduce Motion, the modifier removes each symbol effect of
/// its content, also the effects that the caller applies before this
/// modifier, so the symbol does not move. An ongoing message of a
/// ``StatusBar``, and in AgentViewKit a pending or running tool call and a
/// plan entry in progress, show their symbols with this modifier, so the
/// effect and the Reduce Motion rule are written one time.
public struct LiveSymbolEffect: ViewModifier {
  /// `true` while the status of the symbol goes on.
  let isActive: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Makes the live symbol effect.
  ///
  /// - Parameter isActive: `true` while the status of the symbol goes on.
  public init(isActive: Bool) {
    self.isActive = isActive
  }

  /// Shows the effect on `content` while the status goes on.
  ///
  /// - Parameter content: The symbol.
  /// - Returns: The symbol with the effect, or with no effect under Reduce
  ///   Motion.
  public func body(content: Content) -> some View {
    content
      .symbolEffect(.variableColor.iterative, isActive: isActive)
      .symbolEffectsRemoved(reduceMotion)
  }
}

extension View {
  /// Shows the live symbol effect of ``LiveSymbolEffect`` on this symbol, and
  /// removes the symbol effects of this symbol under Reduce Motion.
  ///
  /// - Parameter isActive: `true` while the status of the symbol goes on.
  /// - Returns: The symbol with the effect.
  public func liveSymbolEffect(isActive: Bool) -> some View {
    modifier(LiveSymbolEffect(isActive: isActive))
  }
}

#Preview("A live and a settled symbol") {
  HStack(spacing: EditorStyle.default.spacing.m) {
    ForEach([true, false], id: \.self) { isActive in
      StatusSymbolImage(name: ItemStatus.inProgress.systemImage, color: .secondary)
        .liveSymbolEffect(isActive: isActive)
    }
  }
  .padding()
}
