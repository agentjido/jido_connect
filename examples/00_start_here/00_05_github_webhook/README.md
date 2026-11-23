# 00_05 Route a signed GitHub webhook

Read the current pull request after GitHub sends a pull request event.

## Read the code

1. The [Agent](github_webhook.ex) selects the webhook Trigger and the GitHub
   read Action in `connect do`. Its Jido route starts a Flow on the matching
   Signal.
2. The [host](webhook_host.ex) reads the selected Trigger contract and verifies
   the raw request body. It calls the Agent with
   `context: %{connect: %{source: context}}`. The host builds that
   `Jido.Connect.Context` with a connection, policy, and credential resolver.
3. The standard Flow step reads the PR. Connect checks the grant and requests
   a current credential lease from the host resolver.

## Run it

```sh
mix test.examples examples/00_start_here/00_05_github_webhook --warnings-as-errors
```

The [test](github_webhook_test.exs) signs a fixture request. The Agent saves
the PR title from the API response. Invalid signatures, known delivery IDs,
and repositories outside the grant stop before the resolver is called. A
Trigger selection check rejects the separate PR poll Trigger.

## Limits

This example runs in memory and stops its Agent after each case. The host
receives known delivery IDs as input. A production host needs an endpoint
that reads the raw HTTP body, a signing secret, and durable delivery claims.
The webhook signing secret and outbound GitHub credential serve separate
purposes. The host supplies each at its own boundary.

Previous: [Issue credential leases](../00_04_credential_leases/README.md)
