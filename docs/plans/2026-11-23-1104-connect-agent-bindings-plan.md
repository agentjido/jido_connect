---
title: Connect Agent bindings and credential leases
type: implementation-plan
date: 2026-11-23
last_reviewed: 2026-11-23
artifact_contract: kata-plan/v1
artifact_readiness: implementation-ready
domain: software
execution: code
product_contract_source: direct-request
---

# Connect Agent bindings and credential leases

## Goal Capsule

- Fix the audited dependency and prove a signed GitHub event can start a Jido Flow that obtains a credential lease automatically.
- Use the existing connector declarations, one shared Agent Plugin, and a standard Flow Action.
- Use local write authority. Stop after the local implementation and checks are complete.
- The implementer runs the units in order. The verification commands decide the result.

## Product Contract

### Summary

Connector authors supply operations. Agent authors select those operations in `connect do`. The host supplies live access and controls ingress.

### Problem Frame

The lock selects an affected `idna` version. The Agent DSL already resolves a lease for a generated Action. Its Trigger selections need an end-to-end use from a host entry point.

### Actors

The connector author publishes operation contracts. The Agent author declares bindings and routes. The host controls verified delivery, connection access, and credentials.

### Requirements

- **R1** Resolve the `idna` advisory in the shared lock and pass the Hex audit.
- **R2** Use a declared GitHub webhook trigger to route one verified pull request delivery through a standard Action step and obtain a current credential lease.
- **R3** Describe which parts of the package the Agent DSL touches and where host responsibilities begin.

### Key Flows

The host looks up a selected trigger, verifies a delivery, applies its delivery policy, and sends a Signal. Jido routes the Signal. Connect uses the binding and host context to check access and obtain a lease for the read.

### Acceptance Examples

A signed pull request delivery for the allowed repository saves a PR summary from the API fixture. A bad signature, a known delivery ID, or a repository outside the grant fails before provider access. Credential rotation and revocation continue to take effect on the next call.

### Success Criteria

The dependency audit, Agent examples, focused core and GitHub tests, umbrella quality, and demo checks pass. The architecture guide explains how to reproduce the same composition with another connector.

### Scope Boundaries

The changes cover the local v3 branch, a GitHub PR read, and an offline fixture. Hosts own HTTP ingress, durable deduplication, credentials, and action policy. Production setup and publishing are outside this effort.

### Key Decisions

The accepted `connect do` pattern uses a shared Plugin and native Action steps. The host stores credentials by their own IDs and gives each connection a separate grant.

### Rejected Alternatives

A provider-specific Agent Plugin would duplicate binding and lease selection. Connect uses one shared Plugin for this role.

### Dependencies

JSV 0.28 allows `idna` 8. The pinned Jido v3 dependency supplies Agent Server admission, Signal routes, and Flow execution.

### Outstanding Questions

The local fixture is sufficient for this slice. Each production host can select its own delivery store and ingress strategy.

### Sources

