# Jido Connect Connector Roadmap

## Overview

`jido_connect` should become a broad connector catalog for Jido agents: provider
packages that compile Spark DSL declarations into generated Jido actions,
sensors, and plugins while keeping auth, credentials, scopes, webhooks, and
provider API behavior behind stable runtime contracts.

This list is seeded from Lindy's public integrations catalog, with their "Most
Popular" section treated as the top popularity signal:

1. Google Sheets
2. Gmail
3. Slack
4. Google Drive
5. HubSpot
6. Calendly
7. Airtable
8. Salesforce

After those, the ranking is a pragmatic build order based on likely Jido agent
utility, category breadth, OAuth complexity reuse, and how much each connector
helps prove reusable core abstractions.

## Ranking Principles

- Build high-frequency agent workflows first: email, files, spreadsheets, CRM,
  calendar, chat, and support.
- Prefer connector families where one auth/client foundation unlocks multiple
  packages, such as Google, Microsoft, Atlassian, and Salesforce ecosystems.
- Keep provider packages thin: DSL, auth helpers, client boundary, handlers,
  webhook helpers, tests.
- Push reusable behavior down into `jido_connect`: OAuth, app installation
  flows, scope resolution, webhooks, pagination, rate limits, error taxonomy,
  availability checks, and local demo harnesses.
- Every connector should ship with generated Jido actions, generated sensors
  where useful, plugin availability, docs, and local test/demo support.

## Status Legend

- `shipped`: package exists in `apps/` and the tracked roadmap scope is complete.
- `in_progress`: package exists or work has started, but the roadmap scope is not
  complete yet.
- `queued`: Beadwork epics/tasks exist and are ready after current blockers.
- `ready`: Beadwork or the roadmap says this should be built soon, but no package
  exists yet.
- `planned`: important, but after the first connector families are stable.
- `later`: useful breadth once the core package is mature.

## Current Beadwork Queue Snapshot

As of 2026-05-19, the open queue is intentionally chained:

1. `jido_con-jxj` `[G11] Cross-Google Hardening And Demo`
2. `jido_con-bcz` `[G12] Microsoft Graph Foundation`
3. `jido_con-ntx` `[G13] Microsoft Outlook Mail Connector`
4. `jido_con-y3t` `[G14] Microsoft Calendar Connector`
5. `jido_con-tyr` `[G15] Microsoft OneDrive Connector`
6. `jido_con-17g` `[G16] Zendesk Connector`
7. `jido_con-zya` `[G17] Intercom Connector`
8. `jido_con-fe6` `[G18] Notion Connector`
9. `jido_con-aje` `[G19] Asana Connector`
10. `jido_con-cja` `[G20] GitLab Connector`
11. `jido_con-5hk` `[G21] Shopify Connector`
12. `jido_con-ru0` `[G22] Stripe Connector`
13. `jido_con-te1` `[G23] Zoom Connector`
14. `jido_con-n1t` `[G24] Typeform Connector`
15. `jido_con-y2w` `[G25] Generic HTTP Policy And Connector`
16. `jido_con-9rh` `[G26] Mercury Banking Connector`
17. `jido_con-rfb` `[G27] Freshdesk Connector`
18. `jido_con-ka6` `[G28] Trello Connector`
19. `jido_con-3rz` `[G29] monday.com Connector`
20. `jido_con-id6` `[G30] Azure DevOps Connector`
21. `jido_con-e6u` `[G31] SFTP Connector`
22. `jido_con-q2q` `[G32] YouTube Data Connector`
23. `jido_con-fui` `[G33] Mailchimp Connector`
24. `jido_con-yoe` `[G34] ActiveCampaign Connector`
25. `jido_con-5nj` `[G35] Zoho CRM Connector`
26. `jido_con-l40` `[G36] Zoho Desk Connector`
27. `jido_con-6cn` `[G37] BigCommerce Connector`
28. `jido_con-jag` `[G38] Discord Connector`
29. `jido_con-8pw` `[G39] Nextcloud Connector`

`pi-connector-factory` resolves the next runnable leaf task as
`jido_con-jxj.2` via `bun run doctor`. The fresh connector work is chained
behind the Google release-readiness gate so the factory can keep taking one
task at a time without selecting unrelated connector work.

## Ranked Connector Build List

