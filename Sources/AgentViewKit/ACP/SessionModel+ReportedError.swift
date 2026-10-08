import FoundationModelsACP
import FoundationModelsACPClient

extension SessionModel {
  /// Adds an error entry for a failed request that the model did not record
  /// (plan.md §3.2 "Other requests", §3.8 "Error rows").
  ///
  /// `prompt(_:meta:)` records its own failure. Use this function for each
  /// other request of the kit that fails, for example `session/cancel`,
  /// `session/set_config_option`, `auth/login` and `auth/logout`. The error
  /// then shows in the transcript in its order, and the kit keeps no error
  /// list.
  ///
  /// - Parameter error: The error that the request threw.
  func appendError(reporting error: any Error) {
    let failure = RequestError(reporting: error)
    appendError(code: failure.code, message: failure.message, data: failure.data)
  }
}

extension RequestError {
  /// Gives the JSON-RPC form of an error that a request of the kit threw.
  ///
  /// A `RequestError` stays as the agent sent it. A cancellation becomes
  /// `requestCancelled`. Each other error, for example a closed connection,
  /// has no JSON-RPC code, so it becomes `internalError` with its description
  /// as the detail.
  ///
  /// - Parameter error: The error that the request threw.
  init(reporting error: any Error) {
    switch error {
    case let requestError as RequestError:
      self = requestError
    case is CancellationError:
      self = .requestCancelled
    default:
      self = .internalError(detail: String(describing: error))
    }
  }
}
