# Connect and Harness: consolidated Jido V3 upgrade

Date: 2026-11-14. Assignment: U3. Status: ready for a bounded local implementation assignment. Runtime compatibility is not yet proved.

## Scope and authority

This plan covers `jido_connect` and inspection of `jido_harness`. This is a breaking consumer migration to one consolidated `:jido` application. The final graph must not contain separate `:jido_action`, `:jido_signal`, or `:jido_ai` applications or duplicate core modules. Keep provider authorization, credential leases, catalog review, host scheduling, and data meaning unchanged. No core change is authorized.

The coordinator has reported authority for later local upgrades, with no commits or pushes. This assignment stops after the plan. No dependency install, build, test, branch switch, or implementation ran during this audit.

## Recorded source state

Both repositories were clean before this plan write. No `docs/ROLE.md` was present in either repository. Workspace and package `AGENTS.md` files were read.

| Repository | Origin | Branch | HEAD |
| --- | --- | --- | --- |
| Connect | `git@github.com:agentjido/jido_connect.git` | `main` | `0484e51899e2e5d9171d148bde490398d77a3db3` |
| Harness | `git@github.com:agentjido/jido_harness.git` | `main` | `20fe00f7e954b8634b5ca73fc8cb7ee55230de24` |

Recommended Connect baseline: **`origin/release/3.0` at `f10cf3053466013f267f424a1a5dff36b6c18a74`**. GitHub returned the same branch revision during this audit. Use a task branch or isolated checkout from this exact revision when the coordinator assigns implementation. Do not switch over the new plan file without first preserving it.

The comparison with local main contains 446 changed files, 18,712 insertions, and 5,971 deletions. The common ancestor is `8121aef1f0b75de954cdac5722e48607a4fc983f`. Main is the V2 line. Do not rebuild V3 work from main or merge the full V3 line into V2.

Keep Harness at the recorded main revision. There is no demonstrated reason to change its source or manifest.

Shared Jido target: **`agentjido/jido` `release/v3`, revision `05723b96c6ead47dec04fe69b1c34ad62f999c54`**. The manifest, lock, ToolSource, Plugin, Plugin Input, Preparation, Action, Agent, Joi, and instruction config were read through `gh api` at that revision. The older local Jido checkout was not used as target evidence.

The target declares Jido `3.0.0-beta.2`, Zoi `~> 0.19.0`, ReqLLM `~> 1.30`, and Runic `~> 0.1.0-alpha.13`. Its lock selects Zoi 0.19.0, ReqLLM 1.30.0, Runic alpha.13, and JSV 0.27.0. A dependency's lock is evidence, not a lock inherited by consumers.

`bw prime` failed because Beadwork is not initialized. No initialization was done. The release branch removes the Beadwork instructions. This file is the durable plan record.

## Source findings and required changes

All Connect paths below refer to the recommended release baseline unless stated otherwise.

