---
title: Use typed Connect context for Agent bindings
type: implementation-plan
date: 2026-11-23
last_reviewed: 2026-11-23
artifact_contract: kata-plan/v1
artifact_readiness: implementation-ready
domain: software
execution: code
product_contract_source: direct-request
---

# Use typed Connect context for Agent bindings

## Goal Capsule

- Give the host one `%Jido.Connect.Context{}` value to pass for each named Agent binding.
- Use the Context for caller identity, connection selection, and access callbacks. The host stores credentials and the runtime obtains a lease for each authorized operation.
- This request authorizes local planning. Stop after the plan passes review. Implementation starts when the work owner authorizes local code changes.
- The next executor is a Connect implementer working on the v3 Agent DSL branch.

## Product Contract

### Summary

The host can pass `%{connect: %{source: context}}` to a running Agent. A generated Action uses the selected Context to check access and request a lease.

### Problem Frame

The Agent Plugin currently requires an outer access map. Its `integration_context` key holds the tenant, actor, and connection. Policy and resolvers are sibling keys. A typed value makes the common call easier to read and lets the constructor validate the access callback references.

### Actors

The host assigns the actor and tenant, selects a grant, and owns credential storage and policy. The Agent author selects operations and can declare a credential resolver in `connect do`. Connect applies the selected access controls at execution time.

### Requirements

- **R1** A live Agent accepts a `Context` directly under a binding name. The Context can identify a resolved connection or a selector.
- **R2** A Context can carry typed policy and resolver references. A generated Action checks policy before it requests a current lease. A connection can reference a credential that other connections also use.
- **R3** Existing access maps and explicit runtime options remain valid. Prepared writes continue to require explicit leases for their approval snapshots.
- **R4** The webhook and credential lease lessons show the direct Context call, with proof of the access checks and credential lifecycle.

### Key Flows

The host verifies a webhook and sends a Signal with a Context under `:connect`. Live admission selects the binding. The generated Action resolves the connection if necessary, then Connect checks the operation and asks the host resolver for a lease. The Action result can enter Agent state through the Flow output.

### Acceptance Examples

- A signed GitHub delivery and a bare Context for `:source` run the existing `GetPullRequest` Flow step and save the PR summary.
- A denied repository or mismatched tenant or connection stops before the resolver reads a credential. A resolver error ends the operation.
- Two bindings use one stored credential through separate grants. Rotation takes effect on the next call. Revoking one grant stops that connection.
- An existing caller passes an access map with a function policy or an explicit lease as supported by its current entry point.

### Success Criteria

The examples use the same runtime path as application callers. Tests show that a policy supplied on the Context applies to both a generated Action and a direct operation. Tests cover the documented precedence when a host uses an explicit option.

### Scope Boundaries

The v3 slice covers Context construction, live Agent binding admission, shared generated Action and poll adapter context handling, and the core access checks those paths call. Callback references and host claims are in scope. Credential storage, lease contracts, approval snapshots, webhook verification, delivery claims, and provider handler contracts retain their existing owners. General catalog configuration and MCP endpoint or notification lifecycle changes are outside this slice.

### Key Decisions

`Connection.credential_ref` links to a credential under its own host-owned ID. Access callbacks can use the Context and parsed operation input. The runtime authorizes the operation before it requests a lease. Request timeouts, provider clients, callback arguments, and test overrides stay in runtime options.

### Rejected Alternatives

A second public access wrapper for every Agent call would keep the extra map at the boundary. A general metadata field for callbacks would leave the callback shapes implicit. Typed fields on the existing Context cover the common call.

### Dependencies

This plan builds on the v3 Agent DSL, the shared generated Action runtime, and the signed GitHub example in the current checkout. It uses the pinned Jido Plugin admission and the existing Zoi schema patterns.

### Outstanding Questions

The additive v3 slice can proceed once authorized. Removal of the outer map, a tenant-wide bundle of Contexts, or declarative policy on the binding would each require a separate decision.

### Sources

