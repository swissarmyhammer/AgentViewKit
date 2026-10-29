import EditorCommands

nonisolated extension MenuPath {
  /// The Session menu of the agent commands.
  ///
  /// The path has no system slot, so EditorKit `EditorMenuCommands` shows it
  /// as a custom menu, with the raw value as its title. A host puts its own
  /// session commands in the same menu with this path. The path is in the
  /// style library, so that another kit, such as SnapshotViewKit, puts its
  /// commands in the same menu with no ACP product.
  public static let session: MenuPath = "Session"
}