| File or boundary | Evidence and required work |
| --- | --- |
| `mix.exs`; `apps/jido_connect/mix.exs` | Both pin `mikehostetler/new_jido` at `54fde0c...` and the Zoi fork at `2fff2a2...`. Replace the core source with the exact shared target in both declarations. Replace both Zoi fork declarations with `~> 0.19.0` from Hex. Keep one source per package. Remove an override only when the graph no longer needs it; do not use an override to retain a split core package. |
| `mix.lock` | Resolve only the changed dependency closure. Replace the fork entries and stale ReqLLM 1.29.0. Verify the selected ReqLLM satisfies 1.30 and uses Zoi 0.19. Keep Runic compatible with alpha.13. Do not copy the target's full lock or unlock unrelated dependencies. |
| `apps/jido_connect/mix.exs`; `apps/jido_connect_trello/mix.exs` | Both require Arbor MCP `== 2.0.0-rc.7` and override JSV to `~> 0.26.2`. Keep rc.7 for the first candidate. Arbor's recorded lock metadata requires JSV `~> 0.25.0`; the existing override is intentional and must be tested. ReqLLM 1.30.0 accepts JSV `>= 0.26.2 and < 1.0.0-0`, so the existing 0.26.2 selection can satisfy ReqLLM. Do not infer that Jido's locked 0.27.0 is mandatory. Do not silently drop the override or downgrade to 0.25. |
| Jidoka `mix.exs` (coordinator owns edit) | Jidoka pins Arbor MCP rc.6. This cannot resolve with Connect's exact rc.7 requirement. Raise the host pin to rc.7, then test its MCP server handler, authentication, and context boundary. Do not force rc.6 through an override. |
| `apps/jido_connect/test/jido_connect/catalog_test.exs` | `CatalogHostAgent` supplies `{Catalog.Plugin, %{modules: [...]}}`. Keep this public map declaration. Execution corrected the initial audit: `Jido.Agent.Plugin.Declaration` accepts a plain map and converts it to keyword options for the internal normalizer. The attempted keyword fixture failed at compile time and was restored. No fixture change is required. |
| `apps/jido_connect/lib/jido_connect/catalog/plugin.ex`; `catalog/input.ex` | Target `prepare/2`, all seven `Preparation` fields, and `%Jido.Plugin.Input{prepared: value}` exist. `Map.new(opts)` in `prepare/2` already accepts the target keyword options. Keep host route ownership and explicit context precedence. No replacement callback is needed from the inspected source. Run the existing normalization and public Agent command tests. |
| `apps/jido_connect/lib/jido_connect/ai/catalog_tool_source.ex` | Target has `spec/0`, `list_tools/2`, `run_tool/3`, `load/1`, `executor/1`, and `run/3`. The current callback shapes match. Keep portable source data, reviewed fingerprints, current context at invocation, and rejection of mutation tools. Test load and invocation through the target public API; no live model is needed. No source change is established yet. |
| `jido/module_generator.ex`, `jido/projection_builder.ex`, `support/schema.ex`, `catalog/actions/*.ex`, `mcp/actions/*.ex` under the core library | Target Joi schemas are ordinary Zoi schemas. `Jido.Joi.Schema.schema?/1` checks the Zoi protocol. A full Zoi-to-Joi rewrite is not required by source. Target Action validates static, map-shaped schemas. Test generated Actions, enum limits, defaults, unknown keys, output validation, and JSON Schema after removing the fork. Fix only proved failures. Do not change stored-data meaning. |
| Generated provider `.Plugin` and sensor modules | Preserve the release architecture: provider Plugins return Connect discovery maps; only `Catalog.Plugin` is a runtime Jido Plugin. Sensors implement `Jido.Connect.Sensor`, return schedule/emit instructions, and use `Jido.Signal.new!/3`. The host owns scheduling and delivery. Do not attach generated provider Plugins or sensors directly as runtime Jido facets. |
| `docs/v3_status.md`, `docs/branch_support.md`, `docs/generated_jido_modules.md`, relevant core guides | Record the target, actual dependency selections, commands, results, and limits. Remove active guidance that directs consumers to split core applications or old forks. Keep historical dependency records clearly dated. |

Preserve the release branch's MCP move into `apps/jido_connect`. `apps/jido_connect_mcp` is removed there, and core uses Arbor MCP directly. Do not restore the main branch's `jido_mcp` dependency or copy modules from that separate repository.

## Harness verdict

`jido_harness/mix.exs` declares Zoi `~> 0.19.0`, Jason, Telemetry, and Arbor ACP; it has no Jido dependency. Its lock selects Zoi 0.19.0. A source search found no `Jido.*` use outside its own `Jido.Harness` namespace.

Jidoka's `lib/jidoka/inference/detector.ex` calls `Jido.Harness.providers/0` and `status/1`. Both exist in `lib/jido_harness.ex`. The consumed fields `installed`, `smoke_ready`, `authenticated`, and `version` exist in `ProviderStatus`. No caller failure has been demonstrated. Plan no Harness edits. A compile or caller test failure is required before expanding this scope.

## Unit order

1. Preserve this plan and prepare an isolated Connect candidate from the exact release baseline. Recheck origin, HEAD, and status first.
2. Replace the two core pins and Zoi pins. Resolve the lock closure with ReqLLM 1.30. Keep Arbor rc.7 and the existing JSV override for the first candidate. This is the first safe implementation unit.
3. Preserve the catalog host fixture with map Plugin configuration. Run the focused core tests. Repair source only for a demonstrated target contract failure.
4. Check the standalone core package and a consumer with the same sparse path that Jidoka uses. Then check all 40 provider applications and the demo. Test Trello because it also declares Arbor/JSV.
5. Verify Harness unchanged. Return exact dependency selections and check results to U5. U5 changes Jidoka's Arbor pin and source selection, then tests the host callers.

No U1, U2, or U4 implementation is required to start U3. Final combined resolution belongs to U5. Future release order is Jido, Connect, then Jidoka. Harness has no planned release. No release is authorized.

