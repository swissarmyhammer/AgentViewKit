---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6pm9t8nkmddqa51w32t8aj4
  text: |-
    EK ^a0rwxe1 is in progress (editorkit-b5):
    - EditorButton and EditorToolbarButton take a symbol variable value (live `Image(systemName:variableValue:)`).
    - A busy state: a themed spinner in the icon slot, caption kept, button disabled, accessibility value "In progress". When squeezed, the spinner stays and the caption hides.
    Waiting on the SHA.
  timestamp: 2026-11-05T19:52:16.917868+00:00
position_column: todo
position_ordinal: 8d80
title: Microphone live level and sign-in busy state on EditorButton
---
**Blocked** on EK (requested from editorkit-b5, 2026-11-05). Gaps from the button migration ^v1bmh1p:
- The microphone button no longer shows the live input level while recording, because EditorButton takes a fixed SF Symbol. AVK needs a symbol variable value or an EditorSymbol with a value on EditorButton.
- The sign-in buttons' spinner sits next to a disabled button instead of inside it. AVK needs a busy state on EditorButton.

## What
- When EK lands these, use them. No AVK button styling.

## Tests
- [ ] Hosted: while recording, the microphone button's accessibility value carries the level. While signing in, the button reads as in progress.
- [ ] Gallery recording and signing-in states, light and dark.