| Rank | Package | Provider | Status | Auth shape | First actions | First triggers/sensors | Why this rank |
| ---: | --- | --- | --- | --- | --- | --- | --- |
| 1 | `jido_connect_google` | Google shared foundation | shipped | OAuth2 user, service account, delegated service account | token exchange, refresh, scope catalog, service-account minting, transport helpers | n/a | Shared foundation is now the Google-family base package. |
| 2 | `jido_connect_google_sheets` | Google Sheets | shipped | OAuth2 user, service account later | spreadsheet/values read, append/update/clear values, sheet management | new row poll | Lindy top popular item; proves tabular data workflows. |
| 3 | `jido_connect_gmail` | Gmail | shipped | OAuth2 user | list/get/search messages and threads, send/draft/reply, labels, watch lifecycle | new email poll, Gmail watch | Core personal assistant workflow with restricted scopes and privacy boundaries. |
| 4 | `jido_connect_google_drive` | Google Drive | shipped | OAuth2 user, service account, delegated service account | files, folders, content download/export, permissions, comments, replies, revisions, shared drives, watch lifecycle | file changed poll, Drive watch channels | File context is essential for agents; shares Google auth foundation. |
| 5 | `jido_connect_google_calendar` | Google Calendar | shipped | OAuth2 user | calendars, calendar lists, events, ACLs, freebusy, availability, watch lifecycle | event changed poll, Calendar watch channels | Natural pair with Gmail and scheduling workflows. |
| 6 | `jido_connect_google_contacts` | Google Contacts | shipped | OAuth2 user | people, other contacts, directory, contact groups, batch writes | n/a | Completes core personal workspace context after Gmail/Calendar. |
| 7 | `jido_connect_google_analytics` | Google Analytics | shipped | OAuth2 user | GA4 reports, batch reports, realtime reports, metadata, property summaries | n/a | Product and marketing analytics connector is implemented. |
| 8 | `jido_connect_google_meet` | Google Meet | shipped | OAuth2 user | meeting spaces, conference records, recordings, transcripts | Workspace Events spike only | Package exists and tracked Beadwork scope is complete. |
| 9 | `jido_connect_google_search_console` | Google Search Console | shipped | OAuth2 user | sites, search analytics, sitemaps, URL inspection | n/a | SEO/search reporting package is implemented and its Beadwork epic is closed. |
| 10 | `jido_connect_calcom` | Cal.com | shipped | API key, OAuth2 user, webhook signing later | list event types, list bookings, get booking, cancel/reschedule booking | booking webhook lifecycle | Recovered package and hardening/webhook tasks are closed. |
| 11 | `jido_connect_google_docs` | Google Docs | shipped | OAuth2 user | get/create documents, batch update | Drive-backed change strategy later | Implemented and live read smoke tested. |
| 12 | `jido_connect_google_slides` | Google Slides | shipped | OAuth2 user | get/create presentations, batch update, pages, thumbnails | Drive-backed change strategy later | Implemented and live read smoke tested. |
| 13 | `jido_connect_google_forms` | Google Forms | shipped | OAuth2 user | list/get/create forms, batch update, response reads | Forms watches/triggers where supported | Implemented and live read smoke tested. |
| 14 | `jido_connect_google_tasks` | Google Tasks | shipped | OAuth2 user | task lists, task CRUD, move/clear tasks | task polling where viable | Implemented and live read smoke tested. |
| 15 | `jido_connect_hubspot` | HubSpot | shipped | OAuth2 app, private app token | search contacts, create/update contact, create note, create deal | contact/deal pollers and webhooks | Wave 4 Beadwork epic is closed and package exists. |
| 16 | `jido_connect_airtable` | Airtable | shipped | OAuth2, personal access token | list records, get record, create/update record, delete record | changed records poll design | Wave 4 Beadwork epic is closed and package exists. |
| 17 | `jido_connect_jira` | Jira / Jira Service Management | shipped | OAuth2, API token | search issues, create issue, update issue, add comment | issue webhook | Wave 5 Beadwork epic is closed and package exists. |
| 18 | `jido_connect_linear` | Linear | shipped | OAuth2, API key | search issues, create issue, update issue, add comment | issue webhook | Wave 5 Beadwork epic is closed and package exists. |
| 19 | `jido_connect_posthog` | PostHog | shipped | project API key, personal API key, self-hosted host override | capture event, batch events, evaluate feature flag, query HogQL, list insights | annotation or alert webhook later | Wave 6 Beadwork epic is closed and package exists. |
| 20 | `jido_connect_http` | Generic HTTP | queued | API key, bearer token, basic auth, custom headers | policy-gated request, get JSON, post JSON, transform response | n/a | New Beadwork epic `jido_con-y2w`; starts with SSRF/egress policy before arbitrary HTTP actions. |
| 21 | `jido_connect_webhook` | Generic Webhook | shipped | shared secret/HMAC, static token, unsigned dev mode | normalize inbound payload, verify signature | inbound webhook | Wave 4 Beadwork epic is closed and package exists. |
| 22 | `Jido.Connect.MCP` in core `jido_connect` | MCP bridge | shipped | host-provided endpoint credentials, OAuth/bearer passthrough | list tools, call tool | none | Narrow protocol bridge for MCP tools; not a separate package. |
| 23 | `jido_connect_slack` | Slack | shipped | OAuth2 bot/user | channels, messages, users, reactions, files, search, pins, scheduled messages | Events API webhooks | Existing collaboration reference connector. |
| 24 | `jido_connect_github` | GitHub | shipped | OAuth2 user, GitHub App installation | repositories, issues, PRs, Actions, files, releases, search, installations | polls and webhooks | Existing dev-work connector and GitHub App auth reference. |
| 25 | `jido_connect_mercury` | Mercury banking | queued | API token, read-only/read-write/custom tier metadata | list accounts, balances, transactions, recipients, invoices | transaction/invoice poll later | New Beadwork epic `jido_con-9rh`; start read-only and require strict policy for money movement. |
| 26 | `jido_connect_calendly` | Calendly | shipped | OAuth2 user, webhook signing | list events, get event, cancel event | invitee created webhook, invitee canceled webhook | Wave 4 Beadwork epic is closed and package exists. |
| 27 | `jido_connect_salesforce` | Salesforce | shipped | OAuth2, refresh token, connected app | query SOQL, get record, create/update lead, create task | sync trigger design | Wave 4 Beadwork epic is closed and package exists. |
| 28 | `jido_connect_microsoft` | Microsoft Graph foundation | queued | OAuth2 Microsoft Graph | auth, refresh, transport, pagination, error normalization | n/a | New Beadwork epic `jido_con-bcz`; unlocks Outlook, Calendar, and OneDrive. |
| 29 | `jido_connect_microsoft_outlook` | Microsoft Outlook Mail | queued | OAuth2 Microsoft Graph | list messages, get message, send email, create draft | new email poll | New Beadwork epic `jido_con-ntx`; mirrors Gmail for Microsoft tenants. |
| 30 | `jido_connect_microsoft_calendar` | Microsoft Calendar | queued | OAuth2 Microsoft Graph | list events, create/update event, find availability | event changed poll | New Beadwork epic `jido_con-y3t`; completes Microsoft assistant workflow. |
| 31 | `jido_connect_microsoft_onedrive` | OneDrive | queued | OAuth2 Microsoft Graph | search files, download file, upload file, permissions | delta change poll design | New Beadwork epic `jido_con-tyr`; complements Microsoft 365 file workflows. |
| 32 | `jido_connect_zendesk` | Zendesk | queued | OAuth2, API token | search tickets, create ticket, update ticket, add comment | ticket updated webhook | New Beadwork epic `jido_con-17g`; strong support category anchor. |
| 33 | `jido_connect_intercom` | Intercom | queued | OAuth2, access token | search contacts, create conversation, reply to conversation | conversation/contact webhook | New Beadwork epic `jido_con-zya`; support and sales assistant workflows. |
| 34 | `jido_connect_freshdesk` | Freshdesk | queued | API key, OAuth later | list tickets, create ticket, update ticket, add note | ticket webhook/poll strategy | New Beadwork epic `jido_con-rfb`; support breadth with simpler API-key auth. |
| 35 | `jido_connect_notion` | Notion | queued | OAuth2, internal integration token | search pages, read page, create page, update database item | change strategy note | New Beadwork epic `jido_con-fe6`; high agent utility for knowledge/workspace data. |
| 36 | `jido_connect_asana` | Asana | queued | OAuth2, personal access token | list tasks, create task, update task, add comment | task changed webhook | New Beadwork epic `jido_con-aje`; common task management automation. |
| 37 | `jido_connect_trello` | Trello | queued | OAuth1/API key token | list cards, create card, move card, comment | card changed webhook | New Beadwork epic `jido_con-ka6`; lightweight project workflow. |
| 38 | `jido_connect_monday` | monday.com | queued | API token, OAuth later | list boards, create item, update column value | item changed webhook/poll | New Beadwork epic `jido_con-3rz`; broad ops use. |
| 39 | `jido_connect_gitlab` | GitLab | queued | OAuth2, personal access token | list issues, create issue, comment, list merge requests | issue/MR/pipeline webhook | New Beadwork epic `jido_con-cja`; natural follow-on to GitHub. |
| 40 | `jido_connect_azure_devops` | Azure DevOps | queued | OAuth2/PAT | list work items, create work item, update work item | work item/PR/build service hooks | New Beadwork epic `jido_con-id6`; enterprise dev workflow. |
| 41 | `jido_connect_shopify` | Shopify | queued | OAuth2 app, admin API token | list orders, get order, guarded customer/product writes | order/customer/product webhook | New Beadwork epic `jido_con-5hk`; commerce anchor. |
| 42 | `jido_connect_stripe` | Stripe | queued | API key, restricted key, webhook signing | list customers, invoices, subscriptions, guarded low-risk writes | payment/invoice/customer webhook | New Beadwork epic `jido_con-ru0`; requires strict safety defaults. |
| 43 | `jido_connect_sftp` | SFTP | queued | password, key-based auth | list files, download file, upload file, move file | new file poll | New Beadwork epic `jido_con-e6u`; proves non-HTTP credentials and host-key policy. |
| 44 | `jido_connect_nextcloud` | Nextcloud | shipped | app password, OAuth2 where configured | list/search/get/download/upload/move/copy/delete files, create folders, shares, sharee search, Office launch metadata | file polling later | Beadwork epic `jido_con-8pw`; implemented as a single provider package with modular WebDAV, OCS sharing, and Office internals. |
| 45 | `jido_connect_zoom` | Zoom | queued | OAuth2 server-to-server/user | list meetings, create meeting, get recording | meeting ended webhook, recording ready webhook | New Beadwork epic `jido_con-te1`; meetings and assistant workflows. |
| 46 | `jido_connect_typeform` | Typeform | queued | OAuth2, personal token, webhook signing | list forms, get responses | new response webhook | New Beadwork epic `jido_con-n1t`; forms are high-value lead/support triggers. |
| 47 | `jido_connect_youtube` | YouTube Data API | queued | OAuth2/API key | search videos, get video, list channel videos | new channel video poll | New Beadwork epic `jido_con-q2q`; complements the Google family. |
| 48 | `jido_connect_mailchimp` | Mailchimp | queued | OAuth2/API key | list audiences, add/update member, create campaign | subscriber event webhook | New Beadwork epic `jido_con-fui`; marketing automation category. |
| 49 | `jido_connect_activecampaign` | ActiveCampaign | queued | API key | search contacts, create/update contact, add tag | contact/deal webhook/poll | New Beadwork epic `jido_con-yoe`; marketing/sales automation. |
| 50 | `jido_connect_zoho_crm` | Zoho CRM | queued | OAuth2 | search leads, create lead, update contact | record changed poll | New Beadwork epic `jido_con-5nj`; CRM breadth. |
| 51 | `jido_connect_zoho_desk` | Zoho Desk | queued | OAuth2 | list tickets, create ticket, update ticket | ticket changed poll | New Beadwork epic `jido_con-l40`; support breadth. |
| 52 | `jido_connect_bigcommerce` | BigCommerce | queued | OAuth2/API token | list orders, get order, guarded customer/product writes | order/customer/product webhook | New Beadwork epic `jido_con-6cn`; commerce breadth. |
| 53 | `jido_connect_discord` | Discord | queued | OAuth2 bot | list channels, send message | webhook/interaction strategy | New Beadwork epic `jido_con-jag`; collaboration breadth after Slack/Teams. |

