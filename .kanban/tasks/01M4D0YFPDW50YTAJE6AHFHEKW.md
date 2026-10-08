---
assignees:
- claude-code
position_column: todo
position_ordinal: bd80
title: Ask FoundationModelsACPClient to make RequestError(reporting:) public, and remove the kit copy
---
## What
`Sources/AgentViewKit/ACP/SessionModel+ReportedError.swift` has a kit copy of the client `RequestError.init(reporting:)` (FoundationModelsACPClient e1cac1d, `Model/SessionModel+Prompt.swift`). The client initializer is internal, thus the kit cannot call it.

The kit copy has no `ConnectionError` case. Thus for a closed connection or a time-out, the kit error entry shows `String(describing: error)`. The client gives a text for these errors ("The connection to the agent closed before the agent answered." and "The request timed out before the agent answered."), and adds the `connectionError` data key. This is a copy of client logic and of a client text, against the owner binding rule.

Found in ^fh4y0d7.

- [ ] Ask the client to make `RequestError.init(reporting:)` public (or to give a public `SessionModel.appendError(reporting:)`).
- [ ] Move the pin when the client change is available.
- [ ] Remove the kit `RequestError.init(reporting:)` and call the client API.
- [ ] Add a test: a closed connection on a kit request shows the client text in the error row.

## Acceptance Criteria
- [ ] The kit has no copy of `RequestError.init(reporting:)`.
- [ ] A closed connection gives the client text in the error entry.

## Tests
- [ ] The new test fails before the change and passes after it.
- [ ] `swift test` passes. #blocked-upstream