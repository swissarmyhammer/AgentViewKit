---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6qh5w3qppmxq55thgmww19g
  text: 'Research: the inspections are static (`Model.inspection`), so EK''s `.opening { object, url in }` cannot read the SwiftUI environment where AVK''s open hook lives (`EnvironmentValues.attachmentFileService`, internal; default is the per-scope `AttachmentPresenter`, whose `.openAttachment` calls `NSWorkspace.shared.open`). Narrowest route: `InspectedClientModel` (the object every path row''s open block receives) now stores an internal optional `fileService: (any AttachmentFileService)?` (internal init `init(_:fileService:)`; the public `init(_:)` passes nil), and `openPath(_:)` runs `.openAttachment` on `Attachment(url:)` with that service, else a new `AttachmentPresenter()`. Every path row (`InspectionPath.workingDirectory` for terminal + session, session Additional Directories, tool call Locations) gets `.opening { $0.openPath($1) }`. AgentAttachmentCommands.swift untouched. EK''s `.opening` is on EditorKit main e1d17e2.'
  timestamp: 2026-11-06T04:16:56.439851+00:00
- actor: claude-code
  id: 01m6qhewqj275qsqs27ymg449s
  text: |-
    ### implement — changed
    - evidence: commit e5e182ff on worktree-agent-abbe40266e70e9b9f; 6 files — Sources/AgentViewKit/Inspection/{InspectedClientModel,InspectionPath,ClientModels+Inspectable,TranscriptEntries+Inspectable}.swift, Tests/AgentViewKitTests/Inspection/InspectionPathTests.swift, IntegrationTests/.../Inspection/ClientModelInspectionHostedTests.swift. Root swift test: 1066 tests/121 suites + 50/10 passed; IntegrationTests: 1016 tests/139 suites passed (5 known issues, pre-existing withKnownIssue); ScreenshotTests build complete; zero AVK warnings. Package.resolved not committed.
    - next: /review (merge into local main first)
  timestamp: 2026-11-06T04:21:51.986936+00:00
position_column: done
position_ordinal: ffffffbc80
title: Inspector path chips open their file
---
User decision (2026-11-05): pressing a path chip in the inspector opens the file.

Every path row in AVK inspections (single `URL` rows such as Working Directory, the `[URL]` Additional Directories row, and the `[PathLocation]` Locations row) gets EK `.opening { object, url in … }`. That block runs AVK's existing open-file path, the same one the attachment Open command uses: the host's open hook if there is one, otherwise the default.

- [x] Every inspector path row opens its chip's URL
- [x] Hosted tests through accessibility: `InspectorDriver.openPath(at:in:)` / pressing a single-path chip opens that URL through a recording host hook
- [x] No synthesized mouse