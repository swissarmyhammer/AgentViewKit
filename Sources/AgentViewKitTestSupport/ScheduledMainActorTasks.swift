/// Lets the main-actor tasks that are scheduled now run to their end.
///
/// A `ScrollAnchorManager` sends its scroll requests in a main-actor
/// `Task`. A test calls ``runScheduled()`` after a call that schedules such a
/// task, and then reads what the task did. The wait is one main-actor task
/// that the caller awaits: the tasks scheduled before it run first, because
/// the main actor runs its jobs in order. It uses no clock.
@MainActor
public enum ScheduledMainActorTasks {
  /// Suspends until each main-actor task that is scheduled now has run.
  public static func runScheduled() async {
    await Task {}.value
  }
}
