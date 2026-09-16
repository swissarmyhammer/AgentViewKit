import SwiftUI

/// A history slider over the restore points of a thread, with the restore
/// actions (plan.md §9 E, research R13).
///
/// Pass ``AgentThread/checkpoints`` as `checkpoints`. When the list is empty,
/// the view is empty: a source with no restore points, such as an ACP agent
/// in v1, shows no slider.
///
/// The slider has one stop for each checkpoint. Each stop is also a button
/// with the label of its checkpoint. The last checkpoint is selected at
/// first. Below the stops, three buttons restore the code, the conversation,
/// or both, to the selected checkpoint. The flags of the checkpoint enable
/// each button. The buttons are in a row and not in a pull-down menu, so that
/// each restore action is visible and each assistive technology can get to
/// it.
///
/// A conversation restore removes the turns after the checkpoint. When a
/// later checkpoint is in the list, the view asks for a confirmation before
/// it calls ``CheckpointActions/restore(_:code:conversation:)``. A code
/// restore removes no turns and needs no confirmation. When the restore
/// throws, the view shows the error.
public struct CheckpointView: View {
  /// The accessibility identifier of the view.
  public static let viewIdentifier = "checkpoint-view"

  /// The accessibility identifier of the slider.
  public static let sliderIdentifier = "checkpoint-slider"

  /// The start of the accessibility identifier of each stop.
  public static let stopIdentifierPrefix = "checkpoint-stop-"

  /// The accessibility identifier of the Restore Code button.
  public static let restoreCodeIdentifier = "checkpoint-restore-code"

  /// The accessibility identifier of the Restore Conversation button.
  public static let restoreConversationIdentifier = "checkpoint-restore-conversation"

  /// The accessibility identifier of the Restore Both button.
  public static let restoreBothIdentifier = "checkpoint-restore-both"

  /// The accessibility identifier of the button that confirms a restore.
  public static let confirmIdentifier = "checkpoint-confirm"

  /// The accessibility identifier of the button that cancels a restore.
  public static let cancelIdentifier = "checkpoint-cancel"

  /// The accessibility identifier of the error text of a failed restore.
  public static let errorIdentifier = "checkpoint-error"

  /// The distance between two stops of the slider.
  static let sliderStep: Double = 1

  /// The largest number of lines of a stop label.
  static let stopLineLimit = 1

  /// The accessibility identifier of the stop at the index.
  ///
  /// - Parameter index: The position of the checkpoint in the list.
  /// - Returns: The identifier, such as `checkpoint-stop-0`.
  public static func stopIdentifier(index: Int) -> String {
    "\(stopIdentifierPrefix)\(index)"
  }

  /// One restore that the user asked for.
  public struct RestoreRequest: Equatable, Sendable {
    /// The restore point.
    public let checkpoint: Checkpoint

    /// `true` to put the files back.
    public let code: Bool

    /// `true` to put the conversation back.
    public let conversation: Bool

    /// Makes a restore request.
    ///
    /// - Parameters:
    ///   - checkpoint: The restore point.
    ///   - code: `true` to put the files back.
    ///   - conversation: `true` to put the conversation back.
    public init(checkpoint: Checkpoint, code: Bool, conversation: Bool) {
      self.checkpoint = checkpoint
      self.code = code
      self.conversation = conversation
    }
  }

  /// The restore points, in turn order.
  let checkpoints: [Checkpoint]

  @Environment(\.checkpointActions) private var actions
  @Environment(\.agentTheme) private var theme

  /// The index of the stop that the user selected, or `nil` for the last
  /// stop.
  @State private var selection: Int?

  /// The restore that waits for the confirmation, or `nil`.
  @State private var pendingRestore: RestoreRequest?

  /// `true` while a restore runs.
  @State private var isRestoring = false

  /// The text of the error of the last restore, or `nil`.
  @State private var errorText: String?

  /// Makes the view.
  ///
  /// - Parameter checkpoints: The restore points in turn order, such as
  ///   ``AgentThread/checkpoints``.
  public init(checkpoints: [Checkpoint]) {
    self.checkpoints = checkpoints
  }

  /// Tells whether a restore removes turns from the thread.
  ///
  /// - Parameters:
  ///   - request: The restore.
  ///   - checkpoints: The restore points of the thread.
  /// - Returns: `true` when the restore puts the conversation back and a
  ///   checkpoint of a later turn is in `checkpoints`.
  public static func dropsLaterTurns(_ request: RestoreRequest, in checkpoints: [Checkpoint])
    -> Bool
  {
    request.conversation
      && checkpoints.contains { $0.turnIndex > request.checkpoint.turnIndex }
  }

