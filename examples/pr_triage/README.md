# GitHub and Slack PR triage agent

Run this example from the `release/3.0` umbrella root.

```sh
mix deps.get
mix run examples/pr_triage/run.exs
```

The example uses fixture clients for both providers. It needs no tokens, network
access, or model. It prints `Ready for review: example/widgets#42`.

- The Agent declares two named bindings in `connect do`. The GitHub binding
  selects a PR update trigger and a read Action. The Slack binding selects a
  posting Action.
- The host drives one tick of the generated GitHub Sensor. It sends the
  resulting Signal to the Agent and passes runtime context for each binding
  under `:connect`, separate from the Signal.
- The Agent route starts the Flow. The Flow uses the generated
  `GitHub.Actions.GetPullRequest`, then saves a draft for an open PR that is
  ready for review.
- The host uses the separate Slack binding to prepare and commit the draft.
  The fixture supplies a one-use approval. A real host must obtain and store
  the approval and check it at commit. The example checks that a second
  submission of the same approval fails.

In a running application, use a host scheduler or a SensorManager driver for
polling and persist the checkpoint when needed. Keep stored credentials in
the host credential store under their own IDs. Resolve a lease for each
authorized operation.