- [Agent composition](https://github.com/agentjido/jido_connect/blob/22772cbf9d87c78aedaf143b5f73d6908074755f/docs/architecture.md#agent-composition)
- [Prior Agent binding plan](2026-11-23-1104-connect-agent-bindings-plan.md)
- [Host-owned storage and lease rules](../host_owned_storage.md)

## Planning Contract

### Product Contract Preservation

The plan preserves the agreed caller shape and the host's credential ownership. Existing forms stay available during adoption.

### Current System

`Context` contains the tenant, actor, connection or selector, claims, and metadata. `Plugin.admit/3` filters named host access maps and `Plugin.action_context/3` returns the selected access map. `Jido.RuntimeContext` reads the context, resolves a selector for generated adapters, and forwards runtime options. `Runtime.fetch_execution_lease/4` reads an explicit resolver or lease. `Policy.authorize/6` receives the policy separately. Both `prepare` and `commit` fetch an explicit lease.

### Target System

Proposed Agent call with a resolved connection:

```elixir
source = Jido.Connect.Context.new!(%{
  tenant_id: tenant_id,
  actor: actor,
  connection: github_connection,
  policy: MyApp.GitHubPolicy,
  credential_resolver: MyApp.Credentials
})

Jido.AgentServer.call(server, signal, context: %{connect: %{source: source}})
```

`context` is live host input. Claims carry facts the host has established. The Agent Signal carries operation input. Admission passes the Context as transient Plugin runtime data.

### Key Technical Decisions

- **KTD1** Add optional `policy` and `credential_resolver` module fields. Add an optional `connection_resolver` `{module, function}` pair for the existing one-argument selector callback. Use the existing callback dispatch. Function callbacks and tuples with extra arguments remain available through existing runtime options. Covers R1–R3 and U1–U2.
- **KTD2** Normalize a bare Context before the generic map case in Plugin admission. Use `%{integration_context: context}` as the internal access map and retain the legacy allowlist and `action_context/3` return contract. Preserve the Context struct in `Jido.RuntimeContext` and let an explicit connection resolver option take precedence over the Context reference. Keep provider and selector matching. Direct core calls still supply a resolved connection. Covers R1–R3 and U2.
- **KTD3** Apply a Context policy in `Policy.authorize/6` when the explicit policy is absent or `nil`. A non-`nil` explicit policy supplied by the host takes precedence. Cover the shared authorization helper because direct calls, prepared writes, availability with a supplied Context, and MCP notification authorization can reach it. Covers R2–R3 and U1.
- **KTD4** For direct execution and poll, use the binding-declared credential resolver first, then an explicit resolver option when present, then the Context resolver. Use the explicit lease path only when the call has no selected resolver. An explicitly supplied invalid resolver option keeps its current error behavior. Resolver denial cannot fall back to a lease. `prepare` and `commit` still fetch the explicit lease and check the snapshot. Covers R2–R3 and U1–U2.

### System Boundaries and Change Surface

| Surface | Planned change | Compatibility and trust boundary |
| --- | --- | --- |
| `Context` and `Policy` | Typed callback references and shared policy fallback. | Old contexts still construct and authorize. The host supplies these fields. |
| `Runtime` | Read the Context credential resolver as a default for invoke and poll. | Explicit resolver and explicit lease cases retain their current contracts. |
| Shared Plugin and adapter `RuntimeContext` | Accept a bare Context and preserve typed selector resolution. | Keep access maps for per-call controls and existing clients. |
| Credential and webhook lessons | Use bare Contexts on live turns and check the provider read. | Preserve host-side verification and current grant checks. |
| Persisted records | Store grants, credential IDs, and prepared snapshots through current contracts. | Keep access callbacks, runtime context, and lease material out of portable Agent data. |

### Implementation Units

#### U1 Add Context callbacks and enforce core access checks

- **Outcome** Context construction validates callback shapes, and core execution uses them as defaults.
- **Requirements and dependencies** R2–R3. No unit dependency.
- **Affected surfaces** `Context`, `Policy`, `Runtime`, `contracts_test.exs`, `authorization_test.exs`, `invoke_test.exs`, and `prepared_action_test.exs`.
- **Implementation direction** Apply KTD1, KTD3, and the core part of KTD4. Reuse the policy and lease authorization paths. Keep binding setup out of core execution.
- **Proof and completion** Run the core tests for the affected contracts. Check typed policy denial with omitted and `nil` policy options, an explicit override, resolver denial with a supplied lease, and a prepared write that still requires an explicit lease. The typed Context works in a direct read and a direct poll.

#### U2 Pass the Context through a live binding

- **Outcome** A live Agent can run a standard generated Action with a bare Context. A generated poll can use typed selector resolution and keep its checkpoint.
- **Requirements and dependencies** R1–R3. Depends on U1.
- **Affected surfaces** Shared Plugin and generated adapter `RuntimeContext`, `agent_plugin_test.exs`, and `jido/runtime_test.exs`.
- **Implementation direction** Apply KTD2 and binding resolver precedence. Keep explicit agent-call controls in the supported wrapper during migration.
- **Proof and completion** Test resolved and selector forms, conflicting resolver selections, mismatched provider or selector, and a legacy wrapper call with function or tuple callbacks. Confirm the runtime uses the host Context when a Signal payload contains access-like data. Verify the poll checkpoint survives context refresh.

#### U3 Migrate the two lessons and document adoption

- **Outcome** The signed webhook and shared-credential examples show the direct Context call. The generated module guide and host-storage guide explain precedence and compatibility.
- **Requirements and dependencies** R4 and integration proof of R1–R3. Depends on U2.
- **Affected surfaces** Lessons `00_04_credential_leases` and `00_05_github_webhook`, `docs/generated_jido_modules.md`, and `docs/host_owned_storage.md`.
- **Implementation direction** Use the binding resolver in the rotation example and a Context resolver in the webhook example. Keep the existing Fixture clients and the same Agent routes. Leave the other examples available to exercise older callers and runtime options.
- **Proof and completion** A signed request performs one read. Bad signatures, duplicate deliveries, and a denied repository cause zero lease requests. Rotation and revocation take effect on subsequent calls. Agent state contains the Flow result. The full verification gate passes.

### Work Graph

U1 → U2 → U3. U1 sets the fallback behavior before the Plugin and examples depend on it. U3 checks the complete caller path and updates the guide to match.

### Verification Contract

Run these checks from the umbrella root unless the table names another directory. Local HTTP and MCP fixture tests need loopback sockets.

| Requirements | Command | Evidence |
| --- | --- | --- |
| R1–R3 | `mix test apps/jido_connect/test --cover` | Core contract, prepared write, catalog, MCP, and generated adapter regressions pass. |
| R1, R2, R4 | `mix test.examples --warnings-as-errors` | Signed delivery, binding selection, on-demand lease, rotation, and revocation pass. |
| R1–R4 | `mix quality` and `git diff --check` | Umbrella compilation, formatting, and tests pass. |
| R2–R3 | `mix hex.audit` | The shared lock passes the existing advisory gate. |
| R1–R3 | In `dev/demo`, `MIX_ENV=test mix do format --check-formatted + compile --warnings-as-errors + test` | The demo continues to use the shared core contracts. |

### Rollout and Recovery

Add the typed form beside the current one. The two lessons are the first callers to adopt it. Other hosts can adopt the typed form per binding. A host can switch a caller back to its existing access map if it needs legacy callback or runtime options. The plan requires no stored data migration.

### Risks and Assumptions

- A policy can be lost if an adapter constructs an explicit `nil` option. The fallback and tests must cover that case.
- Mismatched selectors, invalid callbacks, and resolver denial must stop before a provider call. A denied request must not read a credential through a second path.
- Contexts are trusted runtime inputs. Persisted Agent data may carry a grant reference. The host supplies the execution Context afresh on admission. Field definitions and examples must keep credential material out of claims and metadata.

### Open Planning Decisions

None block the additive slice. The work owner retains the decision to start implementation. The scope can be reconsidered if a later caller needs a new callback shape or persistent context reference.

### Definition of Done

The typed Context works through the signed webhook Agent and shared-credential example. Direct calls enforce the Context policy. Existing callers and explicit-lease approval flows pass the regression tests. The documentation matches the supported fields and precedence rules.

### Planning Sources

- [Context contract](../../apps/jido_connect/lib/jido_connect/contracts/context.ex)
- [Agent Plugin admission and selection](https://github.com/agentjido/jido_connect/blob/22772cbf9d87c78aedaf143b5f73d6908074755f/apps/jido_connect/lib/jido_connect/jido/plugin.ex)
- [Generated adapter context handling](../../apps/jido_connect/lib/jido_connect/jido/runtime_context.ex)
- [Policy callback](../../apps/jido_connect/lib/jido_connect/runtime/policy.ex) and [core lease selection](../../apps/jido_connect/lib/jido_connect/runtime/runtime.ex)
- [Selector callback shapes](../../apps/jido_connect/lib/jido_connect/contracts/connection_selector.ex)
- [Webhook example](https://github.com/agentjido/jido_connect/blob/22772cbf9d87c78aedaf143b5f73d6908074755f/examples/00_start_here/00_05_github_webhook/README.md) and [credential lease example](https://github.com/agentjido/jido_connect/blob/22772cbf9d87c78aedaf143b5f73d6908074755f/examples/00_start_here/00_04_credential_leases/README.md)

## Adapter Results

The Markdown file is the canonical plan.
