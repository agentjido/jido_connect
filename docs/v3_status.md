# Version 3 development status

This is maintainer development. Do not adopt this line in an external
application. Alpha and beta Hex packages are permitted. Compatibility can
change with each deliberate upstream update.

## Dependency record

Selected on 2026-09-19:

| Package | Requirement | Source |
| --- | --- | --- |
| `jido_action` | `== 3.0.0-beta.10` | Hex |
| `jido_signal` | `== 3.0.0-beta.4` | Hex |
| `jido` | `b02052402a6f1c4be10098c2d560831f14daec58` | Exact commit from `v3-spike` |
| `ex_mcp` | `~> 1.4`, locked to 1.4.0 | Hex |
| `bandit` | Locked to 1.12.5 in the shared demo/umbrella lockfile | Hex |

Action is a published beta, although this work may also use alpha packages.
The Action override selects the Hex package instead of the local path in the
selected Jido source. Jido v3 is not yet on Hex. Replace its Git reference when
a suitable package is available; do not return to the abandoned Jido v2/v3
compatibility PR #324.

ExMCP 1.4.0 contains the status-timeout and subscription-filter fixes from
upstream PRs #45 and #46. Connect verifies both behaviors through its generated
status action and notification-session integration tests.

## Client release scope

The v3 line includes SharePoint and the full selected MCP client surface:
tools, resources, templates, prompts, completion, notifications, and connection
lifecycle. See the [MCP client guide](../apps/jido_connect/guides/mcp_bridge.md).
ExMCP owns protocol and transports. No `jido_mcp` files were changed.

Managed notifications use MCP 2026-07-28. Legacy notification delivery needs an
upstream public client API and is tracked in [#81](https://github.com/agentjido/jido_connect/issues/81).
Legacy tool, resource, and prompt requests remain supported. Host callbacks own
roots, sampling, elicitation, progress, and log policy.

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
still has EEF-CVE-2026-43966, EEF-CVE-2026-43969, and EEF-CVE-2026-43971 in the
Hex audit data. The existing three exact exceptions remain visible. The core
tests check response header validation and the absence of direct imports of
the affected cookie and link encoders from Connect and ExMCP.

An audit that succeeds with these exceptions does not mean Cowlib is fixed.
Keep Connect issue #79 open until the findings are resolved. Review the
exceptions after each ExMCP or HTTP-stack update and before publication.

## Verification

On 2026-09-19, ExMCP 1.4.0 from Hex compiled with the v3 umbrella. The
generated endpoint-status action passed a delayed-client timeout test and a
responsive-client field check. Umbrella `mix quality` passed with this pin.
Demo formatting, warnings-as-errors compilation, and 21 tests also passed.
Connect integration tests also passed against the ExMCP 1.4 subscription
fix: equal and narrower acknowledgments stay usable, and expanded initial or
reconnect acknowledgments cause no unrequested resource read or snapshot.

Checked locally on Elixir 1.20.3 and OTP 29.0.5:

- Umbrella `mix quality`: passed, 4,137 tests across 41 packages; 39 live tests excluded.
- Core `mix quality`: passed, 181 tests and 80.55% coverage. The 80% threshold is unchanged.
- Demo formatting, compilation with warnings as errors, and tests: passed, 21 tests.
- `mix hex.audit`: succeeds with the three existing Cowlib exceptions listed above.
- `git diff --check`: passed.

The full run also found a cold-load defect in the Things transport validator.
Commit `09f3a555` loads the module before it checks the transport callback.
That small fix can be backported to v2 independently.

No package was published. A Hex package build was not claimed because the
Jido dependency uses Git. CI also checks the declared Elixir 1.19.5 /
OTP 28.3 environment when these commits are pushed.

## Work after this change

- SharePoint PR #66 is integrated on v3 at `74f41c69`.
- Follow upstream Jido v3 changes with explicit dependency updates and tests.
- Replace the Jido Git reference when its v3 package is on Hex.
- Clear the remaining Cowlib findings in #79.
- Prepare package versions and release notes only when publication is wanted.
- Track legacy notification support in #81.
- Keep all Jido MCP work separate.

The release branches do not publish packages. The old migration record keeps
historical evidence; this file records the current v3 dependency set.
