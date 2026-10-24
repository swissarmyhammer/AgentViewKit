---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5nw5qzea5te72az1yemd3xd
  text: |-
    BLOCKED on EditorKit ^aqqd6sb (filed by editorkit-28, 2026-10-23); breaking change. Shape:
    - `FontFace` (family: String?, design: Font.Design, size: CGFloat?) with `font(_ style: Font.TextStyle = .body) -> Font`: no family gives `.system(style, design:)`; a family gives `.custom(family, size:, relativeTo: style)`; statics `.system` and `.monospaced`.
    - Theme requirements become `uiFace` / `displayFace` / `codeFace`; extension `face(for:)` and `font(for: role, style: = .body)`; `uiFont` / `displayFont` / `codeFont` are derived only (the face at .body).
    AVK work when it lands: Theme conformers (DistinctRolesTheme, EnlargedRoleTheme, maybe AgentTheme) set faces; route the ~60 `.caption`/`.headline`/`.callout` sites to `theme.font(for: .ui, style: …)`; extend FontRoleTests to forbid a bare system text style in a view.
    Asked editorkit-28 to land it via a hold branch: AVK adapts against the SHA, then EditorKit pushes, so a fresh resolve never breaks.
  timestamp: 2026-10-24T02:34:55.854965+00:00
- actor: claude-code
  id: 01m5pqdcmex55v40szf8rg5mtz
  text: |-
    Picked up. Built against EK hold/font-faces 39c0801 via `swift package edit EditorKit --path <scratchpad>/ek-font-faces` (clone, untouched). Research:
    - 63 bare text-style sites (`.font(.caption)`, `.headline`, `.callout`, `.subheadline`, `.body.weight`, `.caption.monospacedDigit()`) across 32 files in Sources/AgentViewKit plus one in Examples/AgentViewKitDemo (GalleryTabView section header). The FontRoleTests scan covers both `Sources` and `Examples`, so the demo site moves too.
    - Every site is chrome (titles, labels, captions, status, chips, paths beside code), so each routes to `editorTheme.font(for: .ui, style: …)`. No site is prose or code at a non-body style; code text already uses `codeFont` at body by decision ^ctff8rk.
    - Test themes: EnlargedRoleTheme and DistinctRolesTheme move to `uiFace`/`displayFace`/`codeFace`. A Font at a text style has no face equivalent, so they use a serif face with a fixed body size taken from the system text style they used before (largeTitle, title2, title). A fixed size scales to every text style, so an enlarged ui role now also enlarges a caption site.
    - EK's own UIFamilyTheme lives in EditorTestSupport, which is not a product; AVK needs its own family test theme.
    - Out of scope, unchanged: InlineCitation's digit font is `.system(size:)` from a measured size (Docs/decisions/dynamic-type.md), not a text style.
  timestamp: 2026-10-24T10:30:57.934563+00:00
- actor: claude-code
  id: 01m5pqxr2zds9y6zf9rwv70qtx
  text: 'Progress: RED seen for both new tests. FontRoleTests.noViewPicksAFontOutsideTheRoles listed 60 bare text-style sites (59 in Sources/AgentViewKit, 1 in Examples GalleryTabView); theHeadlineOfTheAgentNameDrawsInTheFamilyOfTheUIFace failed with the agent name 25.7 pt off the Helvetica Neue width. Gotcha found: RegexBuilder `Anchor.wordBoundary` uses Unicode (UAX #29) boundaries, so there is no boundary inside `headline.weight` (MidNumLet); the bare-style pattern ends with `NegativeLookahead { CharacterClass.word }` instead. GalleryTabView''s section title moved into a small `GallerySectionTitle` view so it reads the theme of `.galleryLook(_:)` and not the theme around the tab.'
  timestamp: 2026-10-24T10:39:53.951769+00:00