  public var body: some View {
    if let lastIndex = checkpoints.indices.last {
      let selected = checkpoints[min(selection ?? lastIndex, lastIndex)]
      VStack(alignment: .leading, spacing: theme.spacing.m) {
        Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
          .font(.headline)
          .fontWeight(theme.symbolWeight)
        if lastIndex > 0 {
          slider(lastIndex: lastIndex, selected: selected)
        }
        stops(selected: selected)
        restoreButtons(for: selected)
        if let pendingRestore {
          confirmation(for: pendingRestore)
        }
        if let errorText {
          Text(errorText)
            .font(.callout)
            .foregroundStyle(theme.statusColors.failed)
            .accessibilityIdentifier(Self.errorIdentifier)
        }
      }
      .padding(theme.spacing.m)
      .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.l))
      .accessibilityElement(children: .contain)
      .accessibilityLabel(Text("History"))
      .accessibilityIdentifier(Self.viewIdentifier)
      .onChange(of: checkpoints) {
        pendingRestore = nil
      }
    }
  }

  // MARK: - Parts

  /// The slider across the stops.
  ///
  /// - Parameters:
  ///   - lastIndex: The index of the last stop. It is more than zero.
  ///   - selected: The selected checkpoint.
  /// - Returns: The slider.
  private func slider(lastIndex: Int, selected: Checkpoint) -> some View {
    let value = Binding<Double>(
      get: { Double(min(selection ?? lastIndex, lastIndex)) },
      set: { select(Int($0.rounded())) }
    )
    return Slider(value: value, in: 0...Double(lastIndex), step: Self.sliderStep) {
      Text("Checkpoint")
    }
    .labelsHidden()
    .accessibilityValue(Text(selected.label))
    .accessibilityIdentifier(Self.sliderIdentifier)
  }

  /// One button for each stop, in order.
  ///
  /// - Parameter selected: The selected checkpoint.
  /// - Returns: The row of stops.
  private func stops(selected: Checkpoint) -> some View {
    HStack(spacing: theme.spacing.s) {
      ForEach(Array(checkpoints.enumerated()), id: \.element.id) { index, checkpoint in
        let isSelected = checkpoint.id == selected.id
        Button {
          select(index)
        } label: {
          Text(checkpoint.label)
            .font(.caption)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(isSelected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.secondary))
            .lineLimit(Self.stopLineLimit)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderless)
        .help(checkpoint.createdAt.formatted(date: .abbreviated, time: .shortened))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(Self.stopIdentifier(index: index))
      }
    }
  }

  /// The three restore buttons for the checkpoint.
  ///
  /// - Parameter checkpoint: The selected checkpoint.
  /// - Returns: The row of buttons.
  private func restoreButtons(for checkpoint: Checkpoint) -> some View {
    HStack(spacing: theme.spacing.s) {
      restoreButton(
        "Restore Code", identifier: Self.restoreCodeIdentifier,
        request: RestoreRequest(checkpoint: checkpoint, code: true, conversation: false),
        enabled: checkpoint.canRestoreCode)
      restoreButton(
        "Restore Conversation", identifier: Self.restoreConversationIdentifier,
        request: RestoreRequest(checkpoint: checkpoint, code: false, conversation: true),
        enabled: checkpoint.canRestoreConversation)
      restoreButton(
        "Restore Both", identifier: Self.restoreBothIdentifier,
        request: RestoreRequest(checkpoint: checkpoint, code: true, conversation: true),
        enabled: checkpoint.canRestoreCode && checkpoint.canRestoreConversation)
    }
  }

  /// One restore button.
  ///
  /// - Parameters:
  ///   - title: The title of the button.
  ///   - identifier: The accessibility identifier of the button.
  ///   - request: The restore that the button asks for.
  ///   - enabled: `true` when the checkpoint supports the restore.
  /// - Returns: The button.
  private func restoreButton(
    _ title: LocalizedStringKey,
    identifier: String,
    request: RestoreRequest,
    enabled: Bool
  ) -> some View {
    Button(title) { ask(request) }
      .buttonStyle(.glass)
      .disabled(!enabled || isRestoring)
      .accessibilityIdentifier(identifier)
  }

  /// The confirmation of a restore that removes turns.
  ///
  /// - Parameter request: The restore that waits.
  /// - Returns: The confirmation.
  private func confirmation(for request: RestoreRequest) -> some View {
    HStack(spacing: theme.spacing.m) {
      Text("Restore to “\(request.checkpoint.label)”? The later turns are removed.")
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: theme.spacing.s)
      Button("Cancel", role: .cancel) { pendingRestore = nil }
        .accessibilityIdentifier(Self.cancelIdentifier)
      Button("Restore", role: .destructive) { perform(request) }
        .buttonStyle(.glassProminent)
        .accessibilityIdentifier(Self.confirmIdentifier)
    }
    .padding(theme.spacing.s)
    .glassEffect(theme.materialLevel.glass, in: .rect(cornerRadius: theme.radii.m))
    .accessibilityElement(children: .contain)
  }

  // MARK: - Actions

  /// Selects the stop at the index and drops a restore that waits.
  ///
  /// - Parameter index: The position of the checkpoint in the list.
  private func select(_ index: Int) {
    selection = index
    pendingRestore = nil
  }

  /// Asks for a restore. A restore that removes turns waits for the
  /// confirmation. Each other restore starts at once.
  ///
  /// - Parameter request: The restore.
  private func ask(_ request: RestoreRequest) {
    if Self.dropsLaterTurns(request, in: checkpoints) {
      pendingRestore = request
    } else {
      perform(request)
    }
  }

  /// Calls the restore verb and keeps the error text of a failure.
  ///
  /// - Parameter request: The restore.
  private func perform(_ request: RestoreRequest) {
    pendingRestore = nil
    errorText = nil
    isRestoring = true
    let actions = actions
    Task {
      defer { isRestoring = false }
      do {
        try await actions.restore(
          request.checkpoint, code: request.code, conversation: request.conversation)
      } catch {
        errorText = error.localizedDescription
      }
    }
  }
}
