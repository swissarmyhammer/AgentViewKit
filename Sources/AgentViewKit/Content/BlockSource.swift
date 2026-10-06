/// The value that a content block view shows: a kit value of a thread
/// message, or an ACP value that a transcript entry holds.
///
/// ``ContentBlockView``, ``ImageView``, ``AudioPlayerView``, ``LinkView`` and
/// ``ResourceBlockView`` keep their input in this one type. The `record` case
/// serves only the old thread path, and goes away when the kit copies of the
/// ACP value types go away.
enum BlockSource<Record, Wire> {
  /// A kit value of a thread message.
  case record(Record)

  /// An ACP value that a transcript entry holds.
  case wire(Wire)
}

extension BlockSource: Equatable where Record: Equatable, Wire: Equatable {}

extension BlockSource: Hashable where Record: Hashable, Wire: Hashable {}