## Source and lock strategy

For local evidence, use a candidate checkout based on the recorded Connect release revision. Keep Jido as the exact Git revision above. If a local Jido path is required for diagnosis, use a separate exact-target export, record the override, and remove it before final portable verification. Never use the older workspace checkout by default.

Use the shared Connect root `mix.lock` for umbrella and demo checks. Run dependency resolution from the umbrella, then from the demo, and inspect each lock change. Do not hand-edit lock hashes. Reject active split core entries and duplicate module providers after resolution.

For isolated package evidence, copy only the candidate core package's declared package files to a temporary directory. Compile it with an independent lock, outside the umbrella, with no pre-existing dependencies or build output. This tests whether the package can operate without the umbrella's Jido/Zoi overrides and root config. Check the package's relative `build_path`, `config_path`, `deps_path`, and `lockfile` settings; they currently point two directories above the core app. Change them only if this test shows that a standalone consumer fails.

For final portable Git evidence, the consumer dependency must be:

```elixir
{:jido_connect,
 git: "https://github.com/agentjido/jido_connect.git",
 ref: "<immutable checked candidate revision>",
 sparse: "apps/jido_connect"}
```

Its Jido dependency must resolve to `05723b96c6ead47dec04fe69b1c34ad62f999c54`, and Zoi must resolve from Hex. Use a fresh consumer lock and no sibling paths. An uncommitted candidate cannot yet be fetched from GitHub. With the present no-commit/no-push limit, use the isolated package export as local evidence and report remote sparse verification as pending. Do not claim an old remote baseline proves the new candidate. Later immutable source publication needs separate authority.

## Supported future checks

Commands below were confirmed from manifests and source test paths. They were not executed in planning. Use Elixir 1.19.5 and OTP 28.3, as in release CI. Dependency installation needs network access. Do not use paid providers or live service tests.

From the Connect candidate umbrella root:

```sh
mix deps.get
MIX_ENV=test mix compile --warnings-as-errors
mix deps.tree
mix test apps/jido_connect/test/jido_connect/ai/catalog_tool_source_test.exs apps/jido_connect/test/jido_connect/catalog_test.exs apps/jido_connect/test/jido_connect/jido/runtime_test.exs apps/jido_connect/test/jido_connect/dsl_v2_test.exs apps/jido_connect/test/jido_connect/runtime/spec_schema_test.exs
mix test apps/jido_connect/test/jido_connect/mcp apps/jido_connect/test/jido_connect/mcp_test.exs apps/jido_connect/test/jido_connect/prepared_action_test.exs
mix test apps/jido_connect_trello/test
mix quality
mix hex.audit
git diff --check
```

The umbrella `quality` alias compiles with warnings as errors, checks formatting, and runs tests. For core coverage, from `apps/jido_connect`, run `MIX_ENV=test mix quality`; that alias also runs `test --cover` with an 80% threshold. Keep the threshold unchanged.

From `dev/demo`:

```sh
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

From the fresh isolated consumer directory, after writing its minimal manifest with the candidate source:

```sh
mix deps.get
mix deps.tree
mix compile --warnings-as-errors
mix test
```

The consumer test must load `CatalogToolSource` with an offline fixture integration, run a reviewed read action, reject a changed fingerprint, attach `Catalog.Plugin` with map configuration, and execute a host route. Check that `:jido` starts with the core connector and MCP supervision. Inspect loaded application module lists for a single owner of `Jido.Action`, `Jido.Signal`, and `Jido.AI.ToolSource`. A dependency tree alone does not prove module ownership.

From unchanged Harness:

```sh
mix deps.get
MIX_ENV=test mix compile --warnings-as-errors
mix test test/jido_harness/api_test.exs test/jido_harness/registry_test.exs test/jido_harness/zoi_structs_test.exs test/jido_harness/run_request_test.exs
```

Harness requires its native helper build on macOS/Linux. Report missing compiler/toolchain limits separately. Its test helper excludes integration, soak, load, and Antigravity wrapper tests. `mix quality` is required if a later demonstrated failure causes Harness edits; it does not run the test suite, so retain focused tests. Do not run `mix jido_harness.chat`.

U5 caller gates, from Jidoka after combined resolution:

```sh
mix test test/jidoka/inference/detector_test.exs test/jidoka/inference/contracts_test.exs
mix test test/jidoka_ops/mcp/connect_catalog_test.exs test/jidoka_ops/mcp/authentication_test.exs test/jidoka_ops/mcp/handler_test.exs
```

## Untested consumers, blockers, and readiness

No package compile or runtime test has run in this planning phase. All 40 provider applications are affected by shared generated Action/schema code and remain untested: Airtable, Asana, Bitbucket, Cal.com, Calendly, Confluence, GitHub, GitLab, Gmail, Google base, Google Analytics, Calendar, Contacts, Docs, Drive, Forms, Meet, Search Console, Sheets, Slides, Tasks, HubSpot, Intercom, Jira, Linear, Microsoft base, Calendar, OneDrive, Outlook, SharePoint, Nextcloud, Notion, PostHog, Salesforce, Slack, Things, Trello, Webhook, X, and Zendesk. The demo, Jidoka, and external Connect consumers such as Hozen are also untested. Do not claim ecosystem compatibility.

There is no demonstrated missing target API or stored-data decision that blocks the first safe implementation unit. Exact known work is source/lock replacement, and U5's Arbor rc.7 pin. The existing JSV override needs MCP and dependency audit evidence. Standalone sparse resolution is an unproved packaging boundary. Network access was available through approved `gh api` reads after the initial sandbox network failure.

Readiness: **plan checked; ready to start local dependency and focused contract work when assigned by the coordinator; not ready for integration acceptance or publication**. Stop and report an exact missing API or data-meaning change if tests expose one. Do not change core or add a compatibility copy.

## Source references

- [Coordinator plan](../../../../docs/plans/2026-11-14-0821-jidoka-consolidated-v3-plan.md)
- [Connect baseline](https://github.com/agentjido/jido_connect/tree/f10cf3053466013f267f424a1a5dff36b6c18a74)
- [Target manifest](https://github.com/agentjido/jido/blob/05723b96c6ead47dec04fe69b1c34ad62f999c54/mix.exs)
- [Target lock](https://github.com/agentjido/jido/blob/05723b96c6ead47dec04fe69b1c34ad62f999c54/mix.lock)
- [ToolSource](https://github.com/agentjido/jido/blob/05723b96c6ead47dec04fe69b1c34ad62f999c54/lib/jido/ai/tool_source.ex)
- [Plugin normalizer](https://github.com/agentjido/jido/blob/05723b96c6ead47dec04fe69b1c34ad62f999c54/lib/jido/plugin/normalizer.ex)
- [Joi](https://github.com/agentjido/jido/blob/05723b96c6ead47dec04fe69b1c34ad62f999c54/lib/jido/joi.ex)
- [Harness manifest](../../../jido_harness/mix.exs)


## Local execution return — 2026-11-14

Implementation was authorized after planning. Connect is now on
`codex/consolidated-v3-local` at baseline HEAD
`f10cf3053466013f267f424a1a5dff36b6c18a74`, with local manifest, lock, and
documentation changes. No source API edit was needed. The Plugin fixture was
restored after a failed attempt proved that public declarations require maps.
The internal normalizer's keyword form is not the public Agent DSL form.

The checked source for U5 is
`/Users/mhostetler/Source/Jido/jido_connect/jido_connect/apps/jido_connect`.
It resolves exact Jido `05723b96c6ead47dec04fe69b1c34ad62f999c54`, Hex Zoi
0.19.0, ReqLLM 1.30.0, Arbor MCP rc.7, JSV 0.26.2, and Runic alpha.13.
Only the required dependency closure changed. Demo resolution added the
missing declared demo packages to the shared lock; no broad update ran.

See `docs/v3_status.md` for the check results and limits. Umbrella quality,
focused contracts, core coverage, demo checks, isolated export checks, and
unchanged Harness focused checks passed. Harness remains at main HEAD
`20fe00f7e954b8634b5ca73fc8cb7ee55230de24` with a clean working tree.
The local candidate is ready for U5 integration. Remote publication is not a
gate for this no-commit task. No data change, commit, push, or release ran.


## Delivery authority — 2026-11-14

The user later authorized scoped commits and pushes. The live remote had no
`release/v3` branch; `release/3.0` still pointed to the approved baseline.
Delivery creates `release/v3` from that already published baseline plus this
migration. CI and branch guidance now include `release/v3`. The core docs
source ref also uses that branch. No force push, history rewrite, Hex release,
or unrelated repository change is part of delivery. The final return must
record the full commit and the result of GitHub sparse verification.


## Checkpoint follow-up and cleanup — 2026-11-14

The coordinator supplied the published core fix
`047bf746330a2fbe7c3b25c045552e0303c97eaf`. It supersedes the original
`05723b96c6ead47dec04fe69b1c34ad62f999c54` target in the historical plan.
Both package pins and the Jido lock entry now use the new revision. No other
dependency lock entry or public API is changed by this follow-up. Connect
keeps strict checkpoint checks and existing stored data unchanged.

The first delivered Connect commit was
`17bd51aab9af98a898ac7185994cfdb4a7dbb92f` on `release/v3`. A fresh consumer
fetched that exact GitHub commit with `sparse: "apps/jido_connect"`, resolved
its exact core and registry Zoi, compiled with warnings as errors, and passed
38 offline ToolSource, Plugin, MCP startup, and module ownership tests. The
sparse checkout contained no other provider apps or split core dependencies.
This evidence is retained here before its temporary consumer is removed.

Cleanup inventory: only the primary Connect and Harness worktrees exist.
The local task branch `codex/consolidated-v3-local` points to the first
published commit. It can be removed after confirming that it is an ancestor
of the final published `release/v3`. Preserve `main`, all release branches,
the primary repositories, and their build/dependency/data directories.
Harness source, lock, and branch remain unchanged.

Task-only temporary consumers are `/tmp/u3-connect-standalone`,
`/tmp/u3-connect-remote-sparse`, and `/tmp/u3-connect-checkpoint-sparse`.
The remaining `/tmp/u3-*` entries are this assignment's logs, source
snapshots, and two plan backup files. Their check results must be recorded
here or in `docs/v3_status.md` before removal. No other temporary directory or
worktree is in this cleanup scope. The root coordinator owns chat archival.


## Final verification record before cleanup

Implementation: `c8e12b724a8f6c045715a633fe3c7d01404720d9`, published on
`agentjido/jido_connect` `release/v3`. No subsequent source edit was needed.
Both pins and the lock use core `047bf746330a2fbe7c3b25c045552e0303c97eaf`.

Checks used Elixir 1.19.5 / OTP 28.3 and four schedulers where noted:

| Check | Exit and result |
| --- | --- |
| `MIX_ENV=test ERL_FLAGS='+S 4:4' mix compile --warnings-as-errors` | 0 |
| Focused paths from this plan with `mix test --max-requires 1 --max-cases 4` and four schedulers | 0; 190 tests, zero failures |
| Isolated `arbor_mcp_client_test.exs` with four schedulers | 0; eight tests, zero failures |
| Demo `mix deps.get`, format check, warnings-as-errors compile, `mix test` | All 0; 21 tests, zero failures |
| `mix hex.audit` | 0; no retired or advisory packages |
| Harness focused command with `--no-cover` and four schedulers | 0; 19 tests, zero failures; concurrent unrelated work preserved |
| Fresh GitHub sparse consumer `mix deps.get` | 0; exact implementation and core refs verified |
| Fresh sparse consumer warnings-as-errors compile | 0 |
| Fresh sparse consumer `mix test --max-requires 1 --max-cases 4` with four schedulers | 0; 46 tests, zero failures |

The new sparse consumer was `/tmp/u3-connect-checkpoint-sparse`. Its manifest
used the exact published implementation ref and `sparse: "apps/jido_connect"`,
without a local package path or a core override. It checked ToolSource,
Plugin/host execution, the MCP fixture, supervision, and one owner for core
modules. It resolved Hex Zoi 0.19.0, Arbor MCP rc.7, and JSV 0.26.2.

Broader limit: two full umbrella quality attempts stopped at Arbor MCP's
five-second schema compilation limit at
`apps/jido_connect/test/jido_connect/mcp/arbor_mcp_client_test.exs:14`.
The first also hit the Ngrok test's two-second local accept limit. Compile
and formatting completed. The isolated MCP file passed under the same four
scheduler conditions; the serial-file focused suite also passed. The
coordinator directed no further full repeat while Jidoka's clean build used
the host. No timeout, assertion, schema check, or coverage gate was weakened.
The earlier 4,264-test full pass belongs to the original core selection and
is not claimed as a full pass for this follow-up.

The current Harness working tree has unrelated README, migration guide,
manifest, Amp, and integration work. It is outside this delivery and cleanup.
No Harness file, branch, or data is to be removed or committed here.

This record and `docs/v3_status.md` preserve the useful evidence from the task
logs and temporary consumers. After this documentation is published, remove
only the inventoried task artifacts and the local task branch whose commit
is reachable from the published release branch. Keep the primary worktrees.
The root coordinator owns chat archival.
