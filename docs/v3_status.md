# Version 3 development status

This is maintainer development. Do not adopt this line in an external
application. Alpha and beta Hex packages are permitted. Compatibility can
change with each deliberate upstream update.

## Dependency record

Updated on 2026-11-14 for deterministic checkpoint schema fingerprints:

- Current core: `agentjido/jido` revision
  `047bf746330a2fbe7c3b25c045552e0303c97eaf` on `release/v3`.
- Both root and core app pins use this revision. Dependency resolution changed
  only the Jido lock entry. Hex Zoi 0.19.0, ReqLLM 1.30.0, Runic alpha.13,
  Arbor MCP rc.7, and the JSV 0.26.2 override are unchanged.
- The core owner reports deterministic Joi field order, independent rebuild
  coverage, and continued rejection of real code changes. Connect does not
  change checkpoint validation, data, or public API behavior.

Follow-up checks use Elixir 1.19.5 / OTP 28.3. All 190 focused ToolSource,
Plugin, generated Action/schema, authorization, and MCP tests passed with
`ERL_FLAGS='+S 4:4' mix test --max-requires 1 --max-cases 4` and the focused
paths in the package plan. Demo formatting, warnings-as-errors compilation,
and 21 tests passed. `mix hex.audit` found no retired or advisory packages.
The isolated `arbor_mcp_client_test.exs` file passed all eight tests under the
same four-scheduler setting. Harness's 19 focused tests also passed with
`--no-cover`; concurrent Harness manifest and Amp source work is unrelated
and is preserved outside this delivery.

The broad `mix quality` run did not pass on this follow-up. Its compile and
format steps completed, but the Ngrok test's two-second local accept timed
out and Arbor MCP's schema compilation exceeded five seconds at
`test/jido_connect/mcp/arbor_mcp_client_test.exs:14`. A four-scheduler full
repeat also reached the schema limit. The isolated file and the serial-load
focused suite passed without changing either timeout or any assertion. The
coordinator directed no further broad repeat while Jidoka's clean build used
the host. This is a recorded broader-suite limit, not a claimed full pass.

Published implementation ref:
`c8e12b724a8f6c045715a633fe3c7d01404720d9`
(`fix(deps): use checkpoint-compatible Jido revision`).
A new consumer fetched this exact commit from GitHub with
`sparse: "apps/jido_connect"`. Fresh dependency resolution and
`MIX_ENV=test mix compile --warnings-as-errors` passed. The consumer resolved
core `047bf746330a2fbe7c3b25c045552e0303c97eaf`, Hex Zoi 0.19.0,
Arbor MCP rc.7, and JSV 0.26.2. It passed all 46 offline tests with serial
file loading and four cases. These include the eight MCP fixture tests,
ToolSource invocation, Plugin attachment, MCP supervision startup, and
single core module ownership. No source change was needed after this ref.
A separate owning umbrella warnings-as-errors compile also passed.

The plan retains the check results before cleanup. Only the three task
consumer directories, this task's `/tmp/u3-*` logs/snapshots/backups, and the
fully published local `codex/consolidated-v3-local` branch are in cleanup
scope. Primary repositories and their build/dependency/data directories,
`main`, release branches, and concurrent Harness work must remain.
The result-record commit changes documentation only; Jidoka can keep the
immutable implementation ref above.

The entries below preserve earlier selections and their check evidence.


Selected on 2026-11-14 for the local Jidoka consolidated V3 candidate:

| Package | Requirement | Source |
| --- | --- | --- |
| `jido` | `05723b96c6ead47dec04fe69b1c34ad62f999c54` | `agentjido/jido`, consolidated V3 |
| `zoi` | `~> 0.19.0`; locked 0.19.0 | Hex |
| `req_llm` | Core requires `~> 1.30`; locked 1.30.0 | Hex |
| `runic` | Core requires `~> 0.1.0-alpha.13`; locked alpha.13 | Hex |
| `arbor_mcp` | `== 2.0.0-rc.7` | Hex, unchanged |
| `jsv` | `~> 0.26.2`; locked 0.26.2 | Hex, existing override retained |

This local candidate starts from release revision
`f10cf3053466013f267f424a1a5dff36b6c18a74`. It removes the core and Zoi fork
sources. No split core applications are declared. The JSV override remains
because Arbor MCP rc.7 declares `~> 0.25.0`; tests and the audit must check the
selected graph. Jidoka must use Arbor MCP rc.7 with this candidate.

Public Agent Plugin declarations still use map configuration. Jido converts
that map to callback keyword options. Keep the existing catalog host fixture.
The target supports the current ToolSource and Plugin preparation callbacks;
no source API change was needed for the checked focused contracts.

Checks on this candidate used Elixir 1.19.5 and OTP 28.3:

- `MIX_ENV=test mix compile --warnings-as-errors`: passed for all 41 apps.
- Focused ToolSource, Plugin, generated Action/schema, prepare/commit, and MCP
  tests: 190 tests, zero failures.
- Umbrella `mix quality`: passed; 4,264 tests, zero failures. Live smoke tests
  stayed excluded by the existing helpers.
- Core coverage: 274 tests, zero failures; 82.48%, above the 80% threshold.
  The provider inventory test ran in the passed umbrella suite. It cannot run
  in core-only mode because that mode does not load the 36 provider modules.
- `mix hex.audit`: passed; no retired packages or security advisories found.
- Demo dependency resolution, formatting, warnings-as-errors compilation,
  and tests: passed; 21 tests, zero failures.
- Isolated core package export at `/tmp/u3-connect-standalone`: fresh consumer
  resolution and compilation passed, with 38 tests and zero failures. The
  consumer uses only the exported package files, not the umbrella config. It
  checks ToolSource calls, Plugin attachment, host routes, MCP supervision,
  and single ownership of core modules by `:jido`.
- Unchanged Harness: compilation passed; 19 focused tests passed with
  `--no-cover`. The first focused run passed its tests but failed the global
  70% coverage threshold, as expected for a small test subset.

A separate default-environment root format command failed when Spark could
not load Sourceror. The required test-environment umbrella quality check
passed. A separate core `mix quality` run failed only its umbrella provider
inventory assertion; the same assertion passed with all providers present.
No threshold or test expectation was reduced.

At local verification, remote Git sparse verification was pending because
the candidate had no commit or push. Local package export verification passed. No live provider,
paid model, Hozen host, or Jidoka caller test ran in this package assignment.
Jidoka integration remains the coordinator's gate. Harness source and lock
are unchanged. No package was committed, pushed, or published in that phase.

Delivery was later authorized for `release/v3`. The branch uses the approved
`release/3.0` baseline and this scoped migration. CI also checks the new branch.
Remote sparse resolution is a required delivery check after the commit is
available on GitHub. No Hex publication or release tag is part of this work.

The records below are historical dependency selections, not current pins.

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