## Suggested Build Waves

### Wave 0: Seeded Reference Connectors

- GitHub
- Slack
- MCP bridge

These already exist and should remain the reference connectors for auth
alternatives, generated Jido modules, webhook normalization, plugin availability,
and provider client organization.

### Wave 1: Shipped Google And Assistant Core

- Google OAuth foundation
- Google Sheets
- Gmail
- Google Drive
- Google Calendar

This wave is implemented. It proves shared OAuth app setup, sensitive scopes,
refresh handling, cross-package auth reuse, and high-frequency assistant
workflows.

### Wave 2: Current Google Expansion

- Google Contacts
- Google Analytics
- Google Meet
- Google Search Console

Contacts, Analytics, Meet, and Search Console are implemented, and their
Beadwork parents are closed.
The remaining Google work is cross-product hardening, catalog/scope audit,
demo integration, and release-readiness documentation.

### Wave 3: Ready Google Workspace Tail

- Google Docs
- Google Slides
- Google Forms
- Google Tasks

This wave is implemented. Docs, Slides, Forms, and Tasks have all tracked
Beadwork child tasks closed and passed live read-oriented smoke tests using the
project-owned Google OAuth client.

### Wave 4: Scheduling, Sales, And Data

- Cal.com hardening and webhooks
- HubSpot
- Airtable
- Generic Webhook
- Calendly
- Salesforce
- Generic HTTP deferred pending policy

