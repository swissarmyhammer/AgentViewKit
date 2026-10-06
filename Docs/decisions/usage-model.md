# Usage model (R16)

Not current. See `Docs/decisions/acp-client-kit.md`.

status: accepted
date: 2026-09-16
plan: plan.md §3.2, §14 (R16)

## Question

Which usage data does the kit keep in one `ContextUsage` value?

The source is the ACP v2 `SessionUpdate.usage_update` (`UsageUpdate` with
`Cost`).

The first version of this record also merged the FoundationModels
`LanguageModelSession.Usage` and the Private Cloud Compute `QuotaUsage`. The
kit is now an ACP client kit, so those sources and their fields are gone
(update.md §6).

## Sources read

- `FoundationModelsACP` generated models: `UsageUpdate` (`size`, `used`,
  `cost`, `_meta`) and `Cost` (`amount`, `currency`, `_meta`).

## Merge table

Each row maps one source field to one stored property of `ContextUsage`.
`ContextUsageTests` reads this table. The second cell of each row must be a
stored property name of `ContextUsage`, and each stored property must have a
row.

| source field | ContextUsage field | note |
| --- | --- | --- |
| ACP `UsageUpdate.used` | `used` | Tokens in the context window now. |
| ACP `UsageUpdate.size` | `size` | The size of the context window in tokens. |
| ACP `UsageUpdate.cost.amount` | `cost` | Goes to `Cost.amount`. The cost is cumulative for the session. |
| ACP `UsageUpdate.cost.currency` | `cost` | Goes to `Cost.currency`, an ISO 4217 code. |

## Fields that the kit does not merge

- ACP `_meta`: extension data with no fixed keys. A host that needs it reads
  the source directly.

## Decision

- `ContextUsage` has two required fields, `used` and `size`, and one optional
  part, `cost`.
- A source that gives no cost leaves `cost` as `nil`.
- `ContextUsage` has no `fraction`. `ContextUsageView` reads
  `SessionModel.usage` directly, and its `UsageRingView` makes the ring and
  the percentage from `used` and `size`.
