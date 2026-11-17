---
assignees:
- claude-code
depends_on:
- 01M7NEP1KG5VE1ZJQ9W4NTCSM3
- 01M7NEP5YE0VKB9HG2639BJQ22
- 01M7NEP8RY1KTK477F0KFTSY8S
- 01M7NEPB4MXHC8XXZ18PHEST6R
- 01M7NEPDTW71D703W2XY69XSJ2
- 01M7NEPFMFBXQM762TB9C40T46
- 01M7NEPK3QHB30W786RBDV6CER
position_column: todo
position_ordinal: '8780'
title: 'AVK-9.8: Remove Textual from AgentViewKit'
---
D185. Do this after AVK-9.1 to AVK-9.7.

- Remove Textual from Package.swift (textualProducts, the package entry, the AgentViewKit target) and from IntegrationTests/Package.swift.
- Delete the Textual tests.
- Update Docs/decisions (text-selection.md, code-block-source.md, math-engine.md, dependencies.md) and the README.
- Tell testudoapp the commit: after it, the chat no longer uses Textual.

#avk-9