import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI

extension HostedViewHarness {
  /// The label of the ``StateBanner`` that the harness shows.
  ///
  /// The value is `nil` when the banner does not show.
  var stateBannerLabel: String? {
    element(identifier: StateBanner.bannerIdentifier)?.label
  }
}