This wave proves scheduling APIs, CRM object models, search/list/create/update
patterns, webhook/poll parity, generic long-tail API access, and richer schema
metadata. Cal.com, HubSpot, Airtable, Generic Webhook, Calendly, and
Salesforce are implemented and their Beadwork epics are closed. The standalone
Generic HTTP connector remains deferred because core HTTP transport helpers
already exist and arbitrary outbound HTTP needs a separate policy/SSRF design
pass.

### Wave 5: Work Management And Chat Handoffs

- Jira
- Linear
- GitLab
- Azure DevOps

This wave proves issue normalization, threaded comments, assignees/statuses,
webhook dedupe, and `jido_chat` handoff workflows such as "turn this
conversation into an issue" or "summarize this issue thread."
Jira and Linear are implemented and their Beadwork epics are closed. GitLab is
queued as `jido_con-cja`; Azure DevOps remains a planned follow-on.

### Wave 6: Product Analytics And Generic Bridge

- PostHog
- Generic HTTP
- Generic Webhook
- MCP bridge expansion

This wave proves analytics/query actions, feature-flag checks, and the generic
long-tail bridge family. Keep HTTP, Webhook, and MCP as separate provider
packages, but make them share auth, credential lease, policy, transport, error,
and catalog contracts.
PostHog and Generic Webhook are implemented. Generic HTTP was deferred until
the security policy surface was explicit; it is now queued as policy-first
work in `jido_con-y2w`.

