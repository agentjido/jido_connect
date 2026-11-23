# 00_04 Issue credential leases

Run a GitHub PR read through two named connections that share one credential.

## Read the code

1. [Agent](credential_leases.ex) declares two GitHub bindings. Each binding
   lists its Signal type and declares the shared host resolver. Both routes
   run the same Flow step with `action: GetPullRequest`. The Signal payload
   contains the repository and PR number.
2. [Host](lease_host.ex) keeps connection grants and credentials in separate
   records. Each grant records the actor and repository. Each connection
   points to the credential through `credential_ref`. The host supplies a
   `Jido.Connect.Context` for each named binding. Each Context holds a policy
   module and a store reference.
3. [Test](credential_leases_test.exs) runs the Action through the live Agent
   and swaps the real GitHub client for a fixture.

Connect selects the binding from the current Signal type and requests a lease
from the resolver declared in `connect do` when the Action runs. The resolver
checks the current grant and reads the credential in one store operation.
It returns a 60-second lease with the
current credential version and scopes. Connect checks the lease's connection
and effective scopes before it calls the handler.

## Run it

```sh
mix test.examples examples/00_start_here/00_04_credential_leases --warnings-as-errors
```

Both connections use the replacement token on the next call after rotation.
Revoking one grant stops that connection. Revoking the shared credential stops
the other connection at its next lease request. A lease from the first
connection fails the binding check for the second connection, and a lease
with insufficient scope fails before an API request.

## Limits

This example uses synthetic tokens and an in-memory host store. The tests
stop the Agent and store. Revocation applies to future lease requests. A
request already in flight uses its issued lease.

Previous: [Triage a PR with Slack](../00_03_triage_with_slack/README.md) |
Next: [Route a signed GitHub webhook](../00_05_github_webhook/README.md)
