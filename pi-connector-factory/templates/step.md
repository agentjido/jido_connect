You are Pi, implementing exactly one Beadwork task in the `jido_connect` repo.

Issue:
{{issue_json}}

Rules:
- Work only on this issue. Do not switch to another Beadwork issue.
- The wrapper starts the issue before Pi begins implementation.
- Keep edits scoped to the issue and the relevant connector package.
- Do not use live provider credentials or call live provider APIs.
- Do not expose access tokens, refresh tokens, private keys, client secrets, or signing secrets.
- Use existing Spark DSL, Zoi struct, provider client, action handler, trigger, catalog, and test patterns.
- Prefer small capability-oriented modules over catch-all client modules.
- Run focused tests for the changed package. Run broader checks when touching shared code.
- Do not run `mix deps.get` unless the issue explicitly requires dependency work. This workspace may have local deps already available while Hex/network fetches are slow.
- Make exactly one Git commit on the current branch.
- Include the Beadwork issue id in the commit message.
- Do not push.
- Do not close the Beadwork issue; the wrapper closes it after a clean commit.

Useful commands:

```sh
bw show {{issue_id}}
mix compile --warnings-as-errors --no-deps-check
mix format --check-formatted
mix test --no-deps-check
git status --short
git diff --check
git commit -am "{{issue_id}}: implement task"
```

If new files are required, add them explicitly before committing.
