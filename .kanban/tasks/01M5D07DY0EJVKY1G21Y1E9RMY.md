---
assignees:
- claude-code
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