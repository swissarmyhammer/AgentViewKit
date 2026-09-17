# Permission and mode UX (R8)

Status: decided. Source: plan.md §9 E and §14 R8.

This file records the permission prompts and the permission modes of Claude
Code, Cursor, and Codex. It maps them onto the four ACP `PermissionOptionKind`
values and onto the ACP config option of category `mode`. Then it records how
`PermissionView` shows the options and when it offers "switch to auto".

`Tests/AgentViewKitTests/HumanInTheLoop/PermissionPresentationTests.swift`
parses the two tables in the Decision section. It compares each row with
`PermissionPresentation` in
`Sources/AgentViewKit/HumanInTheLoop/PermissionPresentation.swift`. Keep the
headers and the form of the rows. Use `yes` or `no` in the flag columns. Put
the kind and the mode state in backticks.

## Survey

All pages were read on 2026-09-16.

### Claude Code

Sources:

- <https://code.claude.com/docs/en/permissions>
- <https://code.claude.com/docs/en/permission-modes>

Permission modes (the `permissions.defaultMode` values):

| mode | what runs without a prompt |
|---|---|
| `default` | Reads. The docs call it Manual mode. |
| `acceptEdits` | Reads and file edits. |
| `plan` | Reads. The user approves a plan before edits start. |
| `auto` | Most actions. A classifier model reviews them. |
| `dontAsk` | Only the actions that rules allow. It denies the others and never prompts. |
| `bypassPermissions` | All actions, but not the actions that ask rules match. Deny rules still block. |

- Shift+Tab cycles the modes in the CLI: `default`, `acceptEdits`, `plan`.
  `bypassPermissions` and `auto` come after `plan` when they are available.
  `dontAsk` is never in the cycle.
- The permission prompt has a one-time "Yes", a "Yes, and don't ask again"
  answer, and a "No" answer where the user can tell Claude what to do in a
  different way. "Don't ask again" is kept for each repository and command
  for Bash, and until the session ends for file edits.
- In `default` and `acceptEdits`, when auto mode is available, the Bash
  prompt adds "Yes, and switch to auto mode". The PowerShell prompt does not.
- The plan approval prompt has "Yes, and use auto mode" and "Yes, manually
  approve edits".
- The prompt for a write to `.claude/` has "Yes, and allow Claude to edit its
  own settings for this session".
- There is no "always for this folder" answer. A kept Bash rule applies to the
  full repository.

### Cursor

Sources:

- <https://cursor.com/docs/agent/security/run-modes>
- <https://cursor.com/changelog/auto-review> (Cursor 3.6, 2026-05-29)

Run modes (Settings > Cursor Settings > Agents > Run Mode):

| run mode | what runs without a prompt |
|---|---|
| Auto-review | Allowlisted calls. Then sandboxed shell commands. A classifier reviews the other calls and can ask the user. |
| Allowlist | Allowlisted calls, and sandboxed shell commands when the sandbox is on. |
| Run Everything | All tool calls. |

- Auto-review is the default from Cursor 3.6.
- The docs do not give the labels of the approval buttons. The allowlist is
  a kept answer for a command or an MCP tool, so it maps to `allow_always`.
- The approval prompt does not offer to change the run mode. The docs do not
  show such an action.

### Codex

Sources:

- <https://learn.chatgpt.com/docs/agent-approvals-security>
- <https://learn.chatgpt.com/docs/sandboxing/auto-review>

Permission presets (the `/permissions` command):

| preset | what runs without a prompt |
|---|---|
| Read Only | Reads. |
| Auto | Reads and edits in the workspace. The default. |
| Full Access | All actions, with network access. |

- `approval_policy` is `on-request`, `never`, or a granular table.
  `untrusted` is retired.
- `approvals_reviewer = "auto_review"` sends the approval requests to a
  reviewer agent. `user` is the default.
- The approval prompt has "Yes, proceed", "Yes, and don't ask again for
  commands that start with ...", and "No, and tell Codex what to do
  differently".
- There is no "always for this folder" answer. The kept answer is a command
  prefix.

### ACP

- ACP v2 `PermissionOptionKind` has four values: `allow_once`,
  `allow_always`, `reject_once`, and `reject_always`. The agent sends the
  options in its own order, with its own labels.
