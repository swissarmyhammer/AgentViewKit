---
assignees:
- claude-code
position_column: todo
position_ordinal: '8280'
title: Integration CI job on main is red (run 44757895393, a60d101a)
---
Request from testudoapp-9a (2026-11-20). Job "Integration (opt-in, real dependencies)" on mini-01 failed. The user cleared the runner screens, and the job runs again (rerun started 2026-11-20).

Failures:
- `TranscriptSearchStepHostedTests.swift:86` findNextHitRunsInAMountedThreadWithHits: `registry.perform(findNextHit)` is false.
- `ThreadBarBannerOverlapHostedTests.swift:84` theLastRowAtRestIsAboveTheBannersOfTheBottomBar.
- `AttachmentTextContentHostedTests.swift:23` aMarkdownAttachmentShowsTheRenderedForm.
- `ThreadAccessibilityHostedTests.swift:223` theTextsOfTheBlocksOfOneMessageLinkEachOther.
- `AgentItemFocusHostedTests.swift:149` theFirstResponderCoversAFocusedItem(kind: .message, landing: .nav).

Do:
- Read the result of the rerun. For each failure that stays, find the cause from the CI log and the code, and fix it. The hosted suites are not run locally; CI checks them.
- Push, and send the sha and the CI result to testudoapp-9a.