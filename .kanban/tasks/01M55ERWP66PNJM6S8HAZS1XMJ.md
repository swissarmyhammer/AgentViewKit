---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m55f6zstdrrynaavgpz27bca
  text: |-
    Research:
    - `swift package update FoundationModelsACPClient` moved only that package: 26b7bf7 -> f50f3b3 (and the originHash). Package.resolved is in .gitignore, so git shows no diff for it.
    - `ElicitationValidator.Message` is private and has a text for each Kind except `fieldNotInSchema`. Plan: an internal `ElicitationValidator.message(for:)` in the same file calls the Message members, so no string literal is copied. One new Message entry for `fieldNotInSchema`.
    - An issue field can name a property that the kit does not normalize (for example an array with no choices, the "files" fixture). Thus the title comes from the raw `requestedSchema` property (`title`, else the name), with one helper in `ElicitationFieldSchema` that `normalize` also uses.
    - The text: no field -> the existing key "The agent cannot accept this answer: %@" with the kit rule text. A field -> a new key "The agent cannot accept the answer for “%@”: %@".
    - Two hosted tests expect the English Extras text (`failureLead + reason`, and `contains("\"files\"")`). They change to the kit text. Docs/decisions/accessibility.md names the announcement text and changes too.
  timestamp: 2026-10-17T17:40:34.234166+00:00
- actor: claude-code
  id: 01m55gam0eqhdx0y8r6yd0tcfr
  text: |-
    Implementation landed (not committed, not pushed, by order of the dispatcher).
    - DISCOVERY: ACPClient f50f3b3 does not compile with the old FoundationModelsExtras pin 1804680 (`cannot find type 'ElicitationValidationIssue'`). `swift package update FoundationModelsExtras` moved Extras to dd3a078 ("validationIssue(of:) gives the validation failure as data"). Thus two packages moved in Package.resolved: FoundationModelsACPClient 26b7bf7 -> f50f3b3 and FoundationModelsExtras 1804680 -> dd3a078. No other package moved.
    - DISCOVERY: the full `swift test` then failed `ResolvedPinsTests.theGeneratedDemoProjectPinsTheRootACPRevisions`, because the git-ignored demo project of this checkout still had the old pins. `ruby Examples/AgentViewKitDemo/Scripts/generate_xcodeproj.rb` copies the root pins again. No UI test ran.
    - Code: `ElicitationValidator.message(for:)` maps each Kind to the existing private `Message` members (one new member, `notInForm`, for `fieldNotInSchema`). `ElicitationFieldSchema.title(ofProperty:in:)` reads the raw `requestedSchema` property title, with the same rule as `normalize`, so a property with no field (the "files" fixture) also gets its title. `ElicitationView.failureText(for:requestedSchema:)` replaces `failureText(reason:)`. Submit calls `validationIssue(of:)`. Decline is not changed.
    - Catalog: xcodebuild with SWIFT_EMIT_LOC_STRINGS=YES, then one `xcstringstool sync` with `--stringsdata` one time and the 179 AgentViewKit-t files. Two new keys, each set to "translated" with an explicit English value. A second sync changed nothing. 307 keys, no stale key. The sync drops the end-of-file newline; it was put back to keep the diff small.
    - What did not work: `@Test(arguments:)` lists in the main-actor test target must be `nonisolated static let`, as in GrammarBundleTests.
    - Open: the Push section of the card (wait for the ACPClient CI of f50f3b3, Examples re-run of run 39049037284) is not done. The dispatcher said do not commit or push.
  timestamp: 2026-10-17T18:00:01.806960+00:00
- actor: claude-code
  id: 01m55gavd3acmxf22kqdf0xevp
  text: |-
    ### implement — changed
    - evidence: 7 files — Sources/AgentViewKit/Elicitation/ElicitationValidator.swift, Sources/AgentViewKit/Elicitation/ElicitationView.swift, Sources/AgentViewKit/Elicitation/ElicitationFieldSchema.swift, Sources/AgentViewKit/Resources/Localizable.xcstrings, Docs/decisions/accessibility.md, Tests/AgentViewKitTests/Elicitation/ElicitationIssueTextTests.swift (new), Tests/AgentViewKitTests/Elicitation/ElicitationViewHostedTests.swift. Package.resolved (git-ignored): ACPClient f50f3b3, Extras dd3a078. `swift build --build-tests`: no Swift warning. `swift test`: 1334 + 129 + 1 tests pass, 0 failures (2 existing known issues of the helper self-tests). `Scripts/check-readme.sh`: passed. RED seen first: 50 assertion failures in the new and changed tests.
    - next: /review. The Push section of the card is still open (no commit and no push by order of the dispatcher).
  timestamp: 2026-10-17T18:00:09.379190+00:00
position_column: doing
position_ordinal: '80'
title: Show a kit text for the elicitation validation issue at Submit
---
Request from swissarmyhammer-96 (elicitation plan, step 4; part 2 of the localization work). Known gap: the Extras failure text at Submit is English.

## API (FoundationModelsACPClient f50f3b3; no Extras import)
- `PendingElicitation.validationIssue(of: JSONValue?) -> PendingElicitation.ValidationIssue?`. It is nil in the same cases as `validationFailure(of:)`.
- `ValidationIssue { field: String?; kind: Kind; init(field:kind:); failureText: String }`. `failureText` is English and is for logs only.
- `Kind`: `requiredFieldMissing`, `fieldNotInSchema`, `wrongType(expected: ExpectedValue)` (`string`, `number`, `wholeNumber`, `boolean`, `stringList`), `tooShort(minLength:)`, `tooLong(maxLength:)` (code points), `patternMismatch(pattern:)`, `invalidPattern(pattern:)`, `invalidFormat(StringFormat)` (`email`, `uri`, `date`, `dateTime`), `belowMinimum(Double)`, `aboveMaximum(Double)`, `valueNotAllowed(allowed:)`, `itemNotAllowed(value:allowed:)`, `tooFewItems(minItems:)`, `tooManyItems(maxItems:)`.

## Work
- Update Package.resolved so that FoundationModelsACPClient is at f50f3b3 or later.
- At Submit (`ElicitationView.swift`, about line 249, `request.validationFailure(of:)`), use `validationIssue(of:)`. Show a kit text for the issue, from `String(localized:bundle: .module)`. Use the field title from the schema when it has one, else the field name.
- When `ElicitationValidator.Message` (commit 3cb3933) already has a text for the same rule, use that same text. Then the user sees one sentence for one rule, from the field check and from Submit. Add new texts only for the kinds that it does not have.
- Each new key goes into `Localizable.xcstrings` with an explicit English value in the "translated" state (the rule in the Package.swift comment).
- Do not show `failureText` in the UI. Do not change the decline to the agent: ACPClient sends the English reason.

## Tests
- One test for each `Kind`, made with `ValidationIssue(field:kind:)`. Each test checks the English kit text.
- One hosted test or state test proves that Submit shows the kit text, not `failureText`.
- No sleep, poll, retry, clock or time limit.

## Push
Push only after the ACPClient CI for f50f3b3 is green. Push with the Examples re-run of run 39049037284 when the runner screen is unlocked. If the runner is still locked, push and report that the Examples job is blocked.

## Acceptance
- [ ] Submit shows a localized kit text for each issue kind.
- [ ] The rules that the field check and Submit share use the same text.
- [ ] The catalog has each new key with a translated English value.
- [ ] There is a test for each Kind, and a Submit test.
- [ ] `swift test` and `Scripts/check-readme.sh` pass. #elicitation #acp-client