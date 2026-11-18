---
assignees:
- claude-code
position_column: todo
position_ordinal: '80'
title: Move agent.exportMarkdown out of the clipboard command group
---
Request from testudoapp-9a (2026-11-18), after task 01M7QEQ262NCNK8H5K2NHBDXJ4 (dfcb483d, b949c434).

Now: `AgentCommandVerb.exportMarkdown` is in the `clipboard` command group with Copy Thread. Export writes a file. It does not use the pasteboard. Thus a host that turns off the clipboard verbs must not lose the export.

Do:
- Put the verb in a group for file or session actions. Use an existing group if one fits. Else add a new public group `export`, with docs.
- Keep its place in the Session menu: group `agentThread`, order 1, after Copy Thread.
- Update the group tables in the docs of `AgentCommandVerb` and `AgentCommandGroup`, and the tests (AgentCommandGroupTests, ExportMarkdownCommandTests).
- Add a test: a host that turns off `clipboard` keeps the export verb.

Run `swift test`. Push, and send the sha to testudoapp-9a.