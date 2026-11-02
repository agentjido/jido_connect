# Jido Connect Tempo

`jido_connect_tempo` is the Tempo Cloud provider package for `jido_connect`.
It includes:

- `Jido.Connect.Tempo`, the provider declaration with two auth profiles,
  five local labels and the read actions `tempo.worklogs.list_own` and
  `tempo.period.bookability.get`
- the worklog, period and timesheet approval reads in
  `Jido.Connect.Tempo.Client`, the normalized `Jido.Connect.Tempo.Worklog`
  and `Jido.Connect.Tempo.TimesheetApproval`, and the result
  `Jido.Connect.Tempo.PeriodBookability`
- the read-only catalog packs `:tempo_reader` and `:tempo_period_lookup` in
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
to the connection's origin and returns the decoded JSON body. The token
never leaves that origin:

- every request built by `Transport.request/2` checks its final URL before
  it is sent; another scheme, host or port fails with
  `details.reason: :foreign_origin` and `delivery: :not_sent`
- redirects are not followed; a 3xx response is an error
- the Req options `:tempo_req_options`, meant for `Req.Test`, cannot change
  the base URL, the auth or the redirect policy

Automatic retries are off by default.

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
reduced to a value-free summary.

## Limits Owned by the Host

The package bounds the number of pages and results per read, and the
approval reads of one period bookability read to 20 periods. It does not
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

The successful code exchange and refresh are recorded in
`oauth_exchange.json` and `oauth_refresh.json`, the rejections in
`oauth_invalid_code.json` and `oauth_invalid_refresh_token.json`. See
`docs/live_smoke_tests.md` for the variables and the recording mode.
