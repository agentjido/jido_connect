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
| 9 | `jido_connect_google_search_console` | Google Search Console | in_progress | OAuth2 user | scaffold landed; site, analytics, sitemap, URL inspection actions remain | n/a | SEO/search reporting package exists but Beadwork tasks remain open. |
| 10 | `jido_connect_calcom` | Cal.com | queued | API key, OAuth2 user, webhook signing later | list event types, list bookings, get booking, cancel/reschedule booking | booking webhook lifecycle later | Recovered package exists; Beadwork hardening/webhook queue now starts with fixing package tests. |
| 11 | `jido_connect_google_docs` | Google Docs | shipped | OAuth2 user | get/create documents, batch update | Drive-backed change strategy later | Implemented and live read smoke tested. |
| 12 | `jido_connect_google_slides` | Google Slides | shipped | OAuth2 user | get/create presentations, batch update, pages, thumbnails | Drive-backed change strategy later | Implemented and live read smoke tested. |
| 13 | `jido_connect_google_forms` | Google Forms | shipped | OAuth2 user | list/get/create forms, batch update, response reads | Forms watches/triggers where supported | Implemented and live read smoke tested. |
| 14 | `jido_connect_google_tasks` | Google Tasks | shipped | OAuth2 user | task lists, task CRUD, move/clear tasks | task polling where viable | Implemented and live read smoke tested. |
| 15 | `jido_connect_hubspot` | HubSpot | queued | OAuth2 app, private app token | search contacts, create/update contact, create note, create deal | new contact poll, deal stage change poll | Wave 4 Beadwork epic and leaf tasks are queued. |
| 16 | `jido_connect_airtable` | Airtable | queued | OAuth2, personal access token | list records, get record, create/update record, delete record | changed records poll | Wave 4 Beadwork epic and leaf tasks are queued. |
| 17 | `jido_connect_jira` | Jira / Jira Service Management | queued | OAuth2, API token | search issues, create issue, update issue, add comment | issue created/updated webhook | Wave 5 Beadwork epic and leaf tasks are queued. |
| 18 | `jido_connect_linear` | Linear | queued | OAuth2, API key | search issues, create issue, update issue, add comment | issue created/updated webhook | Wave 5 Beadwork epic and leaf tasks are queued. |
| 19 | `jido_connect_posthog` | PostHog | queued | project API key, personal API key, self-hosted host override | capture event, batch events, evaluate feature flag, query HogQL, list insights | annotation or alert webhook later | Wave 6 Beadwork epic and leaf tasks are queued. |
| 20 | `jido_connect_http` | Generic HTTP | deferred | API key, bearer token, basic auth, custom headers | request, get JSON, post JSON, transform response | n/a | Core HTTP helpers already exist; standalone arbitrary HTTP connector is deferred pending policy/SSRF review. |
| 21 | `jido_connect_webhook` | Generic Webhook | queued | shared secret/HMAC, static token, unsigned dev mode | normalize inbound payload, verify signature | inbound webhook | Wave 4 Beadwork epic and leaf tasks are queued. |
| 22 | `jido_connect_mcp` | MCP bridge | shipped | host-provided endpoint credentials, OAuth/bearer passthrough | list tools, call tool | resource/prompt discovery later | Protocol bridge for MCP servers; pairs with HTTP/Webhook as the generic bridge family. |
| 23 | `jido_connect_slack` | Slack | shipped | OAuth2 bot/user | channels, messages, users, reactions, files, search, pins, scheduled messages | Events API webhooks | Existing collaboration reference connector. |
| 24 | `jido_connect_github` | GitHub | shipped | OAuth2 user, GitHub App installation | repositories, issues, PRs, Actions, files, releases, search, installations | polls and webhooks | Existing dev-work connector and GitHub App auth reference. |
| 25 | `jido_connect_mercury` | Mercury banking | planned | API token, read-only/read-write/custom tier metadata | list accounts, balances, transactions, recipients, invoices | transaction/invoice poll later | Finance/ops connector; start read-only and require strict policy for money movement. |
| 26 | `jido_connect_calendly` | Calendly | queued | OAuth2 user, webhook signing | list events, get event, cancel event | invitee created webhook, invitee canceled webhook | Wave 4 Beadwork epic and leaf tasks are queued after Cal.com hardening. |
| 27 | `jido_connect_salesforce` | Salesforce | queued | OAuth2, refresh token, connected app | query SOQL, get record, create/update lead, create task | record changed poll/webhook later | Wave 4 Beadwork epic and leaf tasks are queued. |
| 28 | `jido_connect_microsoft_outlook` | Microsoft Outlook Mail | planned | OAuth2 Microsoft Graph | list messages, get message, send email, create draft | new email poll | Mirrors Gmail for Microsoft tenants. |
| 29 | `jido_connect_microsoft_calendar` | Microsoft Calendar | planned | OAuth2 Microsoft Graph | list events, create/update event, find availability | event changed poll | Completes Microsoft assistant workflow. |
| 30 | `jido_connect_microsoft_onedrive` | OneDrive | planned | OAuth2 Microsoft Graph | search files, download file, upload file | new file poll | Complements Outlook and Microsoft 365 file workflows. |
| 31 | `jido_connect_zendesk` | Zendesk | planned | OAuth2, API token | search tickets, create ticket, update ticket, add comment | new ticket poll, ticket updated webhook | Strong support category anchor from Lindy's support list. |
| 32 | `jido_connect_intercom` | Intercom | planned | OAuth2, access token | search contacts, create conversation, reply to conversation | conversation created webhook | Support and sales assistant workflows. |
| 33 | `jido_connect_freshdesk` | Freshdesk | planned | API key, OAuth later | list tickets, create ticket, update ticket, add note | new ticket poll | Support breadth; simpler API-key connector. |
| 34 | `jido_connect_notion` | Notion | planned | OAuth2, internal integration token | search pages, read page, create page, update database item | database item changed poll | High agent utility for knowledge/workspace data. |
| 35 | `jido_connect_asana` | Asana | planned | OAuth2, personal access token | list tasks, create task, update task, add comment | task changed webhook | Common task management automation. |
| 36 | `jido_connect_trello` | Trello | planned | OAuth1/API key token | list cards, create card, move card, comment | card changed webhook | Lightweight project workflow. |
| 37 | `jido_connect_monday` | monday.com | planned | API token, OAuth later | list boards, create item, update column value | item changed webhook/poll | Appears in Lindy sales list; broad ops use. |
| 38 | `jido_connect_gitlab` | GitLab | planned | OAuth2, personal access token | list issues, create issue, comment, list merge requests | issue/MR webhook | Natural follow-on to GitHub. |
| 39 | `jido_connect_azure_devops` | Azure DevOps | planned | OAuth2/PAT | list work items, create work item, update work item | work item updated webhook | Enterprise dev workflow; visible in Lindy catalog. |
| 40 | `jido_connect_shopify` | Shopify | planned | OAuth2 app, admin API token | list orders, get order, update order, create customer | order created webhook | Commerce anchor; Lindy lists Shopify OAuth. |
| 41 | `jido_connect_stripe` | Stripe | planned | API key, restricted key, webhook signing | list customers, create customer, create invoice, get payment | payment succeeded webhook | Payments/revenue operations; same policy tier as Mercury. |
| 42 | `jido_connect_sftp` | SFTP | planned | password, key-based auth | list files, download file, upload file, move file | new file poll | Lindy lists password and key SFTP; proves non-HTTP credentials. |
| 43 | `jido_connect_zoom` | Zoom | planned | OAuth2 server-to-server/user | list meetings, create meeting, get recording | meeting ended webhook, recording ready webhook | Meetings and assistant workflows. |
| 44 | `jido_connect_typeform` | Typeform | planned | OAuth2, personal token, webhook signing | list forms, get responses | new response webhook | Forms are high-value lead/support triggers. |
| 45 | `jido_connect_youtube` | YouTube Data API | later | OAuth2/API key | search videos, get video, list channel videos | new channel video poll | Complements the Google family once core Google auth is proven. |
| 46 | `jido_connect_mailchimp` | Mailchimp | later | OAuth2/API key | list audiences, add/update member, create campaign | subscriber event webhook | Marketing automation category. |
| 47 | `jido_connect_activecampaign` | ActiveCampaign | later | API key | search contacts, create/update contact, add tag | contact updated webhook/poll | Marketing/sales automation. |
| 48 | `jido_connect_zoho_crm` | Zoho CRM | later | OAuth2 | search leads, create lead, update contact | record changed poll | Lindy marketing list includes Zoho CRM. |
| 49 | `jido_connect_zoho_desk` | Zoho Desk | later | OAuth2 | list tickets, create ticket, update ticket | ticket changed poll | Lindy support list includes Zoho Desk. |
| 50 | `jido_connect_bigcommerce` | BigCommerce | later | OAuth2/API token | list orders, get order, update order | order webhook | Commerce breadth; Lindy visible in catalog. |
| 51 | `jido_connect_discord` | Discord | later | OAuth2 bot | list channels, send message | message webhook/gateway later | Collaboration breadth after Slack/Teams. |

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

