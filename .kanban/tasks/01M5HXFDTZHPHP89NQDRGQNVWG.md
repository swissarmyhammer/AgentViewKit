---
assignees:
- claude-code
position_column: todo
position_ordinal: a380
title: 'AVK-14e Add #Preview blocks for the content block views and the command output rows'
---
## Goal

The user examines the look of each component in the Xcode canvas. These content views have no `#Preview`:

- `Sources/AgentViewKit/Content/Blocks/TextBlockView.swift` — `TextBlockView`
- `Sources/AgentViewKit/Content/Blocks/ResourceBlockView.swift` — `ResourceBlockView`
- `Sources/AgentViewKit/Content/MarkdownProse.swift` — `MarkdownProse`
- `Sources/AgentViewKit/Diff/DiffRendererSlot+EditorKit.swift` — `EditorKitDiffRenderer`
- `Sources/AgentViewKit/Content/OutputChrome.swift` — `OutputCapRow`, `OutputExitLabel`

## Change

Add `#Preview` blocks in the same file as each view. Use `Sources/AgentViewKit/Infrastructure/PreviewFixtures.swift`, and add to it if a value is missing. Give each preview a name that tells its state.

- [ ] `TextBlockView` and `MarkdownProse`: headings, lists, a table, inline code, links, a citation, and a very long paragraph.
- [ ] `ResourceBlockView`: a text resource, a binary resource, and a resource with a long URI.
- [ ] `EditorKitDiffRenderer`: a small diff, a large diff, a diff that only adds, and a diff that only removes.
- [ ] `OutputCapRow`: the row that tells that the output was cut.
- [ ] `OutputExitLabel`: exit code 0, a code that is not 0, and a stop by a signal, if the model has it.

The white fill of the EditorKit text area (^m231ph5, stuck) shows in the diff and code previews. Do not try to fix it here.

## Rules

- No new public API. No backward compatibility code (ARCHITECTURE.md).
- The package builds with 0 warnings. The full suite passes with the window monitor. #avk-14