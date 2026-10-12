import SwiftUI

/// The symbol effect of a status that goes on, with the Reduce Motion rule of
/// the kit.
///
/// While `isActive` is `true`, the symbol shows the iterative variable color
/// effect. Under Reduce Motion, the modifier removes each symbol effect of
/// its content, also the effects that the caller applies before this
/// modifier, so the symbol does not move. A pending or running tool call
/// (``ToolCallView``), a plan entry in progress (``TaskListView``) and an
/// ongoing status message (`StatusBar`) show their symbols with this
/// modifier, so the effect and the Reduce Motion rule are written one time.
struct LiveSymbolEffect: ViewModifier {
  /// `true` while the status of the symbol goes on.
  let isActive: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
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
  func liveSymbolEffect(isActive: Bool) -> some View {
    modifier(LiveSymbolEffect(isActive: isActive))
  }
}
