import SwiftUI

/// The record of a ``SlotProbe``: whether the slot showed the probe, and the
/// text that the slot gave to it.
@MainActor final class SlotProbeRecord {
  /// Whether a slot showed the probe.
  var isShown = false

  /// The text that the slot gave to the probe, or `nil`.
  var text: String?
}

/// A view that a test puts in a slot of the thread, and that records when
/// the slot shows it.
///
/// The probe records in `onChange(of:initial:)`, not in its body, so a
/// layout pass of a host with no window records it one time.
struct SlotProbe: View {
  /// The record that gets the show.
  let record: SlotProbeRecord

  /// The text that the slot gave to the probe, or `nil`.
  var text: String?

  var body: some View {
    Color.clear
      .onChange(of: text, initial: true) {
        record.isShown = true
        record.text = text
      }
  }
}
