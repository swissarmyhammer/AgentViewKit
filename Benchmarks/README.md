# AgentViewKit benchmarks

This package measures the streaming path of plan.md §8: the cost of the
transcript view when many chunks stream into one agent message of a
`SessionModel` (update.md §7 item 2). It records the numbers as a committed
baseline, and `Scripts/check-benchmarks.sh` fails when a change makes the path
slower than the baseline permits.

This is a **separate SwiftPM package** that depends on AgentViewKit by path, as
`../EditorKit/Benchmarks` is. The root package does not get the benchmark
dependencies, and `swift test` does not build the benchmarks.

## Run them

From the repository root:

```bash
# Each scenario, with a report.
swift package --package-path Benchmarks --disable-sandbox benchmark

# One scenario.
swift package --package-path Benchmarks --disable-sandbox benchmark \
    --filter "Transcript stream, default cadence"

# The gate.
./Scripts/check-benchmarks.sh
```

The scenarios mount SwiftUI views in an off-screen window. The window server
is not available in the sandbox of a package plugin, and a SwiftUI render in
the sandbox stops the process. Thus each command uses `--disable-sandbox`.

The full suite takes about 2 minutes on the development machine (Apple
silicon, 32 cores, Darwin 27, Swift 6.4, release build), and the gate takes
about 5 minutes with the build. The scenario with the cadence zero uses most
of the time.

## The scenarios

`SessionModelObservationBenchmarks.swift` has two scenarios. Each iteration
opens a `SessionModel` over the scripted agent of the root package, and
hosts `AgentThreadView` over the model. Outside the measurement, the agent
sends the first chunk of one agent message. The measured part is: the agent
sends 1,000 `agent_message_chunk` updates to that message, the model applies
them, and the window renders until the entry holds each chunk.

| Scenario | Cadence of the model |
| --- | --- |
| `Transcript stream, cadence zero` | `.zero`: the model applies each chunk at once |
| `Transcript stream, default cadence` | `SessionModel.defaultCoalescingCadence` (33 ms), as in an app |

The view binds directly to the `TranscriptEntry` objects of the model
(`Docs/decisions/acp-client-kit.md`). The chunks go through the coalescing of
the model, and through no coalescer and no text copy of the kit.
`SessionModelRedrawScopeTests` in `AgentViewKitTests` proves the redraw scope
of the same path in a debug build: 100 chunks into one agent message of a
transcript of 10 rows evaluate the row of that message only.

The package has no observation benchmark of FoundationModels. The observation
benchmarks of research R4 measured a FoundationModels stream through
`SessionThreadSource`. The kit is an ACP client kit, so these benchmarks and
their baselines went with the FoundationModels adapter (update.md §7 item 2).

### The boundary

A package can use only the products of another package. To compile a file of
a test target or of the test support target, put a symbolic link to the file
in `Benchmarks/AgentViewKitBenchmarks/`, and edit the file in the root
package. The target links two files:

| Link | File of the root package |
| --- | --- |
| `ScriptedWireAgent.swift` | `Sources/DemoSupport/ScriptedWireAgent.swift` |
| `ScriptedSession.swift` | `Sources/AgentViewKitTestSupport/ScriptedSession.swift` |

The two files compile in one module of this package, which has no
`DemoSupport` module and no default isolation. Thus `ScriptedSession.swift`
imports `DemoSupport` only when the module exists, and each class of the two
files states `@MainActor`. The benchmark target cannot use the default
isolation of the root package: the boilerplate file that the benchmark plugin
writes into the target does not compile with it.

`BenchmarkSymlinkTests` in `PackageStructureTests` fails when a link points at
a file that moved, and when the set of links changes.

`BenchmarkBoundaryTests` in `PackageStructureTests` fails when a benchmark
source imports FoundationModels or `AgentViewKitFoundationModels`, when
`Package.swift` links the `AgentViewKitFoundationModels` product, and when a
benchmark source declares an `@Observable` class. Such a class could stand
between the entry and the row view of the measured path.