### Wave 7: Microsoft Graph And 365

- Microsoft Graph foundation
- Microsoft Outlook Mail
- Microsoft Calendar
- Microsoft OneDrive

This is the next fresh connector family in Beadwork. Build the shared Graph
foundation first, then Outlook, Calendar, and OneDrive. The epics are
intentionally chained behind the cross-Google release-readiness gate so the
factory can execute one leaf task at a time.

### Wave 8: Queued Support, Work, Commerce, Payments, And Intake

- Zendesk
- Intercom
- Notion
- Asana
- GitLab
- Shopify
- Stripe
- Zoom
- Typeform

This wave is now queued in Beadwork after Microsoft OneDrive. It rounds out
support, knowledge, work-management, developer, commerce, payments, meetings,
and intake/form workflows. Stripe and Shopify writes should start low-risk and
require explicit policy/destructive metadata for higher-risk mutations.

### Wave 9: Queued Remaining Roadmap

- Generic HTTP policy and connector
- Mercury
- Freshdesk
- Trello
- monday.com
- Azure DevOps
- SFTP
- YouTube
- Mailchimp
- ActiveCampaign
- Zoho CRM
- Zoho Desk
- BigCommerce
- Discord

These complete the current `CONNECT_TODO.md` roadmap in Beadwork. The queue is
still dependency-chained, with Generic HTTP starting only after Typeform and
Discord currently at the end of the roadmap chain.

## Core Work Remaining While Scaling

- Keep Beadwork aligned with package state; close stale completed epics and keep
  ready epics split into leaf tasks before handing them to Pi.
- Standard pagination and cursor helpers across non-Google providers.
- Standard rate-limit and retry metadata in provider errors.
- Dynamic scope requirements at action and input level for every new provider.
- Connection health checks and availability diagnostics.
- Webhook verification helpers with replay/dedupe contracts for non-Google
  providers.
- Finance-grade policy defaults for high-risk write actions.
- Chat handoff conventions for work-management connectors that pair with
  `jido_chat`.
- Provider test harness helpers for Req stubs, OAuth callbacks, app manifests,
  and webhook fixtures.
- Demo UI that can host many integrations without custom pages per provider.
