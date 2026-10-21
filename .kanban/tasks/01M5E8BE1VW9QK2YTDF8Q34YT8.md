---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m5e93z9erd5q64r35b3h3zsp
  text: 'Changed for D113 (testudoapp-4c), answers 1, 3, 6 and 7. Added the Tinted look and the Clear look checks (seven settings now), the check that no content card or header row has a fill, the bar scroll check and the morph check. This card stays LAST. depends_on: removed AVK-8a1 ^w9y5tq6 (closed as replaced); added AVK-8v to AVK-8am. Items for the person that other cards name: the request card in the bottom bar with no fill (AVK-8y ^br70yr3), the chips that AVK-8r allows, the dictation symbol with no tint (AVK-8ai ^xa3r4z2), the terminal background (AVK-8aa ^mz0nfka).'
  timestamp: 2026-10-21T03:47:13.838899+00:00
depends_on:
- 01M5DFBC5CXFEGX6P4XB316BQV
- 01M5DFBW8F3WMN4JFY7M7QDDWE
- 01M5DFBK5AGCT57V0RJGQZTXTA
- 01M5E89EEX3YFT59487ZFZ0B4V
- 01M5E8A0DARXD97DX4BGTKSDZW
- 01M5E8ARAN32Y4WA38D78JX8YR
- 01M5E8S3KAQ7EV2C2K13Y1K31Q
- 01M5E8SRKB36TVJNFAE2F1ARB7
- 01M5E8SYCWE9FM05FFS1T18BMX
- 01M5E8T69B91ATX31Q3BR70YR3
- 01M5E8TFNDT9Q9WE6C2D6YW9PP
- 01M5E8TQ4JA20GAATH7MZ0NFKA
- 01M5E8TYC4FB02MHJKMXA6V4JC
- 01M5E8V827CA2TZMZ136DVSPVV
- 01M5E8VGGTR59NGWNVHSDKM4QT
- 01M5E8VRDBMPYNDX62PS6C2TF0
- 01M5E8W08CXBJD9CHP8EKR44GZ
- 01M5E8WCXKPRJWZ9XMPSPYDP18
- 01M5E8WMM146Y611ZQDZM1HM5Q
- 01M5E8WVTY0ANTQVTGYXA3R4Z2
- 01M5E8X2DC7CT94TQJG2G7W4MZ
- 01M5E8XAAZ7ZAT3RKSG102C8KK
- 01M5E8XMJXF8XABYA7P3ZGM5SF
- 01M5E8XTQS654VRMEBB5A6B05B
position_column: todo
position_ordinal: '9e80'
title: 'AVK-8u Manual check by a person: screenshots of the demo app compared with Finder and System Settings, with the Tinted look and the Clear look (D111 step 8, D113 answers 3 and 6)'
---
## Why

D111 step 8 (`style.md` "Procedure"): "Check with a screenshot. Build, run, take a screenshot, and compare it with Finder and System Settings. Remove each opaque layer that stays." `style.md`: "The screenshot step is part of the acceptance of each Liquid Glass card. Take the screenshots in light mode, dark mode, Reduce Transparency, Increase Contrast and the Tinted look, and keep them with the test results for a person to look at."

D113 (testudoapp-4c):
- Answer 6: "A test cannot turn the system setting on deterministically, so the Tinted check is the manual screenshot check (AVK-8u)."
- Answer 3: "The Clear look is a system setting that the system applies to `.regular` glass." So the Clear look is also a manual check here.
- Answer 1: "If the step-8 screenshot shows that a group needs more, use a system container (GroupBox, or a grouped Form), never a custom fill."

This is a MANUAL check. A person does it, with the demo app. It is not an automatic test: an automatic test of AVK-8 must be deterministic (no clock, sleep, poll, retry, timeLimit or XCUITest), and a screenshot compare with Finder is not. Do this card LAST, after all the other AVK-8 cards.

## What to do

An agent prepares. A person checks.

- [ ] Agent: build the demo app: `xcodebuild -skipMacroValidation -skipPackagePluginValidation build -scheme AgentViewKitDemo` in `Examples/AgentViewKitDemo` (the command of ^09tvapv). Record the result in a comment.
- [ ] Agent: write in a comment the list of the screens to capture: the ACP tab (`ACPTabView`) with a session that has a transcript, a tool call card, a code block, a terminal output, a diff, a permission request in the deck, a notice banner, the state banner, the sign-in prompt, the scroll-to-bottom pill, the suggestion chips and the composer; the list scrolled so that rows are under the top bar and under the bottom bar; the gallery (`GalleryColumns`) with the look popover; the attachment inspector open.
- [ ] Person: run the demo app. Capture each screen in these seven settings: light mode, dark mode, Reduce Transparency, Increase Contrast, the Tinted look, the Clear look, and the Tinted look with dark mode (System Settings > Appearance, and Accessibility > Display). Also capture a Finder window and System Settings in the same settings.
- [ ] Person, the Tinted look: the floating glass (composer field, editor menu, pill, chips, accessory buttons) takes the system tint like the toolbar of Finder. The kit adds no tint of its own (D113 answer 6). Send is the only tinted action.
- [ ] Person, the Clear look: the floating glass shows more of the content under it, like the toolbar of Finder. No floating control stays frosted or opaque (D113 answer 3).
- [ ] Person, content: no card, notice, request card, code block or header row has a fill (D113 answers 1 and 4). Each one shows a thin separator edge. Look especially at the request card in the bottom bar (AVK-8y), the chips that AVK-8r allows, the dictation symbol while it listens (AVK-8ai), and the terminal background (answer of AVK-8aa). For each group that needs more, write which one; the fix is a `GroupBox` or a grouped `Form`, never a fill.
- [ ] Person, bars: the list scrolls under the top bar and under the bottom bar, with the scroll edge effect (D113 answer 7). No opaque fill behind a bar, the sidebar, the inspector, the composer or the toolbar.
- [ ] Person, morphs: show and hide the pill, the editor menu and the suggestion chips. The glass morphs and does not jump. With Reduce Motion on, nothing moves.
- [ ] Person: for each finding, write a comment with the screen, the setting, and the view.
- [ ] Agent: for each finding of the person, make one new small `avk-8` card with the file, what to change and a deterministic test.
- [ ] Person: keep the screenshots with the test results (attach them to this card or put them in the folder that the person names).

## Acceptance

- A person writes a comment on this card that says: "Screenshots checked in seven settings, with the Tinted look and the Clear look. No opaque layer stays," or gives the list of findings with a new card for each one.
- The screenshots are attached or their place is recorded in a comment.
- No automatic test is added in this card. #avk-8