Contacts, Analytics, and Meet are implemented. Search Console is the active
unfinished Google package and has remaining Beadwork tasks queued.

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
- Generic HTTP
- Generic Webhook
- Calendly and Salesforce after the first Wave 4 packages stabilize

This wave proves scheduling APIs, CRM object models, search/list/create/update
patterns, webhook/poll parity, generic long-tail API access, and richer schema
metadata. Beadwork now has queued epics and leaf tasks for Cal.com hardening,
HubSpot, Airtable, Generic HTTP, and Generic Webhook. Cal.com should go first
because its recovered package currently exposes test/dependency hardening work.
The standalone Generic HTTP connector is now deferred because core HTTP
transport helpers already exist and arbitrary outbound HTTP needs a separate
policy/SSRF design pass. Generic Webhook remains queued because generic inbound
trigger handling is lower risk and complements provider-specific webhooks.
Calendly and Salesforce epics are queued for later Wave 4 scheduling/CRM
coverage.

### Wave 5: Work Management And Chat Handoffs

- Jira
- Linear
- GitLab
- Azure DevOps

This wave proves issue normalization, threaded comments, assignees/statuses,
webhook dedupe, and `jido_chat` handoff workflows such as "turn this
conversation into an issue" or "summarize this issue thread."
Jira and Linear epics are queued with leaf tasks.

### Wave 6: Product Analytics And Generic Bridge

- PostHog
- Generic HTTP
- Generic Webhook
- MCP bridge expansion

This wave proves analytics/query actions, feature-flag checks, and the generic
long-tail bridge family. Keep HTTP, Webhook, and MCP as separate provider
packages, but make them share auth, credential lease, policy, transport, error,
and catalog contracts.
PostHog and Generic Webhook are queued. Generic HTTP is deferred until the
security policy surface is explicit.

### Wave 7: Support, Commerce, Payments, And Finance

- Zendesk
- Intercom
- Freshdesk
- Mercury
- Stripe
- Shopify

This wave rounds out support and revenue operations. Mercury and Stripe should
start with read-only or low-risk actions and require explicit host policy for
money movement, payment creation, or account mutation.

### Wave 8: Additional Breadth

- Notion
- Asana
- Trello
- monday.com
- SFTP
- Zoom
- Typeform
- Mailchimp
- ActiveCampaign
- Zoho CRM
- Zoho Desk

These remain useful breadth once the highest-signal assistant, sales, work,
analytics, and bridge packages have established repeatable patterns.

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
