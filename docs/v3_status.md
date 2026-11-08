# Version 3 development status

This is maintainer development. Do not adopt this line in an external
application. Alpha and beta Hex packages are permitted. Compatibility can
change with each deliberate upstream update.

## Dependency record

Selected on 2026-11-08 for the Hozen GitHub collection candidate:

| Package | Requirement | Source |
| --- | --- | --- |
| `jido` | `54fde0cf79aae9dcc2c00636d9846834abd06852` | `mikehostetler/new_jido` Git fork |
| `arbor_mcp` | `== 2.0.0-rc.7` | Hex |
| `arbor_rpc` | Locked to `1.0.0-rc.4` | Hex |
| `zoi` | `2fff2a23e23e7ac0b26f62f49bbc1b12f7818ac9` | `mikehostetler/zoi` Git fork |

The monolithic Jido v3 source replaces the separate `jido_action`, `jido_ai`,
and `jido_signal` dependency entries. The umbrella lock contains one Jido
source. The catalog host test uses the current Agent `plugins:` option and the
current `Jido.Agent.Plugin.Preparation` fields.

Selected on 2026-10-27:

| Package | Requirement | Source |
| --- | --- | --- |
| `jido_action` | `d2a981895fb986e9a2fe88f8c523326572643117` | Git |
| `jido_signal` | `7b825f1d050a0e0159bb2a72ba79c100b5d362d3` | Git |
| `jido` | `aaca071c90691662c7036fe4d71ab63e6ee3432a` | Git |
| `jido_ai` | `3b02d83eaa248e262ba1760f39da73cab5fe3bdf` | Git |
| `arbor_mcp` | `== 2.0.0-rc.6` | Hex |
| `bandit` | Locked to 1.14.0 in the shared demo/umbrella lockfile | Hex |

Jido, Action, Signal, and Jido AI use the exact Git revisions recorded by the
Jido AI v3 line. ArborMCP uses an exact prerelease version. This keeps each
upstream change deliberate during v3 development. Do not return to the
abandoned Jido v2/v3 compatibility PR #324.

ArborMCP `2.0.0-rc.6` replaces ExMCP. Source modules use the `Arbor.MCP`
namespace and the OTP application is `:arbor_mcp`. Connect verifies status,
modern subscriptions, and retained legacy-notification delivery through its
generated status action and notification-session integration tests.

## Client release scope

The v3 line includes SharePoint and the full selected MCP client surface:
tools, resources, templates, prompts, completion, notifications, and connection
lifecycle. See the [MCP client guide](../apps/jido_connect/guides/mcp_bridge.md).
ArborMCP owns protocol and transports. No `jido_mcp` files were changed.

Managed notifications use correlated streams on MCP 2026-07-28 and ArborMCP's
public local listener on MCP 2024-11-05 through 2025-11-25. Connect keeps its
authorized filter, lease checks, cleanup, and sanitization in both protocol
eras. Legacy tool, resource, and prompt requests remain supported. Host
callbacks own roots, sampling, elicitation, progress, and log policy.

## Changes from the old candidate

- Preserve the catalog and MCP migration from PR #75 and current main changes.
- Keep `Catalog.Item` as the canonical operation projection.
- Use direct ArborMCP; remove the unpublished MCP application and its dependency.
- Use current Action schemas and execution. Remove the old Action Git pin.
- Use a v3 runtime Plugin for catalog configuration. Generated provider
  `.Plugin` modules supply Connect discovery data as a plain map. They are not
  v3 Agent Plugins or the removed v2 `Jido.Plugin.Spec` shape.
- Generated trigger adapters use `Jido.Connect.Sensor` callbacks. The host
  owns scheduling and Signal delivery. These adapters are not OTP processes
  and cannot be passed directly to v3 SensorManager.

See [generated modules](generated_jido_modules.md) for the host contract.
Registering a generated Plugin does not install routes or add credentials to
an Agent. The host declares its routes and provides current invocation context.

## Security findings

Bandit 1.14.0 is selected in the shared demo lockfile. ArborMCP makes Cowboy
and Cowlib optional, and the Connect client dependency graph does not select
them. The old Cowlib advisory exceptions were removed. The core tests still
check Plug response-header validation and confirm that Connect and ArborMCP do
not import the affected Cowlib encoders. `mix hex.audit` now runs without an
exception list.

