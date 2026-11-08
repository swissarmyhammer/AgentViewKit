@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import Testing

/// Tests for the paths of the scopes of ``AgentCommandTarget``.
@MainActor struct AgentCommandTargetTests {
  /// A production change that fails this test: the path of a request card
  /// is not the request segment below the scope of its session.
  @Test func theRequestPathIsTheRequestSegmentInTheScopeOfTheSession() throws {
    let session = CancelFixtures.makeSession(state: nil, pendingPermissions: [CancelFixtures.permissionRequest])
    let request = try #require(session.pendingPermissions.first)
    let path = AgentCommandTarget.requestPath(in: session, request: request)
    #expect(path.segments == [AgentCommandTarget.segment(for: session), AgentScopeKind.request(request.id)])
  }
}
