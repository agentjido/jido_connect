# Connect example instructions

The examples teach the public Jido v3 and Connect contracts. These instructions
apply to files under `examples/`.

- Put each new lesson in a numbered chapter and give it a README, source, and
  colocated integration test. Keep the main Agent first in the source file.
- Teach one primary behavior per lesson. Use named routes, Joi schemas, and
  explicit Flow output. Execute Actions through a Flow, an Agent route, or
  `Jido.Exec`.
- Use the same Agent path offline and live. Keep fixture clients and runner
  setup outside the reader-facing Agent. Share support only where lessons
  use the same boundary.
- Keep credentials in the host. Keep runtime context separate from Signals
  and Agent state. Document required live variables and service permissions.
- Make live service access opt-in and state what it reads or writes.
- Use a deterministic offline test to verify the behavior in each README.
  Document limits and how the runner removes resources it starts.

From the umbrella root, run `mix test.examples --warnings-as-errors`,
`mix format --check-formatted`, and each changed demo.
