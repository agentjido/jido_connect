# GitHub Webhooks

Use `Jido.Connect.GitHub.Webhook.verify_request/3` to verify
`X-Hub-Signature-256`, parse delivery metadata, and decode JSON payloads.

Use `normalize_signal/2` to turn supported GitHub events into stable
signal-shaped maps. Issue lifecycle events support opened, edited, closed,
reopened, assigned, labeled, and unlabeled actions. Issue opened events keep
the poll sensor fields. Issue comment events support created, edited, and
deleted actions, and include `comment_target` plus `pull_request?` fields to
distinguish issue comments from pull request comments. Pull request lifecycle
events support opened, synchronize, synchronized, reopened, closed, merged,
ready_for_review, and converted_to_draft signal shapes. Pull request review
events support submitted, edited, and dismissed actions; pull request review
comment events support created, edited, and deleted actions. Release lifecycle
events support published, edited, unpublished, deleted, prereleased, and
released actions. Push events include
repository, ref, commits, pusher, and delivery metadata when normalized from a
verified delivery.

Hosts own delivery dedupe and persistence.
