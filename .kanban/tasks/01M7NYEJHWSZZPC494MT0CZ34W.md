---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m7qcaxbv5hrjkjxnfcxez2yk
  text: |-
    Research and implementation:
    - Profile rule of the new ProfileStore (FoundationModelsACPAgent 7f2524e): a profile is a file `profiles/<name>.yaml` in the project layer (`<cwd>/.<name>/profiles/`), in the user layer, or in the bundled resources. The first layer that has the name wins. The bundled profiles are `large` (default) and `small` only. The defaults layer (`*_DEFAULTS_DIR`) gives NO profile file. `profile: <name>` is the current form. `profile: {preset: <name>}` is the old map form.
    - `swift package update FoundationModelsACPAgent` alone does not build: the new agent needs a newer FoundationModelsAgents (`skillsMarketplaces`) and FoundationModelsRouter (`KVCacheQuantization`). A full `swift package update` builds. Package.resolved is not tracked.
    - Change: `DemoAgent.defaultProfileName` = "small". `defaultProfileModel` = "mlx-community/Qwen3.8-27B-4bit". New `defaultProfileDrafter` = "mlx-community/Qwen3.8-27B-MTP-4bit". `defaultProfileText` = "profile: small\n".
    - Discovery: the drafter is a part of the model identity. A session restore with only the repo fails with `modelMismatch` (recorded drafterRepo nil, resident drafterRepo MTP-4bit). The index file writes a model with a drafter as a mapping (`model:` / `repo:` / `drafter:`). New `DemoAgent.defaultProfileModelEntry` holds that text, and RecordedSessionsStage writes it in each copied index file.
    - Removed `RecordedSessionsStage.profileText` (a copy of `DemoAgent.defaultProfileText`). The stage writes `DemoAgent.defaultProfileText`.
    - Not done, by decision: a demo-owned `tiny` profile file. It would need a write into the real user layer of the ACP tab. Effect: the live ACP tab now selects a 27B 4-bit model with a drafter, which needs more memory than the old Qwen3-4B. The tests use the stub model, so no model loads in the tests.
    - README of RecordedSessions updated to match.
  timestamp: 2026-11-18T13:08:00.507599+00:00
- actor: claude-code
  id: 01m7qcaztvdz8g69yh8d95xyq7
  text: |-
    ### implement — changed
    - evidence: 5 files — Sources/AgentViewKitDemoSupport/DemoAgent.swift, Sources/AgentViewKitDemoSupport/RecordedSessionsStage.swift, Tests/AgentViewKitTests/ACP/DemoAgentTests.swift, Tests/AgentViewKitTests/ACP/RecordedSessionsStageTests.swift, Examples/AgentViewKitDemo/RecordedSessions/README.md. `swift test`: 1279 tests in 150 suites passed, 55 tests in 11 suites passed, 0 failures.
    - next: review
  timestamp: 2026-11-18T13:08:03.035637+00:00
- actor: claude-code
  id: 01m7qcfmpayzj28e5ba6e7q4k3
  text: |-
    ### test - green
    - evidence: swift test at package root, exit 0. 1279 tests in 150 suites passed (Swift Testing), 55 tests in 11 suites passed. 0 failed, 0 skipped.
    - evidence: swift build --build-tests in IntegrationTests and in ScreenshotTests, both exit 0, no compile error. These suites were not run.
    - evidence: swift format lint -s on the 4 changed files shows 5, 5, 23 and 14 findings (DemoAgent.swift, RecordedSessionsStage.swift, DemoAgentTests.swift, RecordedSessionsStageTests.swift). The HEAD versions show the same counts (5, 5, 23, 14), so the change adds no finding. The repo has no .swift-format file, so the default rules apply, and the old code already breaks the LineLength rule.
    - note: each build prints one SwiftPM message, "missing creator for mutated node ... mlx-swift_Cmlx.bundle/Contents/MacOS". It comes from the mlx-swift dependency bundle, not from the code of this task.
    - next: review
  timestamp: 2026-11-18T13:10:35.466133+00:00
position_column: doing
position_ordinal: '80'
title: DemoAgent default profile "tiny" is missing in the new FoundationModelsACPAgent
---
A fresh package resolve gets FoundationModelsACPAgent main 7f2524e (the new `ProfileStore`). Then 12 tests fail in DemoAgentTests and RecordedSessionsAgentTests with `no profile is named "tiny"; the profiles are: large, small`. `DemoAgent.defaultProfileName` is "tiny".

The main checkout still passes, because its untracked Package.resolved pins an older FoundationModelsACPAgent. The failure comes back at the next `swift package update`.

Do: find the profile rule of the new ProfileStore. Change `DemoAgent.defaultProfileName` (or the profile setup of the tests) so that the demo agent uses a profile that exists. Then run `swift package update FoundationModelsACPAgent` and `swift test`.