- [Hex idna advisory](https://hex.pm/packages/idna/advisories)
- [JSV 0.28 dependencies](https://hex.pm/packages/jsv/0.28.0/dependencies)
- [Architecture](../architecture.md) and [Generated modules](../generated_jido_modules.md)

## Planning Contract

### Product Contract Preservation

This plan carries the direct request and the existing local credential lease example into one verified v3 change.

### Current System

`Jido.Connect.Plugin` lowers bindings and supplies transient Action context. The generated Action runtime selects the binding during a live turn. GitHub verifies and normalizes pull request webhook deliveries. GitHub publishes a PR poll trigger, while its webhook helpers are independent of the Agent DSL.

### Target System

The host looks up a Trigger contract under a declared binding. A GitHub PR webhook trigger reads the verified delivery and supplies typed Signal data. A standard Jido route starts the Flow and a generated Action obtains the host lease on demand.

### Key Technical Decisions

- **KTD1** Update the existing JSV overrides in core and Trello. Require `idna` 8 in core. JSV still accepts earlier major releases. A direct minimum also protects a consumer that already has an older `idna` lock. Covers R1 and U1.
- **KTD2** Add a host lookup for one declared Trigger and use the existing GitHub verification entry point. Keep request verification and delivery policy at ingress. Covers R2 and U2.
- **KTD3** Keep binding selection in the shared Plugin and run the read through the existing generated Action runtime. The provider trigger supplies data and the Agent route owns the response. Covers R2–R3 and U2–U3.

### System Boundaries and Change Surface

| Surface | Owner and proposed work | Compatibility |
| --- | --- | --- |
| Package graph | Core and Trello dependency declarations and the shared lock select patched versions. | Umbrella and demo share the lock. |
| Agent | Shared Plugin exposes the compiled Trigger selection and uses the existing admission path. | Existing bind and call shapes still work. |
| Provider | GitHub declares a PR webhook trigger and projects data from a verified delivery. | Existing webhook verification and PR polling keep their entry points. |
| Host | Lesson receives a verified delivery and supplies the live binding context on Signal dispatch. | The host owns delivery state and lease issuance. |

### Implementation Units

#### U1 Fix the advisory

R1. Update the existing JSV dependency to 0.28 and require `idna` 8. Review the shared lock and record the selected versions. The audit must pass before the DSL changes start.

#### U2 Route a declared GitHub webhook trigger

R2. Depends on U1. Add a declared-trigger lookup in the shared Plugin, a GitHub PR webhook Trigger, and a numbered Agent lesson. The fixture must show a successful verified delivery and rejection of invalid, duplicate, undeclared, and disallowed inputs. A native generated Action must read the PR via the host resolver.

#### U3 Explain the package boundary and run the full checks

R3. Depends on U2. Update the architecture and generated-modules guides. Keep the lease example and the two-integration Flow as regression coverage. Record final checks in the dependency status document.

### Work Graph

U1 → U2 → U3. The dependency repair is the first independent result. U3 integrates the documented design and the tested checkout.

### Verification Contract

Run the first four checks from the umbrella root. Run demo checks in `dev/demo`.

| Requirement | Check | Expected result |
| --- | --- | --- |
| R1 | `mix hex.audit` and shared lock diff | Patched `idna` and a clean audit. |
| R2 | `mix test.examples --warnings-as-errors` | Signed delivery performs one read. Denials stop before the provider read. |
| R2 | `mix test apps/jido_connect/test --cover` | Core Trigger selection and runtime tests pass. |
| R2–R3 | `mix quality` and `git diff --check` | Package tests and formatting pass. The code agrees with the guide. |
| R1–R3 | `MIX_ENV=test mix do format --check-formatted + compile --warnings-as-errors + test` | Demo compiles and passes its tests. |

### Rollout and Recovery

The branch uses a shared lock and adds one Agent-facing lookup. No stored records need migration. A host can adopt the trigger by adding a binding selection and route in its Agent definition.

### Risks and Assumptions

A verified event can still name a repository outside the grant. The host checks that grant when the Action runs. The offline test uses known delivery IDs and does not establish production deduplication behavior.

### Open Planning Decisions

The production delivery store is a host decision and is outside this fixture.

### Definition of Done

The audit passes, the signed delivery reaches the standard Action via the declared Trigger, denial cases are covered, and the architecture guide names the actual code boundaries.

### Planning Sources

- [Core Plugin](https://github.com/agentjido/jido_connect/blob/22772cbf9d87c78aedaf143b5f73d6908074755f/apps/jido_connect/lib/jido_connect/jido/plugin.ex)
- [Generated Action runtime](../../apps/jido_connect/lib/jido_connect/jido/action_runtime.ex)
- [GitHub webhook verification](../../apps/jido_connect_github/lib/jido_connect/github/webhook/verification.ex)
- [Branch support and verification](../branch_support.md)

## Adapter Results

Markdown is the canonical plan. This request uses the repository plan only.
