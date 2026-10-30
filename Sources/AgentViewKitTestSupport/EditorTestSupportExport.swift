// The generic test helpers of EditorKit: the hosted windows, the captures,
// the waits, the accessibility reads, the recorders and the shared checks.
// AgentViewKitTestSupport re-exports them, as each `<Kit>TestSupport` does
// (EditorTestSupport DocC, "Integration tests"), so that a test that imports
// the agent fixtures reads the generic helpers with no second import, and the
// integration package names them through the root package.
@_exported import EditorTestSupport