## Verification

The Hozen GitHub collection candidate was checked locally on 2026-11-08:

- Umbrella `mix q`: passed across all connector packages.
- GitHub connector tests: passed, 209 tests.
- GitHub App user connections use permission-derived scopes and do not claim
  the broad OAuth `repo` scope.
- The reviewed Hozen catalog contains 16 read actions for account checks,
  repository discovery, portfolio evidence, and exact-commit source reads.
- Unknown and write actions are denied by the Hozen host before credential
  access or transport.
- Live read checks collected source packages for seven repositories and full
  evidence for six open pull requests. No GitHub mutation ran.
- `mix hex.audit` reports `jsv` 0.25.0 advisory EEF-CVE-2026-117680 at low
  severity. ArborMCP 2.0.0-rc.7 still requires `jsv ~> 0.25.0`. Hozen uses a
  tested host override to JSV 0.27.0. The connector package still needs an
  ArborMCP dependency update before this advisory can close without an
  override.

The ArborMCP `2.0.0-rc.6` update was checked locally on 2026-10-27:

- Umbrella `mix quality`: passed.
- Focused ArborMCP client, modern notification, legacy notification, and
  dependency security tests: passed, 27 tests.
- Trello OAuth migration tests: passed, 4 tests.
- Demo formatting, compilation with warnings as errors, and tests: passed,
  21 tests.
- `mix hex.outdated`: all declared Hex dependencies are current.
- `mix hex.audit`: passed without advisory exceptions.

The broader candidate was checked locally on 2026-09-19 with Elixir 1.19.5 and
OTP 28.3.1:

- Umbrella `mix quality`: passed, 4,234 tests across 41 packages; 39 live tests excluded.
- Core `mix quality`: passed, 264 tests and 82.63% coverage. The 80% threshold is unchanged.
- Focused catalog and MCP tests: passed, 123 tests.
- X and Trello tests: passed, 24 and 37 tests.
- Demo formatting, compilation with warnings as errors, and tests: passed, 21 tests.
- Core documentation: built without warnings.
- Direct Hex dependencies: current according to `mix hex.outdated`.
- `mix hex.audit`: succeeds with the two Cowlib exceptions listed above.
- Connector factory type check: passed. `@types/bun` 1.4.2 is available as a non-package update.
- Core Hex build: passed with only Hex package requirements and 133 intended files.
- Package inventory excludes the demo, secrets, build output, dependencies, and generated docs.
- No live source or package dependency refers to the removed `jido_connect_mcp` application.
- `git diff --check`: passed.

The generated endpoint-status action passes delayed-client timeout and
responsive-client field tests. Equal and narrower subscription acknowledgments
remain usable. Expanded initial and reconnect acknowledgments cause no
unrequested resource read or snapshot.

The full run also found a cold-load defect in the Things transport validator.
Commit `09f3a555` loads the module before it checks the transport callback.
That small fix can be backported to v2 independently.

The core package is ready for publication review. No package was published.
CI also checks the declared Elixir 1.19.5 / OTP 28.3 environment when these
commits are pushed.

## Work after this change

- SharePoint PR #66 is integrated on v3 at `74f41c69`.
- Follow Jido, Action, and Signal prereleases with explicit dependency updates and tests.
- Run `mix hex.audit` after each ArborMCP or HTTP-stack update.
- Prepare package versions and release notes only when publication is wanted.
- Keep the legacy notification contract covered while ArborMCP retains it.
- Keep all Jido MCP work separate.

The release branches do not publish packages. The old migration record keeps
historical evidence; this file records the current v3 dependency set.

## Zoi compatibility follow-up — 2026-10-09

The dependency patch uses the merged Jido source at `90763478104f1edbf0afcfcf9444621c3f9755e8`. Its source tree is identical to the earlier pin, but the merged commit is reachable from the release branch. Catalog preparation now follows `Jido.Agent.Plugin.Preparation` and returns a package-owned value. Actions read that value from `context.plugin_inputs`. Explicit host configuration keeps priority. Public Agent command coverage and the full umbrella CI passed.