## The gates

Each scenario checks its own gates, and stops with an error when a gate
fails. `Scripts/check-benchmarks.sh` fails on such an error. The gates of the
observation scenarios:

- The entry holds each chunk before the time limit (10 seconds).
- The render evaluated the view that reads the content of the entry. A probe
  view reads the same `content` of the entry as the message view, and counts
  its body evaluations, because `BodyEvaluationCounter` exists only in debug
  builds.

## The observation numbers

The baseline run, at a load average of 7 to 11 on the development machine:

| Scenario | p90 wall clock for 1,000 chunks | p90 instructions |
| --- | --- | --- |
| Cadence zero | **10.9 s** | 97.3 G |
| Default cadence | **209 ms** | 2.73 G |

With the cadence zero, each chunk changes the entry at once, and each change
renders the message again: about 10 ms for one chunk, on average over the
stream. The message view joins the chunks and splits the text into
paragraphs again for each change (`TranscriptMessageView`), so the cost of
one render can grow with the message. With the default cadence, the model writes
the entry one time for each flush, and the whole stream costs 50 times less.
A host that gives a cadence of zero to `ConnectionModel` gets the first cost.

The scenario with the cadence zero records only 3 samples in its 30 seconds,
so its p50 and its p90 are near each other. The instruction count is the same
in each sample, so the instruction gate stays exact.

## R1: Textual streaming cost

This section is a record. The R1 scenarios measured `StreamingMessage` and
`StreamingCoalescer` of the old kit session model. That model is removed
(`Docs/decisions/acp-client-kit.md`), and the scenarios and their baselines
went with it, so the gate does not read these numbers. The streaming tail,
the lazy stack and `lazyResponseParagraphs` went with the old session model.
A `ResponseView` now shows the full text of an entry as paragraphs, and each
paragraph that does not change does not evaluate again
(`ParagraphReuseTests`).

### The numbers

The last baseline run:

| Scenario | p90 wall clock | p90 paragraphs parsed per chunk | p90 body evaluations per chunk |
| --- | --- | --- | --- |
| Split on | **3.30 ms** (the gate reads 3.18 ms) | 1 | 1 |
| Split off | **86.2 ms** | 449 | 1 |

With the split, one chunk costs the same at the start and at the end of the
message. With no split, the cost of one chunk grows with the message: at 500
paragraphs, one chunk parses 500 paragraphs and costs about 100 ms, which is
three coalescer intervals.

The first run of this benchmark failed the gate: the p90 was **46 ms** with the
split. Two costs grew with the message:

1. `StreamingMessage` split the full text again for each flush. At 500
   paragraphs the split took 1.2 ms. `ParagraphSplitter.split(_:resumingAt:)`
   now starts at the first line that is not settled, and the flush takes
   0.03 ms at each point of the message.
2. The settled paragraphs were in a `VStack`. Each chunk changes the height of
   the tail, and the stack placed each settled paragraph again: 0.1 ms for
   each paragraph. In a scroll view, the settled paragraphs are now in a
   `LazyVStack`, which places only the paragraphs on screen
   (`EnvironmentValues.lazyResponseParagraphs`, set by `ConversationView`).
   A lazy stack shows its content only in a scroll view, so a `ResponseView`
   outside a scroll view keeps the `VStack`.

After the two changes, the render of one chunk is 1.5 ms to 4 ms at each point
of the message. Most of it is the Textual parse and layout of the tail, and
the Core Animation commit of the frame.

### The decision

**The tail stays on Textual, with the paragraph split and the balancer. The kit
does not add a lighter tail renderer** (plan.md §11 decision 9). The split is
necessary: with no split, the cost of one chunk grows past the coalescer
interval. With the split, the resumed split, and the lazy stack, the p90 cost
of one chunk is 3.2 ms to 3.3 ms, under the 4 ms gate.

