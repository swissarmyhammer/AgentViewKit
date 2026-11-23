/// The one form of a ``BodyEvaluationCounter`` key: a prefix of the view or of
/// the work, and the id of the item. Each counter key of the kit comes from
/// ``make(prefix:id:)``, so two keys never use different forms.
///
/// The type is not only in DEBUG builds, because the key functions of the
/// views are not only in DEBUG builds.
enum BodyEvaluationKey {
  /// Makes the counter key of one item.
  ///
  /// - Parameters:
  ///   - prefix: The prefix of the view or of the work, such as `response-`.
  ///   - id: The id of the item, or the text of a model.
  /// - Returns: The key.
  static func make(prefix: String, id: String) -> String {
    prefix + id
  }
}
