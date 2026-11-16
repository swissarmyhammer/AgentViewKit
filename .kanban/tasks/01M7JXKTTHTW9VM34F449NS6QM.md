---
assignees:
- claude-code
position_column: done
position_ordinal: ffffffd680
title: 'AVK-10 (1/3): status line configuration types, format, presets and setting'
---
D194 (TestudoApp features/decisions.md), AVK-10. Typed `StatusLineDefinition` with one struct for each module, `StatusLineFormat` (starship-like `$module`, `( … )` groups, `\$ \( \)` escapes), `StatusLineStyle` (ANSI names to the theme terminal palette, theme roles, bold/italic/dimmed), `StatusLineSymbol` (text, `sf:`, `icon:`), `StatusLines` presets (default, minimal, full), `StatusLineSetting.resolve(JSONValue?) -> StatusLineResolution` with problems and key paths, `StatusLineDefinition.settingsKeys`. Unit tests for the parser, each preset and the setting decode. #feature