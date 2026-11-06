---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6qh0d0dfc1pvywxe5sydesn
  text: 'Research: EK''s plural subject is `@FromSelection(kind:)`, resolved by `ParameterResolver.selection(kind:)` over `context.selection` (Finder rule: clicked inside selection -> whole selection, clicked outside -> clicked alone, no click -> whole selection). KVK''s board contributes `context.selection` + `contributeSubject` for each selected card from its board scope (`BoardCommandTarget.contributeSelection`). Plan for AVK: the attachment scope of a file view that selects (select != nil) contributes the selection (in transcript order) only when its own file is selected — so a keyboard run on a focused unselected file also acts on that file alone (a thread-level contribution would give the whole selection there). `AgentAttachmentCommand` reads `@FromSelection(kind: AgentScopeKind.attachment)`; availability = every file available; `AttachmentFileService` keeps the per-file `run(_:on: Attachment)` primitive and gains a batch `run(_:on: [Attachment])` (default loops); `AttachmentPresenter` reveals all in one Finder call, shares all in one picker, queues Save panels, and shows Quick Look over the list. The inspector of several files still shows no actions (out of scope; follow-up card).'
  timestamp: 2026-11-06T04:13:57.133915+00:00
- actor: claude-code
  id: 01m6qj02g98q9twz0gy7y8z5zb
  text: |-
    ### implement — changed
    - evidence: commit 3a4210bf on worktree-agent-a32b7013b4c6b748a, 13 files. Root `swift test`: 1079 tests in 124 suites + 50 tests in 10 suites passed. IntegrationTests `swift test`: 1018 tests in 140 suites passed (5 known issues are the existing FontRoleExpectationsTests ones). ScreenshotTests `swift build --build-tests` complete. No AVK warnings.
    - notes: hosted context-menu rows hide unavailable commands (`ContextMenuUnavailablePolicy.agentItem = .hide`), so the availability test checks the Open row leaves the menu. Disabling the contribution made 4 of the 6 new hosted tests fail (the 2 unselected-file tests pass either way by design). Save of several files shows one save panel per file in turn; Quick Look browses the list; Reveal and Share take all URLs in one call. The per-file `run(_:on: Attachment)` primitive is kept for ^dph42eg. Follow-up card ^xbhtytm: the folded inspector of several files still shows no actions.
    - next: /review
  timestamp: 2026-11-06T04:31:14.953492+00:00
- actor: claude-code
  id: 01m6qjtvs8w5w0tebgy4p347vg
  text: |-
    ### implement — changed (review findings)
    - evidence: commit 35ae6d88 on worktree-agent-a32b7013b4c6b748a (local main fast-forwarded in first; no merge commit needed). Fixed all 4 reuse findings: `AttachmentFileSet` (AgentViewKitTestSupport) holds the three-file setup used by both suites and AttachmentMultiSelectHostedTests; `HostedViewHarness.performSelection(_:on:)` (IntegrationTests Helpers) replaces both suites' `perform(_:on:in:)`; `AttachmentFixtures.calls(of:on:)` replaces both `calls` copies. Root swift test 1081/124 + 50/10 passed; IntegrationTests 1022/140 passed (5 existing FontRoleExpectations known issues). No AVK warnings.
    - notes: `package` access does not reach the nested IntegrationTests package, so `RecordingAttachmentFileService` and its `Call` are now `public` (its run and `calls` stay internal). Main needed a newer EditorKit (breadcrumb tokens); I ran `swift package update EditorKit` in root and IntegrationTests and left Package.resolved uncommitted.
  timestamp: 2026-11-06T04:45:52.808275+00:00
position_column: done
position_ordinal: ffffffbd80
title: Attachment commands act on every selected file
---
User decision (2026-11-05): Open, Reveal in Finder and the other attachment and file commands act on every selected file, not just the one under the cursor. KVK's board does this already through EK's command context selection (`$0.selection`).

- [ ] Attachment commands (Open, Reveal, Copy, and the rest) run on every file in AVK's file selection (`InspectorSelection` / host `AttachmentInspectorMode.host` binding). When a command fires on a file that isn't in the selection, it acts on that file alone (Finder convention)
- [ ] Availability follows the whole selection
- [ ] Context menu and keyboard paths both act on the selection
- [ ] Hosted tests through accessibility: select several files, then perform the command, and every file is acted on through a recording host hook. Also cover a command on an unselected file