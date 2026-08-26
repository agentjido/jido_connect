# Release Readiness Review: Google Connector Family

**Review date**: 2026-05-19
**Milestone**: M2 – Google Connectors
**Epic**: G11 – Cross-Google Hardening And Demo
**Reviewer**: Pi (automated)

**2026-08-25 update**: This is a historical review. The unpublished
`jido_connect_mcp` application and its `jido_mcp` dependency were removed after
the bridge and its tests moved into core `jido_connect`. RISK-1 is resolved and
does not need the recommendation below.

## Summary

The Google connector family and sibling connector packages pass the quality
gate after targeted fixes. Two minor formatting issues and one missing test
dependency were corrected during this review. Two residual risks are tracked
as follow-up issues.

## Quality Gate Results

### Compilation

| Check | Result |
|---|---|
| `mix compile --warnings-as-errors --no-deps-check` | **PASS** |

Zero warnings across all 26 umbrella apps.

### Formatting

| Check | Result |
|---|---|
| Per-app `mix format --check-formatted` | **PASS** (25/26 apps) |
| `jido_connect_mcp` | **SKIPPED** – transitive Hex deps of the `jido_mcp` git dependency cannot be resolved offline; see RISK-1 |

### Tests

| Check | Result |
|---|---|
| Per-app `mix test --no-deps-check` | **PASS** (25/26 apps) |
| Total tests | **2566 tests, 0 failures** |
| `jido_connect_mcp` | **SKIPPED** – same dep resolution issue as RISK-1 |
| `jido_connect_posthog` seed-dependent test | See RISK-2 |

## Fixes Applied

1. **`jido_connect` core – missing `plug` test dependency** (`apps/jido_connect/mix.exs`)
   - `Req.Test` uses `Plug.Parsers` internally; `plug` was not declared as a
     test-only dependency, causing the provider transport test to fail.
   - Added `{:plug, "~> 1.19", only: :test}` following the same pattern
     introduced in `jido_con-ime.2` for `jido_connect_calcom`.

2. **Formatting – `jido_connect_google_search_console`** (2 files)
   - `inspect_url_test.exs` and `normalizer_test.exs` had minor whitespace
     inconsistencies. Reformatted with `mix format`.

3. **Formatting – `jido_connect_hubspot`** (2 files)
   - `contact_changed_poller_test.exs` and `deal_changed_poller_test.exs`
     had trailing blank lines. Reformatted with `mix format`.

## Google Package Test Coverage

| Package | Tests | Result |
|---|---|---|
| `jido_connect_google` (shared) | 42 | PASS |
| `jido_connect_google_sheets` | 77 | PASS |
| `jido_connect_gmail` | 92 | PASS |
| `jido_connect_google_drive` | 119 | PASS |
| `jido_connect_google_calendar` | 82 | PASS |
| `jido_connect_google_contacts` | 50 | PASS |
| `jido_connect_google_docs` | 63 | PASS |
| `jido_connect_google_forms` | 107 | PASS |
| `jido_connect_google_slides` | 54 | PASS |
| `jido_connect_google_tasks` | 82 | PASS |
| `jido_connect_google_analytics` | 50 | PASS |
| `jido_connect_google_search_console` | 115 | PASS |
| `jido_connect_google_meet` | 40 | PASS |

**Total Google tests: 973**, all passing.

## Risks Tracked as Follow-Up Issues

### RISK-1: `jido_connect_mcp` dep resolution requires network access (resolved)

The `jido_mcp` git dependency transitively requires `anubis_mcp`, `jido`,
and `zoi` from Hex. These packages exist in the local Hex cache and in the
umbrella `deps/` directory, but Mix's dependency checker cannot verify them
without a successful `mix deps.get`. When network access is slow or
unavailable, format checks and tests for `jido_connect_mcp` are blocked.

**Resolution, 2026-08-25**: The unpublished application was removed. Its bridge
and tests now live in core `jido_connect`, which uses stable ExMCP directly.

### RISK-2: `jido_connect_posthog` seed-dependent test failure

`test/jido_connect/posthog/handlers/actions/get_insight_test.exs` defines
`ErrorGetInsightMock` inline alongside the test module. With certain random
seeds (e.g. 999), the mock module is not yet compiled when the async test
executes, causing `UndefinedFunctionError`. Tests pass with seed 0.

**Recommendation**: Move inline error mock modules to dedicated test support
files under `test/support/` and ensure they are compiled before any test
module that references them.

## Pre-Existing Issues (Not Blocking Release)

- `erl_crash.dump` files exist in several app directories. These are artifacts
  from previous crashes and should be `.gitignore`d or cleaned up.