- actor: claude-code
  id: 01m5prb73b1ph4sd93jhk2azzf
  text: |-
    ### implement — changed
    - evidence: `swift test` against EK hold/font-faces 39c0801 (via `swift package edit EditorKit`, left in place for test/review): 1802 tests in 220 suites passed with 7 known issues; exit 0. No snapshot PNG changed (default themes draw `Font.system(style)` as before). FontRoleTests (3) and FontRoleHostedTests (12, incl. new theHeadlineOfTheAgentNameDrawsInTheFamilyOfTheUIFace) watched RED then GREEN.
    - changes: 60 bare text-style sites → `editorTheme.font(for: .ui, style: …)` (59 kit, 1 demo via new private `GallerySectionTitle`); `.body.weight(.medium)` → `editorTheme.uiFont.weight(.medium)`. All sites are chrome, so all use the ui role. FontRoleTests forbids `.font(.<style>`, `Font.<style>`, `.system(.<style>`. Test themes moved to faces (`FontFace.serif(sizedAs:)` helper, new `UIFamilyTheme`). FontRoleExpectations.expectText now allows `layoutRounding` (1 pt): with captions in the ui role, an enlarged ui role moved the code subject of PermissionView by a sub-pixel and its height rounded 0.29 pt differently (theCommandDrawsInTheCodeRole failed); the role case now needs more than 1 pt growth. Docs: dynamic-type.md, README theme paragraph, AgentTheme doc.
    - not changed: InlineCitation digit font `.system(size:)` (fixed measured size per dynamic-type.md, not a text style). Demo xcodebuild not run (cannot see the edit; full gate after EK push).
    - next: /review
  timestamp: 2026-10-24T10:47:15.307903+00:00
- actor: claude-code
  id: 01m5prk2fm47t9rfswexray9h1
  text: |-
    ### implement — changed (follow-up: fixed-size fonts)
    - evidence: `swift test` (EK edit still in place): 1802 tests in 220 suites passed, 7 known issues, exit 0. No snapshot PNG changed. FontRoleTests.noViewPicksAFontOutsideTheRoles went RED on Citations/InlineCitation.swift (the only `.system(size:` site in Sources and Examples), then GREEN.
    - changes: FontRoleTests also forbids `.system(size:`. InlineCitationPill draws its number in a copy of `editorTheme.face(for: .ui)` with `size` set to the metrics digit size (`digitFace.font().weight(.semibold).monospacedDigit()`). dynamic-type.md updated.
    - exceptions to the fixed-size rule: none found.
    - note: InlineCitationMetrics still measures the pill with `NSFont.monospacedDigitSystemFont`, a measurement and not a drawn font, so a much wider ui family could press against the fixed pill frame.
    - next: /review
  timestamp: 2026-10-24T10:51:32.724320+00:00
- actor: claude-code
  id: 01m5prqdv125e9s3zxz9xphvq2
  text: |-
    ### test — green
    - evidence: swift test (against the EditorKit edit, hold/font-faces 39c0801) — 1802 tests in 220 suites passed, 0 failed, 7 known issues (expected); 229-test and 1-test runs in the same output also passed. Zero warnings from repo sources; the only warning line is a build-system note from the mlx-swift_Cmlx.bundle dependency ("missing creator for mutated node"). Demo xcodebuild and UI tests not run, per instruction.
    - next: review; no files changed, nothing committed.
  timestamp: 2026-10-24T10:53:55.425792+00:00
position_column: doing
position_ordinal: '8380'
title: Chrome text styles (.caption, .headline, .callout) do not follow a custom uiFont
---
Found while doing ^p6e0v5w. The kit draws its smaller and larger chrome text in SwiftUI text styles (`.font(.caption)`, `.headline`, `.callout`, about 60 sites in Sources/AgentViewKit), as the EditorKit chrome does (palette, completion popup, tag chips). With the default themes this is the ui role, because `ThemeRoleDefaults.uiFont` is the system font. But a theme that sets `uiFont` to another family (a Zed `ui_font_family`, for example) changes only the body-size chrome that reads `editorTheme.uiFont`; a caption or a headline stays in the system font. A SwiftUI `Font` cannot be re-styled to another text style, so AVK cannot derive "uiFont at caption" by itself.

Needs an EditorKit API first, for example `Theme.uiFont(_ style: Font.TextStyle) -> Font` (or a family on the role) so a host chrome can ask for the ui role at a text style. Then route the AVK text-style sites through it and extend `Tests/PackageStructureTests/FontRoleTests.swift` to forbid a bare system text style in a view.

#avk-8 #cross-repo