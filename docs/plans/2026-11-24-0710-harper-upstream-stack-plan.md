---
title: Prepare Harper's connector work for upstream review
type: implementation-plan
date: 2026-11-24
last_reviewed: 2026-11-24
artifact_contract: kata-plan/v1
artifact_readiness: implementation-ready
domain: software
execution: code
product_contract_source: direct-request
---

# Prepare Harper's connector work for upstream review

## Goal Capsule

- Objective. Supply a verified stack of draft PRs for Mike's review.
- Means. Port the rebuilt fork in provider-sized changes and record the source of each change.
- Authority. Local implementation, tests, commits, pushes, and draft PRs in agentjido/jido_connect.
- Stop conditions. The review stack is ready, or a material dependency prevents further work.
- Next executor. The implementation agent, followed by the repository maintainer for review.

## Product Contract

### Summary

Prepare the applicable changes from Harper's rebuilt v3 branch for upstream.

### Problem Frame

The fork mixes provider fixes, new capabilities, shared test changes, and live recordings. Some of the work is already upstream. Its Docs request changes overlap with PR #128.

### Actors

Harper supplies the source. Mike reviews the stack.

### Requirements

- R1. Account for all 15 commits in the rebuilt v3 range and the separate Slack scope fix.
- R2. Port the relevant Slack, Google Workspace, Jira, Confluence, and shared fixes. Exclude Tempo.
- R3. Verify the stack and publish draft PRs with exact source and test evidence.

### Key Flows

Trace the source, apply and adapt each unit, check its behavior, and publish in review order.

### Acceptance Examples

The recorder is the first layer. The Slack scope fix precedes the rest of Slack. The Docs batch-update request keeps the upstream encoder. Jira delivery capture follows Jira signature verification.

### Success Criteria

Each PR has a bounded diff, an upstream or previous stack base, and evidence for its head. A coverage map accounts for upstream, ported, and excluded source changes.

### Scope Boundaries

Use upstream `release/3.0` and Harper's rebuilt `release/3.0`. The user reserved merge decisions for review. Tempo is outside this work.

### Key Decisions

Use provider boundaries for the review stack. Separate the Slack scope fix and the recorder from provider feature work.

### Rejected Alternatives

A whole-branch merge conflicts with upstream Docs changes and would include Tempo. The closed draft #112 remains historical evidence.

### Dependencies

The stack relies on upstream harness #117, Slack capture #118, Jira public data #119, ADF #120–#122, and Docs encoding #128.

### Outstanding Questions

Live provider credentials and a newly ended Meet session are outside the offline verification scope. Record the gap in review.

### Sources

- [Fork inventory](https://github.com/Harper04/jido_connect/blob/a7364ad0/docs/fork_inventory.md)
- [Original review](https://github.com/agentjido/jido_connect/pull/112)

## Planning Contract

### Product Contract Preservation

Track R1–R3 in the PR bodies and final coverage map.

### Current System

The merge base is `22772cbf`. The current upstream head at intake is `09ae02d9`. The fork tip is `a7364ad0`.

### Target System

Each provider owns its client, normalization, action, trigger, docs, and tests. Core hosts the recorder and scoped test configuration.

### Key Technical Decisions

- KTD1. Port source commits on a clean clone. Preserve attribution in each commit and keep the current checkout independent. Applies to R1–R3.
- KTD2. Prefer upstream Docs request handling and separately port response handling and tabs. Applies to R2.
- KTD3. Preserve only recordings needed to prove behavior. Review fixture data and use offline tests. Applies to R2–R3.

### System Boundaries and Change Surface

| Surface | Planned work | Check |
| --- | --- | --- |
| Shared tests | Recorder and Google resolver contract | Recorder, fixture, and provider contract tests |
| Authorization | Slack scope floor and provider scope updates | Scope and action tests |
| Provider responses | Google Workspace, Jira, and Confluence updates | Provider tests and compatibility checks |
| Delivery | Slack and Jira webhook updates | Verification, normalization, and demo tests |

### Implementation Units

| Unit | Source | Acceptance |
| --- | --- | --- |
| U1 Recorder | 00408d7c and generic part of b622e41d | Recorder and fixture checks |
| U2 Slack scope | b4ed853c, 24823918, e292d7a3 | Scope resolver tests |
| U3 Calendar | fb2335ba and 3eacfd60 | Polling tests with a missing final token |
| U4 Gmail | 8cfc916e | Scope, MIME, content, polling tests |
| U5 Drive | fa0819da | Links, bytes, upload, polling tests |
| U6 Docs | 874cf84c | Tabs, acknowledgement, upstream wire encoder |
| U7 Meet | 8e2f13dc | Recorded transcript, participant, polling tests |
| U8 Confluence | 31779777 | Source URL and ADF output tests |
| U9 Jira | 3012d1fa and ed6b10cf | Reads, verified deliveries, demo capture |
| U10 Slack | 070f0390 | History, scopes, interactivity and signals |
| U11 Review map | 34097216, a7364ad0, provider parts of b622e41d | Docs and source coverage with Tempo excluded |

### Work Graph

U1 first. U2 precedes U10. U3 precedes the remaining Google layers. Jira verification precedes demo capture. Provider variables and docs land with their tests.

### Verification Contract

Run targeted package tests, the umbrella `mix quality` gate, demo format and tests, fixture review, Git diff checks, and a remote PR base and head check. Use the CI Erlang and Elixir versions. Live write tests remain opt-in.

### Rollout and Recovery

Publication creates draft PRs. Each layer can be reviewed or held before upstream merge.

### Risks and Assumptions

Docs uses a different wire-key approach in the fork. Jira search changes its pagination contract. External live coverage is limited to evidence Harper recorded. The PRs must identify these boundaries.

### Open Planning Decisions

The maintainer decides whether to merge each draft and when to run live provider tests.

### Definition of Done

Verified draft PRs exist for the in-scope changes. The delivery map accounts for all source commits, including the Tempo exclusion and existing upstream work.

### Planning Sources

- [Upstream v3](https://github.com/agentjido/jido_connect/tree/release/3.0)
- [Current fork delta](https://github.com/agentjido/jido_connect/compare/22772cbf...Harper04:jido_connect:release/3.0)

## Adapter Results

- Markdown is canonical in the repository plan directory.
