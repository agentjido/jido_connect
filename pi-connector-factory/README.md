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
