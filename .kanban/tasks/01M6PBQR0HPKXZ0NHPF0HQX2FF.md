---
assignees:
- claude-code
position_column: todo
position_ordinal: '9080'
title: 'Code block: the line numbers touch the code with no gap (gallery, EK b707d51a)'
---
Seen in the gallery re-capture of ^sy19jd4 (`~/Library/Caches/AgentViewKit/screenshot-check/generated/HostedSnapshotTests/code-block-light.png` and `-dark.png`): the gutter numbers of `CodeBlockView` (`.editorGutter(LineNumbers())`) stand right against the text, e.g. "1def total_with_tax", in light and dark. ^sy19jd4 switched the block to `.editorWrapMode(.viewportWidth)` (EK's WrapMap row grid), so first find out whether the gap was lost with the wrap mode or was already missing before (capture once with `.none`), then fix it in the right package (EK gutter vs AVK's use of it).

## Tests
- [ ] Gallery image of the code block shows a gap between the gutter and the code, light and dark.