- The permission mode is a `SessionConfigOption` of category `mode`. Its
  choices are the ids of the agent, such as `default`, `acceptEdits`, `plan`,
  and `auto`. ACP has no standard id list.
- The ACP wire has no directory-scoped grant and no field for a comment. The
  kit sends a comment as the next user message (plan.md §3.4).

## Mapping

| product answer | ACP kind |
|---|---|
| Claude Code "Yes" | `allow_once` |
| Claude Code "Yes, and don't ask again" | `allow_always` |
| Claude Code "Yes, and allow Claude to edit its own settings for this session" | `allow_always` |
| Claude Code "No" with the text of the user | `reject_once` and a comment |
| Claude Code "Yes, and switch to auto mode" | `allow_once`, then the `mode` option set to `auto` |
| Codex "Yes, proceed" | `allow_once` |
| Codex "Yes, and don't ask again for commands that start with ..." | `allow_always` |
| Codex "No, and tell Codex what to do differently" | `reject_once` and a comment |
| Cursor run of one call | `allow_once` |
| Cursor add to the allowlist | `allow_always` |
| Cursor skip of one call | `reject_once` |
| (no product answer) | `reject_always` |

| product mode | `mode` choice id |
|---|---|
| Claude Code `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions` | the same string |
| Codex Read Only, Auto, Full Access | the ids that the ACP adapter of Codex sends. This survey did not read that adapter. The Auto preset maps to `auto` only when the adapter uses that id. |
| Cursor Auto-review, Allowlist, Run Everything | Cursor has no ACP agent in the survey |

## Decision

### Option order and weight

`PermissionPresentation.order(for:)` sorts the kinds by `position`.
`PermissionPresentation.order(of:)` sorts the options with the same rule, and
`PermissionView` shows its buttons in that order. The order of the request
does not decide the order of the buttons.
`PermissionPresentation.isSecondary(_:)` gives the `secondary` column.

| kind | position | secondary |
|---|---|---|
| `allow_once` | 1 | no |
| `allow_always` | 2 | yes |
| `reject_once` | 3 | no |
| `reject_always` | 4 | yes |
| `unknown` | 5 | yes |

Rules:

- The order puts each one-time answer before its kept answer. This is the
  order of the Claude Code and Codex prompts.
- The sort is stable. Options with the same position keep the order of the
  request. The card shows each option that the request sends, also a repeated
  kind.
- The one-time answers are the primary buttons. A kept answer changes later
  prompts, so the card shows it with less weight.
- The `unknown` row applies to each kind that the kit does not know.

### Directory-scoped option

There is no fifth, directory-scoped option in v1.

- No product in the survey has an "always for this folder" answer. Claude
  Code keeps a rule for the repository. Codex keeps a command prefix.
- ACP has no such kind. The FoundationModelsRouter has no permission store.
  `../FoundationModelsACPAgent/plan.md` has no store for kept answers.
- Thus no v1 source supplies the option. When a source sends a kind that the
  kit does not know, the card shows it last, as a secondary option, with the
  label of the source.

### Switch to auto

`PermissionPresentation.showsSwitchToAuto(configOptions:)` gives the second
column. `PermissionPresentation.autoModeOption(in:)` gives the option that the
action sets. The action sends the choice id `auto`.

| mode state | shows switch to auto |
|---|---|
| `no mode option` | no |
| `no auto choice` | no |
| `current auto` | no |
| `current plan` | no |
| `current other` | yes |

Mode states:

- `no mode option`: no config option has the category `mode`.
- `no auto choice`: the first `mode` option is not a select, or no choice has
  the id `auto`. Grouped choices count the choices of each group.
- `current auto`: the current value is `auto`.
- `current plan`: the current value is `plan`. The plan approval prompt of the
  source offers auto mode, not the command prompt.
- `current other`: each other current value, for example `default`,
  `acceptEdits`, or a read-only mode.

Rules:

- The first config option of category `mode` decides. The kit does not look
  at a second `mode` option.
- The ids are compared exactly. ACP ids are case-sensitive strings.
- The action is an extra control on the card, not a `PermissionOption`. When
  the user selects it, the card sends the `allow_once` option of the request,
  then sets the mode option to `auto`. When the request has no `allow_once`
  option, the card does not show the action. `PermissionView` owns that check.
- Claude Code shows the action for Bash prompts only. The kit shows it for
  each request, because the ACP request does not tell the tool type in a
  standard form.
