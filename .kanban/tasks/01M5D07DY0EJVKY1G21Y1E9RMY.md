---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5d09y1ame3k6hh55p9bz4ee
  text: |-
    Agreed API with foundationmodelsacpclient-29 (their card FoundationModelsACPClient ^yvrk73p, Step 5). This card waits for it.
    - `public func apply(_ update: SessionUpdate)` on SessionModel. On a preview model (coalescing cadence `.zero`) it folds synchronously, so a test reads the transcript on the next line. A closed model ignores the update.
    - `PreviewSessionRequestSender` is `@MainActor @Observable` with `public private(set) var sent: [Sent]` in send order. `Sent` cases: `.prompt(PromptRequest)`, `.cancel(CancelSessionNotification)`, `.setConfigOption(SetSessionConfigOptionRequest)`, `.permissionResponse(RequestPermissionResponse, ...)`, `.elicitationResponse(...)`. I asked that the two response cases carry the local id of the pending request.
    - Permission and elicitation answers get a new path to the recorder, so Approve and Stop return at once on a preview model.
    - `SessionModel.preview(requestSender:)` stays. A test keeps a reference to the sender and waits on `sent` with the AgentViewKit `ObservationWait`.
  timestamp: 2026-10-20T15:53:57.546900+00:00
- actor: claude-code
  id: 01m5d0a3cv2rvzdr3wq9kkj3ab
  text: 'Final cases from foundationmodelsacpclient-29: `.permissionResponse(id: PendingPermissionRequest.ID, response: RequestPermissionResponse)` and `.elicitationResponse(id: <local pending id of the elicitation>, response: ...)`. No toolCallId field: a test reads the tool call from the pending request.'
  timestamp: 2026-10-20T15:54:03.035233+00:00
- actor: claude-code
  id: 01m5d8y9xjz1kam3hnmpzzzanr
  text: |-
    ### finish iteration 1 — stuck
    - implement: stuck — FoundationModelsACPClient origin/main 8a287da does not have the API. `SessionModel.apply(_:)` is internal. `PreviewSessionRequestSender` has no `sent: [Sent]` recorder.
    - next: continue this card when ^yvrk73p is merged into FoundationModelsACPClient main.
  timestamp: 2026-10-20T18:24:53.682205+00:00
position_column: todo
position_ordinal: '80'
title: 'AVK-7a Use the code-built SessionModel: public apply(_:) and request recorder'
---
Design: TestudoApp/features/packages/agentviewkit.md "AVK-7", decision D105 (h). Step 5 work.

FoundationModelsACPClient already has `SessionModel.preview(sessionId:cwd:transcript:...)` and `previewSample` (Preview/SessionModel+Preview.swift:57,89). Two parts are missing there:
- `SessionModel.apply(_:)` is internal (Model/SessionModel.swift:421). It must be public and take one `SessionUpdate` with no wire.
- `PreviewSessionRequestSender` keeps only a private count. Tests need a recorder of the outgoing requests (method and params) that they can read.

These two parts are in the FoundationModelsACPClient repo. Agree on the API with the session foundationmodelsacpclient-29 before the work. This card is done when the FoundationModelsACPClient change is on main, AgentViewKit Package.resolved points to it, and one AgentViewKit test uses `SessionModel.preview` + `apply(_:)` + the recorder in place of `ScriptedSession`.

Acceptance:
- One headless test builds a session from values, applies one update, runs one agent command, and reads the recorded request.
- No wire, no clock, no sleep in the test. #avk-7