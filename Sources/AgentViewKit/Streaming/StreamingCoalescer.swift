/// Collects streamed text chunks and flushes them as one batch at a fixed
/// cadence (plan.md §8).
///
/// A source can get many chunks in a few milliseconds. When each chunk
/// changes the streaming tail, the tail row renders one time for each chunk.
/// The coalescer keeps the chunks, and calls its flush closure at most one time
/// for each interval. The default interval is 33 ms, the `ACPSessionState`
/// cadence.
///
/// The first chunk after a flush starts the interval. When the interval ends,
/// the coalescer flushes each chunk that it got in the interval, in order, as
/// one string. ``flushNow()`` flushes at once, for example at the end of a
/// stream.
///
/// The coalescer is `@MainActor`, because the streaming tail that it feeds
/// is `@MainActor` state.
@MainActor
public final class StreamingCoalescer {
  /// The default flush interval: 33 ms.
  public static let defaultInterval: Duration = .milliseconds(33)

  /// The time from the first chunk of a batch to the flush of the batch.
  public let interval: Duration

  /// The closure that gets each batch.
  private let onFlush: (String) -> Void

  /// The chunks that the coalescer did not flush yet, joined.
  private var buffer = ""

  /// The task that flushes the buffer when the interval ends, or `nil` when
  /// no flush is scheduled.
  private var pendingFlush: Task<Void, Never>?

  /// Makes a coalescer.
  ///
  /// - Parameters:
  ///   - interval: The time from the first chunk of a batch to its flush.
  ///   - onFlush: The closure that gets each batch. The coalescer never calls
  ///     it with an empty string.
  public init(
    interval: Duration = StreamingCoalescer.defaultInterval,
    onFlush: @escaping (String) -> Void
  ) {
    self.interval = interval
    self.onFlush = onFlush
  }

  /// Cancels the scheduled flush. The chunks that the coalescer did not
  /// flush are discarded.
  isolated deinit {
    pendingFlush?.cancel()
  }

  /// Adds `chunk` to the batch, and schedules a flush when none is scheduled.
  ///
  /// - Parameter chunk: The streamed text. An empty chunk does nothing.
  public func append(_ chunk: String) {
    guard !chunk.isEmpty else { return }
    buffer += chunk
    guard pendingFlush == nil else { return }
    pendingFlush = Task { [weak self, interval] in
      try? await Task.sleep(for: interval)
      guard !Task.isCancelled else { return }
      self?.flushNow()
    }
  }

  /// Flushes the batch at once, and cancels the scheduled flush.
  ///
  /// When the batch is empty, the coalescer does not call the flush closure.
  public func flushNow() {
    pendingFlush?.cancel()
    pendingFlush = nil
    guard !buffer.isEmpty else { return }
    let batch = buffer
    buffer = ""
    onFlush(batch)
  }
}
