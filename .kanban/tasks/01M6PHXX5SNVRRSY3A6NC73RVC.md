---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6pkj84p4t6rb54p28b71z8j
  text: 'Duplicate: fixed by ^sy19jd4 commit 9f35b8ba (`\.buttons` in theStyleHasNoPaddingByte plus theButtonTokensHaveNoPaddingByte).'
  timestamp: 2026-11-05T19:39:24.694303+00:00
position_column: done
position_ordinal: ffffffb280
title: 'Adopt EditorKit 40928bc: EditorStyle gained `buttons`, ViewValueLayoutTests red'
---
Found while fixing review findings of ^sy19jd4. With EK main at 40928bc (newer than b707d51a), root `swift test` fails 1 of 1005: `ViewValueLayoutTests.theStyleHasNoPaddingByte` — EditorStyle is 163 bytes, the listed fields cover 129, 34 uncovered. EK added a stored `buttons: EditorStyle.Buttons` (ButtonTokens.swift: labelSpacing, opacities, Font.TextStyle caption styles, ButtonTint tints). The test lists every stored field, so it must name `\.buttons`, and `EditorStyle.Buttons` (and `ButtonTint`) need their own no-padding checks — if Buttons has padding (1-byte TextStyle fields beside 8-byte fields), that is an EK layout bug to raise with EK, since ToolCallBody holds EditorStyle by value (^4zzf5cw).

## Tests
- [ ] `theStyleHasNoPaddingByte` names `\.buttons`; a new test covers `EditorStyle.Buttons`; root `swift test` green on EK ≥ 40928bc.