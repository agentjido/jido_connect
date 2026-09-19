# Connect v3 release candidate

Scope: the `release/3.0` compatibility line. Keep `release/2.0` for v2 fixes.
Use prerelease Action Hex packages. ExMCP owns MCP protocol and transports.
Do not change `jido_mcp`. Do not publish packages as part of this work.

```mermaid
flowchart TD
  A[Keep separate v2 and v3 branches] --> B[Integrate SharePoint on v3]
  A --> C[Add full MCP client capabilities]
  B --> D[Run core, umbrella, and demo checks]
  C --> D
  D --> E[Update guides, release notes, and issue status]
  E --> F[Present the v3 development candidate]
  F --> G[Review dependency exceptions before publication]
```

| Work | Beadwork | State |
| --- | --- | --- |
| SharePoint on v3 | `jido_con-s91.1` | Landed at `74f41c69`; PR #66 closed |
| Tools, resources, prompts, completion, notifications, connection lifecycle | `jido_con-s91.2` | Implemented at `a783ef6d`; core, umbrella, and demo checks pass |
| Release record and issue cleanup | `jido_con-s91.3` | Checks recorded; #79 accepted and closed; #81 remains |

The MCP client work includes scoped access, pages, normalized errors, lease
expiry and revocation, host client ownership, and stream cleanup. Modern
notification streams use the public ExMCP subscription API. Resources and
prompts preserve the MCP result maps. Tools retain the existing normalized
Connect result and approval flow.

The selected ExMCP release has no public client event path for legacy,
uncorrelated resource/list-change notifications. Connect uses its modern
subscription API. It must not add a second protocol parser to work around
this limit. Follow-up: [#81](https://github.com/agentjido/jido_connect/issues/81). See the guide for the supported protocol and host callbacks.

The two Cowlib findings are accepted as exact, reviewed exceptions. Connect and
ExMCP do not call the affected encoders, and Connect does not publish a Cowboy
server. Issue #79 records the decision and is closed. Recheck the exceptions
after dependency updates and remove them when ExMCP can omit Cowboy.
Jido, Jido Action, Jido Signal, and ExMCP now use Hex releases. The core Hex
package builds without a Git dependency.
These are publication checks, separate from the development candidate.
