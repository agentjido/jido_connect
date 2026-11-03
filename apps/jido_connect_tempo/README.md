# Jido Connect Tempo

`jido_connect_tempo` is the Tempo Cloud provider package for `jido_connect`.
It includes:

- `Jido.Connect.Tempo`, the provider declaration with two auth profiles,
  five local labels, the read actions `tempo.worklogs.list_own`,
  `tempo.period.bookability.get`, `tempo.work_attribute.list` and
  `tempo.account.list_for_project`, and the confirmation-gated write action
  `tempo.worklog.create`
- the worklog, period, timesheet approval, work attribute and account reads
  and the worklog create in `Jido.Connect.Tempo.Client`, the normalized
  `Jido.Connect.Tempo.Worklog`, `Jido.Connect.Tempo.TimesheetApproval`,
  `Jido.Connect.Tempo.WorkAttribute` and `Jido.Connect.Tempo.Account`, and
  the result `Jido.Connect.Tempo.PeriodBookability`
- the read-only catalog packs `:tempo_reader`, `:tempo_period_lookup` and
  `:tempo_booking_lookup` and the writer pack `:tempo_writer` in
  `Jido.Connect.Tempo.CatalogPacks`
- OAuth 2.0 helpers in `Jido.Connect.Tempo.OAuth`
- the connection contract in `Jido.Connect.Tempo.Client.Request`
- the Bearer transport in `Jido.Connect.Tempo.Client.Transport`
- bounded offset pagination in `Jido.Connect.Tempo.Client.Pagination`
- error normalization in `Jido.Connect.Tempo.Client.Response`
- labels and grant mapping in `Jido.Connect.Tempo.ScopeResolver`

The package targets the Tempo REST API v4.

## Status

This package is **experimental**.

## Installation

```elixir
def deps do
  [
    {:jido_connect_tempo, "~> 0.8"}
  ]
end
```

## Connection Contract

The host owns the durable `Jido.Connect.Connection`. Every Tempo call starts
with `Jido.Connect.Tempo.Client.Request.new/2`, which accepts only:

| Field | Value |
| --- | --- |
| `provider` | `:tempo` |
| `profile` | `:api_token` or `:oauth2_user` |
| `subject.account_id` | the Atlassian account ID of the connected user, not blank |
| `metadata.api_origin` | `https://api.tempo.io`, `https://api.eu.tempo.io` or `https://api.us.tempo.io`, exactly |

The credential lease must carry the token field of the profile. Anything
else returns a `Jido.Connect.Error.AuthError` before any HTTP request.

Neither Tempo token reveals the user's account ID. The host reads it from
Jira `GET /rest/api/3/myself` with the same user and stores it in
`subject.account_id`.

Tempo keeps each customer's data on one cluster. A token sent to another
regional origin gets a 401. Tempo documents `https://api.tempo.io` as the
universal origin; on the test account it answered both tokens for data on
the US cluster. Prefer the regional origin of the customer's Tempo site.

## Auth Profiles

| Profile | Kind | Lease field | Sent as |
| --- | --- | --- | --- |
| `:api_token` (default) | API key | `api_token` | `Authorization: Bearer <api_token>` |
| `:oauth2_user` | OAuth 2.0 authorization code | `access_token` | `Authorization: Bearer <access_token>` |

A Tempo API token belongs to one user and carries that user's rights. The
OAuth profile needs a Tempo OAuth application, created under Tempo >
Settings > Data Access > OAuth 2.0 authentication.

## Labels

Tempo actions require these local labels:

| Label | Satisfied by the Tempo grant |
| --- | --- |
| `tempo.worklogs.read` | `worklogs:view` or `read` |
| `tempo.worklogs.write` | `worklogs:manage` or `write` |
| `tempo.accounts.read` | `accounts:view` or `read` |
| `tempo.periods.read` | `periods:view` or `read` |
| `tempo.approvals.read` | `approvals:view` or `read` |

The runtime checks `required -- connection.scopes`. A label counts only when
the host has recorded it in `connection.scopes`:

- API token: Tempo does not report a token's rights, so the host records the
  labels the user granted when creating the token.
- OAuth: the host records
  `Jido.Connect.Tempo.ScopeResolver.granted_labels(token.scope)`, or keeps
  the labels recorded before when `token.scope` is `nil`.

Tempo returns the OAuth `scope` as a space-separated list of grants. On the
test site these were `<area>:view` and `<area>:manage` grants and
`activities:produce`. Five of them map to one label each: `worklogs:view`,
`worklogs:manage`, `accounts:view`, `periods:view` and `approvals:view`, so
the test user's scope yields all five labels. Tempo's OpenAPI example shows
the coarse `read write`, where `read` satisfies the four read labels and
`write` satisfies `tempo.worklogs.write`. A manage or `write` grant implies
no read label. All other grants map to no label, among them
`accounts:manage`, `approvals:manage`, `teams:view` and `activities:produce`.
The effective rights stay bounded by the user's Tempo permissions.

