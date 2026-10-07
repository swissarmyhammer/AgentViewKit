import FoundationModelsACP

extension ResumeSessionRequest {
  /// Makes the `session/resume` request that a kit view sends (update.md §4.7
  /// "Resume").
  ///
  /// ACP v2 requires a resume to send the same `cwd` and the full list of
  /// additional directories of the session again. All kit views that resume a
  /// session make their request with this function, so that this rule has one
  /// location only.
  ///
  /// When the list is empty, the request has no `additionalDirectories`. ACP
  /// gives the same meaning to an empty list and to no list: no additional
  /// root. Thus the frame of a session with no additional root has no
  /// `additionalDirectories` field, also when the agent does not advertise
  /// `session.additionalDirectories`.
  ///
  /// The function only makes the value. It keeps no state.
  ///
  /// - Parameters:
  ///   - sessionId: The session to resume.
  ///   - cwd: The working directory of the session.
  ///   - additionalDirectories: The full list of additional workspace roots of
  ///     the session. An empty list means no additional root.
  ///   - replayFrom: The position where the agent starts the replay of the
  ///     history, or `nil` for no replay.
  /// - Returns: The request to give to `ConnectionModel.resumeSession(_:)`.
  static func makeAgentViewKitRequest(
    sessionId: SessionId,
    cwd: AbsolutePath,
    additionalDirectories: [AbsolutePath],
    replayFrom: ReplayFrom?
  ) -> ResumeSessionRequest {
    ResumeSessionRequest(
      cwd: cwd,
      sessionId: sessionId,
      additionalDirectories: additionalDirectories.isEmpty ? nil : additionalDirectories,
      replayFrom: replayFrom)
  }
}
