---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m710b5wr8akgnxqgx4d7s80t
  text: |-
    Implementation notes.
    - New file Sources/AgentViewKit/Inspection/InspectionName.swift: the shared helper. firstWords(of:) gives the first 6 words (word ranges of Foundation, runs of spaces and line breaks become one space, an ellipsis when the text has more words). message(author:startedAt:text:) gives "author · time" when the entry has both, else the first words. plan(_:) gives the first words of the first step that is not complete, else the last step.
    - Inspection.objectName(_:title:) in InspectionLabel.swift now holds the "nil name gives the title" rule. .named(...) and the message and unknown inspections use it.
    - Names: user, agent and thought messages have no author in FoundationModelsACPClient, so they use the first words. The session message uses its senderSessionId as the author, with its start time. Plan: current step. Compaction: first words of the summary, else the status. Error: first words of the message, else the code. Unknown update: its type. Connection: the agent name (initializeResponse.info.name), else the state. Tool call, terminal, session, MCP server and attachment had names already; the tests now cover them.
    - The example "agent-1" on the card is the message id of the gallery fixture, not an author. The entries have no author field.
    - Permission request, elicitation, plan entry and "agent" have no AVK inspection (no Inspectable conformance), so there is no block to name.
    - Tests read the name through `@testable import EditorInspector` and `InspectorBlock.header(of:in:)`, the same text the name row shows. The en_US time has U+202F before "AM".
    - No hosted test or gallery fixture asserts the old block names; both nested packages build with no change.
  timestamp: 2026-11-09T20:35:08.824378+00:00
- actor: claude-code
  id: 01m710b90qdyvahy9swjj5gtr9
  text: |-
    ### implement — changed
    - evidence: 7 files — Sources/AgentViewKit/Inspection/InspectionName.swift (new), Sources/AgentViewKit/Inspection/InspectionLabel.swift, Sources/AgentViewKit/Inspection/TranscriptEntries+Inspectable.swift, Sources/AgentViewKit/Inspection/ClientModels+Inspectable.swift, Sources/AgentViewKit/Resources/Localizable.xcstrings, README.md, Tests/AgentViewKitTests/Inspection/InspectionNameTests.swift (new, 24 tests). Root `swift test`: 1098 tests in 125 suites pass, and 50 tests in 10 suites pass. `swift build --package-path IntegrationTests --build-tests` and `swift build --package-path ScreenshotTests --build-tests` pass. No windowed test or gallery was run.
    - next: /review. The peer regenerates the gallery images inspector-*-two.
  timestamp: 2026-11-09T20:35:12.023280+00:00
position_column: doing
position_ordinal: '80'
title: Each inspection of an item has a name that tells the item
---
## Problem
The gallery images inspector-agent-message-{wide,narrow}-two show two blocks. Both blocks have the name "Agent Message". This name is the title of the type, because the message inspection gives no `name`. The user must tell two blocks apart by their names (peer editorkit-9f, batch gallery review on 2026-11-09).

## Work
- Give each AVK inspection of an item a `name` (EK `.named(..., name:)` or the equivalent) that tells the item. Look at Sources/AgentViewKit/Inspection/TranscriptEntries+Inspectable.swift and ClientModels+Inspectable.swift.
- Message (user, agent, thought, session): the author and the time, for example "agent-1 · 6:15 AM", or the first words of its text when there is no author or time. Use one shared helper for the first words.
- Do the same for the other inspections: tool call (already named by its title, check it), terminal (already named by the command, check it), permission request, elicitation, plan, plan entry, compaction, error, unknown update, attachment, and the client models (session, connection, MCP server, agent and the rest). Each name comes from data of the item.
- Localize the new strings in Localizable.xcstrings.
- Update the docs (DocC and README) where they tell the block titles.

## Acceptance
- [ ] Each inspection of an item gives a name that comes from the item.
- [ ] A headless unit test: two items of one type (for example two agent messages) give two blocks with different names. Add this for each inspection type that can have two items.
- [ ] The root `swift test` passes. `swift build --package-path IntegrationTests --build-tests` and `swift build --package-path ScreenshotTests --build-tests` pass.
- [ ] Do NOT run windowed tests or the gallery. The peer tells when to regenerate the gallery.