# Google Polling Checkpoints

Google polling triggers must be credential-free in tests and host-owned in
storage. Connector packages only accept the checkpoint value passed by the host
and return the next value after a successful poll.

## Current Checkpoint Types

- Gmail message polling uses Gmail `historyId`.
- Drive file-change polling uses Drive change `pageToken` / `startPageToken`.
- Calendar event-change polling uses Calendar `syncToken`.

## Required Behavior

Pollers share the same offline contract:

1. Empty checkpoints initialize without replaying existing provider history.
2. Non-empty checkpoints drain all provider pages before returning.
3. Signals are deduped using the trigger DSL `dedupe` key.
4. The returned checkpoint is the newest provider checkpoint available.
5. Repeated page tokens return an invalid-response error with reset guidance.
6. Expired provider checkpoints return `reason: :checkpoint_expired` with reset
   guidance and the original provider reason/details.

Reset guidance has this shape:

```elixir
%{
  action: :clear_checkpoint,
  behavior: :initialize_without_replay
}
```

Hosts should clear the stored checkpoint and run the poller again. The next run
will initialize from the provider's current cursor and should not replay older
history.
