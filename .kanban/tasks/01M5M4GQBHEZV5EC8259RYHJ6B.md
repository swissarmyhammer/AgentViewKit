---
assignees:
- claude-code
position_column: todo
position_ordinal: ac80
title: 'Vary the preview and snapshot sample content: not the same "Parser.swift does not import Foundation" story everywhere'
---
User review of the snapshot images (2026-10-23): "main problem is highly repeated Parser.swift does not import Foundation ... add import at top of file".

Today `Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift` reuses ONE story everywhere: Parser.swift uses `URL` without `import Foundation`, so the build fails, and the agent adds the import. It appears in:
- agentAnswer, streamedAnswerChunks and the error answer;
- buildError (`Sources/Parser.swift:12:18`), completeThought and streamedThoughtChunks;
- the diffs of Sources/Parser.swift and LegacyParser.swift, and sourceFileAttachment;
- the elicitation title "Review of Parser.swift";
- plus inline previews in CodeBlockView.swift:169, TaskListView.swift:233, DiffView.swift:379, CommandOutputView.swift:275 and UnknownItemView.swift:90.
So every snapshot and canvas preview shows the same text and the components can't be told apart by content.

Work:
- Give each kind of content its own plausible scenario, varied across the kit. For example: a conversation that plans a feature, a thought about a test failure, a diff that renames a function, command output from `swift test` or `git status`, a code block in another language (Python, shell, JSON), a task list for a release, a permission request to run a migration, an elicitation that asks for a deploy target. Keep each one realistic and short. No lorem ipsum, and no real people, companies or secrets.
- A conversation preview or snapshot may tell ONE story across its items, but different components must not all repeat it.
- Keep the fixture rules: named constants, a test for each changed fixture (PreviewFixturesTests), and reuse over duplication.
- Update the inline previews named above, plus any other repeat of the story found by `rg -n "Parser.swift|import Foundation|cannot find type 'URL'"`.
- Re-record the affected snapshots in the documented record mode and list each one by name. The diffs must show only content changes, not layout regressions; check the snapshot sizes.
- The full `swift test` is green. #avk-14