The gate has a margin of about 20 % on the development machine. The benchmark
window has a fixed size (`sizingOptions = []`), as the window of an app has.
If a slower machine fails the 4 ms gate, measure the tail render first: it is
the largest part of the cost.

## R4: observation granularity

This section is a record. The R4 scenarios and their baselines went with the
FoundationModels adapter (see "The scenarios"), so the gate does not read
these numbers. The decision applies to `SessionThreadSource` while the
FoundationModels adapter is in the package.

### The numbers

The last baseline run, for one stream of 1,000 chunks:

| Tail source | p90 tail updates | p90 wall clock |
| --- | --- | --- |
| `Snapshot.transcriptEntries` | 970 | 14.2 ms |
| `SessionPropertyValues.history` | 692 | 15.6 ms |
| `session.transcript` | 690 | 15.6 ms |

| Observer, through `SessionThreadSource` | p90 invalidations per stream |
| --- | --- |
| `thread.items` | 3 (2 entries: the prompt and the response) |
| `thread.streaming[id]` | 3 |

- The stream gives one snapshot for almost each chunk. The two observed
  values change together: `session.properties.history` does not give a finer
  or a coarser granularity than `session.transcript`. An observer of either
  one gets fewer updates only because the changes between two main actor
  passes count as one.
- The first run of this benchmark found a leak: the items observer changed
  3 to 9 times for the same stream. Before the first snapshot opened the
  stream, the observation of `session.transcript` replaced the response item
  for each chunk. `SessionThreadSource` now keeps the response items of a turn
  while the turn streams, and replaces them one time at the end. The items
  observer now changes 3 times on each run.
- The streaming observer changes 3 times per stream, because
  `StreamingMessage` coalesces the chunks of one 33 ms interval.

### The decision

**`SessionThreadSource` takes the streaming tail from
`ResponseStream.Snapshot.transcriptEntries`**, as it does now:

- The snapshot source costs the least, and it gives each text in order, with
  the entry id of the response.
- `SessionPropertyValues.history` has the same granularity as
  `session.transcript`, and it gives no new data. The source does not use it.
- The source observes `session.transcript` only for entry boundaries: a new
  entry, a changed entry that does not stream, and a removed entry. A view
  reads `thread.items`, which changes only at entry boundaries, and the tail
  row reads `thread.streaming[id]`.

## The gate policy

`BenchmarkPolicy.swift` holds each number of the policy, which is the policy
of `../EditorKit/Benchmarks`:

- **Instructions**: the primary gate. Tolerance **25 %** at p50 and p90.
- **Wall clock**: the secondary gate. Tolerance **75 %** at p50 and p90.
- **Throughput**: recorded, not gated.

## The baseline-update flow

The baseline is committed as two artifacts from the same run:

| Path | Purpose |
| --- | --- |
| `Benchmarks/Baselines/*.p90.json` | The baseline that a reader can review: the p90 of each metric of each scenario |
| `Benchmarks/.benchmarkBaselines/AgentViewKitBenchmarks/main/` | The baseline that `benchmark baseline check` reads |

Record both again, from the repository root:

```bash
swift package --package-path Benchmarks --disable-sandbox \
    --allow-writing-to-package-directory benchmark baseline update main

swift package --package-path Benchmarks --disable-sandbox \
    --allow-writing-to-package-directory \
    benchmark thresholds update main --path Benchmarks/Baselines
```

Then run `./Scripts/check-benchmarks.sh` and commit both paths in the same
change.

Record the baseline again for an intentional regression (and tell why in the
change), for an improvement past a threshold, for a new scenario, or for a
new recording machine. Do not record the baseline again to make a failed gate
pass.

## Adding a scenario

1. Put the scenario in the file for its area, or add a file with a type that
   has a `register()` function, and call it from `Main.swift`.
2. Use `BenchmarkPolicy.configuration(iterations:)`. Do not
   write a threshold of your own.
3. Build the workload outside the measurement. Only the path under test goes
   between `startMeasurement()` and `stopMeasurement()`.
4. Record the baseline in the same change.
