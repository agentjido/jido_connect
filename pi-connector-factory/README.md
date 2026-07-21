# Pi Connector Factory

Small Beadwork-driven wrapper for letting Pi + Z.ai implement one connector task
at a time in this repo.

Beadwork is the backlog and state system. Codex should create and refine
connector tasks in `bw`; this wrapper only selects ready Beadwork tasks and asks
Pi to implement them.

## Setup

```sh
cd pi-connector-factory
cp .env.example .env
$EDITOR .env
bun install
npm install -g @earendil-works/pi-coding-agent
```

## Commands

Show top-level help:

```sh
bun run src/cli.ts help
```

Show command-specific help (no side effects):

```sh
bun run src/cli.ts doctor --help
bun run src/cli.ts prompt --help
bun run src/cli.ts step --help
bun run src/cli.ts loop --help
bun run src/cli.ts status --help
bun run src/cli.ts recover --help
```

Check local wiring:

```sh
bun run doctor
```

Run exactly one ready Beadwork task:

```sh
bun run step
```

This streams Pi session events while the task runs. Raw JSONL session logs are
also written under `runs/<timestamp>-<issue>-step/sessions/`.
The default Pi timeout is 30 minutes; override it with `PI_TIMEOUT_MS` in
`.env` when a task needs more room.

Run one specific task:

```sh
bun run step -- --issue jido_con-abc
```

Run a Ralph-style loop, one Beadwork task at a time:

```sh
bun run loop -- --limit 5
```

The loop runs the same clean one-commit contract as `step`, then re-reads
Beadwork before selecting the next task. It stops when there are no ready child
tasks left or when one step fails.

Preview the exact Pi prompt for the next task:

```sh
bun run prompt
```

## Timeout & Recovery

The factory is designed to run long loops unattended. A Pi timeout is an
expected event with large connector tasks, not an exceptional disaster.

### What happens on timeout

When a `step` fails (timeout, Pi crash, wrong commit count, dirty tree after
commit), the factory:

1. Writes a `recovery.json` marker to the run directory.
2. Prints a structured failure report:
   - Active issue id
   - Run directory and log path
   - Whether the git worktree is dirty
   - Whether the Beadwork issue is still `in_progress`
   - Exact recovery commands to run
3. Exits with code 1 **without** modifying git or Beadwork state.

The factory **never** auto-drops, auto-stashes, or auto-resets uncommitted
work. Your WIP is preserved exactly as Pi left it.

### Check factory state

```sh
bun run status
```

This shows: git clean/dirty, Beadwork issues in_progress, last run directory,
and whether the last run left a recovery marker.

### Guided recovery

```sh
bun run recover
```

By default this only prints the current state and recommended next steps.
It does **not** modify anything.

```sh
# Stash WIP with a descriptive name
bun run recover -- --stash

# Reopen the Beadwork issue so it can be re-attempted
bun run recover -- --reopen

# Both at once
bun run recover -- --stash --reopen
```

### Manual recovery

If you prefer to handle recovery by hand:

```sh
# 1. Check what happened
bun run status

# 2. Review uncommitted changes
git status
git diff

# 3. Stash or commit WIP as appropriate
git stash push -m "factory-recover-<issue-id>"

# 4. Reopen the Beadwork issue
bw reopen <issue-id>

# 5. Verify environment
bun run doctor

# 6. Re-attempt the step
bun run step -- --issue <issue-id>
```

### Key principle

The factory preserves the **clean-tree / one-commit contract**: each step
starts and ends with a clean worktree and exactly one new commit. Recovery
from a failure means getting back to that state explicitly, never silently.

## Contract

Each `step`:

- Requires a clean Git worktree before Pi starts.
- Selects one ready Beadwork task, excluding epics by default.
- If `bw ready` returns only epics, selects the first ready child task whose
  blockers are closed.
- Starts the task with `bw start`.
- Runs Pi with Z.ai `glm-5.1`.
- Requires Pi to make exactly one commit on the current branch.
- Requires the worktree to be clean after that commit.
- Closes the Beadwork task after the commit succeeds.

If no non-epic Beadwork task is ready, Codex needs to split an epic into child
tasks first.

## Wave Verification

After a factory loop finishes (or at any checkpoint), verify the health of the
connector family:

```sh
bun run verify-wave
```

This runs **serially** (no parallel Mix build lock contention):

1. Root `mix compile --warnings-as-errors --no-deps-check` — catches API drift
   and stale dependency assumptions across the umbrella.
2. Package tests for each connector, one at a time: Cal.com, HubSpot, Airtable,
   Webhook, Jira, Linear, PostHog, Calendly, Salesforce.

It prints a concise PASS/FAIL summary and exits non-zero if any step fails.

Skip the root compile check:

```sh
bun run verify-wave -- --skip-compile
```

Run only specific packages:

```sh
bun run verify-wave -- --package calcom --package jira
```

### How this differs from `bun run loop`

`bun run loop` runs Pi implementation tasks one at a time. Each step only
verifies that Pi produces a clean commit for that single task. It does **not**
check whether other connector packages still pass their tests.

`bun run verify-wave` is a **post-loop gate**: after the factory finishes a
batch of connector tasks, run this to confirm the whole connector wave is
green. It catches dependency drift, compilation warnings, and package test
failures that a single-task check would miss.

### When to run it

- After a factory loop completes a wave of connector tasks.
- Before merging or releasing a batch of connectors.
- As a periodic health check on the connector family.