`ScopeResolver.required_scopes/3` resolves each operation through an
operation map that each Tempo action extends. An operation without an entry
fails closed with a `Jido.Connect.Error.ConfigError`.

`tempo.work_attribute.list` requires `tempo.worklogs.read`. This is the
connector's choice: Tempo grants token rights per area and has no area for
work attributes, which belong to the worklog form. On the test site both
the API token and the OAuth access token of the test user read them.

## Own Worklogs

`tempo.worklogs.list_own` returns every Tempo worklog of the connection's
own account with a booking day from `from` to `to`, both inclusive:

```elixir
Jido.Connect.invoke(
  Jido.Connect.Tempo,
  "tempo.worklogs.list_own",
  %{from: "2026-10-01", to: "2026-10-31"},
  context: context,
  credential_lease: lease
)
```

The account is always `connection.subject.account_id`; the input holds only
`from` and `to`, and any other key fails input validation. The action
requires `tempo.worklogs.read` and is the only tool of the read-only pack
`:tempo_reader`. `from` and `to` are ISO dates in the form `YYYY-MM-DD`, and
`from` must not be after `to`; otherwise the call fails with a
`Jido.Connect.Error.ValidationError` with reason `:invalid_date_range`
before any request.

The read calls `GET /4/worklogs/user/{accountId}` with the percent-encoded
account ID, `from`, `to`, `offset` and `limit`, and never `updatedFrom`. It
reads pages of 50 within the bounds of [Pagination](#pagination): at most 20
pages and 1000 worklogs. `Jido.Connect.Tempo.Client.list_own_worklogs/2`
offers the same read with other bounds.

| Output | Meaning |
| --- | --- |
| `account_id` | the connection's `subject.account_id`, the author of every worklog |
| `from`, `to` | the range as supplied |
| `worklogs` | the worklogs in Tempo's order, as maps |
| `complete` | `true`: Tempo's pagination for the range is exhausted |

`complete` means that the read followed Tempo's pages until one came without
a `next` link. It is not a snapshot: the pages are read one after another,
and Tempo can add, change or delete worklogs during and after the read. It
is not a write receipt either. A read that does not exhaust the pages
returns an error and no worklogs, so a successful result always carries
`complete: true`.

Each worklog has these keys; the last six appear only when Tempo sent them:

| Key | Tempo field |
| --- | --- |
| `tempo_worklog_id` | `tempoWorklogId` |
| `author_account_id` | `author.accountId` |
| `start_date` | `startDate`, the booking day |
| `time_spent_seconds` | `timeSpentSeconds`, exact seconds |
| `issue_id` | `issue.id`, the numeric Jira issue ID |
| `description` | `description`, `nil` when Tempo sent none |
| `work_attributes` | `attributes.values` as `%{key: key, value: value}` maps, `[]` when absent |
| `start_time` | `startTime` |
| `start_date_time_utc` | `startDateTimeUtc` |
| `billable_seconds` | `billableSeconds`, `0` stays `0` |
| `created_at` | `createdAt` |
| `updated_at` | `updatedAt` |
| `self` | `self`, Tempo's link to the worklog |

`start_date` is the booking day in the worker's time zone, and Tempo filters
`from` and `to` by it. It can differ from the date of `start_date_time_utc`:
on the test site, a worklog booked at 00:30 Europe/Berlin on 2026-10-31 has
`start_date_time_utc` `2026-10-30T23:30:00Z` and belongs to the range
2026-10-31 to 2026-10-31. An empty description stays `""`, apart from an
absent one. On the test site, Tempo answered worklogs created through Tempo
without a description and with an empty one with its default text
`Working on work item <issue key>`, and worklogs created through Jira's
worklog API without a comment and with an empty comment with `""`. No
answer left `description` out.

`issue_id` is the only booking target. The Tempo package does not call Jira;
to read the issue, call `jira.issue.get` of `jido_connect_jira` with
`issue_key: Integer.to_string(issue_id)`, since Jira accepts the numeric ID
as `issueIdOrKey`.

The read fails as a whole; no part of the range is returned. Besides the
errors of [Pagination](#pagination) and [Errors](#errors), these are
`Jido.Connect.Error.ProviderError`s with `delivery: :response_received`:

| Reason | Cause | Details |
| --- | --- | --- |
| `:invalid_worklog` | a missing or malformed field, such as a worklog without Tempo ID, author, booking date, duration or issue ID | `field`, the Tempo field path |
| `:foreign_worklog_author` | a worklog whose `author.accountId` is not the connection's account | `tempo_worklog_id` |
| `:worklog_outside_range` | a booking day before `from` or after `to` | `tempo_worklog_id`, `start_date`, `from`, `to` |

The details never hold a description or another account's ID.

## Period Bookability

`tempo.period.bookability.get` returns the approval evidence of every Tempo
period that intersects an inclusive date range, for the connection's own
account:

```elixir
Jido.Connect.invoke(
  Jido.Connect.Tempo,
  "tempo.period.bookability.get",
  %{from: "2026-08-15", to: "2026-10-15"},
  context: context,
  credential_lease: lease
)
```

The account is always `connection.subject.account_id`; the input holds only
`from` and `to`, with the same date rule as the own worklog read, and fails
before any request otherwise. The action requires `tempo.periods.read` and
`tempo.approvals.read` and is the only tool of the read-only pack
`:tempo_period_lookup`.

The read calls `GET /4/periods` with `from` and `to`. Tempo answers with
every full period that intersects the range, also when the range starts or
ends inside a period. For each of these periods the read then calls
`GET /4/timesheet-approvals/user/{accountId}` with the percent-encoded
account ID and exactly that period's first and last day, because Tempo
answers a range across periods with a 400: `This is not a valid period. Did
you mean from '2026-08-01' to '2026-08-31'?`. All requests are GETs; the
`submit` and `recall` links of an approval are never followed.
`Jido.Connect.Tempo.Client.list_periods/2` and
`Jido.Connect.Tempo.Client.get_timesheet_approval/3` offer the two reads.

At most 20 periods are read. A range that intersects more fails after the
periods read and before the first approval read with a
`Jido.Connect.Error.ProviderError` with reason `:period_limit_exceeded` and
`details.max_periods: 20`; a range of exactly 20 periods succeeds. The bound
is the `:max_periods` option of
`Jido.Connect.Tempo.PeriodBookability.build/4`. The action uses the
default, and its input cannot change it.

### Evidence

| Output | Meaning |
| --- | --- |
| `account_id` | the connection's `subject.account_id`, the user of every approval |
| `from`, `to` | the range as supplied |
| `checked_at` | UTC time before the first Tempo request, ISO 8601 to the second |
| `complete` | `true` when the segments cover every day of the range once and each has an approval status |
| `segments` | one map per intersecting period, ordered by date |

| Segment key | Meaning |
| --- | --- |
| `from`, `to` | the part of the range that lies in this period |
| `period_from`, `period_to` | the full period as Tempo reports it |
| `approval_status` | Tempo's `status.key` as sent: `OPEN`, `IN_REVIEW`, `APPROVED` or another raw string; `nil` when no status was read |
| `approval_updated_at` | Tempo's `status.updatedAt` as sent, `nil` when absent; an `OPEN` status carries none |
| `approval_error` | `nil` when the approval read returned an approval; else `reason`, `status` and `retry_after` of the failed read |
| `closure_evidence` | always `:unknown` |
| `state` | `:blocked` or `:unknown`, derived as below |

On the test site, August 15 to October 15, 2026 gives three segments:
August 15 to 31 of the August period, `APPROVED`; all of September,
`IN_REVIEW`; and October 1 to 15 of the October period, `OPEN`. The
evidence times are timestamps such as `2026-10-30T19:19:42Z`, while Tempo's
OpenAPI documents a date; both are kept as sent.

The output never holds the approval comment, the actor or the reviewer, the
`actions` links, the worklog link or the approval's seconds.

`approval_status` is `nil` when Tempo sent no status, when the approval read
failed, and when Tempo answered for another user or another period. A
missing status is never read as `OPEN`. An unfamiliar key stays the raw
string; no atom is created for it.

`approval_error` separates these cases. It is `nil` when Tempo answered
with an approval, also one without a status. A failed read keeps only the
`reason`, `status` and `retry_after` of its normalized error: a token that
may read periods but not approvals gives `%{reason: :forbidden, status:
403, retry_after: nil}` on every segment, a 429 with `Retry-After: 30`
gives `%{reason: :rate_limited, status: 429, retry_after: 30}`, and an
approval of another user gives `%{reason: :foreign_approval_user, status:
nil, retry_after: nil}`. Any other error, such as one of an injected
provider client, is `:approval_read_failed` with `status` and
`retry_after` `nil`. Tempo's error text and the error details are not
kept.

`complete` is `false` when Tempo's periods leave a day of the range
uncovered or cover it twice, and when a segment has no `approval_status`.
The other segments keep their evidence. A failed `/4/periods` read returns
the normalized error instead, with the status and `retry_after` of
[Errors](#errors).

### Derived State

`state` is a derivation from the evidence, not a Tempo field:

- a segment is `:blocked` when its `approval_status` is `IN_REVIEW` or
  `APPROVED`, and `:unknown` otherwise: for `OPEN`, an unfamiliar key and a
  missing status;
- the result is `:blocked` when any segment is blocked, else `:unknown`.

`:bookable` is never derived, because it would need closure evidence. No
public Tempo Cloud API reads manual period closures, Scheduler freezes or
grace periods, so `closure_evidence` stays `:unknown`. An `OPEN` approval
therefore does not make a period bookable: Period Management can close a
period for everyone while the user's approval is still `OPEN`. Missing
evidence never turns a blocked segment into an unknown one.

The result is neither a reservation nor a write guarantee. It reports what
Tempo answered after `checked_at`; Tempo can change an approval or close a
period at any time afterwards, and a write into a closed period is rejected
only when it is made.

## Booking Lookup

The read-only pack `:tempo_booking_lookup` holds two reads for a booking
target that the host has already resolved: the work attributes Tempo
requires and the account candidates of the target's Jira project. Neither
calls Jira. The host finds the issue and its project ID with
`jira.issue.search` of `jido_connect_jira`, requesting the `project` field.
Jira returns that ID as a string, such as `"10882"`; the host converts it
to an integer, since `project_id` takes a positive integer and rejects a
string with a `Jido.Connect.Error.ValidationError`. Choosing a target, an
account or attribute values is the host's task.

### Work Attributes

`tempo.work_attribute.list` takes no input and returns every work attribute
of the Tempo site, read through [Pagination](#pagination) from
`GET /4/work-attributes`. Tempo lists the site's attributes, not those of
one project. The action requires `tempo.worklogs.read`; see
[Labels](#labels).

| Output | Meaning |
| --- | --- |
| `attributes` | every attribute in Tempo's order, as maps |
| `complete` | `true` when the value of every required attribute can be described |
| `incomplete` | the required attributes that make `complete` false, each with `key` and `reason` |

| Attribute key | Tempo field |
| --- | --- |
| `key` | `key`, an opaque string such as `_JclPhase_` |
| `name` | `name` |
| `type` | `type`, kept raw |
| `required` | `required` |
| `self` | `self`, `nil` when absent |
| `values` | for `STATIC_LIST`: `values` as `%{value: value, label: label}` maps, the label from `names`; `nil` when Tempo sent no `values`, and for every other type |

Tempo stores each attribute value of a worklog as a string. On the test site
on 2026-11-03 the seeded worklog stored, per type:

| Type | Stored value |
| --- | --- |
| `ACCOUNT` | the account key, `JCL-PROJECT`, not its name or numeric ID; the keys come from `tempo.account.list_for_project` |
| `CHECKBOX` | `"true"` |
| `INPUT_FIELD` | the free text as entered, `"JCL live note"` |
| `INPUT_NUMERIC` | `"1.5"` |
| `STATIC_LIST` | one of the stored `values`, a UUID that Tempo assigns, not its label |

A stored value of a static list is immutable, while its label can be
renamed and two labels can be equal; the stored value identifies the
choice. The package never assumes that an `ACCOUNT` attribute is called
`_Account_` and never turns a key or a type into an atom.

Any type other than these five, such as `DYNAMIC_DROPDOWN`, stays the raw
string. A required attribute of such a type is listed in `incomplete` with
reason `:unsupported_type`, and a required `STATIC_LIST` without a `values`
list with reason `:missing_choices`; an empty `values` list is a known empty
choice list, not a missing one. `complete: false` marks such a requirement,
not a failed read. A failed, looping or malformed page and a malformed
attribute fail the whole read; the attribute error has reason
`:invalid_work_attribute` and details `index` and `field`.

### Account Candidates

`tempo.account.list_for_project` takes `project_id`, the Jira project ID
as a positive integer, and returns the accounts the project offers for
booking. It requires `tempo.accounts.read`:

```elixir
Jido.Connect.invoke(
  Jido.Connect.Tempo,
  "tempo.account.list_for_project",
  %{project_id: 10_001},
  context: context,
  credential_lease: lease
)
```

The read calls `GET /4/account-links/project/{projectId}` with
`includeGlobalAccounts=true` once, then `GET /4/accounts/{id}` once per
candidate account, in link order. The account ID comes from each link's
`account.self` only after two checks: the reference names a Tempo origin
under the rule of [Pagination](#pagination), so the `https://api.tempo.io`
links of a regional site pass, and its path is exactly `/4/accounts/{id}`
with a positive decimal ID, without query or fragment. The reference is
never requested; the details are read at the connection's origin. Every
link is checked before the first account read.

A link is a candidate when its scope is `PROJECT` with the requested ID. A
link of another project is left out, and its account is read only when
another link makes it a candidate.

| Output | Meaning |
| --- | --- |
| `project_id` | the project ID as supplied |
| `accounts` | the candidates in the order of their first link, as maps |

| Account key | Meaning |
| --- | --- |
| `id`, `key`, `name` | Tempo's account ID, key and name; the key is the value of an `ACCOUNT` attribute |
| `status` | `OPEN`, `CLOSED`, `ARCHIVED` or another raw string |
| `global` | Tempo's `global` flag |
| `self` | Tempo's link to the account |
| `links` | one map per link of the project to this account: `id`, `default`, `scope_type`, `scope_id` |

On the test site Tempo reports a global account as a link with ID 0 on the
requested project, and exactly one link of the project is `default: true`.
An account with two links keeps both. A closed or archived account stays a
candidate with its status. The lead, contact, customer, category and budget
of an account are not returned.

The read fails as a whole; no account is returned without its details.
Besides the errors of [Errors](#errors), such as Tempo's 404 `Invalid
account` for an account read, these are `Jido.Connect.Error.ProviderError`s
with `delivery: :response_received`:

| Reason | Cause | Details |
| --- | --- | --- |
| `:invalid_account_links` | an answer without a `results` list | |
| `:invalid_account_link` | a missing or malformed link field | `index`, `field` |
| `:foreign_account_reference` | an `account.self` on another origin or path | `index`, `link_id` |
| `:account_limit_exceeded` | more candidate accounts than `:max_accounts` (100), before the first account read | `max_accounts`, `accounts` |
| `:invalid_account` | malformed account details | `account_id`, `field` |
| `:account_mismatch` | details of another account than the one requested | `account_id`, `returned_id` |

`Jido.Connect.Tempo.Client.list_accounts_for_project/3` offers the same read
with another `:max_accounts`; the action uses the default.

## Worklog Creation

`tempo.worklog.create` creates one worklog for the connection's own account
and returns it as Tempo confirmed it. It declares
`effect(:write, confirmation: :always, provider_idempotency?: false)`, the
policy `:own_worklog_author` and the label `tempo.worklogs.write`, and it is
the only tool of the writer pack `:tempo_writer`.

### Confirmation

The declaration alone does not enforce confirmation: the core allows direct
mutation calls by default and only logs a deprecation warning. A strict host
denies them with `config :jido_connect, direct_mutation_mode: :deny`, which
also covers the generated Jido action, or per call with
`direct_mutation_mode: :deny`, and creates a worklog in two steps:

```elixir
input = %{
  author_account_id: connection.subject.account_id,
  issue_id: 10_001,
  start_date: "2026-10-29",
  start_time: "09:00:00",
  time_spent_seconds: 5400,
  description: "Review"
}

{:ok, prepared} =
  Jido.Connect.prepare(Jido.Connect.Tempo, "tempo.worklog.create", input,
    context: context,
    credential_lease: lease,
    direct_mutation_mode: :deny
  )

# Show prepared.preview to the user and store the approval.

{:ok, %{worklog: worklog}} =
  Jido.Connect.commit(Jido.Connect.Tempo, prepared, input,
    context: context,
    credential_lease: lease,
    direct_mutation_mode: :deny,
    execution_authorization: approval,
    authorization_validator: &MyApp.Approvals.validate/3
  )
```

`prepare/4` sends no request. It checks the input and returns a preview
with `operation`, `issue_id`, `start_date`, `start_time`,
`time_spent_seconds`, `billable_seconds`, `description_bytes` and
`attribute_count`; the description text and the attribute values stay out
of it. `commit/4` fails before the POST without host evidence and when the
input, connection, lease or binding changed since `prepare/4`. With direct
calls denied, `invoke/4` fails with `:execution_authorization_required`.
Core does not lock a prepared action: the host claims `prepared.id` before
`commit/4`, as the core README describes, and never commits it twice.

### Input

| Field | Rule |
| --- | --- |
| `author_account_id` | required; must equal the connection's `subject.account_id` |
| `issue_id` | required; the numeric Jira issue ID, a positive integer, not the issue key |
| `start_date` | required; the booking day as `YYYY-MM-DD` |
| `time_spent_seconds` | required; whole seconds, at least 1 |
| `description` | optional string |
| `attributes` | optional list of maps with exactly a `key` and a `value`, both strings; keys unique |
| `start_time` | optional time of day as `HH:mm:ss` |
| `billable_seconds` | optional whole seconds, at least 0 |

Any other key, such as a raw body, `bypass_period_closures_and_approvals` or
`remaining_estimate_seconds`, fails input validation. The input is checked
three times with one rule: by the preview at `prepare/4`, by the handler
before it resolves the provider client, and by
`Jido.Connect.Tempo.Client.create_worklog/2` before its POST. An invalid
value is a `Jido.Connect.Error.ValidationError` with reason
`:invalid_worklog_input` and the field in `subject`; a type or bound that
the action schema already rejects, such as an issue key or `5400.5`
seconds, fails with reason `:input`. A foreign author is a
`Jido.Connect.Error.AuthError` with reason `:foreign_worklog_author` that
names neither account.

The policy `:own_worklog_author` tells the host to check that the actor may
book time as the connection's user; the action itself enforces the author
rule whatever policy the host passes.

### Request

The create sends one JSON `POST /4/worklogs` with `authorAccountId`,
`issueId`, `startDate`, `timeSpentSeconds` and the given optional fields
`description`, `attributes`, `startTime` and `billableSeconds`, each value as
given: no trimming, rounding or time zone shift. It never sends
`bypassPeriodClosuresAndApprovals` or `remainingEstimateSeconds`.

The POST is sent once. `Transport.post/3` sets `retry: false` after it has
merged the Req options of `:tempo_req_options` and of the caller, so even
`retry: :transient` cannot resend it.

### Result

A 2xx answer counts as a created worklog only when it normalizes through
`Jido.Connect.Tempo.Worklog` with a Tempo ID and names the requested author,
issue, booking day and seconds. The output is `%{worklog: worklog}`, a map
with the keys of [Own Worklogs](#own-worklogs), with the full description and
the attribute values.

On the test site, a create at `08:15:00` on 2026-10-29 came back with
`start_date_time_utc` `2026-10-29T07:15:00Z`, the worker's time zone being
Europe/Berlin. Without `billable_seconds`, Tempo set the billable seconds to
the time spent. Whether an omitted `remainingEstimateSeconds` changes the
Jira remaining estimate was not checked.

### Errors and Delivery

Every error of the create carries `mutation?: true` and
`provider_idempotency?: false`. Its `delivery` tells whether Tempo may have
created the worklog:

| Answer | Reason | Delivery | `Error.retry_guidance/1` |
| --- | --- | --- | --- |
| 403 `The timesheet status must be open for the period` | `:period_locked` | `:rejected` | `:do_not_retry` |
| other 400, 401, 403, 404 | `:bad_request`, `:unauthorized`, `:forbidden`, `:not_found` | `:rejected` | `:do_not_retry` |
| 429 | `:rate_limited`, with `retry_after` | `:rejected` | `:safe_to_retry` |
| 3xx, 5xx | `:redirect_not_followed`, `:server_error` | `:sent_outcome_unknown` | `:do_not_retry` |
| 2xx that is not a worklog | `:invalid_response`, `:invalid_worklog` | `:sent_outcome_unknown` | `:do_not_retry` |
| 2xx with another author, issue, day or seconds | `:worklog_mismatch`, with `tempo_worklog_id` and `mismatched_fields` | `:sent_outcome_unknown` | `:do_not_retry` |
| timeout, closed connection | `:request_error` | `:sent_outcome_unknown` | `:do_not_retry` |
| refused connection, foreign origin | `:request_error` | `:not_sent` | `:safe_to_retry` |

`:period_locked` is Tempo's 403 with the recorded text, observed on the test
site for a booking into the approved August 2026 period. It is the signal
that [Period Bookability](#period-bookability) cannot read in advance. Only
this text gets the label; an unknown 400 or another 403 keeps its status
reason. A booking into a period in review or into one closed in Period
Management was not tried. Its answer may arrive as `:forbidden` or
`:bad_request`, which are `:rejected` with `:do_not_retry` like
`:period_locked`. After `:sent_outcome_unknown` the worklog may exist; read
the day back with `tempo.worklogs.list_own` before booking it again.

Errors hold neither the description nor the attribute values. Tempo quotes
rejected input in its error text, as in `Non valid time '25:00:00'`; where
that text quotes the description, an attribute value or the author's account
ID, `details.message` shows `[redacted]` in its place.

## OAuth Flow

The host owns the callback route, its session binding, token storage and
refresh scheduling.

1. Redirect the user to the authorize URL:

   ```elixir
   Jido.Connect.Tempo.OAuth.authorize_url(
     client_id: client_id,
     redirect_uri: "https://host.example.com/integrations/tempo/oauth/callback",
     jira_url: "https://example.atlassian.net"
   )
   ```

   This builds `https://api.tempo.io/oauth/authorize/redirect` with
   URL-encoded `client_id`, `redirect_uri` and `jira_url`. Tempo's
   documentation lists no `state` parameter, so the helper sends none. On
   the test site, an extra `state` query parameter on this URL reached the
   redirect URI unchanged. Bind the callback to the user's session in the
   host.

2. Exchange the `code` from the callback:

   ```elixir
   {:ok, token} =
     Jido.Connect.Tempo.OAuth.exchange_code(code,
       client_id: client_id,
       client_secret: client_secret,
       redirect_uri: redirect_uri
     )
   ```

   The form post goes to `https://api.tempo.io/oauth/token/`. `token` holds
   `access_token`, `refresh_token`, `expires_in` (seconds) and `scope` (a
   list of Tempo grants); Tempo also sends `token_type` `"Bearer"`, which
   the helper does not read. A successful response that is not a JSON object,
   or lacks either token, is an `:invalid_response` error.
   `expires_in` is `nil` when Tempo sends no positive integer; the expiry is
   then unknown. `scope` is `nil` when Tempo sends no `scope` string; an
   empty string is an empty list.

3. Before `expires_in` runs out, call
   `Jido.Connect.Tempo.OAuth.refresh(refresh_token, opts)` with the same
   options.

### Token Rotation

Every refresh replaces both tokens. Tempo invalidates the old access token
and the old refresh token at once; on the test site the old access token got
a 401 right after the refresh. The host must therefore store both new
tokens, and update `connection.scopes` from the new `scope`, before it uses
either. When `scope` is `nil`, Tempo did not report the grant and the host
keeps the labels it recorded before. A refresh response without a new
refresh token is an error; a missing or malformed `expires_in` or `scope`
does not discard the new tokens, since Tempo has already rotated them. A
failed or lost refresh can leave the connection without a valid refresh
token; the user must then authorize again. Treat the old refresh token as
lost after any response from Tempo and after an error with
`delivery: :sent_outcome_unknown`, such as a timeout, whatever the error's
retry guidance says. Only an error with `delivery: :not_sent`, such as a
refused connection, leaves it valid.

Rejections, such as Tempo's 403 for an invalid code or refresh token, are
`Jido.Connect.Error.ProviderError`s without the client secret, the code or
a token. Token revocation is not implemented.

## Transport

`Jido.Connect.Tempo.Client.Transport.get/3` sends a GET for a path relative
to the connection's origin and returns the decoded JSON body;
`Transport.post/3` sends one JSON POST under the rules of
[Worklog Creation](#worklog-creation). The token never leaves that origin:

- every request built by `Transport.request/2` checks its final URL before
  it is sent; another scheme, host or port fails with
  `details.reason: :foreign_origin` and `delivery: :not_sent`
- redirects are not followed; a 3xx response is an error
- the Req options `:tempo_req_options`, meant for `Req.Test`, cannot change
  the base URL, the auth or the redirect policy

Automatic retries are off by default. A caller may enable them for a GET
through `:req_options`; a POST is never retried.

## Pagination

`Jido.Connect.Tempo.Client.Pagination.collect/3` reads every page of a
pageable GET and returns all results, or fails the whole read. Each next
page is rebuilt from the page's validated `offset` and `count` at the
connection's origin. The `next` link is checked, never requested: it must
name a Tempo origin and the requested path. Tempo's links name
`https://api.tempo.io` even on a regional origin, so a link on another Tempo
origin is accepted while the request stays at the connection's origin.

| Option | Default | Exceeding it |
| --- | --- | --- |
| `:limit` | 50 | page size sent to Tempo |
| `:max_pages` | 20 | `:page_limit_exceeded`, before the next request |
| `:max_results` | 1000 | `:result_limit_exceeded`; exactly this many succeed |

A foreign `next` link, a repeated offset, malformed page metadata, a `next`
link whose `offset` is not the page's `offset` plus `count`, and any failed
page also fail the whole read. Query parameters go in `:params`, a keyword
list or a map; their `offset` and `limit` are dropped. An invalid bound or
`:params` value is a `Jido.Connect.Error.ValidationError` before any
request.

## Errors

Failures are `Jido.Connect.Error.ProviderError`s with `provider: :tempo`,
the status and `details.retry_after` from an integer `Retry-After` header:

| Status | Reason |
| --- | --- |
| 3xx | `:redirect_not_followed` |
| 400 | `:bad_request` |
| 401 | `:unauthorized` |
| 403 | `:forbidden` |
| 404 | `:not_found` |
| 429 | `:rate_limited` |
| 5xx | `:server_error` |
| other | `:http_error` |

`details.message` holds Tempo's error text from `{"errors": [{"message":
...}]}`, several messages joined with `; `, else the top-level `message`
that the token endpoint sends. Tempo answers 401 without a body. A 2xx
response without valid JSON is `:invalid_response`; an error response with
a malformed JSON body keeps its status, reason and `retry_after`. A
transport failure, such as a timeout, is `:request_error`. Raw bodies are
reduced to a value-free summary. The worklog create adds the mutation rules
of [Errors and Delivery](#errors-and-delivery).

## Limits Owned by the Host

The package bounds the number of pages and results per read, the approval
reads of one period bookability read to 20 periods, and the account reads
of one account candidate read to 100 accounts. It does not
limit bytes: response size, the size of results passed to an agent and
storage quotas are host policy.

## Live Smoke Tests

The `:live_smoke` tests read from the test account with the API token and
the OAuth access token and record the fixtures under
`test/fixtures/tempo/recorded`. They never use the stored refresh token. One
test exchanges an authorization code and refreshes the new pair once; it
runs only with `TEMPO_OAUTH_CODE` and writes each new pair to
`TEMPO_OAUTH_TOKEN_FILE`. Run them from the umbrella root:

```sh
set -a; source ~/.config/jido_connect/live/atlassian.env; set +a
MIX_ENV=test mix do --app jido_connect_tempo test --only live_smoke
```

The own worklog checks rely on the test user's seeded worklogs from August
to October 2026. Each read except the empty range compares every worklog's
ID, booking day, start time, UTC start, seconds, billable seconds, issue ID
and description with a direct Tempo read outside the package:

| Check | Path | Recording |
| --- | --- | --- |
| August 1 to October 31: every period boundary day, more than one page | action, API token | `worklogs_own` |
| October 1 in pages of two | client, OAuth access token | `worklogs_own_small_page` |
| October 31 as a one-day range | action, OAuth access token | `worklogs_own_day` |
| October 30, then July 2026 as the empty range | action, OAuth access token | `worklogs_own_empty` |
| October 28, with the descriptions as Tempo sends them | action, API token | `worklogs_own_jira` |

The empty range must return `worklogs: []` and `complete: true`. Some of
these recordings also hold worklogs that the seeded data lacks; see the
Tempo section of `docs/live_smoke_tests.md`.

The period checks rely on the seeded approvals of the test user: August
2026 `APPROVED`, September `IN_REVIEW` and October `OPEN`. Each status and
its time are compared with a direct approval read of the same period by the
same user:

| Check | Path | Recording |
| --- | --- | --- |
| August 15 to October 15: three segments, `blocked`, `blocked`, `unknown`, aggregate `blocked` | action, API token | `period_bookability` |
| October as one period, then August 1 to September 30 as a range across periods, which gets Tempo's 400 | client, OAuth access token | `timesheet_approval` |

Two tests write and run only with `TEMPO_LIVE_DESTRUCTIVE=true`:

| Check | Path | Recording |
| --- | --- | --- |
| create one worklog on 2026-10-29 through `prepare/4` and `commit/4`, read it back with `tempo.worklogs.list_own` and compare ID, day and seconds, then book the same input on 2026-08-14 and get the `:period_locked` 403 | action, API token | `worklog_create` |
| a hand-built POST with the start time `25:00:00` on 2026-08-14 gets Tempo's 400 | transport, API token | `worklog_create_invalid_time` |

Each run of the first test leaves one worklog of the test user on
2026-10-29; the package cannot delete it. The approved-period booking and
the invalid start time cannot create one; if Tempo accepted either, the test
stops at once and names the new ID. The 401 of a create with an invented
token is recorded in `worklog_create_unauthorized` without the write gate,
since that token cannot create anything.

The booking lookup checks are in `booking_lookup_live_smoke_test.exs`:

| Check | Path | Recording |
| --- | --- | --- |
| the account candidates of `TEMPO_JIRA_PROJECT_ID`: the four test accounts with name, status, global flag and one link each, `TEMPO_ACCOUNT_ID` as the only default link, each compared with a direct read | action, OAuth access token | `accounts_for_project` |
| an unknown account ID gets Tempo's 404 `Invalid account` | transport, API token | `account_not_found` |
| the five test work attributes with type, name, required flag, stored values and labels, compared with a direct read; the free-text `_JclNote_` is optional in both modes | action, OAuth access token | `work_attributes_required` or `work_attributes_optional` |
| the seeded worklog of October 1 stores a stored value labelled build, `"true"`, `"1.5"`, the account key `JCL-PROJECT` and the text `"JCL live note"` | action, API token | `work_attribute_values`, in the optional mode only |

The work attribute checks need the test attributes, which exist on the test
site only around a run. They run only with `TEMPO_WORK_ATTRIBUTES` set to
`required` or `optional`, the mode in which the attributes were created.
`work_attribute_values` and `work_attributes_optional` come from the same
optional run, since the offline tests match the stored value of the static
list against that page; see the Tempo section of `docs/live_smoke_tests.md`.

The successful code exchange and refresh are recorded in
`oauth_exchange.json` and `oauth_refresh.json`, the rejections in
`oauth_invalid_code.json` and `oauth_invalid_refresh_token.json`. See
`docs/live_smoke_tests.md` for the variables and the recording mode.
