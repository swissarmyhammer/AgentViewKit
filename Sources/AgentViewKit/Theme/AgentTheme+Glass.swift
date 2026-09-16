import SwiftUI

extension AgentTheme.MaterialLevel {
  /// The Liquid Glass of the level, for a `glassEffect` on the chrome.
  ///
  /// SwiftUI has a regular glass and a clear glass, but no thin glass. A thin
  /// level uses the clear glass, because the clear glass shows more of the
  /// content below it.
  var glass: Glass {
    switch self {
    case .regular: .regular
    case .thin, .clear: .clear
    }
  }
}
