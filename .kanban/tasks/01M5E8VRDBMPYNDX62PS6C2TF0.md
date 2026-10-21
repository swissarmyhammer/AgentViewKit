---
assignees:
- claude-code
depends_on:
- 01M5E8VGGTR59NGWNVHSDKM4QT
position_column: todo
position_ordinal: a880
title: AVK-8ae Remove the materialLevel token and the MaterialLevel enum from AgentTheme, because no theme selects the glass variant (D113 answer 3)
---
## Why

D113 answer 3: "remove the `materialLevel` control of the glass". After AVK-8ad, no code reads `AgentTheme.materialLevel`. A token that does nothing is a wrong promise to a host. This is a change of the public API of `AgentTheme`.

## Files and lines

- `Sources/AgentViewKit/Theme/AgentTheme.swift:83-` (`public enum MaterialLevel`), `:111-112` (the property), `:121` and `:127` (the init parameter), `:133`, `:152` (the default), and the layout comment at `:25-30` (it names `materialLevel` for the padding rule).
- `Tests/AgentViewKitTests/Theme/DefaultTokens.json:4`
- `Tests/AgentViewKitTests/Theme/AgentThemeTests.swift:61`, `:138`
- `Tests/AgentViewKitTests/Theme/AgentThemeGoldenTests.swift:68`
- `Tests/AgentViewKitTests/Infrastructure/ViewValueLayoutTests.swift:20`
- `Docs/decisions/visual-audit.md:30` (the `materialLevel` row).
- Each other hit of `materialLevel` or `MaterialLevel` in Sources, Tests, Examples and Docs (search first).

## What to do

- [ ] Remove the enum, the property, the init parameter and the default value.
- [ ] Change the layout comment of `AgentTheme` and keep the type with no padding byte: `ViewValueLayoutTests.theThemeHasNoPaddingByte` must pass with the new list of stored properties.
- [ ] Remove the token from `DefaultTokens.json`, `AgentThemeTests` and `AgentThemeGoldenTests`.
- [ ] Change the row in `Docs/decisions/visual-audit.md:30`: the token is removed by D113 answer 3.
- [ ] Change each caller of the init in Examples and DemoSupport.

## Acceptance

- A search for `materialLevel` and `MaterialLevel` gives no hit in Sources, Tests and Examples. `visual-audit.md` names the removal.
- `swift build` of the package and of the demo app succeeds. The theme tests and `ViewValueLayoutTests` pass. Write the output of the full suite to a file, not to a pipe.
- Tests use Swift Testing. No clock, sleep, poll, retry, timeLimit or XCUITest. #avk-8