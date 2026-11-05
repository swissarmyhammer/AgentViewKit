---
assignees:
- claude-code
comments:
- actor: claude-code
  id: 01m6nz17f1831cyb54y15dkz1g
  text: |-
    Picked up (on top of ^d86qrhz commit 7a3d72fb; EK fca868d4, c4ed98c5 is ^jaxzzkn). Research:
    - EK CommandRegistry.attempt builds the command, checks availability on that same value with the same context, and runs it at once. So a run that declines only where its own availability would be unavailable never declines for a key: the binding is skipped as unavailable first. That holds for AgentRowListOpenCommand (openRow vs canOpen), AgentCommand (target nil / AgentCommandTarget.run re-checks availability), AgentAttachmentCommand's guards (service, attachment, verb.availability), and SubjectProbeCommand (subject nil).
    - Reachable declines: AgentCommand Focus Composer when composer.focus() returns false (probe could not take the focus); AgentAttachmentCommand when service.run returns false (NSWorkspace.open fails, or the share picker has no view in a window).
    - EK nav.* commands always return true, so in an AgentRowList the list's own bindings never decline; the onKeyPress performKey path (AgentRowListKeys.route) changes only when a command nearer the row, or an outer host command, declines.
    - Fall-through order is: the next scope's definition of the same id first, then the next binding of the chord, then .ignored/host.
    Decisions:
    1. AgentRowListOpenCommand (`openRow ?? false`): fall through. Its decline is unreachable (see above); a key it does not take goes to nav.drillIn. AgentRowListKeys (performKey -> .ignored): fall through is right: a row command that declines Return passes it to Open; a key every command declines is .ignored and reaches the host's own key handler. No code change.
    2. AgentCommand (`target?.run ?? false`): fall through. Focus Composer that cannot move the focus did nothing, so the key goes on like an unbound key. No code change.
    3. AgentAttachmentCommand: guards fall through (they equal unavailability). A run that reached the service HOLDS the key even when the service could not start the action: the key was aimed at that attachment, and passing it on would fire another command of the chord (e.g. a host Return). Change: run returns true once the service ran; the presenter already logs the failure.
    4. AgentScopeSubjectHostedTests fixture (SubjectProbeCommand `guard let subject else { return false }`): fall through; its decline equals unavailability. No change.
  timestamp: 2026-11-05T13:40:35.425333+00:00
position_column: doing
position_ordinal: '9180'
title: Check AVK key commands against EditorKit's declined-key fall-through (^jaxzzkn)
---
**Blocked** on EK ^jaxzzkn (in review, 2026-11-05); editorkit-b5 sends the SHA. A behaviour change, not an API change: when a key's command `run` returns false, the key passes on — the next same-id outer definition first, then the next eligible binding, then the host. Calling a specific id (menu, palette, context menu, commandClick, intent) still targets only that command, and false means it failed.

## What
- Run `swift package update` with all dependencies together.
- Check each AVK site where `run` can return false, and confirm that the key falling through to the next binding is right there and doesn't fire an unintended command:
  - AgentRowListCommands (`openRow ?? false`)
  - AgentCommands (`target?.run ?? false`)
  - AgentAttachmentCommands (the guards)
  - the AgentScopeSubjectHostedTests fixture
- `AgentRowListCommands.swift:352` calls `performKey` from onKeyPress and returns `.ignored` on false. A declined key now tries the next binding before it's ignored.
- Where falling through would be wrong, make the command claim the key explicitly.

## Tests
- [ ] For each site, a hosted test that a declined key reaches the next binding, or is held, as decided. Drive it through accessibility or key events, never the mouse.
- [ ] The full AVK suite is green; RequestDeck:153, AgentNavigation:89/92 and SingleLineFieldChecks:172 still pass.