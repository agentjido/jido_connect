# Version 3 development status

This is maintainer development. Do not adopt this line in an external
application. Alpha and beta Hex packages are permitted. Compatibility can
change with each deliberate upstream update.

## Dependency record

Selected on 2026-09-24:

| Package | Requirement | Source |
| --- | --- | --- |
| `jido_action` | `== 3.0.0-beta.11` | Hex |
| `jido_signal` | `== 3.0.0-beta.4` | Hex |
| `jido` | `== 3.0.0-beta.1` | Hex |
| `ex_mcp` | `~> 1.5`, selected for 1.5.0 | Hex |
| `bandit` | Locked to 1.12.5 in the shared demo/umbrella lockfile | Hex |

Jido, Action, and Signal use exact published beta versions. This keeps each
upstream change deliberate during v3 development. Do not return to the
abandoned Jido v2/v3 compatibility PR #324.

ExMCP 1.5.0 contains the status-timeout and subscription-filter fixes from
upstream PRs #45 and #46 and the public legacy-notification listener API from
upstream PR #50. Connect verifies these behaviors through its generated status
action and notification-session integration tests.

## Client release scope

The v3 line includes SharePoint and the full selected MCP client surface:
tools, resources, templates, prompts, completion, notifications, and connection
lifecycle. See the [MCP client guide](../apps/jido_connect/guides/mcp_bridge.md).
ExMCP owns protocol and transports. No `jido_mcp` files were changed.

Managed notifications use correlated streams on MCP 2026-07-28 and ExMCP's
public local listener on MCP 2024-11-05 through 2025-11-25. Connect keeps its
authorized filter, lease checks, cleanup, and sanitization in both protocol
eras. Legacy tool, resource, and prompt requests remain supported. Host
callbacks own roots, sampling, elicitation, progress, and log policy.

## Changes from the old candidate

- Preserve the catalog and MCP migration from PR #75 and current main changes.
- Keep `Catalog.Item` as the canonical operation projection.
- Use direct ExMCP; remove the unpublished MCP application and its dependency.
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

Bandit 1.12.5 removes the two Bandit findings reported for 1.12.4. Cowlib 2.20.0
also resolves EEF-CVE-2026-43971. The Hex audit data still reports
EEF-CVE-2026-43966 and EEF-CVE-2026-43969. The two exact exceptions remain
visible. The core tests check response header validation and confirm that
Connect and ExMCP do not import the affected Cowlib encoders.

Cowlib rejected fixes for both encoders because Cowboy and Gun validate the
values at their network boundaries. ExMCP 1.5 records the same two exact
exceptions and plans to make its HTTP server dependency optional in 2.0.
Connect uses the ExMCP client and does not publish a Cowboy server.

Connect accepted these scoped exceptions on 2026-09-19 and closed issue #79.
An audit that succeeds with these exceptions does not mean the Cowlib functions
changed. Review the exceptions after each ExMCP or HTTP-stack update and before
publication. Remove them when ExMCP can omit Cowboy or the advisory records
change. The exact list ensures that any new advisory still fails the audit.

## Verification

The ExMCP 1.5 update was checked locally on 2026-09-24 with Elixir 1.20.4 and
OTP 29.0.5:

- Umbrella `mix quality`: passed, 4,240 tests across 41 packages; 39 live tests excluded.
- Focused modern and legacy MCP session tests: passed, 20 tests.
- Demo formatting, compilation with warnings as errors, and tests: passed, 21 tests.
- `mix hex.audit`: succeeds with the two Cowlib exceptions listed above and no new advisory.
- `git diff --check`: passed.

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
- Recheck the accepted Cowlib exceptions after each ExMCP or HTTP-stack update.
- Prepare package versions and release notes only when publication is wanted.
- Close #81 after the ExMCP 1.5 legacy notification integration lands.
- Keep all Jido MCP work separate.

The release branches do not publish packages. The old migration record keeps
historical evidence; this file records the current v3 dependency set.
