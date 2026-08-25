# Jido Connect Ecosystem Migration

This document records the baseline and the fixed package boundaries for the
non-Harness migration. The owning issues are
[`jido_connect#69`](https://github.com/agentjido/jido_connect/issues/69),
[`#70`](https://github.com/agentjido/jido_connect/issues/70),
[`#71`](https://github.com/agentjido/jido_connect/issues/71),
[`#72`](https://github.com/agentjido/jido_connect/issues/72), and
[`jido_mcp#52`](https://github.com/agentjido/jido_mcp/issues/52).

## Fixed Boundaries

- Jido Action v2 is the current Action contract.
- ExMCP owns MCP protocol behavior.
- Jido Connect owns connector specifications, prepared operations, its
  catalog, connector safety rules, and a narrow MCP bridge.
- Jido Harness owns coding-agent processes and lifecycles. Its migration is a
  separate work line.
- `jido_mcp` gets one final ExMCP-based major release candidate. It then enters
  maintenance mode. Formal deprecation can start only after the Connect
  replacement is public and proven.
- The unpublished `jido_connect_mcp` umbrella application is removed after its
  supported behavior is in core `jido_connect`. No compatibility package is
  required.

This work does not move Jido MCP server publication, dynamic Jido AI proxy
Actions, or a general endpoint pool into Connect. It does not change Ando,
ExMCP, or Jido Harness. It does not use Jido Action v3.

## Remote Baseline

The baseline was recorded on 2026-08-25 from new worktrees at the current
remote heads.

| Repository | Remote head | Package version | Dependency state |
| --- | --- | --- | --- |
| `agentjido/jido_connect` | `2a84ef88e464f1b95aaac0d9d137d14f15d6a822` | umbrella and core `0.8.0` | `jido_connect_mcp` uses the `jido_mcp` `main` branch outside Hex build tasks |
| `agentjido/jido_mcp` | `5fc6ad5b6d23f71647062e9148a5fad0a293138e` | `1.1.1` | exact `ex_mcp` `1.0.0-rc.8`; Jido and Jido Action `2.3.x` |

The latest remote CI runs for both heads passed:

- [Jido Connect CI run 32779712168](https://github.com/agentjido/jido_connect/actions/runs/32779712168)
- [Jido MCP CI run 32764059571](https://github.com/agentjido/jido_mcp/actions/runs/32764059571)

Hex lists ExMCP `1.0.0`, released on 2026-08-22, as the current stable `1.0`
release. The migration can use `~> 1.0` without an ExMCP source change.

## Local Baseline Checks

The local baseline uses the repository commands that CI and release checks
use. Results are recorded before the first implementation change.

| Scope | Command | Baseline result |
| --- | --- | --- |
| Connect umbrella | `mix deps.get && mix quality` | Passed |
| Connect catalog | focused catalog and reviewed-catalog tests | Passed, 27 tests |
| Connect MCP bridge | `mix test apps/jido_connect_mcp/test` | Passed, 50 tests |
| Connect demo | format, warnings-as-errors compile, and tests | Passed, 21 tests |
| Jido MCP CI | Credo, docs, compile, and tests | Passed, 183 tests and no high-priority Credo findings |
| Jido MCP release | `mix release.check` | Passed, including the Hex package build |

The dependency audit reports Cowlib `2.19.0` advisories
`EEF-CVE-2026-43966`, `EEF-CVE-2026-43969`, and `EEF-CVE-2026-43971`.
`jido_mcp` has temporary, explained exceptions with a review date of
2026-09-12. The final release candidate must review these exceptions again.
The demo dependency graph also reports Bandit `1.12.4` advisories
`EEF-CVE-2026-75484` and `EEF-CVE-2026-74836`. They are in the local demo host,
not the published Connect package. Release checks must still review them.

## Connect Catalog Compatibility Baseline

The current catalog has more than one operation projection. Git consumers can
call these public paths, so the migration must either preserve them through a
narrow adapter or document the changed return shape.

| Path | Current public shape |
| --- | --- |
| Provider discovery | `entry/2`, `entries/2`, `manifest/2`, `discover/1`, and `discover_with_diagnostics/1` use `Catalog.Entry` and `Catalog.Manifest` |
| Provider search and filter | `search/2` and `filter/2` accept and return `Catalog.Entry` values |
| Operation list | `tools/1` returns `Catalog.ToolEntry` values built through `Catalog.Tool` |
| Operation search | `search_tools/2` returns `Catalog.ToolSearchResult` values that contain `Catalog.ToolEntry` |
| Lookup | `lookup_tool/2` accepts an ID, `{provider, id}`, or `Catalog.ToolEntry` and returns `Catalog.ToolEntry` |
| Describe and review | `describe_tool/2` and `reviewed_descriptors/2` return `Catalog.ToolDescriptor` values |
| Call | `call_tool/3` resolves a catalog tool and calls the core Connect runtime |
| Packs | `Catalog.Pack` stores filters and stable provider-qualified tool references |
| Serialization | `to_map/1` supports entries, manifests, packs, tool entries, search results, and descriptors |
| Jido runtime | `Catalog.Plugin` publishes search, describe, and call signals |
| Action v2 adapter | `action_catalog/1` projects generated Action modules into `Jido.Action.Catalog` |

The CLI catalog use case needs four operations: list or search items, describe
one stable item reference, call one action item, and select items through a
pack. It does not need a second execution model. `Spec`, `ActionSpec`, and
`TriggerSpec` remain canonical.

## Connect Catalog Migration Result

`Jido.Connect.Catalog.Item` is now the canonical, read-only public operation
projection. The builder creates it directly from `Spec`, `ActionSpec`, and
`TriggerSpec`. Its stable reference is `provider:kind:operation-id`, for
example `github:action:github.issue.create`.

| Canonical path | Return shape |
| --- | --- |
| `items/1` | `Catalog.Item` values |
| `search_items/2` | `Catalog.ItemSearchResult` values that contain `Catalog.Item` |
| `lookup_item/2` and `describe_item/2` | One schema-rich `Catalog.Item` |
| `call_item/3` | Core Connect invocation result for an action item |
| `reviewed_items/2` | Fingerprinted `Catalog.Item` values selected by one exact pack |
| `to_map/1` | Deterministic item or item-search-result maps |

The stable reference, a unique operation ID, the old `provider.operation-id`
reference, `{provider, id}`, and `{provider, kind, id}` are accepted during the
migration. Packs accept the same references. Canonical references remove an
ambiguity when one provider uses the same ID for an action and a trigger.

The old `tools`, `search_tools`, `lookup_tool`, `describe_tool`, `call_tool`,
and `reviewed_descriptors` paths keep their prior structs and error reasons as
compatibility adapters. `Catalog.Plugin` keeps its three Action v2 operations.
`action_catalog/1` also stays as an Action v2 adapter. Internal search,
filtering, pack selection, review, lookup, describe, call, availability, and
Action catalog projection use `Catalog.Item`.

## MCP Bridge Compatibility Baseline

The `jido_connect_mcp` application provides the `Jido.Connect.MCP` namespace,
one supervised endpoint lease manager, and two Connect actions:

- `mcp.tools.list`
- `mcp.tool.call`

The supported bridge behavior includes public endpoint fencing, credential
lease checks, scope and policy checks, endpoint generation fencing, schema
hash binding, compatible-schema checks, one-send tool calls, and uncertain
write classification. These controls must move before the application is
removed.

The bridge does not need MCP resources, prompts, server publication, dynamic
proxy Actions, or a copied endpoint pool.

## MCP Bridge Move Result

The bridge namespace and its tests now live in core `jido_connect`. This unit
keeps the existing Jido MCP backend so that the code move and the protocol
backend change remain separate.

| Previous module | Move decision |
| --- | --- |
| `Jido.Connect.MCP` | Move to core as the provider with only `mcp.tools.list` and `mcp.tool.call` |
| `EndpointLeaseManager` | Move to core and supervise from `Jido.Connect.Application` |
| `EndpointResolver` and `HostEndpoint` | Move to core; keep the temporary Jido MCP endpoint adapter |
| `Runtime` | Move to core; keep one-list and one-call behavior without a backend change |
| `SchemaCompatibility`, `ScopeResolver`, `Tool`, and `ToolResult` | Move to core |
| `Handlers.Actions.ListTools` and `CallTool` | Move to core as the two generated Action v2 handlers |
| `Jido.Connect.MCP.Application` | Merge into the core application supervisor |

All 50 bridge tests move with the code. The `jido_connect_mcp` application has
no implementation after this unit. It remains temporarily in the umbrella so
the later removal is a separate verified change. It was never published, must
not be published now, and does not become a compatibility package.

## Jido MCP Compatibility Baseline

The final active release freezes the present documented surface.

| Surface | Final-release decision |
| --- | --- |
| `Jido.MCP` client API | Supported: endpoint registration, tool, resource, prompt, refresh, readiness, and status calls |
| `Jido.MCP.Endpoint`, `Config`, `ClientPool`, and `Response` | Supported compatibility surface; no new endpoint features |
| `Jido.MCP.Actions.*` | Supported Jido Action v2 definitions; no new Actions |
| `Jido.MCP.Plugins.MCP` | Supported and frozen |
| `Jido.MCP.JidoAI.Actions.*` and `JidoAI.Plugins.MCPAI` | Supported and frozen; dynamic proxy behavior does not move to Connect |
| `Jido.MCP.Server`, `Server.Plug`, `Server.Context`, `Server.Resource`, and `Server.Prompt` | Supported and frozen; direct new server work goes to ExMCP |
| Modules with `@moduledoc false` | Internal implementation, including ExMCP adapters, endpoint identity helpers, schema adapters, proxy registry and generator, server runtime, and session limiter |

The Anubis-to-ExMCP change requires the expected `2.0.0` major version. The
release candidate must keep this surface, use stable ExMCP, give users an
upgrade path, and state that the package is in maintenance mode. Publication
requires explicit user approval.
